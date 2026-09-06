import XCTest
@testable import ChangXi

// 本文件私有探针。请求体必须显式传入以让 `stream<B: Encodable>` 的泛型 B 可推断（省略 body 会编译失败）。
private struct StreamBody: Encodable { let message: String }
private struct ChunkProbe: Decodable { let chunk: String; let done: Bool }

/// ``SSEClient`` POST-SSE 流测试：分帧、心跳丢弃、跨包重组、终止事件、建连错误。
///
/// `onEvent` 在 MainActor 回调，故测试类标 `@MainActor`；用本地数组收集事件。
@MainActor
final class SSEClientTests: XCTestCase {
    override func setUp() { MockURLProtocol.reset() }
    override func tearDown() { MockURLProtocol.reset() }

    private func makeSSE() -> SSEClient { SSEClient(api: .makeMock()) }

    func testMessageAndCompleteEvents() async throws {
        let sse = makeSSE()
        let body = Data("event: message\ndata: {\"chunk\":\"你\",\"done\":false}\n\nevent: message\ndata: {\"chunk\":\"好\",\"done\":false}\n\nevent: complete\ndata: {\"reply\":\"你好\"}\n\n".utf8)
        MockURLProtocol.stub { _ in .init(statusCode: 200, headers: ["Content-Type": "text/event-stream"], body: body) }
        var events: [SSEEvent] = []
        try await sse.stream(path: "/chat/stream", body: StreamBody(message: "hi")) { events.append($0) }
        XCTAssertEqual(events.map(\.name), ["message", "message", "complete"])
        XCTAssertEqual(events[0].data, "{\"chunk\":\"你\",\"done\":false}")
        let chunk = try events[0].decodeData(ChunkProbe.self)
        XCTAssertEqual(chunk.chunk, "你")
        XCTAssertFalse(chunk.done)
    }

    func testFramesReassembledAcrossChunks() async throws {
        let sse = makeSSE()
        // 把一个完整事件拆成多个传输分片，验证 bytes.lines 跨包重组。
        let chunks = [
            Data("event: mes".utf8),
            Data("sage\ndata: {\"ch".utf8),
            Data("unk\":\"分段\",\"done\":false}\n\nevent: complete\ndata: {\"reply\":\"ok\"}\n\n".utf8)
        ]
        MockURLProtocol.stub { _ in .init(statusCode: 200, chunks: chunks) }
        var events: [SSEEvent] = []
        try await sse.stream(path: "/chat/stream", body: StreamBody(message: "hi")) { events.append($0) }
        XCTAssertEqual(events.map(\.name), ["message", "complete"])
        XCTAssertEqual(events[0].data, "{\"chunk\":\"分段\",\"done\":false}")
    }

    func testHeartbeatCommentsDiscarded() async throws {
        let sse = makeSSE()
        let body = Data(": ping\n\nevent: message\ndata: {\"chunk\":\"A\"}\n\n: waiting\nevent: complete\ndata: {\"reply\":\"A\"}\n\n".utf8)
        MockURLProtocol.stub { _ in .init(statusCode: 200, body: body) }
        var events: [SSEEvent] = []
        try await sse.stream(path: "/chat/stream", body: StreamBody(message: "hi")) { events.append($0) }
        // `:` 开头的心跳行被丢弃，不产生事件。
        XCTAssertEqual(events.map(\.name), ["message", "complete"])
    }

    func testCompleteTerminatesStream() async throws {
        let sse = makeSSE()
        // complete 之后仍有 message，应被忽略（收到终止事件即 return）。
        let body = Data("event: complete\ndata: {\"reply\":\"done\"}\n\nevent: message\ndata: {\"chunk\":\"after\"}\n\n".utf8)
        MockURLProtocol.stub { _ in .init(statusCode: 200, body: body) }
        var events: [SSEEvent] = []
        try await sse.stream(path: "/chat/stream", body: StreamBody(message: "hi")) { events.append($0) }
        XCTAssertEqual(events.map(\.name), ["complete"])
    }

    func testNonTwoXXThrowsAPIError() async {
        let sse = makeSSE()
        MockURLProtocol.stub { _ in .init(statusCode: 500, body: Data(#"{"detail":"服务异常"}"#.utf8)) }
        do {
            try await sse.stream(path: "/chat/stream", body: StreamBody(message: "hi")) { _ in }
            XCTFail("建连非 2xx 应抛出 APIError")
        } catch let error as APIError {
            guard case .http(let status, _) = error else { return XCTFail("期望 .http，实际 \(error)") }
            XCTAssertEqual(status, 500)
        } catch {
            XCTFail("意外错误类型 \(error)")
        }
    }

    func testSSEEventDecodeDataUsesSnakeCaseDecoder() throws {
        struct Probe: Decodable { let agentRole: String }
        let event = SSEEvent(name: "complete", data: "{\"agent_role\":\"family_doctor\"}")
        XCTAssertEqual(try event.decodeData(Probe.self).agentRole, "family_doctor")
    }
}
