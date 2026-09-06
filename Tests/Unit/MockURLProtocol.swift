import Foundation
@testable import ChangXi

/// 单元测试专用的 `URLProtocol` mock（零第三方依赖）。
///
/// 通过 `URLSessionConfiguration.protocolClasses` 注入，拦截 ``APIClient`` / ``SSEClient`` 的全部请求并返回预设响应。
/// CI（GitHub Actions macOS-15）**没有后端服务**，任何真实网络请求都会超时失败；本 mock 让网络层测试完全离线、确定性运行。
///
/// - Important: CI 使用 `-parallel-testing-enabled NO`，测试**串行**执行，因此可以用静态 handler 保存当前用例的桩响应；
///   每个用例在 `setUp` / `tearDown` 调用 ``MockURLProtocol/reset()`` 清理，避免用例间串扰。
final class MockURLProtocol: URLProtocol {
    /// 一次请求的预设响应。
    struct Stub {
        /// HTTP 状态码。
        var statusCode: Int = 200
        /// 响应头。
        var headers: [String: String] = [:]
        /// 一次性响应体（非流式）。
        var body: Data = Data()
        /// 流式分片（SSE 用）：非空时按序多次 `didLoad` 交付，用于测试跨包分帧。
        var chunks: [Data] = []
        /// 传输层错误：非 nil 时请求直接失败（模拟断网 / 超时）。
        var error: Error?
    }

    private static let lock = NSLock()
    private static var handler: ((URLRequest) -> Stub)?
    private static var captured: [URLRequest] = []

    /// 设置桩响应生成器（每个用例调用一次）。
    static func stub(_ handler: @escaping (URLRequest) -> Stub) {
        lock.lock(); defer { lock.unlock() }
        self.handler = handler
    }

    /// 已捕获的请求（按发生顺序）。用于断言 method / path / headers。
    static var capturedRequests: [URLRequest] {
        lock.lock(); defer { lock.unlock() }
        return captured
    }

    /// 最近一次捕获的请求。
    static var lastRequest: URLRequest? { capturedRequests.last }

    /// 清空 handler 与已捕获请求。
    static func reset() {
        lock.lock(); defer { lock.unlock() }
        handler = nil
        captured = []
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        MockURLProtocol.lock.lock()
        MockURLProtocol.captured.append(request)
        let handler = MockURLProtocol.handler
        MockURLProtocol.lock.unlock()

        let stub = handler?(request) ?? Stub()

        if let error = stub.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        guard let url = request.url,
              let response = HTTPURLResponse(
                url: url, statusCode: stub.statusCode,
                httpVersion: "HTTP/1.1", headerFields: stub.headers
              ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if !stub.chunks.isEmpty {
            for chunk in stub.chunks { client?.urlProtocol(self, didLoad: chunk) }
        } else if !stub.body.isEmpty {
            client?.urlProtocol(self, didLoad: stub.body)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

extension APIClient {
    /// 构造一个走 ``MockURLProtocol`` 的测试用客户端（离线、确定性）。
    ///
    /// - baseURL 用 `https://unit.test`：`https` 前缀绕过 ``APIClient`` 的明文 HTTP 校验，
    ///   且请求被 mock 拦截，不发生真实 DNS / TLS。
    /// - TokenStore 用**唯一随机 account**：即使 Keychain 不可用，`load()` 也只返回 nil（不抛错），
    ///   不影响请求构造；测试从不调用其 `save`。
    static func makeMock(baseURLString: String = "https://unit.test") -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let store = TokenStore(service: "com.lht.changxi.tests", account: "mock-\(UUID().uuidString)")
        return APIClient(baseURL: URL(string: baseURLString)!, session: session, tokenStore: store)
    }
}
