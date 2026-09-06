import Foundation

// MARK: - 照护任务 DTO

/// 照护任务记录（`GET /api/tasks` / `GET /api/tasks/{id}` 返回的 task dict）。
///
/// 字段严格对齐后端 DB 模式实际返回：`id / patient_id / event_id / title / description / task_type /
/// status / priority / assignee_type / assignee_role / deadline / created_at / completed_at`。
/// - Important: DB 模式**不含** `assignee_id / human_owner_id / team_id / due_at`，故不解码它们。
///   `result`（异构对象，可能为 null）不解码，省略。`priority` 为字符串 `low/medium/high`。
struct CareTask: Decodable, Sendable, Identifiable {
    let id: String
    let patientId: String?
    let eventId: String?
    let title: String?
    let description: String?
    let taskType: String?
    let status: String?
    let priority: String?
    let assigneeType: String?
    let assigneeRole: String?
    let deadline: String?
    let createdAt: String?
    let completedAt: String?

    /// 展示标题：优先 `title`，回落到 `task_type`，再回落到通用文案（绝不显示原始 JSON）。
    var displayTitle: String {
        if let title, !title.isEmpty { return title }
        if let taskType, !taskType.isEmpty { return taskType }
        return "照护任务"
    }

    /// 是否已完成（后端完成后 `status` 置为 `completed`）。
    var isCompleted: Bool { status == "completed" }
}

/// `GET /api/tasks` 分页响应。
struct CareTaskPage: Decodable, Sendable {
    let tasks: [CareTask]?
    let total: Int?
    let page: Int?
    let size: Int?
}

/// `POST /api/tasks/{id}/complete` 请求体。
///
/// 编码经 `.convertToSnakeCase`：`outcomeType` → `outcome_type`、`completedBy` → `completed_by`。
/// `outcome_type` 取值 `resolved / escalated / pending / cancelled`，本 app 完成时用 `resolved`。
struct TaskCompleteRequest: Encodable {
    var outcomeType: String = "resolved"
    var notes: String = ""
    var completedBy: String = ""
}

/// `POST /api/tasks/{id}/complete` 响应：`{status, task, outcome}`。`outcome`（异构 / 可空）不解码。
struct TaskCompleteResponse: Decodable, Sendable {
    let status: String?
    let task: CareTask?
}

/// `GET /api/tasks/{id}` 响应：`{task}`。
struct TaskDetailResponse: Decodable, Sendable {
    let task: CareTask?
}

// MARK: - 照护任务服务

/// 照护任务服务：桥接玄同后端 `/api/tasks*` 端点（前缀 `.legacy` = `/api`）。
///
/// 展示玄同会诊工作流自动生成的照护任务，支持勾选完成（写回 ServiceOutcome + Timeline）。
/// - Note: 类型名用 `CareTaskService` 以贴合业务语义（照护任务）。
struct CareTaskService: Sendable {
    let api: APIClient
    init(api: APIClient = .shared) { self.api = api }

    /// 分页列出照护任务（`GET /api/tasks?patient_id=&status=&page=&size=`）。
    /// - Note: 建议始终带 `patient_id`（后端无过滤参数时返回全量分页）。
    func listTasks(patientID: String, status: String? = nil, page: Int = 1, size: Int = 20) async throws -> CareTaskPage {
        var query: [String: String] = ["patient_id": patientID, "page": String(page), "size": String(size)]
        if let status { query["status"] = status }
        return try await api.get("tasks", query: query, prefix: .legacy)
    }

    /// 获取单个任务（`GET /api/tasks/{id}`）；404 或缺 `task` 字段抛 ``APIError``。
    func getTask(_ id: String) async throws -> CareTask {
        let response: TaskDetailResponse = try await api.get("tasks/\(id)", prefix: .legacy)
        guard let task = response.task else {
            throw APIError.decoding(
                DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: [], debugDescription: "响应缺少 task 字段")
                )
            )
        }
        return task
    }

    /// 完成任务（`POST /api/tasks/{id}/complete`）。
    /// - Parameters:
    ///   - outcomeType: `resolved`（默认）/ `escalated` / `pending` / `cancelled`。
    ///   - notes: 用户填写的完成备注（可空）。
    ///   - completedBy: 完成者标识（用患者标识）。
    /// - Returns: 后端回写的最新任务（可能为 nil）。
    @discardableResult
    func completeTask(_ id: String, outcomeType: String = "resolved", notes: String = "", completedBy: String = "") async throws -> CareTask? {
        let body = TaskCompleteRequest(outcomeType: outcomeType, notes: notes, completedBy: completedBy)
        let response: TaskCompleteResponse = try await api.post("tasks/\(id)/complete", body: body, prefix: .legacy)
        return response.task
    }
}
