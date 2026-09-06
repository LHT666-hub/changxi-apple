import XCTest
@testable import ChangXi

// 本文件私有的探针类型（fileprivate 作用域，不与其它测试文件的同名类型冲突）。
private struct EmptyProbe: Decodable {}
private struct PatientProbe: Decodable { let patientId: String }
private struct SnakeProbe: Decodable { let patientId: String; let sessionId: String?; let createdAt: Date }
private struct DateProbe: Decodable { let at: Date }

/// ``APIClient`` 网络层测试：编解码策略、错误归类、请求构造、401 处理、Body 编码工具。
///
/// 全部经 ``MockURLProtocol`` 离线运行，不发真实网络请求（CI 无后端）。
final class APIClientTests: XCTestCase {
    override func setUp() { MockURLProtocol.reset() }
    override func tearDown() { MockURLProtocol.reset() }

    private func httpResp(_ status: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://unit.test/x")!,
            statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil
        )!
    }

    // MARK: - 解码策略

    func testSnakeCaseDecoding() throws {
        let json = #"{"patient_id":"p1","session_id":"s1","created_at":"2026-01-02T03:04:05Z"}"#
        let probe = try APIClient.makeDecoder().decode(SnakeProbe.self, from: Data(json.utf8))
        XCTAssertEqual(probe.patientId, "p1")
        XCTAssertEqual(probe.sessionId, "s1")
    }

    func testDateDecodingToleratesMultipleFormats() throws {
        let decoder = APIClient.makeDecoder()
        let plain = try decoder.decode(DateProbe.self, from: Data(#"{"at":"2026-01-02T03:04:05Z"}"#.utf8)).at
        let frac = try decoder.decode(DateProbe.self, from: Data(#"{"at":"2026-01-02T03:04:05.500Z"}"#.utf8)).at
        let space = try decoder.decode(DateProbe.self, from: Data(#"{"at":"2026-01-02 03:04:05"}"#.utf8)).at
        let stamp = try decoder.decode(DateProbe.self, from: Data(#"{"at":1767322445}"#.utf8)).at
        // 无小数秒的两种形态（带 T / 带空格）应解析为同一时刻。
        XCTAssertEqual(plain.timeIntervalSince1970, space.timeIntervalSince1970, accuracy: 1)
        // 带小数秒比不带多 0.5s。
        XCTAssertEqual(frac.timeIntervalSince1970 - plain.timeIntervalSince1970, 0.5, accuracy: 0.01)
        // Unix 时间戳分支：数值原样解释为秒。
        XCTAssertEqual(stamp.timeIntervalSince1970, 1767322445, accuracy: 0.001)
    }

    // MARK: - 错误归类（纯静态，不发请求）

    func testErrorFormatADetailString() {
        let error = APIError.parse(data: Data(#"{"detail":"资源不存在"}"#.utf8), response: httpResp(404), underlying: nil)
        guard case .http(let status, let message) = error else { return XCTFail("期望 .http，实际 \(error)") }
        XCTAssertEqual(status, 404)
        XCTAssertEqual(message, "资源不存在")
    }

    func testErrorFormatBObject() {
        let json = #"{"error":{"code":"MODEL_CALL_ERROR","message":"模型调用失败"}}"#
        let error = APIError.parse(data: Data(json.utf8), response: httpResp(500), underlying: nil)
        guard case .http(_, let message) = error else { return XCTFail("期望 .http，实际 \(error)") }
        XCTAssertEqual(message, "模型调用失败")
    }

    func testStackedFormatsDoNotCorruptMessage() {
        // detail 与 error 同时存在且都含内容时，message 取顶层 detail，不错乱。
        let json = #"{"detail":"X","error":{"code":"HTTP_404","message":"X","detail":"X","details":["X"]}}"#
        let error = APIError.parse(data: Data(json.utf8), response: httpResp(404), underlying: nil)
        guard case .http(let status, let message) = error else { return XCTFail("期望 .http，实际 \(error)") }
        XCTAssertEqual(status, 404)
        XCTAssertEqual(message, "X")
    }

    func testValidation422ArrayDetail() {
        let json = #"{"detail":[{"loc":["body","name"],"msg":"field required","type":"value_error"}]}"#
        let error = APIError.parse(data: Data(json.utf8), response: httpResp(422), underlying: nil)
        guard case .validation(let messages) = error else { return XCTFail("期望 .validation，实际 \(error)") }
        XCTAssertEqual(messages, ["name field required"])
    }

    func testUnauthorizedAndServerBusyClassification() {
        guard case .unauthorized = APIError.parse(data: nil, response: httpResp(401), underlying: nil)
        else { return XCTFail("401 应归类为 .unauthorized") }
        guard case .serverBusy = APIError.parse(data: nil, response: httpResp(503), underlying: nil)
        else { return XCTFail("503 应归类为 .serverBusy") }
    }

    func testTransportErrorBecomesNetwork() {
        let error = APIError.parse(data: nil, response: nil, underlying: URLError(.timedOut))
        guard case .network = error else { return XCTFail("期望 .network，实际 \(error)") }
        XCTAssertEqual(error.userFacingMessage, "请求超时，请检查网络后重试。")
    }

    func testRequestIDSuffixTruncatedToEight() {
        let rid = "0123456789abcdef0123456789abcdef"
        let error = APIError.parse(data: Data(#"{"detail":"boom"}"#.utf8), response: httpResp(404), underlying: nil, requestID: rid)
        guard case .http(_, let message) = error else { return XCTFail("期望 .http，实际 \(error)") }
        XCTAssertEqual(message, "boom（请求号 01234567）")
    }

    // MARK: - 请求构造（离线）

    func testGetBuildsPathAndSortedQuery() async throws {
        let client = APIClient.makeMock()
        MockURLProtocol.stub { _ in .init(statusCode: 200, body: Data(#"{"patient_id":"p1"}"#.utf8)) }
        let probe: PatientProbe = try await client.get("patients/p1", query: ["size": "20", "page": "1"], prefix: .legacy)
        XCTAssertEqual(probe.patientId, "p1")
        let url = try XCTUnwrap(MockURLProtocol.lastRequest?.url?.absoluteString)
        XCTAssertTrue(url.contains("/api/patients/p1"))
        XCTAssertTrue(url.contains("page=1&size=20"), "query 应按 name 排序：\(url)")
    }

    func testPostFormSetsFormContentType() async throws {
        let client = APIClient.makeMock()
        MockURLProtocol.stub { _ in .init(statusCode: 200, body: Data("{}".utf8)) }
        let _: EmptyProbe = try await client.postForm("/login", form: ["username": "u", "password": "p"], prefix: .auth)
        let request = try XCTUnwrap(MockURLProtocol.lastRequest)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")
        XCTAssertTrue(request.url!.absoluteString.contains("/api/auth/login"))
    }

    func testPostMultipartSetsBoundaryHeader() async throws {
        let client = APIClient.makeMock()
        MockURLProtocol.stub { _ in .init(statusCode: 200, body: Data("{}".utf8)) }
        let file = (name: "file", filename: "r.jpg", mime: "image/jpeg", data: Data("JPEG".utf8))
        let _: EmptyProbe = try await client.postMultipart("/documents/recognize", fields: ["kind": "report"], file: file)
        let contentType = try XCTUnwrap(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Content-Type"))
        XCTAssertTrue(contentType.hasPrefix("multipart/form-data; boundary=ChangXiBoundary-"), contentType)
    }

    func testNonTwoXXThrowsAPIError() async {
        let client = APIClient.makeMock()
        MockURLProtocol.stub { _ in .init(statusCode: 404, body: Data(#"{"detail":"未找到"}"#.utf8)) }
        do {
            let _: EmptyProbe = try await client.get("/missing")
            XCTFail("非 2xx 应抛出 APIError")
        } catch let error as APIError {
            guard case .http(let status, let message) = error else { return XCTFail("期望 .http，实际 \(error)") }
            XCTAssertEqual(status, 404)
            XCTAssertEqual(message, "未找到")
        } catch {
            XCTFail("意外错误类型 \(error)")
        }
    }

    func testUnauthorizedPostsSessionExpiredNotification() async {
        let client = APIClient.makeMock()
        MockURLProtocol.stub { _ in .init(statusCode: 401, body: Data(#"{"detail":"expired"}"#.utf8)) }
        let expectation = self.expectation(forNotification: .cxSessionExpired, object: nil) { _ in true }
        do {
            let _: EmptyProbe = try await client.get("/secure")
            XCTFail("401 应抛出")
        } catch let error as APIError {
            guard case .unauthorized = error else { return XCTFail("期望 .unauthorized，实际 \(error)") }
        } catch {
            XCTFail("意外错误类型 \(error)")
        }
        await fulfillment(of: [expectation], timeout: 2)
    }

    // MARK: - Keychain 相关（不可用时 XCTSkip，绝不 CI 红）

    func testUnauthorizedClearsStoredToken() async throws {
        let store = TokenStore(service: "com.lht.changxi.tests", account: "clear-\(UUID().uuidString)")
        defer { store.clear() }
        do { try store.save("secret-token") } catch { throw XCTSkip("Keychain 不可用：\(error)") }
        guard store.load() == "secret-token" else { throw XCTSkip("Keychain 写入未生效（需在模拟器手动验证）") }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let client = APIClient(baseURL: URL(string: "https://unit.test")!, session: URLSession(configuration: config), tokenStore: store)
        MockURLProtocol.stub { _ in .init(statusCode: 401) }
        do { let _: EmptyProbe = try await client.get("/secure") } catch { /* 预期抛错 */ }
        XCTAssertNil(store.load(), "401 后应清空本地 token")
    }

    func testAuthorizationHeaderInjectedWhenTokenPresent() async throws {
        let store = TokenStore(service: "com.lht.changxi.tests", account: "auth-\(UUID().uuidString)")
        defer { store.clear() }
        do { try store.save("tok-123") } catch { throw XCTSkip("Keychain 不可用：\(error)") }
        guard store.load() == "tok-123" else { throw XCTSkip("Keychain 写入未生效（需在模拟器手动验证）") }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let client = APIClient(baseURL: URL(string: "https://unit.test")!, session: URLSession(configuration: config), tokenStore: store)
        MockURLProtocol.stub { _ in .init(statusCode: 200, body: Data("{}".utf8)) }
        let _: EmptyProbe = try await client.get("/anything")
        XCTAssertEqual(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer tok-123")
    }

    // MARK: - Body 编码工具（纯静态，确定性）

    func testURLEncodedBodyIsSortedAndPercentEncoded() {
        let data = APIClient.urlEncodedBody(["b": "2", "a": "1 2", "c": "x&y"])
        XCTAssertEqual(String(data: data, encoding: .utf8), "a=1%202&b=2&c=x%26y")
    }

    func testMultipartBodyFormatAndFieldOrder() throws {
        let data = APIClient.multipartBody(
            boundary: "BND",
            fields: ["lang": "zh", "dialect": "yue"],
            file: (name: "file", filename: "a.wav", mime: "audio/wav", data: Data("RIFF".utf8))
        )
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(text.contains("--BND\r\n"))
        XCTAssertTrue(text.contains("Content-Disposition: form-data; name=\"dialect\"\r\n\r\nyue\r\n"))
        XCTAssertTrue(text.contains("Content-Disposition: form-data; name=\"lang\"\r\n\r\nzh\r\n"))
        XCTAssertTrue(text.contains("Content-Disposition: form-data; name=\"file\"; filename=\"a.wav\"\r\n"))
        XCTAssertTrue(text.contains("Content-Type: audio/wav\r\n\r\nRIFF\r\n"))
        XCTAssertTrue(text.hasSuffix("--BND--\r\n"))
        // fields 键排序：dialect 段应出现在 lang 段之前。
        let dialectAt = try XCTUnwrap(text.range(of: "name=\"dialect\"")?.lowerBound)
        let langAt = try XCTUnwrap(text.range(of: "name=\"lang\"")?.lowerBound)
        XCTAssertLessThan(dialectAt, langAt)
    }
}
