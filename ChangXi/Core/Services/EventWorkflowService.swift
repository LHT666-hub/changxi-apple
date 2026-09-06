import Foundation

// MARK: - 事件 DTO

/// `POST /api/events`（201）请求体。
///
/// 编码经 `.convertToSnakeCase`：`patientId` → `patient_id`、`eventType` → `event_type`、
/// `occurredAt` → `occurred_at`。`channel` 本 app 固定 `"changxi"`。
/// `payload` / `metadata` 为异构对象，用 ``EventPayloadValue`` 字典承载（键用 snake_case 字面量）。
struct EventCreate: Encodable {
    let patientId: String
    let eventType: String
    let channel: String
    let source: String?
    let payload: [String: EventPayloadValue]?
    let occurredAt: Date?
    let metadata: [String: EventPayloadValue]?
}

/// 事件记录（响应三段结构里的 `event`）。`payload`（异构对象）不解码，省略。
struct EventRecord: Decodable, Sendable {
    let id: String?
    let patientId: String?
    let eventType: String?
    let channel: String?
    let source: String?
    let occurredAt: String?
    let receivedAt: String?
}

/// 工作流执行摘要（响应三段结构里的 `workflow`）。全部 Optional，抗后端字段缺失 / 降级。
///
/// `status` 取值：`completed` / `pending_human` / `skipped` / `failed`。
struct WorkflowSummary: Decodable, Sendable {
    let status: String?
    let threadId: String?
    let severity: String?
    let clinicalRisk: String?
    let consultations: Int?
    let actionSummary: String?
    let patientCommunication: String?
    let tasksGenerated: Int?
    let executionTasks: Int?
    let steps: [String]?

    /// 是否已转人工审核。
    var isPendingHuman: Bool { status == "pending_human" }
    /// 工作流是否失败（降级，不阻断事件创建）。
    var isFailed: Bool { status == "failed" }
}

/// `POST /api/events` 的三段响应：`{event, workflow, task_ids}`。
struct EventWorkflowResponse: Decodable, Sendable {
    let event: EventRecord?
    let workflow: WorkflowSummary?
    let taskIds: [String]?
}

/// `GET /api/events/{id}/status` 响应。
struct EventStatusResponse: Decodable, Sendable {
    let eventId: String?
    let status: String?
    let threadId: String?
    let taskIds: [String]?
    let workflow: WorkflowSummary?
}

/// `GET /api/events/{id}` 响应：`{event}`。
struct EventDetailResponse: Decodable, Sendable {
    let event: EventRecord?
}

/// 一次事件上报 + 工作流执行的聚合结果（供 UI 展示）。
///
/// 由 ``EventWorkflowService/reportEvent(patientID:eventType:payload:occurredAt:source:metadata:)``
/// 从三段响应折叠而来；`Identifiable` 以便作为 `.fullScreenCover(item:)` 的驱动。
struct EventWorkflowResult: Identifiable, Sendable {
    /// 事件 ID（`event.id`）；上报失败 / 降级时为 nil。
    let eventID: String?
    /// 工作流摘要（可能为 nil 或 `status = failed` 的降级结果）。
    let workflow: WorkflowSummary?
    /// 工作流生成的任务 ID 列表。
    let taskIDs: [String]
    var id: String { eventID ?? "pending" }
}

/// SSE 进度流的一帧（全部 Optional，兼容首帧 / 节点帧 / complete / timeout 四种形态）。
///
/// - 首帧：`{"type":"status_snapshot","event_id","status","timestamp"}`
/// - 节点：`{"node":"input_guard","status":"completed","timestamp"}`
/// - 结束：`event: complete` → `{"final_status","event_status"?}`
/// - 超时：`event: timeout` → `{"reason":"idle_timeout","event_id"}`
///
/// `timestamp` 以原始字符串承载（可能为 null），不做日期解码以免整帧失败。
struct WorkflowStreamFrame: Decodable, Sendable {
    let type: String?
    let eventId: String?
    let status: String?
    let timestamp: String?
    let node: String?
    let finalStatus: String?
    let eventStatus: String?
    let reason: String?
}

// MARK: - 工作流节点中文名

/// 玄同工作流节点名 → 中文显示名映射表（Task #25）。
///
/// 依据后端 `app/xuantong/workflow/graph.py` 的 `add_node(...)` 注册（共 **17 个节点** + 终态 `__end__`）。
/// 任务描述里写「13 个节点」，实际图定义注册了 17 个，此处以**代码实际为准**全部覆盖。
/// 未知节点名回落到原始字符串（``display(_:)``）。
enum WorkflowNodeName {
    static let map: [String: String] = [
        "multimodal_detection": "多模态检测",
        "image_analysis": "影像分析",
        "speech_transcription": "语音转写",
        "input_guard": "输入安全校验",
        "emergency": "紧急危机处置",
        "rag_retrieval": "医学知识检索",
        "analyze": "家庭医生分析",
        "dispatch": "会诊调度",
        "consult": "专家会诊",
        "synthesis": "综合会诊意见",
        "risk_assessment": "临床风险评估",
        "output_guard": "输出安全校验",
        "action_guard": "处置风险评估",
        "hitl": "转人工审核",
        "task_generation": "生成照护任务",
        "execution": "执行任务拆解",
        "timeline": "汇总与审计",
        "__end__": "完成"
    ]

    /// 节点中文名；未知节点回落原始字符串。
    static func display(_ node: String) -> String { map[node] ?? node }
}

// MARK: - 事件工作流服务

/// 健康事件 → 工作流服务：玄同最核心的业务链路。
///
/// - ``reportEvent(patientID:eventType:payload:occurredAt:source:metadata:)``：`POST /api/events`（前缀 `.legacy`），
///   **阻塞直到工作流完成**，返回三段结构折叠后的 ``EventWorkflowResult``（含 `workflow.steps` 作 SSE 失败时的回落）。
/// - ``streamEventProgress(eventID:onEvent:)``：`GET /api/v1/events/{id}/stream`（前缀 `.v1`，**与上报不同前缀**），
///   SSE 实时 / 回放逐节点进度。
/// - ``getEventStatus(eventID:)`` / ``getEvent(eventID:)``：查询事件状态 / 详情。
///
/// - Note: ``SSEClient`` 是为 **POST** SSE 设计的（硬编码 method = POST），而进度流是 **GET**。
///   为不修改 Task #22 的既有网络文件，这里**复用** ``APIClient/makeRequest(path:prefix:method:accept:contentType:query:)``
///   构造 GET 请求、复用 ``SSEEvent`` 与 ``APIError``，并按与 ``SSEClient`` **完全一致**的分帧规则自行读取字节流。
struct EventWorkflowService: Sendable {
    let api: APIClient
    init(api: APIClient = .shared) { self.api = api }

    /// 上报健康事件并触发工作流（`POST /api/events`，201，前缀 `.legacy`）。
    ///
    /// - Parameters:
    ///   - patientID: 全局稳定患者标识（``PatientContext/effectiveID(_:)``），后端会 normalize。
    ///   - eventType: `bp_reading` / `glucose_reading` / `weight_reading` 等。
    ///   - payload: 实际数值（键用 snake_case 字面量，如血压 `{"systolic":168,"diastolic":103,"symptom":"头晕"}`）。
    ///   - occurredAt: 读数时间（ISO-8601）。
    ///   - source: 来源标识，默认 `changxi_ios`。
    /// - Returns: 折叠后的 ``EventWorkflowResult``；工作流失败时 `workflow.status == "failed"`（事件仍创建成功）。
    func reportEvent(
        patientID: String,
        eventType: String,
        payload: [String: EventPayloadValue],
        occurredAt: Date? = nil,
        source: String = "changxi_ios",
        metadata: [String: EventPayloadValue]? = nil
    ) async throws -> EventWorkflowResult {
        let body = EventCreate(
            patientId: patientID,
            eventType: eventType,
            channel: "changxi",
            source: source,
            payload: payload,
            occurredAt: occurredAt,
            metadata: metadata
        )
        let response: EventWorkflowResponse = try await api.post("events", body: body, prefix: .legacy)
        return EventWorkflowResult(
            eventID: response.event?.id,
            workflow: response.workflow,
            taskIDs: response.taskIds ?? []
        )
    }

    /// 查询事件状态（`GET /api/events/{id}/status`，前缀 `.legacy`）。
    func getEventStatus(eventID: String) async throws -> EventStatusResponse {
        try await api.get("events/\(eventID)/status", prefix: .legacy)
    }

    /// 查询事件详情（`GET /api/events/{id}`，前缀 `.legacy`）。
    func getEvent(eventID: String) async throws -> EventDetailResponse {
        try await api.get("events/\(eventID)", prefix: .legacy)
    }

    /// 订阅事件工作流 SSE 进度（`GET /api/v1/events/{id}/stream`，**前缀 `.v1`**）。
    ///
    /// 逐帧在**主线程**回调 ``SSEEvent``；收到 `event: complete` / `event: timeout` 后主动结束并返回。
    /// 心跳注释行（`: ping` / `: waiting`）按 SSE 规范丢弃，不作为进度。
    ///
    /// - Throws: 建连失败（含事件不存在且无频道 → 404）抛 ``APIError``；被取消时抛 `CancellationError`。
    func streamEventProgress(
        eventID: String,
        onEvent: @escaping @MainActor (SSEEvent) -> Void
    ) async throws {
        let request = try api.makeRequest(
            path: "events/\(eventID)/stream",
            prefix: .v1,
            method: "GET",
            accept: "text/event-stream"
        )

        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await api.session.bytes(for: request)
        } catch {
            throw APIError.parse(data: nil, response: nil, underlying: error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.parse(data: nil, response: response, underlying: URLError(.badServerResponse))
        }
        let requestID = http.value(forHTTPHeaderField: "X-Request-ID")

        // 建连阶段非 2xx（如事件不存在 → 404）：读取错误体后抛出。
        guard (200..<300).contains(http.statusCode) else {
            var errorData = Data()
            for try await byte in bytes {
                errorData.append(byte)
                if errorData.count >= 8192 { break }
            }
            if http.statusCode == 401 {
                api.tokenStore.clear()
                NotificationCenter.default.post(name: .cxSessionExpired, object: nil)
            }
            throw APIError.parse(data: errorData, response: http, underlying: nil, requestID: requestID)
        }

        var eventName: String?
        var dataLines: [String] = []

        // 逐行读取并按空行分帧（与 SSEClient 一致）。
        for try await line in bytes.lines {
            try Task.checkCancellation()

            if line.isEmpty {
                if dataLines.isEmpty && eventName == nil { continue }
                let event = SSEEvent(name: eventName ?? "message", data: dataLines.joined(separator: "\n"))
                await onEvent(event)
                eventName = nil
                dataLines = []
                if event.name == "complete" || event.name == "timeout" { return }
                continue
            }
            if line.hasPrefix(":") { continue } // 注释 / 心跳，丢弃
            if line.hasPrefix("event:") {
                eventName = String(line.dropFirst("event:".count)).trimmingCharacters(in: .whitespaces)
                continue
            }
            if line.hasPrefix("data:") {
                var value = String(line.dropFirst("data:".count))
                if value.hasPrefix(" ") { value.removeFirst() }
                dataLines.append(value)
                continue
            }
        }

        // 流自然结束但未收到显式终止事件：派发残留的最后一块（若有）。
        if !dataLines.isEmpty || eventName != nil {
            let event = SSEEvent(name: eventName ?? "message", data: dataLines.joined(separator: "\n"))
            await onEvent(event)
        }
    }
}
