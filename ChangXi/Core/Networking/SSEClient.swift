import Foundation

/// 一条已解析的 SSE（Server-Sent Events）报文。
struct SSEEvent: Sendable {
    /// 事件名。后端无 `event:` 行时为默认值 `"message"`。
    let name: String
    /// `data:` 行拼接后的原始字符串（通常是 JSON）。多行 `data:` 以 `\n` 连接。
    let data: String

    /// 将 ``data`` 按 JSON 解码为 `T`（沿用 ``APIClient`` 的 snake_case → camelCase 解码策略）。
    func decodeData<T: Decodable>(_ type: T.Type) throws -> T {
        guard let payload = data.data(using: .utf8) else {
            throw APIError.decoding(
                DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: [], debugDescription: "SSE data 非合法 UTF-8")
                )
            )
        }
        return try APIClient.makeDecoder().decode(T.self, from: payload)
    }
}

/// 手写 SSE 客户端，专门处理玄同后端 **POST** 方式的 `text/event-stream`。
///
/// 浏览器 `EventSource` 只支持 GET，而后端 `POST /api/v1/chat/stream` 是 POST 的 SSE，
/// 因此这里用 `URLSession.bytes(for:)` 逐行读取并按 SSE 规范分帧：
///
/// - 以空行（`\n\n`）分隔报文块；
/// - 块内 `event:` 行取事件名，缺省为 `"message"`；
/// - `data:` 行后是内容（多行按 `\n` 拼接）；
/// - 以 `:` 开头的行是注释 / 心跳（如 `: ping`、`: waiting`）→ 直接丢弃；
/// - 收到 `event: complete` 或 `event: timeout` 后主动关闭连接。
///
/// 支持 Task 取消：取消后底层字节流抛出 `CancellationError`，连接随之关闭。
///
/// 回调 ``stream(path:body:prefix:onEvent:)`` 的 `onEvent` 在 **主线程**（MainActor）上被调用，
/// 便于 UI 直接更新状态。
struct SSEClient: Sendable {
    /// 复用 ``APIClient`` 的请求构造（鉴权头、明文 HTTP 校验、编码器）与 URLSession。
    let api: APIClient

    init(api: APIClient = .shared) {
        self.api = api
    }

    /// 发起 POST SSE 流并逐事件回调。
    ///
    /// - Parameters:
    ///   - path: 相对路径（如 `/chat/stream`），会拼上 ``APIPrefix`` 前缀。
    ///   - body: JSON 请求体（可选）。
    ///   - prefix: 路由前缀，默认 `.v1`。
    ///   - onEvent: 每解析出一条事件即在主线程回调；收到 `complete`/`timeout` 后函数返回。
    /// - Throws: 建连失败（非 2xx）或传输中断时抛 ``APIError``；被取消时抛 `CancellationError`。
    func stream<B: Encodable>(
        path: String,
        body: B? = nil,
        prefix: APIPrefix = .v1,
        onEvent: @escaping @MainActor (SSEEvent) -> Void
    ) async throws {
        let request: URLRequest
        if let body {
            request = try api.makeRequest(
                path: path,
                prefix: prefix,
                method: "POST",
                body: body,
                accept: "text/event-stream"
            )
        } else {
            request = try api.makeRequest(
                path: path,
                prefix: prefix,
                method: "POST",
                accept: "text/event-stream"
            )
        }

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

        // 建连阶段非 2xx：读取错误体后抛出（此时尚未进入事件流）。
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

        var buffer = Data()

        // AsyncLineSequence 在部分 URLProtocol 实现中会折叠空行；直接按字节识别帧边界，
        // 同时兼容 LF 与 CRLF，并保留跨网络分片的半帧。
        for try await byte in bytes {
            try Task.checkCancellation()
            buffer.append(byte)
            while let delimiter = Self.frameDelimiter(in: buffer) {
                let frame = Data(buffer[..<delimiter.lowerBound])
                buffer.removeSubrange(..<delimiter.upperBound)
                guard let event = Self.parseFrame(frame) else { continue }
                await onEvent(event)
                if event.name == "complete" || event.name == "timeout" {
                    return
                }
            }
        }

        // 流自然结束但未收到显式终止事件：派发残留的最后一块（若有）。
        if let event = Self.parseFrame(buffer) {
            await onEvent(event)
        }
    }

    private static func frameDelimiter(in data: Data) -> Range<Data.Index>? {
        let lf = Data([0x0A, 0x0A])
        let crlf = Data([0x0D, 0x0A, 0x0D, 0x0A])
        let lfRange = data.range(of: lf)
        let crlfRange = data.range(of: crlf)
        switch (lfRange, crlfRange) {
        case let (left?, right?): return left.lowerBound < right.lowerBound ? left : right
        case let (left?, nil): return left
        case let (nil, right?): return right
        case (nil, nil): return nil
        }
    }

    private static func parseFrame(_ data: Data) -> SSEEvent? {
        guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return nil }
        var eventName: String?
        var dataLines: [String] = []

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.hasSuffix("\r") ? String(rawLine.dropLast()) : rawLine
            if line.hasPrefix(":") || line.isEmpty { continue }
            if line.hasPrefix("event:") {
                eventName = String(line.dropFirst("event:".count)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                var value = String(line.dropFirst("data:".count))
                if value.hasPrefix(" ") { value.removeFirst() }
                dataLines.append(value)
            }
        }
        guard eventName != nil || !dataLines.isEmpty else { return nil }
        return SSEEvent(name: eventName ?? "message", data: dataLines.joined(separator: "\n"))
    }
}
