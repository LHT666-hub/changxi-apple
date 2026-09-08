import Foundation

// MARK: - 异构 JSON 值

/// 用于构造后端 `payload` / `content` 这类**异构对象**的可编码值（零第三方依赖）。
///
/// 后端 `EventCreate.payload`、`HealthRecordCreate.content` 都是自由结构 `object`。
/// Swift 没有 `Any` 的 `Encodable`，故用枚举承载有限的标量类型。
///
/// - Important: 承载这些值的字典**键一律使用 snake_case 字面量**（如 `"systolic"`、`"memory_id"`）。
///   因为 `JSONEncoder.keyEncodingStrategy = .convertToSnakeCase` 对 `[String: T]` 字典键的转换行为
///   在不同版本上不确定；使用本就是 snake_case / 单个小写词的键是**幂等**的，两种行为下都正确。
enum EventPayloadValue: Encodable, Sendable {
    case int(Int)
    case double(Double)
    case string(String)
    case bool(Bool)
    case array([EventPayloadValue])
    case object([String: EventPayloadValue])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}

// MARK: - 指标映射

/// ``MetricKind`` ↔ 后端 `measurement_type` / `unit` / `event_type` / `record_type` 的映射常量。
///
/// 后端契约（逐字）：
/// - `measurement_type`：血压 → `blood_pressure`、血糖 → `blood_glucose`、体重 → `weight`
/// - `unit`：血压 `mmHg`（value=收缩压，secondary_value=舒张压）、血糖 `mmol/L`、体重 `kg`
/// - `event_type`（触发工作流）：血压 → `bp_reading`、血糖 → `glucose_reading`、体重 → `weight_reading`
enum HealthMetricMapping {
    /// 测量类型（写入 measurements）。
    static func measurementType(_ kind: MetricKind) -> String {
        switch kind {
        case .pressure: return "blood_pressure"
        case .glucose: return "blood_glucose"
        case .weight: return "weight"
        }
    }

    /// 单位。与 ``MetricKind/unit`` 保持一致，此处显式列出以贴合后端契约。
    static func unit(_ kind: MetricKind) -> String {
        switch kind {
        case .pressure: return "mmHg"
        case .glucose: return "mmol/L"
        case .weight: return "kg"
        }
    }

    /// 触发工作流的事件类型（写入 `POST /api/events` 的 `event_type`）。
    static func eventType(_ kind: MetricKind) -> String {
        switch kind {
        case .pressure: return "blood_pressure.recorded"
        case .glucose: return "blood_glucose.recorded"
        case .weight: return "weight.recorded"
        }
    }

    /// 健康记录类型（写入 `POST /api/health-records` 的 `record_type`）。
    static func recordType(_ kind: MetricKind) -> String {
        switch kind {
        case .pressure: return "bp_reading"
        case .glucose: return "glucose_reading"
        case .weight: return "weight_reading"
        }
    }

    /// 反向映射：后端 `measurement_type` → 本地 ``MetricKind``（下行合并用）。未知类型返回 nil。
    static func kind(forMeasurementType type: String) -> MetricKind? {
        switch type {
        case "blood_pressure": return .pressure
        case "blood_glucose": return .glucose
        case "weight": return .weight
        default: return nil
        }
    }
}

// MARK: - 健康记录 DTO

/// `POST /api/health-records`（201）请求体。
///
/// `recordedAt` 以 `Date` 承载，经 ``APIClient`` 的 `.iso8601` 编码为字符串，后端 `recorded_at: str|None` 接受。
struct HealthRecordCreate: Encodable {
    let patientId: String
    let recordType: String
    let title: String
    let content: [String: EventPayloadValue]?
    let source: String?
    let recordedAt: Date?
}

/// 健康记录响应（`HealthRecordOut`）。`content`（异构对象，默认 `{}`）不解码，省略。
struct HealthRecordOut: Decodable, Sendable, Identifiable {
    let id: String
    let patientId: String?
    let recordType: String?
    let title: String?
    let source: String?
    let recordedAt: String?
    let createdAt: String?
}

/// `GET /api/health-records` 分页响应。
struct HealthRecordPage: Decodable, Sendable {
    let records: [HealthRecordOut]?
    let total: Int?
    let page: Int?
    let size: Int?
}

/// `POST /api/health-records/{id}/measurements`（201）请求体。
struct MeasurementCreate: Encodable {
    let measurementType: String
    let value: Double
    let secondaryValue: Double?
    let unit: String
    let measuredAt: Date?
    let patientId: String?
}

/// 测量响应（`MeasurementOut`）。`measured_at` 以原始字符串承载（可能为 null），
/// 由 ``HealthSyncService/date(fromISO:)`` 容错解析，避免解码期抛错。
struct MeasurementOut: Decodable, Sendable, Identifiable {
    let id: String
    let patientId: String?
    let measurementType: String
    let value: Double
    let secondaryValue: Double?
    let unit: String
    let measuredAt: String?
}

/// `GET /api/patients/{id}/measurements` 分页响应。
struct MeasurementPage: Decodable, Sendable {
    let patientId: String?
    let measurements: [MeasurementOut]?
    let total: Int?
    let page: Int?
    let size: Int?
}

// MARK: - 健康记录服务

/// 健康记录与测量服务：桥接玄同后端 `/api/health-records*` 端点（前缀 `.legacy` = `/api`）。
///
/// - Important: **后端健康记录没有 DELETE 端点**，本地删除无法同步到云端（详见 ``HealthSyncService``）。
struct HealthRecordService: Sendable {
    let api: APIClient
    init(api: APIClient = .shared) { self.api = api }

    /// 创建健康记录（`POST /api/health-records`，201）。
    @discardableResult
    func createRecord(
        patientID: String,
        recordType: String,
        title: String,
        content: [String: EventPayloadValue]? = nil,
        source: String? = "changxi_ios",
        recordedAt: Date? = nil
    ) async throws -> HealthRecordOut {
        let body = HealthRecordCreate(
            patientId: patientID, recordType: recordType, title: title,
            content: content, source: source, recordedAt: recordedAt
        )
        return try await api.post("health-records", body: body, prefix: .legacy)
    }

    /// 分页列出健康记录（`GET /api/health-records?patient_id=&record_type=&page=&size=`）。
    func listRecords(patientID: String? = nil, recordType: String? = nil, page: Int = 1, size: Int = 20) async throws -> HealthRecordPage {
        var query: [String: String] = ["page": String(page), "size": String(size)]
        if let patientID { query["patient_id"] = patientID }
        if let recordType { query["record_type"] = recordType }
        return try await api.get("health-records", query: query, prefix: .legacy)
    }

    /// 获取单条健康记录（`GET /api/health-records/{id}`）；404 抛 ``APIError``。
    func getRecord(recordID: String) async throws -> HealthRecordOut {
        try await api.get("health-records/\(recordID)", prefix: .legacy)
    }

    /// 为健康记录追加测量（`POST /api/health-records/{id}/measurements`，201）。
    /// - Note: 后端把测量的 `patient_id` 取自所属记录（已 normalize），此处 `patientID` 仅作冗余传入。
    @discardableResult
    func appendMeasurement(
        recordID: String,
        measurementType: String,
        value: Double,
        secondaryValue: Double? = nil,
        unit: String,
        measuredAt: Date? = nil,
        patientID: String? = nil
    ) async throws -> MeasurementOut {
        let body = MeasurementCreate(
            measurementType: measurementType, value: value, secondaryValue: secondaryValue,
            unit: unit, measuredAt: measuredAt, patientId: patientID
        )
        return try await api.post("health-records/\(recordID)/measurements", body: body, prefix: .legacy)
    }
}
