import Foundation
import XCTest
@testable import ChangXi

final class XuantongEventConversationServiceTests: XCTestCase {
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
            let data = Data(#"{"workflow":{"status":"completed","patient_communication":"  已记录  ","clinical_risk":"yellow"}}"#.utf8)
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
