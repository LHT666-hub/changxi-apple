import Foundation
import Observation

struct AssistantFillContext: Identifiable {
    let id: UUID
    var title: String
    var draft: String
    let fill: @MainActor (String) -> Bool
}

@MainActor @Observable
final class AssistantCoordinator {
    var registeredContext: AssistantFillContext?
    var activeContext: AssistantFillContext?

    func register(id: UUID, title: String, draft: String, fill: @escaping @MainActor (String) -> Bool) {
        registeredContext = AssistantFillContext(id: id, title: title, draft: draft, fill: fill)
    }

    func update(id: UUID, title: String, draft: String, fill: @escaping @MainActor (String) -> Bool) {
        guard registeredContext?.id == id else { return }
        registeredContext = AssistantFillContext(id: id, title: title, draft: draft, fill: fill)
    }

    func unregister(id: UUID) {
        if registeredContext?.id == id { registeredContext = nil }
    }

    @discardableResult
    func activateRegistered() -> Bool {
        guard let registeredContext else { return false }
        activeContext = registeredContext
        return true
    }

    func activateGeneral() {
        activeContext = nil
    }

    var initialPrompt: String {
        guard let context = activeContext else { return "" }
        let draft = context.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        return draft.isEmpty ? "" : "请帮我完善\(context.title)：\(draft)"
    }

    func fillActive(with value: String) -> Bool {
        activeContext?.fill(value) ?? false
    }

    func finish() {
        activeContext = nil
    }
}

enum AssistantFillParser {
    static func bloodPressure(from input: String) -> (systolic: String, diastolic: String)? {
        let normalized = input.replacingOccurrences(of: "／", with: "/")
        let pattern = #"(?<!\d)(\d{2,3})\s*[/\-]\s*(\d{2,3})(?!\d)"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(normalized.startIndex..., in: normalized)
        let matches = expression.matches(in: normalized, range: range)
        guard matches.count == 1,
              let systolicRange = Range(matches[0].range(at: 1), in: normalized),
              let diastolicRange = Range(matches[0].range(at: 2), in: normalized),
              let systolic = Int(normalized[systolicRange]),
              let diastolic = Int(normalized[diastolicRange]),
              (40...300).contains(systolic),
              (20...200).contains(diastolic),
              diastolic < systolic else { return nil }
        return (String(systolic), String(diastolic))
    }

    static func singleNumber(from input: String, range: ClosedRange<Double>) -> String? {
        let pattern = #"(?<!\d)(\d+(?:[.,]\d+)?)(?!\d)"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
        let normalized = input.replacingOccurrences(of: ",", with: ".")
        let sourceRange = NSRange(normalized.startIndex..., in: normalized)
        let matches = expression.matches(in: normalized, range: sourceRange)
        guard matches.count == 1,
              let valueRange = Range(matches[0].range(at: 1), in: normalized),
              let value = Double(normalized[valueRange]),
              value.isFinite,
              range.contains(value) else { return nil }
        return String(normalized[valueRange])
    }
}

struct HealthReading: Codable, Identifiable {
    var id = UUID()
    var kind: MetricKind
    var value: Double
    var secondary: Double?
    var date: Date = .now
    var note = ""
    /// 云端健康记录 ID（`POST /api/health-records` 返回）。未同步 / 离线时为 nil。Task #25 新增。
    var remoteRecordID: String?
    /// 触发的工作流事件 ID（`POST /api/events` 返回）。未触发 / 离线时为 nil。Task #25 新增。
    var remoteEventID: String?
    /// 云端同步状态；nil 表示仅本机记录（从未尝试同步）。Task #25 新增，Optional 以兼容旧本地 JSON。
    var syncState: SyncState?
    var display: String {
        if let secondary { return "\(Int(value))/\(Int(secondary))" }
        return value.formatted(.number.precision(.fractionLength(kind == .pressure ? 0 : 1)))
    }
}

enum MetricKind: String, Codable, CaseIterable, Identifiable {
    case pressure = "血压", glucose = "血糖", weight = "体重"
    var id: Self { self }
    var unit: String { switch self { case .pressure: "mmHg"; case .glucose: "mmol/L"; case .weight: "kg" } }
    var icon: String { switch self { case .pressure: "heart.fill"; case .glucose: "drop.fill"; case .weight: "scalemass.fill" } }
    var inputRange: ClosedRange<Double> { switch self { case .pressure: 40...300; case .glucose: 0.5...50; case .weight: 10...400 } }
}

/// 中国成人 BMI 分级（WS/T 428—2013）。BMI 是由身高和体重推导出的指标，不作为一条独立测量记录保存。
enum BMIClassification: String, CaseIterable, Identifiable, Equatable {
    case underweight = "体重过低"
    case normal = "体重正常"
    case overweight = "超重"
    case obesity = "肥胖"

    var id: Self { self }

    var rangeDescription: String {
        switch self {
        case .underweight: "BMI < 18.5"
        case .normal: "18.5 ≤ BMI < 24.0"
        case .overweight: "24.0 ≤ BMI < 28.0"
        case .obesity: "BMI ≥ 28.0"
        }
    }

    static func classification(for bmi: Double) -> Self {
        switch bmi {
        case ..<18.5: .underweight
        case ..<24.0: .normal
        case ..<28.0: .overweight
        default: .obesity
        }
    }
}

struct BMIResult: Equatable {
    let value: Double
    let classification: BMIClassification

    var display: String {
        value.formatted(.number.precision(.fractionLength(1)))
    }

    static func calculate(weightKilograms: Double, heightCentimeters: Double) -> Self? {
        guard weightKilograms.isFinite, weightKilograms > 0,
              heightCentimeters.isFinite, heightCentimeters > 0 else { return nil }
        let heightMeters = heightCentimeters / 100
        let roundedValue = ((weightKilograms / (heightMeters * heightMeters)) * 10).rounded() / 10
        return BMIResult(
            value: roundedValue,
            classification: BMIClassification.classification(for: roundedValue)
        )
    }
}

/// 云端同步状态（Task #25）。随 ``HealthReading`` 持久化到本地 JSON（`String` 原始值）。
///
/// 旧版 `changxi-local-demo.json` 无此键 → ``HealthReading/syncState`` 解码为 nil（仅本机记录），
/// 因此新增该字段**完全向后兼容**。本枚举不依赖 SwiftUI（图标名以字符串提供，由视图层用 `Image(systemName:)` 渲染）。
enum SyncState: String, Codable {
    /// 已入队，等待后台上行。
    case pending
    /// 正在上行（建记录 / 追加测量 / 触发工作流）。
    case syncing
    /// 已成功同步到云端。
    case synced
    /// 上行失败，可在明细页重试。
    case failed

    /// 中文标签。
    var label: String {
        switch self {
        case .pending: return "待同步"
        case .syncing: return "同步中"
        case .synced: return "已同步"
        case .failed: return "同步失败"
        }
    }

    /// SF Symbol 图标名（视图层用 `Image(systemName:)` 渲染）。
    var systemImage: String {
        switch self {
        case .pending: return "clock.arrow.circlepath"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .synced: return "checkmark.icloud"
        case .failed: return "exclamationmark.icloud"
        }
    }
}

struct DailyPlan: Codable, Identifiable {
    var id = UUID()
    var title: String
    var time: String
    var icon: String
    var detail: String
    var completed = false
    var completedAt: Date?
}

struct MemoryItem: Codable, Identifiable {
    var id = UUID()
    var title: String
    var text: String
    var category: String
    var confirmed = false
    var source = "示例对话 · 9月6日"
}

struct ConversationMessage: Codable, Identifiable {
    var id = UUID()
    var isUser: Bool
    var text: String
    var date: Date = .now
    var responseDetail: ConversationResponseDetail?
}

struct ConversationReference: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var source: String
    var excerpt: String
    var evidenceScore: Double?
    var kind: String?
    var cited: Bool? = nil
    var url: String? = nil
}

struct ConversationWorkOrder: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var description: String
    var taskType: String
    var status: String
    var priority: String
    var assigneeRole: String?
    var deadline: String?
}

struct ConversationResponseDetail: Codable, Hashable, Sendable {
    var clinicalRisk: String?
    var actionSummary: String?
    var workflowSteps: [String]
    var references: [ConversationReference]
    var workOrders: [ConversationWorkOrder]
}

struct ServiceBooking: Codable, Identifiable {
    var id = UUID()
    var service: String
    var person: String
    var date: Date
    var note: String
    var cancelled = false
}

struct Medication: Codable, Identifiable {
    var id = UUID()
    var name: String
    var dosage: String
    var instructions: String
    var hour = 20
    var minute = 0
}

struct DoseRecord: Codable, Identifiable {
    var id = UUID()
    var medicationID: UUID
    var medicationName: String
    var date: Date = .now
    var taken: Bool
}

/// 本机导入的报告记录。
///
/// 以下云端相关的可选字段（`documentID` / `analysisText` / `findings` / `bpReading`）
/// 由「拍照识别报告」流程（`ReportImportView`）调用玄同后端 `documents/analyze` 与
/// `POST /api/v1/documents` 后填充：
/// - 全部为 Optional，旧版 `changxi-local-demo.json`（缺这些键）仍能正常解码（`decodeIfPresent`）；
/// - **展示层尚未接线**：`Features/Health/ReportView.swift` 的 `ReportDetailView` /
///   `ReportGroupView` / `ImportedReportView` 目前仍显示硬编码示例，尚未消费这些字段，
///   其界面呈现由 Task #25 完成。
struct ImportedReport: Codable, Identifiable {
    var id = UUID()
    var title: String
    var filename: String
    var date: Date = .now
    var note: String
    /// 后端归档返回的 `document_id`（`POST /api/v1/documents`）；未归档 / 离线时为 nil。
    var documentID: String?
    /// analyze 返回的 `analysis` 全文；未识别时为 nil。
    var analysisText: String?
    /// analyze 返回的 `findings` 逐条要点；未识别时为 nil。
    var findings: [String]?
    /// bp 模式识别出的血压读数；非血压识别时为 nil。
    var bpReading: BPReading?
}

struct LocalState: Codable {
    var patientID = UUID().uuidString
    var name = "张阿姨"
    var person = "张阿姨（本人）"
    /// 演示档案身高。真实使用时可在「个人资料」中修改，BMI 会据此自动重算。
    var heightCentimeters = 165.0
    var onboarded = false
    var rememberAllowed = true
    var medicationReminders = false
    var healthReminders = false
    var haptics = true
    var largeText = false
    var lastPlanDay = Calendar.current.startOfDay(for: .now)
    var plans = [
        DailyPlan(title: "测血压", time: "08:00", icon: "heart.fill", detail: "记录今天的血压和测量时间。", completed: true),
        DailyPlan(title: "散步20分钟", time: "16:00", icon: "figure.walk", detail: "按自己的节奏，完成后记下一笔。", completed: true),
        DailyPlan(title: "晚间用药", time: "20:00", icon: "pills.fill", detail: "按本人处方核对药名、剂量和时间。此处为演示计划。"),
        DailyPlan(title: "睡前记录", time: "22:00", icon: "moon.zzz.fill", detail: "记下今天的感受，为明天留一份参考。")
    ]
    var memories = [
        MemoryItem(title: "症状自述", text: "最近一周早晨偶尔头晕，通常起床几分钟后缓解。", category: "健康档案"),
        MemoryItem(title: "用药记录", text: "有一份每日晚间用药计划，药名和剂量待本人核对。", category: "健康档案"),
        MemoryItem(title: "交流偏好", text: "喜欢用语音交流，希望提醒简短清楚。", category: "偏好", confirmed: true)
    ]
    var readings: [HealthReading] = Self.sampleReadings
    var messages: [ConversationMessage] = []
    var bookings: [ServiceBooking] = []
    var journal = ""
    var feedback = ""
    var doctorMessageRead = false
    var medications: [Medication] = []
    var doseHistory: [DoseRecord] = []
    var demoSignedIn = false
    var emergencyName = ""
    var emergencyPhone = ""
    var importedReports: [ImportedReport] = []
    // 食养业务域保留自己的可撤回档案；旧版本地 JSON 缺少这些键时会由默认值补齐。
    var shiyangOnboarded = false
    var shiyangPantryIngredientIDs = ["tomato", "egg", "mushroom", "rice", "bokchoy"]
    var shiyangExcludedIngredientIDs: [String] = []
    var shiyangSelectedRecipeID = "tomato-scrambled-eggs"
    var shiyangRecommendationSummary = ""
    var shiyangCity = "上海"
    var shiyangMealContext = "经常外卖"
    var shiyangStaplePreference = "都可以"
    var shiyangGoal = "吃得均衡"
    var shiyangAvoidanceNote = ""
    var shiyangHealthNote = ""
    var shiyangMedicationNote = ""
    var shiyangUseLifestyleMemory = false
    var shiyangUseHealthData = false
    var shiyangUseMedicationData = false
    var shiyangServings = 2
    var shiyangAvailableMinutes = 30
    var shiyangLowSalt = true
    var shiyangLikesSpicy = true
    static var sampleReadings: [HealthReading] {
        (0..<30).flatMap { day -> [HealthReading] in
            let date = Calendar.current.date(byAdding: .day, value: day - 29, to: .now)!
            return [HealthReading(kind: .pressure, value: Double([124,128,132,126,130,122,128][day % 7]), secondary: Double([76,78,81,77,79][day % 5]), date: date), HealthReading(kind: .glucose, value: 5.4 + Double(day % 5) * 0.1, date: date), HealthReading(kind: .weight, value: 68.4 + Double(day % 4) * 0.1, date: date)]
        }
    }
}

@MainActor @Observable
final class AppStore {
    var data: LocalState { didSet { persist() } }
    var storageError: String?
    private let fileURL: URL
    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? URL.documentsDirectory.appending(path: "changxi-local-demo.json")
        do {
            let bytes = try Data(contentsOf: self.fileURL)
            let defaults = try JSONSerialization.jsonObject(with: JSONEncoder().encode(LocalState())) as! [String: Any]
            guard let saved = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else { throw CocoaError(.fileReadCorruptFile) }
            let merged = defaults.merging(saved) { _, saved in saved }
            data = try JSONDecoder().decode(LocalState.self, from: JSONSerialization.data(withJSONObject: merged))
        } catch {
            data = LocalState()
            if FileManager.default.fileExists(atPath: self.fileURL.path) { storageError = "本地记录未能读取，原文件仍保留。请先导出备份，避免覆盖。" }
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing")
            || ProcessInfo.processInfo.arguments.contains("--integration-testing") {
            data = LocalState()
            data.onboarded = true
            if ProcessInfo.processInfo.arguments.contains("--large-text") { data.largeText = true }
        }
        #endif
        refreshDay()
    }
    func persist() {
        guard storageError == nil else { return }
        do {
            let bytes = try JSONEncoder().encode(data)
            try bytes.write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch { storageError = "记录暂时未能保存，请检查设备存储空间。" }
    }
    func refreshDay() {
        let today = Calendar.current.startOfDay(for: .now)
        if data.lastPlanDay != today {
            for index in data.plans.indices { data.plans[index].completed = false; data.plans[index].completedAt = nil }
            data.lastPlanDay = today
        }
    }
    var completed: Int { data.plans.filter(\.completed).count }
    var pendingMemories: Int { data.memories.filter { !$0.confirmed }.count }
    func latest(_ kind: MetricKind) -> HealthReading? { data.readings.filter { $0.kind == kind }.max { $0.date < $1.date } }
    var currentBMI: BMIResult? {
        guard let weight = latest(.weight)?.value else { return nil }
        return BMIResult.calculate(weightKilograms: weight, heightCentimeters: data.heightCentimeters)
    }
    func readings(_ kind: MetricKind, days: Int) -> [HealthReading] {
        let start = Calendar.current.date(byAdding: .day, value: -(days - 1), to: Calendar.current.startOfDay(for: .now))!
        return data.readings.filter { $0.kind == kind && $0.date >= start }.sorted { $0.date < $1.date }
    }
    func togglePlan(_ id: UUID) {
        guard let index = data.plans.firstIndex(where: { $0.id == id }) else { return }
        data.plans[index].completed.toggle()
        data.plans[index].completedAt = data.plans[index].completed ? .now : nil
    }
    func resetDemo() {
        for report in data.importedReports { try? FileManager.default.removeItem(at: reportURL(report)) }
        storageError = nil
        data = LocalState()
    }
    func reportURL(_ report: ImportedReport) -> URL { fileURL.deletingLastPathComponent().appending(path: (report.filename as NSString).lastPathComponent) }
    func saveReport(imageData: Data, title: String, note: String) throws {
        guard storageError == nil else { throw CocoaError(.fileWriteUnknown) }
        let report = ImportedReport(title: title, filename: "report-\(UUID()).jpg", note: note)
        try imageData.write(to: reportURL(report), options: [.atomic, .completeFileProtection])
        data.importedReports.append(report)
    }
    func deleteReport(_ report: ImportedReport) throws {
        let url = reportURL(report)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        data.importedReports.removeAll { $0.id == report.id }
    }
    var exportJSON: String { (try? String(data: JSONEncoder().encode(data), encoding: .utf8)) ?? "{}" }
}
