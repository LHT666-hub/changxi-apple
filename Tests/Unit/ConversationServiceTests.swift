import XCTest
@testable import ChangXi

/// ``RemoteConversationService`` / ``DemoConversationService`` 测试。
///
/// - 用 `RemoteConversationService(api: mockClient, patientId: "test-pid")` 显式传入 patientId，
///   **不触发** `localPatientId` 静态（避免 Keychain），也不发真实网络请求。
/// - `streamReply` 是 `@MainActor`，故测试类标 `@MainActor`。
@MainActor
final class ConversationServiceTests: XCTestCase {
    override func setUp() { MockURLProtocol.reset() }
    override func tearDown() { MockURLProtocol.reset() }

    func testChatRequestEncodesSnakeCase() throws {
        let request = ChatRequest(
            message: "你好",
            patientId: "p1",
            sessionId: "s1",
            context: [ChatContextTurn(role: "user", content: "hi")]
        )
        let json = try XCTUnwrap(String(data: APIClient.makeEncoder().encode(request), encoding: .utf8))
        XCTAssertTrue(json.contains("\"patient_id\":\"p1\""), json)
        XCTAssertTrue(json.contains("\"session_id\":\"s1\""), json)
        XCTAssertTrue(json.contains("\"message\":\"你好\""), json)
        XCTAssertTrue(json.contains("\"role\":\"user\""), json)
    }

    func testChatMetadataDecodingThreeShapes() throws {
        let decoder = APIClient.makeDecoder()
        let emergency = try decoder.decode(ChatMetadata.self, from: Data(#"{"guard":"emergency","reason":"危机"}"#.utf8))
        XCTAssertTrue(emergency.isGuarded)
        XCTAssertTrue(emergency.isEmergency)
        XCTAssertEqual(emergency.badge, "紧急提示")

        let block = try decoder.decode(ChatMetadata.self, from: Data(#"{"guard":"block"}"#.utf8))
        XCTAssertTrue(block.isGuarded)
        XCTAssertFalse(block.isEmergency)
        XCTAssertEqual(block.badge, "内容已拦截")

        let degraded = try decoder.decode(ChatMetadata.self, from: Data(#"{"degraded":true,"reason":"简化"}"#.utf8))
        XCTAssertFalse(degraded.isGuarded)
        XCTAssertEqual(degraded.badge, "简化回复")

        let empty = try decoder.decode(ChatMetadata.self, from: Data(#"{}"#.utf8))
        XCTAssertNil(empty.badge)
        XCTAssertFalse(empty.isGuarded)
    }

    func testSendNonStreaming() async throws {
        let client = APIClient.makeMock()
        let json = #"{"reply":"你好，我在","agent_role":"family_doctor","session_id":"s-1","metadata":null}"#
        MockURLProtocol.stub { _ in .init(statusCode: 200, body: Data(json.utf8)) }
        let service = RemoteConversationService(api: client, patientId: "test-pid")
        let reply = try await service.send(message: "你好")
        XCTAssertEqual(reply.reply, "你好，我在")
        XCTAssertEqual(reply.agentRole, "family_doctor")
        XCTAssertEqual(reply.sessionId, "s-1")
        XCTAssertNil(reply.metadata)
        XCTAssertTrue(MockURLProtocol.lastRequest!.url!.absoluteString.contains("/api/v1/chat"))
    }

    func testStreamReplyPrefersCompleteEvent() async throws {
        let client = APIClient.makeMock()
        let body = Data("event: message\ndata: {\"chunk\":\"部分\",\"done\":false}\n\nevent: complete\ndata: {\"reply\":\"最终全文[1]\",\"agent_role\":\"family_doctor\",\"session_id\":\"s-2\",\"references\":[{\"id\":\"ref-1\",\"title\":\"高血压健康管理指南\",\"source\":\"hypertension_guidelines.md\",\"excerpt\":\"家庭血压监测资料\",\"evidence_score\":0.8,\"kind\":\"local_knowledge_base\"}]}\n\n".utf8)
        MockURLProtocol.stub { _ in .init(statusCode: 200, chunks: [body]) }
        let service = RemoteConversationService(api: client, patientId: "test-pid")
        var chunks: [String] = []
        let final = try await service.streamReply(message: "hi") { chunks.append($0) }
        XCTAssertEqual(final.reply, "最终全文[1]", "complete 事件的全文应优先于累积文本")
        XCTAssertEqual(final.agentRole, "family_doctor")
        XCTAssertEqual(final.sessionId, "s-2")
        XCTAssertEqual(chunks, ["部分"])
        XCTAssertEqual(final.references.first?.title, "高血压健康管理指南")
    }

    func testStreamReplyThrowsOnErrorEvent() async {
        let client = APIClient.makeMock()
        let body = Data("event: error\ndata: {\"message\":\"生成失败\"}\n\n".utf8)
        MockURLProtocol.stub { _ in .init(statusCode: 200, chunks: [body]) }
        let service = RemoteConversationService(api: client, patientId: "test-pid")
        do {
            _ = try await service.streamReply(message: "hi") { _ in }
            XCTFail("收到 error 事件且无最终结果应抛错")
        } catch let error as APIError {
            guard case .http(_, let message) = error else { return XCTFail("期望 .http，实际 \(error)") }
            XCTAssertEqual(message, "生成失败")
        } catch {
            XCTFail("意外错误类型 \(error)")
        }
    }

    func testStreamReplyFallsBackToAccumulatedText() async throws {
        let client = APIClient.makeMock()
        // 无 complete 事件：用累积的 message chunk 文本兜底。
        let body = Data("event: message\ndata: {\"chunk\":\"你\",\"done\":false}\n\nevent: message\ndata: {\"chunk\":\"好\",\"done\":false}\n\n".utf8)
        MockURLProtocol.stub { _ in .init(statusCode: 200, chunks: [body]) }
        let service = RemoteConversationService(api: client, patientId: "test-pid")
        let final = try await service.streamReply(message: "hi") { _ in }
        XCTAssertEqual(final.reply, "你好")
        XCTAssertEqual(final.agentRole, "family_doctor")
    }

    func testDemoConversationServiceOfflineReply() async throws {
        let demo = DemoConversationService()
        let reply = try await demo.reply(to: "我有点头晕")
        XCTAssertFalse(reply.isEmpty, "离线演示服务应返回非空示例文本")
    }
}
