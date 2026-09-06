import Foundation

/// 玄同后端统一 HTTP 客户端（可复用的公共网络基础设施）。
///
/// 特性：
/// - **snake_case ↔ camelCase 自动转换**：解码用 `.convertFromSnakeCase`，编码用 `.convertToSnakeCase`；
///   因此 Swift 侧属性请按转换后的驼峰命名（如后端 `patient_id` → Swift `patientId`，
///   后端 `session_id` → Swift `sessionId`），无需为每个字段写 `CodingKeys`。
/// - **容错日期解码**：兼容后端 `created_at` 带/不带小数秒、带/不带时区的多种 ISO-8601 形态。
/// - **自动注入** `Authorization: Bearer <token>`（从 ``TokenStore`` 读取）。
/// - **401 处理**：清空 token 并发送 ``Notification.Name/cxSessionExpired`` 通知（后端无 refresh 机制）。
/// - **X-Request-ID**：从响应头读取并拼进错误信息，便于联调排障。
/// - 三组前缀通过 ``APIPrefix`` 选择（认证 `/api/auth`、v1 `/api/v1`、旧版 `/api`）。
///
/// 线程安全：所有存储属性均为 `let` 且 `Sendable`，可在任意并发上下文使用。
final class APIClient: Sendable {
    /// 全局共享实例（默认读取 ``AppConfiguration/apiBaseURL``）。
    static let shared = APIClient()

    /// 后端基础地址。
    let baseURL: URL
    /// 底层 URL 会话（可注入以便测试）。
    let session: URLSession
    /// JWT 存储（可注入以便测试）。
    let tokenStore: TokenStore

    init(
        baseURL: URL = AppConfiguration.apiBaseURL,
        session: URLSession = .shared,
        tokenStore: TokenStore = TokenStore()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.tokenStore = tokenStore
    }

    // MARK: - 编解码器

    /// 构造统一的 JSON 解码器（snake_case → camelCase，容错 ISO-8601 日期）。
    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom(decodeDate)
        return decoder
    }

    /// 构造统一的 JSON 编码器（camelCase → snake_case，ISO-8601 日期）。
    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    // 缓存的日期解析器（DateFormatter/ISO8601DateFormatter 创建成本高）。
    private static let iso8601WithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let iso8601Plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    private static let fallbackDateFormatters: [DateFormatter] = {
        let patterns = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss"
        ]
        return patterns.map { pattern in
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(secondsFromGMT: 0)
            f.dateFormat = pattern
            return f
        }
    }()

    /// 容错日期解码：支持 Unix 时间戳、多种 ISO-8601（含/不含小数秒与时区）、以及 `YYYY-MM-DD HH:MM:SS`。
    private static func decodeDate(_ decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        if let timestamp = try? container.decode(Double.self) {
            return Date(timeIntervalSince1970: timestamp)
        }
        let string = try container.decode(String.self)
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if let date = iso8601WithFractional.date(from: trimmed) { return date }
        if let date = iso8601Plain.date(from: trimmed) { return date }
        for formatter in fallbackDateFormatters {
            if let date = formatter.date(from: trimmed) { return date }
        }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "无法解析日期字符串: \(string)"
        )
    }

    // MARK: - 高层请求方法

    /// GET 请求并解码为 `T`。
    func get<T: Decodable>(
        _ path: String,
        query: [String: String]? = nil,
        prefix: APIPrefix = .v1
    ) async throws -> T {
        let request = try makeRequest(path: path, prefix: prefix, method: "GET", query: query)
        let (data, _) = try await perform(request)
        return try decode(T.self, from: data)
    }

    /// POST 请求（可选 JSON body）并解码为 `T`。
    func post<B: Encodable, T: Decodable>(
        _ path: String,
        body: B? = nil,
        query: [String: String]? = nil,
        prefix: APIPrefix = .v1
    ) async throws -> T {
        let request: URLRequest
        if let body {
            request = try makeRequest(path: path, prefix: prefix, method: "POST", body: body, query: query)
        } else {
            request = try makeRequest(path: path, prefix: prefix, method: "POST", query: query)
        }
        let (data, _) = try await perform(request)
        return try decode(T.self, from: data)
    }

    /// PUT 请求（可选 JSON body）并解码为 `T`。
    func put<B: Encodable, T: Decodable>(
        _ path: String,
        body: B? = nil,
        query: [String: String]? = nil,
        prefix: APIPrefix = .v1
    ) async throws -> T {
        let request: URLRequest
        if let body {
            request = try makeRequest(path: path, prefix: prefix, method: "PUT", body: body, query: query)
        } else {
            request = try makeRequest(path: path, prefix: prefix, method: "PUT", query: query)
        }
        let (data, _) = try await perform(request)
        return try decode(T.self, from: data)
    }

    /// DELETE 请求并解码为 `T`。
    func delete<T: Decodable>(
        _ path: String,
        query: [String: String]? = nil,
        prefix: APIPrefix = .v1
    ) async throws -> T {
        let request = try makeRequest(path: path, prefix: prefix, method: "DELETE", query: query)
        let (data, _) = try await perform(request)
        return try decode(T.self, from: data)
    }

    /// POST `application/x-www-form-urlencoded` 表单（用于 `/api/auth/login`，后端是 OAuth2PasswordRequestForm）。
    ///
    /// - Warning: 登录端点**必须**用表单编码，发 JSON 会被后端判为 422。
    func postForm<T: Decodable>(
        _ path: String,
        form: [String: String],
        prefix: APIPrefix = .auth
    ) async throws -> T {
        var request = try makeRequest(path: path, prefix: prefix, method: "POST")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.urlEncodedBody(form)
        let (data, _) = try await perform(request)
        return try decode(T.self, from: data)
    }

    /// POST `multipart/form-data`（用于多模态：语音转写、文档识别等文件上传）。
    ///
    /// - Parameters:
    ///   - fields: 普通文本字段。
    ///   - file: 可选文件字段（后端 `UploadFile` 约定字段名为 `file`）。
    func postMultipart<T: Decodable>(
        _ path: String,
        fields: [String: String] = [:],
        file: (name: String, filename: String, mime: String, data: Data)? = nil,
        prefix: APIPrefix = .v1
    ) async throws -> T {
        let boundary = "ChangXiBoundary-\(UUID().uuidString)"
        var request = try makeRequest(path: path, prefix: prefix, method: "POST", accept: "application/json")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.multipartBody(boundary: boundary, fields: fields, file: file)
        let (data, _) = try await perform(request)
        return try decode(T.self, from: data)
    }

    // MARK: - 请求构造（供 SSEClient 复用）

    /// 构造一个**无请求体**的 `URLRequest`（GET / DELETE / 表单 / multipart 用）。
    ///
    /// - Note: 该方法不做网络请求，仅构造请求对象，供 ``SSEClient`` 等需要自定义响应处理者复用。
    func makeRequest(
        path: String,
        prefix: APIPrefix = .v1,
        method: String,
        accept: String = "application/json",
        contentType: String? = "application/json",
        query: [String: String]? = nil
    ) throws -> URLRequest {
        try buildRequest(path: path, prefix: prefix, method: method, bodyData: nil, accept: accept, contentType: contentType, query: query)
    }

    /// 构造一个**带 JSON 请求体**的 `URLRequest`（POST / PUT / SSE 用）。
    ///
    /// - Note: `body` 为必填（非可选），以避免与无请求体重载产生泛型推断歧义；
    ///   编码沿用 ``makeEncoder()``（camelCase → snake_case）。
    func makeRequest<B: Encodable>(
        path: String,
        prefix: APIPrefix = .v1,
        method: String,
        body: B,
        accept: String = "application/json",
        contentType: String? = "application/json",
        query: [String: String]? = nil
    ) throws -> URLRequest {
        let bodyData = try Self.makeEncoder().encode(body)
        return try buildRequest(path: path, prefix: prefix, method: method, bodyData: bodyData, accept: accept, contentType: contentType, query: query)
    }

    /// 请求构造核心：拼装 URL、鉴权头、超时、明文 HTTP 校验与可选请求体。
    private func buildRequest(
        path: String,
        prefix: APIPrefix,
        method: String,
        bodyData: Data?,
        accept: String,
        contentType: String?,
        query: [String: String]?
    ) throws -> URLRequest {
        // 生产环境强制 HTTPS；开发模式或本地回环地址放行明文 HTTP。
        if baseURL.scheme?.lowercased() != "https", !AppConfiguration.allowsInsecureHTTP(baseURL) {
            throw APIError.network(URLError(.secureConnectionFailed))
        }

        var components = URLComponents()
        components.scheme = baseURL.scheme
        components.host = baseURL.host
        components.port = baseURL.port
        components.path = prefix.rawValue + (path.hasPrefix("/") ? path : "/" + path)
        if let query, !query.isEmpty {
            components.queryItems = query
                .map { URLQueryItem(name: $0.key, value: $0.value) }
                .sorted { $0.name < $1.name }
        }
        guard let url = components.url else {
            throw APIError.network(URLError(.badURL))
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.timeoutInterval = AppConfiguration.requestTimeout

        if let bodyData {
            request.httpBody = bodyData
            if let contentType {
                request.setValue(contentType, forHTTPHeaderField: "Content-Type")
            }
        }

        // 自动注入 Authorization。
        if let token = tokenStore.load(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    // MARK: - 底层执行

    /// 执行请求，返回响应体与 HTTP 响应；非 2xx 抛 ``APIError``，401 时清 token 并发通知。
    @discardableResult
    func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.parse(data: nil, response: nil, underlying: error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.parse(data: data, response: response, underlying: URLError(.badServerResponse))
        }

        let requestID = http.value(forHTTPHeaderField: "X-Request-ID")

        // 401：token 失效/过期，后端无 refresh，清本地并发通知触发重新登录。
        if http.statusCode == 401 {
            tokenStore.clear()
            NotificationCenter.default.post(name: .cxSessionExpired, object: nil)
        }

        guard (200..<300).contains(http.statusCode) else {
            throw APIError.parse(data: data, response: http, underlying: nil, requestID: requestID)
        }
        return (data, http)
    }

    /// 解码响应体，失败时归类为 ``APIError/decoding(_:)``。
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try Self.makeDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    // MARK: - Body 编码工具

    /// 将字典编码为 `application/x-www-form-urlencoded` 请求体。
    static func urlEncodedBody(_ form: [String: String]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~") // RFC 3986 unreserved
        let pairs = form.keys.sorted().map { key -> String in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let encodedValue = form[key]?.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
            return "\(encodedKey)=\(encodedValue)"
        }
        return Data(pairs.joined(separator: "&").utf8)
    }

    /// 构造 `multipart/form-data` 请求体。
    static func multipartBody(
        boundary: String,
        fields: [String: String],
        file: (name: String, filename: String, mime: String, data: Data)?
    ) -> Data {
        var body = Data()
        func append(_ string: String) { body.append(Data(string.utf8)) }

        for key in fields.keys.sorted() {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            append("\(fields[key] ?? "")\r\n")
        }
        if let file {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(file.name)\"; filename=\"\(file.filename)\"\r\n")
            append("Content-Type: \(file.mime)\r\n\r\n")
            body.append(file.data)
            append("\r\n")
        }
        append("--\(boundary)--\r\n")
        return body
    }
}
