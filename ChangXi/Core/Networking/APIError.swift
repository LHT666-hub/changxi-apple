import Foundation

/// 统一的网络错误模型。
///
/// 玄同后端存在两种错误 JSON 结构，本类型都能容错解析：
///
/// - **格式 A（FastAPI `HTTPException`，业务路由主流）**
///   ```json
///   { "detail": "Event not found" }
///   ```
///   `detail` 也可能是 FastAPI 默认校验错误那样的数组：`{"detail":[{"loc":[...],"msg":"...","type":"..."}]}`。
///
/// - **格式 B（`XuantongError` / 全局校验 / 500，见 `app/api/middleware/error_handler.py`）**
///   ```json
///   { "error": { "code": "MODEL_CALL_ERROR", "message": "...", "detail": { ... } } }
///   ```
///   其中 422 校验错误里键是复数 `details`（数组），而 `XuantongError` 里是单数 `detail`（对象）——两者都要容错。
///
/// 该错误面向 UI 展示时应使用 ``userFacingMessage``，绝不把原始 JSON 抛给用户。
enum APIError: Error {
    /// 后端返回了非 2xx 状态码，`message` 为已尽力解析出的可读描述。
    case http(status: Int, message: String)
    /// 请求参数校验失败（422），携带逐条字段错误描述。
    case validation([String])
    /// 传输层错误（无网络、超时、DNS、TLS 等），携带底层 `URLError`。
    case network(Error)
    /// 响应体无法解码为期望类型。
    case decoding(Error)
    /// 401 未认证 / token 失效。上层应触发重新登录。
    case unauthorized
    /// 后端明确繁忙（503 或降级 code），可稍后重试。
    case serverBusy

    /// 从一次失败的请求构造 ``APIError``。
    ///
    /// - Parameters:
    ///   - data: 响应体（可能为 `nil`，如纯传输错误）。
    ///   - response: URL 响应（用于取 HTTP 状态码）。
    ///   - underlying: 底层抛出的错误（`URLError` / `CancellationError` / 解码错误等）。
    ///   - requestID: 后端回写的 `X-Request-ID`（32 位 hex），会拼进错误描述便于联调。
    /// - Returns: 归类后的 ``APIError``。
    static func parse(
        data: Data?,
        response: URLResponse?,
        underlying: Error?,
        requestID: String? = nil
    ) -> APIError {
        // 1) 取消：原样透传，交由调用方按 CancellationError 处理。
        if let underlying, underlying is CancellationError {
            return .network(underlying)
        }

        // 2) 传输层错误（无 HTTP 响应）：归类为 network。
        guard let http = response as? HTTPURLResponse else {
            if let underlying { return .network(underlying) }
            return .network(URLError(.badServerResponse))
        }

        let status = http.statusCode

        // 3) 若调用方抛出的是解码错误且状态码正常，归类为 decoding。
        if let underlying, underlying is DecodingError, (200..<300).contains(status) {
            return .decoding(underlying)
        }

        // 4) 解析错误体（格式 A / B 都尝试）。
        let parsed = parseBody(data)
        let suffix = requestID.map { "（请求号 \($0.prefix(8))）" } ?? ""

        // 5) 按状态码归类。
        switch status {
        case 401:
            return .unauthorized
        case 422:
            let messages = parsed.validationMessages
            let base = messages.isEmpty ? [parsed.message ?? "请求参数校验失败"] : messages
            return .validation(base.map { $0 + suffix })
        case 503:
            return .serverBusy
        default:
            let message = (parsed.message ?? defaultMessage(for: status)) + suffix
            return .http(status: status, message: message)
        }
    }

    // MARK: - 用户可见文案

    /// 面向用户的中文友好文案（不暴露原始 JSON / 状态码细节）。
    var userFacingMessage: String {
        switch self {
        case .unauthorized:
            return "登录状态已过期，请重新登录。"
        case .serverBusy:
            return "服务器暂时繁忙，请稍后再试。"
        case .network(let error):
            if let urlError = error as? URLError {
                switch urlError.code {
                case .timedOut:
                    return "请求超时，请检查网络后重试。"
                case .notConnectedToInternet, .networkConnectionLost:
                    return "当前网络不可用，请检查网络连接。"
                case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                    return "无法连接到服务器，请稍后再试。"
                case .secureConnectionFailed, .serverCertificateUntrusted:
                    return "安全连接失败，请检查网络设置。"
                case .cancelled:
                    return "请求已取消。"
                default:
                    return "网络请求失败，请稍后再试。"
                }
            }
            return "网络请求失败，请稍后再试。"
        case .decoding:
            return "服务器返回的数据格式异常，请稍后再试。"
        case .validation(let messages):
            return messages.first ?? "提交的信息有误，请检查后重试。"
        case .http(let status, let message):
            // 后端已给出可读描述时优先展示，否则按状态码兜底。
            return message.isEmpty ? Self.defaultMessage(for: status) : message
        }
    }

    // MARK: - 内部解析

    /// 解析后的错误体中间结果。
    private struct ParsedBody {
        var message: String?
        var validationMessages: [String] = []
    }

    private static func parseBody(_ data: Data?) -> ParsedBody {
        var result = ParsedBody()
        guard let data, !data.isEmpty,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return result
        }

        // 格式 A：{"detail": "..."} 或 {"detail": [ {...}, ... ]}
        if let detail = object["detail"] {
            applyDetail(detail, into: &result)
        }

        // 格式 B：{"error": {"code","message","detail"|"details"}}
        if let error = object["error"] as? [String: Any] {
            if let message = error["message"] as? String, !message.isEmpty, result.message == nil {
                result.message = message
            }
            // 校验错误 details（复数，数组）
            if let details = error["details"] {
                applyDetail(details, into: &result)
            }
            // XuantongError detail（单数，对象/字符串）
            if let detail = error["detail"] {
                applyDetail(detail, into: &result)
            }
        }

        return result
    }

    /// 将 `detail` / `details` 字段（字符串、字符串数组、或 FastAPI 校验对象数组）归并进结果。
    private static func applyDetail(_ detail: Any, into result: inout ParsedBody) {
        if let string = detail as? String {
            if !string.isEmpty, result.message == nil { result.message = string }
            return
        }
        if let array = detail as? [[String: Any]] {
            // FastAPI/Pydantic 校验错误数组：[{loc, msg, type}, ...]
            let messages = array.compactMap { item -> String? in
                guard let msg = item["msg"] as? String else { return nil }
                if let loc = item["loc"] as? [Any] {
                    let field = loc.compactMap { $0 as? String }.filter { $0 != "body" }.joined(separator: ".")
                    return field.isEmpty ? msg : "\(field) \(msg)"
                }
                return msg
            }
            if !messages.isEmpty { result.validationMessages.append(contentsOf: messages) }
            return
        }
        if let strings = detail as? [String] {
            result.validationMessages.append(contentsOf: strings.filter { !$0.isEmpty })
            return
        }
        // 其它结构化对象：忽略（不向用户暴露）。
    }

    private static func defaultMessage(for status: Int) -> String {
        switch status {
        case 400: return "请求有误，请重试。"
        case 401: return "登录状态已过期，请重新登录。"
        case 403: return "没有访问权限。"
        case 404: return "请求的内容不存在。"
        case 409: return "内容已存在，请更换后重试。"
        case 422: return "提交的信息有误，请检查后重试。"
        case 429: return "操作过于频繁，请稍后再试。"
        case 500...599: return "服务器开小差了，请稍后再试。"
        default: return "请求失败，请稍后再试。"
        }
    }
}
