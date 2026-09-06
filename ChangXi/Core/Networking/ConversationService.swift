import Foundation

// MARK: - 对话服务协议（UI 测试与离线演示依赖）

/// 对话服务协议。UI 测试（`--ui-testing`）与离线场景使用 ``DemoConversationService``，
/// 联网场景使用 ``RemoteConversationService``。
protocol ConversationService: Sendable {
    /// 单轮问答：输入用户消息，返回助手回复文本。
    func reply(to message: String) async throws -> String
}

/// 确定性的本地演示对话服务：无网络、无临床推理，仅返回固定示例文本。
struct DemoConversationService: ConversationService {
    func reply(to message: String) async throws -> String {
        try await Task.sleep(for: .milliseconds(1200))
        try Task.checkCancellation()
        if message.contains("报告") { return "我们可以先核对报告日期、项目名称、单位和报告列出的参考区间。你也可以打开健康页的报告示例，查看各项数据如何整理。\n\n这是体验版示例回复，尚未读取或分析你的报告。" }
        if message.contains("药") { return "可以先把药名、本人处方中的用法和想问的问题记下来，再向医生或药师核对。\n\n我可以带你查看用药计划。这是示例对话，不会调整你的用药安排。" }
        if message.contains("头晕") || message.contains("不舒服") { return "我听到了。可以记下从什么时候开始、持续多久，以及当时的感受，方便与医生沟通。\n\n当前是体验模式，我无法判断症状或提供实时诊疗。若你需要医疗帮助，请直接联系当地医疗服务。" }
        return "我在这里。你可以记下一次测量，看看今天的计划，或把想问医生的问题整理成草稿。\n\n这是一条体验版示例回复；你的文字仅保存在本机。"
    }
}

// MARK: - 后端对话 DTO（字段按 `.convertFromSnakeCase` 后的驼峰命名）

/// `POST /api/v1/chat`（及 `/chat/stream`）请求体。
///
/// 编码时经 `.convertToSnakeCase`：`patientId` → `patient_id`，`sessionId` → `session_id`。
struct ChatRequest: Encodable {
    let message: String
    let patientId: String?
    let sessionId: String?
    let context: [ChatContextTurn]?
}

/// 历史上下文单轮（后端仅采纳 `role ∈ {user, assistant}` 且 `content` 非空的项）。
struct ChatContextTurn: Encodable {
    let role: String
    let content: String
}

/// 对话响应/消息中的 `metadata`（可能为 null、`{"guard","reason"}` 或 `{"degraded","reason"}`）。
struct ChatMetadata: Codable, Sendable, Equatable {
    /// 安全护栏类型：`emergency` / `block`（后端键为 `guard`，Swift 关键字需反引号）。
    var `guard`: String?
    var reason: String?
    /// LLM 降级标记（`true` 表示当前为简化兜底回复）。
    var degraded: Bool?

    /// 是否命中安全护栏（危机 / 阻断），UI 需醒目标注。
    var isGuarded: Bool { self.`guard` == "emergency" || self.`guard` == "block" }
    /// 是否为紧急危机引导文案。
    var isEmergency: Bool { self.`guard` == "emergency" }
    /// 护栏 / 降级类型的展示标签。
    var badge: String? {
        switch self.`guard` {
        case "emergency": return "紧急提示"
        case "block": return "内容已拦截"
        default:
            if degraded == true { return "简化回复" }
            return nil
        }
    }
}

/// `POST /api/v1/chat` 响应体。
struct ChatReply: Decodable {
    let reply: String
    let agentRole: String       // agent_role，固定 "family_doctor"
    let sessionId: String?      // session_id
    let metadata: ChatMetadata?
}

/// 流式对话结束后的最终结果（由 SSE `complete` 事件或累积文本兜底构造）。
struct ChatFinal: Sendable {
    let reply: String
    let agentRole: String?
    let sessionId: String?
    let metadata: ChatMetadata?
}

// SSE data 载荷
private struct ChatStreamChunk: Decodable { let chunk: String; let done: Bool }
private struct ChatStreamGuard: Decodable { let reply: String }
private struct ChatStreamComplete: Decodable {
    let chunk: String?
    let done: Bool?
    let reply: String
    let agentRole: String?
    let sessionId: String?
    let metadata: ChatMetadata?
}
private struct ChatStreamErrorPayload: Decodable { let message: String }

/// 会话记录（`/chat/sessions`）。
struct ChatSession: Decodable, Identifiable, Sendable {
    let id: String
    let patientId: String        // patient_id
    let createdAt: Date          // created_at
    let lastMessageAt: Date?     // last_message_at（可能为 null）
    let messageCount: Int        // message_count
}

/// 会话消息（`/chat/sessions/{id}/messages`）。
struct ChatMessage: Decodable, Identifiable, Sendable {
    let id: String
    let sessionId: String        // session_id
    let patientId: String        // patient_id
    let role: String             // user / assistant / system
    let content: String
    let metadata: ChatMetadata?
    let createdAt: Date          // created_at

    /// 是否为用户发出的消息。
    var isUser: Bool { role == "user" }
}

// 请求体（会话管理）
private struct CreateSessionRequest: Encodable { let patientId: String }
private struct AppendMessageRequest: Encodable {
    let role: String
    let content: String
    let metadata: ChatMetadata?
}

// 响应包装
private struct ChatSessionListResponse: Decodable {
    let sessions: [ChatSession]
    let patientId: String
    let count: Int
}
private struct ChatMessageListResponse: Decodable {
    let messages: [ChatMessage]
    let sessionId: String
    let count: Int
}
private struct DeleteSessionResponse: Decodable {
    let deleted: Bool
    let sessionId: String
}

// MARK: - 远程对话服务

/// 连接玄同后端 `/api/v1/chat*` 的远程对话服务，复用 ``APIClient`` 与 ``SSEClient``。
///
/// 提供：非流式问答、POST-SSE 流式问答、以及会话/消息的增删查。
/// 网络错误、超时、非 2xx 均抛出 ``APIError``，由上层降级到 ``DemoConversationService``。
struct RemoteConversationService: ConversationService {
    let api: APIClient
    let sse: SSEClient
    /// 稳定的匿名患者标识（存于 Keychain，account=`patient_id`）。
    let patientId: String

    /// 进程级缓存的匿名患者 ID：首次访问生成 UUID 并落 Keychain，之后稳定复用。
    ///
    /// 后端 `normalize_patient_id` 会把任意字符串规范化为确定性 UUID，因此本地稳定即可。
    static let localPatientId: String = {
        let store = TokenStore(account: "patient_id")
        if let existing = store.load(), !existing.isEmpty { return existing }
        let generated = UUID().uuidString
        try? store.save(generated)
        return generated
    }()

    init(api: APIClient = .shared, patientId: String = RemoteConversationService.localPatientId) {
        self.api = api
        self.sse = SSEClient(api: api)
        self.patientId = patientId
    }

    // MARK: ConversationService

    /// 单轮问答（非流式，`POST /api/v1/chat`），仅返回回复文本。
    func reply(to message: String) async throws -> String {
        try await send(message: message).reply
    }

    // MARK: 非流式对话

    /// 非流式对话（`POST /api/v1/chat`），返回完整 ``ChatReply``（含 metadata / sessionId）。
    ///
    /// - Parameters:
    ///   - patientId: 缺省用服务自身的匿名患者标识。
    ///   - sessionId: 缺省时后端新建会话；传入不存在的 ID 后端会隐式建档。
    ///   - context: 最近若干轮历史（`{role, content}`），用于多轮上下文。
    func send(
        message: String,
        patientId: String? = nil,
        sessionId: String? = nil,
        context: [ChatContextTurn]? = nil
    ) async throws -> ChatReply {
        let body = ChatRequest(
            message: message,
            patientId: patientId ?? self.patientId,
            sessionId: sessionId,
            context: context
        )
        return try await api.post("/chat", body: body, prefix: .v1)
    }

    // MARK: 流式对话（POST-SSE 打字机）

    /// 流式对话（`POST /api/v1/chat/stream`），逐块回调并返回最终 ``ChatFinal``。
    ///
    /// - Parameter onChunk: 每收到一个文本增量即在**主线程**回调，用于打字机效果。
    /// - Returns: `complete` 事件给出的最终可信全文（可能经 OutputGuard 改写）；
    ///   若未收到 `complete` 则用累积文本兜底。
    /// - Throws: 建连失败抛 ``APIError``；收到 `error` 事件或无有效回复时抛错；被取消时抛 `CancellationError`。
    /// - Note: `@MainActor` —— 内部状态盒在主线程读写，调用方应在主线程 Task 中调用。
    @MainActor
    func streamReply(
        message: String,
        patientId: String? = nil,
        sessionId: String? = nil,
        context: [ChatContextTurn]? = nil,
        onChunk: @escaping @MainActor (String) -> Void
    ) async throws -> ChatFinal {
        let state = ChatStreamState()
        let body = ChatRequest(
            message: message,
            patientId: patientId ?? self.patientId,
            sessionId: sessionId,
            context: context
        )

        try await sse.stream(path: "/chat/stream", body: body, prefix: .v1) { event in
            switch event.name {
            case "message":
                if let chunk = try? event.decodeData(ChatStreamChunk.self), !chunk.chunk.isEmpty {
                    state.text += chunk.chunk
                    onChunk(chunk.chunk)
                }
            case "guard":
                // OutputGuard 改写/阻断：下发最终可信全文。
                if let guarded = try? event.decodeData(ChatStreamGuard.self) {
                    state.guardReply = guarded.reply
                }
            case "complete":
                if let complete = try? event.decodeData(ChatStreamComplete.self) {
                    state.final = ChatFinal(
                        reply: complete.reply,
                        agentRole: complete.agentRole,
                        sessionId: complete.sessionId,
                        metadata: complete.metadata
                    )
                }
            case "error":
                if let payload = try? event.decodeData(ChatStreamErrorPayload.self) {
                    state.errorMessage = payload.message
                }
            case "timeout":
                if state.errorMessage == nil { state.errorMessage = "回复超时，请重试。" }
            default:
                break
            }
        }

        // 优先使用 complete 事件的最终结果。
        if let final = state.final { return final }

        // 收到 error 且无最终结果：抛错交由上层降级。
        if let errorMessage = state.errorMessage {
            throw APIError.http(status: 200, message: errorMessage)
        }

        // 无 complete 事件：用 guard 全文或累积文本兜底。
        let text = state.guardReply ?? state.text
        guard !text.isEmpty else {
            throw APIError.http(status: 200, message: "未能获取回复，请重试。")
        }
        return ChatFinal(reply: text, agentRole: "family_doctor", sessionId: sessionId, metadata: nil)
    }

    // MARK: 会话管理

    /// 创建会话（`POST /api/v1/chat/sessions`）。
    @discardableResult
    func createSession(patientId: String? = nil) async throws -> ChatSession {
        let body = CreateSessionRequest(patientId: patientId ?? self.patientId)
        return try await api.post("/chat/sessions", body: body, prefix: .v1)
    }

    /// 列出某患者的全部会话（`GET /api/v1/chat/sessions?patient_id=`，按最近活跃倒序）。
    func listSessions(patientId: String? = nil) async throws -> [ChatSession] {
        let pid = patientId ?? self.patientId
        let response: ChatSessionListResponse = try await api.get(
            "/chat/sessions",
            query: ["patient_id": pid],
            prefix: .v1
        )
        return response.sessions
    }

    /// 列出会话消息（`GET /api/v1/chat/sessions/{id}/messages?limit=`，时间升序，最近 limit 条）。
    func listMessages(sessionId: String, limit: Int = 50) async throws -> [ChatMessage] {
        let clamped = min(max(limit, 1), 500)
        let response: ChatMessageListResponse = try await api.get(
            "/chat/sessions/\(sessionId)/messages",
            query: ["limit": String(clamped)],
            prefix: .v1
        )
        return response.messages
    }

    /// 向会话追加消息（`POST /api/v1/chat/sessions/{id}/messages`）。会话不存在返回 404。
    @discardableResult
    func appendMessage(
        sessionId: String,
        role: String,
        content: String,
        metadata: ChatMetadata? = nil
    ) async throws -> ChatMessage {
        let body = AppendMessageRequest(role: role, content: content, metadata: metadata)
        return try await api.post("/chat/sessions/\(sessionId)/messages", body: body, prefix: .v1)
    }

    /// 删除会话及其全部消息（`DELETE /api/v1/chat/sessions/{id}`）。
    @discardableResult
    func deleteSession(sessionId: String) async throws -> Bool {
        let response: DeleteSessionResponse = try await api.delete(
            "/chat/sessions/\(sessionId)",
            prefix: .v1
        )
        return response.deleted
    }
}

/// 流式对话过程中的可变状态盒（仅在主线程读写）。
@MainActor
private final class ChatStreamState {
    var text = ""
    var guardReply: String?
    var final: ChatFinal?
    var errorMessage: String?
}
