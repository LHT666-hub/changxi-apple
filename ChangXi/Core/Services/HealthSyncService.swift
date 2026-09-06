import Foundation

/// 健康读数**双向同步**核心（Task #25）。
///
/// 设计原则（硬性）：
/// 1. **本地优先、上行 best-effort**：本地写入由调用方同步完成且必须成功；云端同步是后台尽力而为，
///    失败只把该读数标记为「待同步 / 同步失败」，绝不影响本地记录。
/// 2. **离线零请求**：`AppConfiguration.useRemoteAPI == false`（含 `--ui-testing`）时，所有方法直接返回，
///    不发出任何真实网络请求，保证 CI（无后端）不超时、纯本地演示完全可用。
/// 3. **单一患者标识**：统一用 ``PatientContext/effectiveID(_:)``，不引入第二套 patientID。
///
/// 同步状态存于 ``HealthReading/syncState``（随 ``AppStore`` 本地 JSON 持久化），UI 据此显示小图标与重试入口。
/// 本类**不加 `@Observable`**：状态即 AppStore 里的读数，视图通过观察 AppStore 自动刷新。
@MainActor
final class HealthSyncService {
    static let shared = HealthSyncService()
    private init() {}

    // MARK: - 异常阈值（决定是否触发玄同会诊工作流）

    /// 判断一条读数是否「异常」到需要触发玄同会诊工作流。
    ///
    /// 阈值（保守，仅用于决定是否发起会诊，非医学诊断）：
    /// - 血压：收缩压 ≥ 140 或 舒张压 ≥ 90
    /// - 血糖：≥ 7.0 或 < 3.9 mmol/L
    /// - 体重：不触发（单次体重无急性风险）
    ///
    /// 常规读数仍会归档为 health-record + measurement，只是不跑工作流、不弹进度页。
    nonisolated static func triggersWorkflow(_ reading: HealthReading) -> Bool {
        switch reading.kind {
        case .pressure:
            return reading.value >= 140 || (reading.secondary ?? 0) >= 90
        case .glucose:
            return reading.value >= 7.0 || reading.value < 3.9
        case .weight:
            return false
        }
    }

    /// 构造事件 `payload`（键用 snake_case 字面量，见 ``EventPayloadValue``）。
    /// 血压放 `{systolic, diastolic}`，血糖 / 体重放 `{value, unit}`；备注非空时作为 `symptom`。
    nonisolated static func payload(for reading: HealthReading) -> [String: EventPayloadValue] {
        var payload: [String: EventPayloadValue] = [:]
        switch reading.kind {
        case .pressure:
            payload["systolic"] = .int(Int(reading.value))
            if let secondary = reading.secondary { payload["diastolic"] = .int(Int(secondary)) }
        case .glucose:
            payload["value"] = .double(reading.value)
            payload["unit"] = .string("mmol/L")
        case .weight:
            payload["value"] = .double(reading.value)
            payload["unit"] = .string("kg")
        }
        let symptom = reading.note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !symptom.isEmpty { payload["symptom"] = .string(symptom) }
        return payload
    }

    // MARK: - 上行

    /// 上行同步一条读数：建健康记录 + 追加测量；若异常则再触发工作流事件。
    ///
    /// 全程 best-effort：任一步失败即把读数标记为 ``SyncState/failed`` 并返回 nil，**不抛出**、不影响本地。
    /// - Returns: 触发工作流时返回 ``EventWorkflowResult``（含最终 `workflow`，供进度页展示）；否则 / 失败返回 nil。
    @discardableResult
    func uploadReading(_ reading: HealthReading, store: AppStore, patientID: String) async -> EventWorkflowResult? {
        guard AppConfiguration.useRemoteAPI else { return nil }
        setState(reading.id, .syncing, in: store)
        do {
            // ① 健康记录（重试时若已有云端 record_id 则复用，避免重复建档）。
            let recordID: String
            if let existing = reading.remoteRecordID {
                recordID = existing
            } else {
                var content: [String: EventPayloadValue] = ["display": .string(reading.display)]
                if !reading.note.isEmpty { content["note"] = .string(reading.note) }
                let record = try await HealthRecordService().createRecord(
                    patientID: patientID,
                    recordType: HealthMetricMapping.recordType(reading.kind),
                    title: "\(reading.kind.rawValue)记录 · \(reading.display)",
                    content: content,
                    source: "changxi_ios",
                    recordedAt: reading.date
                )
                recordID = record.id
                setRemoteRecordID(reading.id, record.id, in: store)
            }

            // ② 追加测量。
            try await HealthRecordService().appendMeasurement(
                recordID: recordID,
                measurementType: HealthMetricMapping.measurementType(reading.kind),
                value: reading.value,
                secondaryValue: reading.secondary,
                unit: HealthMetricMapping.unit(reading.kind),
                measuredAt: reading.date,
                patientID: patientID
            )

            // ③ 异常读数：触发玄同会诊工作流（`POST /api/events` 阻塞至完成）。
            var result: EventWorkflowResult?
            if Self.triggersWorkflow(reading) {
                let eventResult = try await EventWorkflowService().reportEvent(
                    patientID: patientID,
                    eventType: HealthMetricMapping.eventType(reading.kind),
                    payload: Self.payload(for: reading),
                    occurredAt: reading.date
                )
                result = eventResult
                if let eventID = eventResult.eventID { setRemoteEventID(reading.id, eventID, in: store) }
            }

            setState(reading.id, .synced, in: store)
            return result
        } catch {
            // 含 CancellationError 与 APIError：统一标记失败，交 UI 提供重试。
            setState(reading.id, .failed, in: store)
            return nil
        }
    }

    /// 把一条读数加入后台上行队列（fire-and-forget）。先标记「待同步」，再异步执行 ``uploadReading``。
    ///
    /// 用于常规读数与「重试同步」入口：不阻断用户、不弹窗。离线时直接返回。
    func enqueueUpload(_ reading: HealthReading, store: AppStore, patientID: String) {
        guard AppConfiguration.useRemoteAPI else { return }
        setState(reading.id, .pending, in: store)
        Task { @MainActor in
            await uploadReading(reading, store: store, patientID: patientID)
        }
    }

    /// 单向归档（计划 / 用药 / 记忆）：仅本地 → 云端 health-record，不做下行合并。
    ///
    /// `recordType` 分别用 `daily_plan` / `medication` / `memory`。best-effort，失败静默。
    func archive(recordType: String, title: String, content: [String: EventPayloadValue], patientID: String) async {
        guard AppConfiguration.useRemoteAPI else { return }
        do {
            try await HealthRecordService().createRecord(
                patientID: patientID,
                recordType: recordType,
                title: title,
                content: content,
                source: "changxi_ios",
                recordedAt: .now
            )
        } catch {
            // 静默：归档失败不影响本地。
        }
    }

    // MARK: - 下行

    /// 进入健康页时拉取云端测量历史，与本地 readings 合并去重（换设备 / 重装后数据不丢）。
    ///
    /// **合并策略：本地优先**。判重键 = `kind + value(±0.01) + secondary(±0.01) + date(±60s)`；
    /// 本地已存在的云端测量跳过；云端独有的追加到本地（`note = "来自云端同步"`、`syncState = .synced`）。
    /// best-effort：失败静默，绝不影响本地数据。离线时直接返回。
    func pullRemote(store: AppStore, patientID: String) async {
        guard AppConfiguration.useRemoteAPI else { return }
        do {
            let page = try await PatientService().getMeasurements(patientID: patientID, page: 1, size: 100)
            guard let measurements = page.measurements, !measurements.isEmpty else { return }
            var toAdd: [HealthReading] = []
            for measurement in measurements {
                guard let kind = HealthMetricMapping.kind(forMeasurementType: measurement.measurementType) else { continue }
                let date = Self.date(fromISO: measurement.measuredAt) ?? .now
                let pool = store.data.readings + toAdd
                let duplicated = pool.contains { existing in
                    existing.kind == kind
                        && abs(existing.value - measurement.value) < 0.01
                        && abs((existing.secondary ?? 0) - (measurement.secondaryValue ?? 0)) < 0.01
                        && abs(existing.date.timeIntervalSince(date)) < 60
                }
                if duplicated { continue }
                var reading = HealthReading(kind: kind, value: measurement.value, secondary: measurement.secondaryValue, date: date, note: "来自云端同步")
                reading.syncState = .synced
                toAdd.append(reading)
            }
            if !toAdd.isEmpty { store.data.readings.append(contentsOf: toAdd) }
        } catch {
            // 静默：下行失败不影响本地数据。
        }
    }

    // MARK: - 删除同步（缺口说明）

    /// 本地删除读数的云端同步策略。
    ///
    /// - Important: **后端健康记录 / 测量没有 DELETE 端点**，本地删除无法同步到云端。
    ///   因此本地删除仅移除本地记录（由 ``MetricDetailView`` 直接完成），云端副本保留为历史归档。
    ///   此方法仅作语义占位与文档说明，不发起任何请求。
    func noteLocalDeletionNotSynced(_ reading: HealthReading) {
        // 后端无 health-record / measurement DELETE 端点 → 无法同步删除，仅本地移除。
    }

    // MARK: - 私有：状态写回（触发 AppStore 持久化与视图刷新）

    private func setState(_ id: UUID, _ state: SyncState, in store: AppStore) {
        if let index = store.data.readings.firstIndex(where: { $0.id == id }) {
            store.data.readings[index].syncState = state
        }
    }

    private func setRemoteRecordID(_ id: UUID, _ recordID: String, in store: AppStore) {
        if let index = store.data.readings.firstIndex(where: { $0.id == id }) {
            store.data.readings[index].remoteRecordID = recordID
        }
    }

    private func setRemoteEventID(_ id: UUID, _ eventID: String, in store: AppStore) {
        if let index = store.data.readings.firstIndex(where: { $0.id == id }) {
            store.data.readings[index].remoteEventID = eventID
        }
    }

    // MARK: - 工具

    /// 容错解析后端 ISO-8601 时间字符串（含 / 不含小数秒）；无法解析返回 nil。
    ///
    /// `nonisolated` 以便任意上下文调用；每次新建 formatter（调用频率低，成本可忽略），
    /// 避免访问 actor 隔离的静态属性。
    nonisolated static func date(fromISO string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractional.date(from: trimmed) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: trimmed)
    }
}
