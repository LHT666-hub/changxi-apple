import Foundation

// MARK: - 患者档案 DTO（字段按 `.convertFromSnakeCase` 后的驼峰命名）

/// `POST /api/patients`（201）请求体。
///
/// 编码经 `.convertToSnakeCase`：`chronicDiseases` → `chronic_diseases`、`userId` → `user_id`、
/// `orgId` → `org_id`、`riskLevel` → `risk_level`。`current_medications` 为异构对象数组，
/// 本 app 不上传，故省略（后端默认 null）。
struct PatientCreate: Encodable {
    var name: String
    var age: Int? = nil
    var gender: String? = nil
    var chronicDiseases: [String]? = nil
    var allergies: [String]? = nil
    var riskLevel: String? = nil
    var userId: String? = nil
    var orgId: String? = nil
}

/// `PUT /api/patients/{id}` 请求体（全字段可选，部分更新）。
///
/// Swift 合成的 `Encodable` 对 Optional 属性使用 `encodeIfPresent`，nil 字段不会出现在 JSON 中，
/// 因此只传需要修改的字段即可实现后端的部分更新语义。
struct PatientUpdate: Encodable {
    var name: String? = nil
    var age: Int? = nil
    var gender: String? = nil
    var chronicDiseases: [String]? = nil
    var allergies: [String]? = nil
    var riskLevel: String? = nil
    var userId: String? = nil
    var orgId: String? = nil
}

/// 患者档案响应（`PatientOut`）。除 `id` 外全部 Optional，兼容后端字段缺失 / 为 null。
/// `current_medications`（异构对象数组）不解码，省略。
struct PatientOut: Decodable, Sendable, Identifiable {
    let id: String
    let userId: String?
    let orgId: String?
    let name: String?
    let age: Int?
    let gender: String?
    let chronicDiseases: [String]?
    let allergies: [String]?
    let riskLevel: String?
    let createdAt: String?
    let updatedAt: String?
    let deletedAt: String?
}

/// `GET /api/patients` 分页响应。
struct PatientPage: Decodable, Sendable {
    let patients: [PatientOut]?
    let total: Int?
    let page: Int?
    let size: Int?
}

/// `DELETE /api/patients/{id}`（软删除）响应。
/// - Note: 类型名用 `PatientDeleteResult` 以避开 ``DeleteResult``（文档服务已占用）。
struct PatientDeleteResult: Decodable, Sendable {
    let deleted: Bool?
    let patientId: String?
}

/// 时间线条目（`GET /api/patients/{id}/timeline`）。`metadata`（异构对象）不解码，省略。
struct TimelineEntry: Decodable, Sendable, Identifiable {
    let id: String
    let patientId: String?
    let entryType: String?
    let title: String?
    let description: String?
    let relatedId: String?
    let createdAt: String?
}

/// 时间线分页响应。
struct TimelinePage: Decodable, Sendable {
    let timeline: [TimelineEntry]?
    let patientId: String?
    let total: Int?
    let page: Int?
    let size: Int?
}

// MARK: - 患者服务

/// 患者档案服务：桥接玄同后端 `/api/patients*` 全套端点（前缀 `.legacy` = `/api`）。
///
/// 全部经 ``APIClient``（自动注入 Bearer、snake_case↔camelCase、容错日期、统一 ``APIError``）。
/// `Sendable`（仅持有 `Sendable` 的 ``APIClient``）。
struct PatientService: Sendable {
    let api: APIClient
    init(api: APIClient = .shared) { self.api = api }

    /// 创建患者档案（`POST /api/patients`，201）。
    func createPatient(
        name: String,
        age: Int? = nil,
        gender: String? = nil,
        chronicDiseases: [String]? = nil,
        allergies: [String]? = nil,
        riskLevel: String? = nil,
        userID: String? = nil,
        orgID: String? = nil
    ) async throws -> PatientOut {
        let body = PatientCreate(
            name: name, age: age, gender: gender,
            chronicDiseases: chronicDiseases, allergies: allergies,
            riskLevel: riskLevel, userId: userID, orgId: orgID
        )
        return try await api.post("patients", body: body, prefix: .legacy)
    }

    /// 获取单个患者档案（`GET /api/patients/{id}`）；404 抛 ``APIError``。
    func getPatient(_ id: String) async throws -> PatientOut {
        try await api.get("patients/\(id)", prefix: .legacy)
    }

    /// 部分更新患者档案（`PUT /api/patients/{id}`）。
    func updatePatient(_ id: String, update: PatientUpdate) async throws -> PatientOut {
        try await api.put("patients/\(id)", body: update, prefix: .legacy)
    }

    /// 分页列出患者（`GET /api/patients?search=&page=&size=`，`search` 按姓名模糊）。
    func listPatients(search: String? = nil, page: Int = 1, size: Int = 20) async throws -> PatientPage {
        var query: [String: String] = ["page": String(page), "size": String(size)]
        if let search, !search.isEmpty { query["search"] = search }
        return try await api.get("patients", query: query, prefix: .legacy)
    }

    /// 软删除患者档案（`DELETE /api/patients/{id}`）。
    /// - Returns: 后端返回的 `deleted` 布尔（缺省视为 false）。
    @discardableResult
    func deletePatient(_ id: String) async throws -> Bool {
        let result: PatientDeleteResult = try await api.delete("patients/\(id)", prefix: .legacy)
        return result.deleted ?? false
    }

    /// 患者时间线（`GET /api/patients/{id}/timeline?entry_type=&page=&size=`）。
    func getTimeline(patientID: String, entryType: String? = nil, page: Int = 1, size: Int = 50) async throws -> TimelinePage {
        var query: [String: String] = ["page": String(page), "size": String(size)]
        if let entryType { query["entry_type"] = entryType }
        return try await api.get("patients/\(patientID)/timeline", query: query, prefix: .legacy)
    }

    /// 患者测量历史（`GET /api/patients/{id}/measurements?measurement_type=&page=&size=`）。
    ///
    /// 后端对 `patient_id` 做 `normalize_patient_id`，且**不要求** patients 表存在对应行，
    /// 因此用全局稳定标识（``PatientContext/effectiveID(_:)``）即可拉取。
    /// - Note: ``MeasurementPage`` / ``MeasurementOut`` 定义于 `HealthRecordService.swift`。
    func getMeasurements(patientID: String, type: String? = nil, page: Int = 1, size: Int = 50) async throws -> MeasurementPage {
        var query: [String: String] = ["page": String(page), "size": String(size)]
        if let type { query["measurement_type"] = type }
        return try await api.get("patients/\(patientID)/measurements", query: query, prefix: .legacy)
    }
}

// MARK: - 患者标识上下文

/// 全局患者标识与档案绑定策略（Task #25）。
///
/// **单一标识原则**：全 app（对话 / 文档 / 健康记录 / 事件 / 测量 / 任务）统一使用
/// ``effectiveID(_:)`` = `登录用户 ID ?? 本地匿名 UUID`，与 ``RemoteConversationService/localPatientId``
/// 机制完全一致，**不引入第二套 patientID**。后端各子资源端点都会 `normalize_patient_id`
/// 把该稳定标识规范化为确定性 UUID，且无需 patients 表存在对应行即可写入 / 查询。
///
/// ``bindProfileIfNeeded(auth:name:person:)`` 只是**一次性 best-effort** 地在后端补建一条患者档案
/// （`user_id = effectiveID`），便于后台关联；它**绝不覆盖** ``effectiveID(_:)``，失败也不阻断本地使用。
@MainActor
enum PatientContext {
    /// 当前患者标识：登录后用 `User.id`，否则用稳定的本地匿名 UUID（与对话 / 文档页一致）。
    static func effectiveID(_ auth: AuthSession) -> String {
        auth.currentUser?.id ?? RemoteConversationService.localPatientId
    }

    /// 一次性 best-effort 在后端建立患者档案（`user_id = effectiveID`）。
    ///
    /// - 用 Keychain 标记（`account = patient_profile_bound`）保证成功后不再重复创建；
    /// - 离线（`useRemoteAPI == false`）直接返回，不发任何请求；
    /// - 后端不可达 / 已存在等失败**静默忽略**，不置标记，下次进入健康页再试，绝不阻断本地。
    static func bindProfileIfNeeded(auth: AuthSession, name: String, person: String) async {
        guard AppConfiguration.useRemoteAPI else { return }
        let flag = TokenStore(account: "patient_profile_bound")
        guard !flag.hasValue else { return }
        let pid = effectiveID(auth)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = trimmedName.isEmpty ? person : trimmedName
        do {
            _ = try await PatientService().createPatient(name: displayName, userID: pid)
            try? flag.save("1")
        } catch {
            // 静默：后端不可达 / 档案已存在都不阻断本地使用；不置标记，下次再试。
        }
    }
}
