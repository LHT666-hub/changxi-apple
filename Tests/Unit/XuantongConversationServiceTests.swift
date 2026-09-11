import Foundation
import XCTest
@testable import ChangXi

final class XuantongEventConversationServiceTests: XCTestCase {
    func testWorkflowRolesUsePatientFacingChinese() {
        XCTAssertEqual(WorkflowNodeName.roleDisplay("assistant"), "常曦助手")
        XCTAssertEqual(WorkflowNodeName.roleDisplay("human_doctor"), "家庭医生")
        XCTAssertEqual(WorkflowNodeName.roleDisplay("pharmacist"), "药师")
    }

    func testBackendAddressValidation() {
        XCTAssertNotNil(AppConfiguration.sanitizedURL("https://api.example.com"))
        XCTAssertNotNil(AppConfiguration.sanitizedURL("http://192.168.1.20:8000"))
        XCTAssertNil(AppConfiguration.sanitizedURL("https://github.com/LHT666-hub/xuantong"))
        XCTAssertNil(AppConfiguration.sanitizedURL("https://user:secret@example.com"))
        XCTAssertNil(AppConfiguration.sanitizedURL("file:///tmp/backend"))
        XCTAssertNil(AppConfiguration.sanitizedURL("https://example.com/api/events"))
    }

    func testBackendProbeReportsMockHonestly() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: configuration)
        URLProtocolStub.handler = { request in
            XCTAssertEqual(request.url?.path, "/api/health/detail")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"app":{"status":"ok"},"llm":{"provider":"mock","healthy":true}}"#.utf8))
        }
        defer { URLProtocolStub.handler = nil }
        let status = try await BackendProbe.check(URL(string: "http://127.0.0.1:8000")!, session: session)
        XCTAssertEqual(status.provider, "mock")
    }
    func testEventContractAndRiskMapping() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: configuration)

        URLProtocolStub.handler = { request in
            XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1:8000/api/events")
            XCTAssertEqual(request.httpMethod, "POST")

            let body = try bodyData(from: request)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["patient_id"] as? String, "patient-001")
            XCTAssertEqual(json["event_type"] as? String, "patient.message.received")
            XCTAssertEqual(json["channel"] as? String, "changxi")
            XCTAssertEqual(json["source"] as? String, "changxi-ios")
            XCTAssertEqual((json["payload"] as? [String: String])?["message"], "今天有点头晕")

            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 201,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let data = Data(#"{"workflow":{"status":"completed","patient_communication":"  已记录  ","clinical_risk":"yellow","action_summary":"继续记录","steps":["rag_retrieval","task_generation"],"references":[{"id":"ref-1","title":"高血压健康管理指南","source":"WHO","excerpt":"记录血压","evidence_score":0.8,"kind":"web_source","url":"https://www.who.int/example"}]},"tasks":[{"id":"task-1","title":"指标监测","description":"连续记录血压","task_type":"monitoring","status":"pending","priority":"medium","assignee_role":"assistant","deadline":null}] }"#.utf8)
            return (response, data)
        }
        defer { URLProtocolStub.handler = nil }

        let service = XuantongEventConversationService(
            baseURL: URL(string: "http://127.0.0.1:8000")!,
            session: session
        )
        let reply = try await service.reply(to: "今天有点头晕", patientID: "patient-001")

        XCTAssertEqual(reply.text, "已记录")
        XCTAssertEqual(reply.clinicalRisk, .yellow)
        XCTAssertEqual(reply.references.first?.title, "高血压健康管理指南")
        XCTAssertEqual(reply.references.first?.url, "https://www.who.int/example")
        XCTAssertEqual(reply.workOrders.first?.title, "指标监测")
        XCTAssertEqual(reply.steps, ["rag_retrieval", "task_generation"])
    }

    func testEventRequestsAttachJWTWhenAvailable() async throws {
        let tokenStore = TokenStore(
            service: "com.lht.changxi.tests.\(UUID().uuidString)",
            account: "access_token"
        )
        do {
            try tokenStore.save("signed-token")
        } catch {
            throw XCTSkip("当前测试环境无法使用 Keychain：\(error)")
        }
        defer { tokenStore.clear() }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: configuration)
        URLProtocolStub.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer signed-token")
            return (
                HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!,
                Data(#"{"workflow":{"status":"completed","patient_communication":"已收到"}}"#.utf8)
            )
        }
        defer { URLProtocolStub.handler = nil }

        let service = XuantongEventConversationService(
            baseURL: URL(string: "http://127.0.0.1:8000")!,
            session: session,
            tokenStore: tokenStore
        )
        _ = try await service.reply(to: "你好", patientID: "patient-001")
    }

    func testAcceptProposedTaskUsesExplicitConsentEndpoint() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: configuration)
        URLProtocolStub.handler = { request in
            XCTAssertEqual(request.url?.path, "/api/tasks/task-1/accept")
            XCTAssertEqual(request.httpMethod, "POST")
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(#"{"status":"accepted"}"#.utf8)
            )
        }
        defer { URLProtocolStub.handler = nil }

        let service = XuantongEventConversationService(
            baseURL: URL(string: "http://127.0.0.1:8000")!,
            session: session
        )
        try await service.acceptTask(id: "task-1")
    }
}

private func bodyData(from request: URLRequest) throws -> Data {
    if let body = request.httpBody { return body }
    let stream = try XCTUnwrap(request.httpBodyStream)
    stream.open()
    defer { stream.close() }

    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 1_024)
    while stream.hasBytesAvailable {
        let count = stream.read(&buffer, maxLength: buffer.count)
        if count < 0 { throw stream.streamError ?? URLError(.cannotDecodeContentData) }
        if count == 0 { break }
        data.append(buffer, count: count)
    }
    return data
}

private final class URLProtocolStub: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let handler = try XCTUnwrap(Self.handler)
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
