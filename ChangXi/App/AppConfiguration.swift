import Foundation

/// 应用级运行配置：决定对话/认证服务走本地示例还是远程玄同后端，并集中管理后端地址、
/// API 前缀与明文 HTTP 放行策略。
///
/// 后端三组路由前缀并不统一：
/// - 认证在 `/api/auth`（``apiPrefixAuth``）
/// - 对话 / 多模态 / 文档 / SSE 在 `/api/v1`（``apiPrefixV1``）
/// - 患者 / 健康记录 / 事件 / 任务在 `/api`（``apiPrefixLegacy``）
enum AppConfiguration {
    // MARK: - 远程开关

    /// UI 自动化运行标记，用于关闭持续动画等会干扰测试空闲判定的效果。
    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("--ui-testing")
            || ProcessInfo.processInfo.arguments.contains("--integration-testing")
    }

    /// 是否连接远程玄同后端。
    ///
    /// - UI 测试（`--ui-testing`）下强制返回 `false`，保证测试确定性、不依赖网络；
    /// - 其余场景默认连接后端；对话连接失败明确报错，不伪装成本地示例回复。
    static var useRemoteAPI: Bool {
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") { return false }
        return true
    }

    // MARK: - 基础地址

    /// 玄同后端基础地址，按以下优先级解析：
    ///
    /// 1. 启动参数 `-apiBaseURL <url>`（便于 UI 测试 / 联调注入，如
    ///    `["-apiBaseURL", "http://192.168.1.20:8000"]`）；
    /// 2. `Info.plist` 的 `CX_API_BASE_URL` 键；
    /// 3. 编译期兜底：模拟器 → `http://127.0.0.1:8000`；真机 → ``deviceFallbackBaseURL``。
    static var apiBaseURL: URL {
        // ① 启动参数注入
        if let fromArgs = baseURLOverride(fromArguments: ProcessInfo.processInfo.arguments) {
            return fromArgs
        }
        if let raw = ProcessInfo.processInfo.environment["XUANTONG_BASE_URL"], let url = sanitizedURL(raw) { return url }
        if let raw = UserDefaults.standard.string(forKey: "cx.backend.url"), let url = sanitizedURL(raw) { return url }
        // ② Info.plist 配置
        if let plistValue = Bundle.main.object(forInfoDictionaryKey: "CX_API_BASE_URL") as? String,
           let url = URL(string: plistValue.trimmingCharacters(in: .whitespacesAndNewlines)),
           url.scheme != nil, url.host != nil {
            return url
        }
        // ③ 编译期兜底
        #if targetEnvironment(simulator)
        return URL(string: "http://127.0.0.1:8000")!
        #else
        return deviceFallbackBaseURL
        #endif
    }

    /// 真机编译期兜底地址。
    ///
    /// - Important: 真机无法访问开发机的 `127.0.0.1`。**发布真机构建前必须**通过以下任一方式提供地址：
    ///   - 运行时注入启动参数 `-apiBaseURL http://<局域网IP>:8000`；
    ///   - 在 `Info.plist` 配置 `CX_API_BASE_URL`；
    ///   - 或直接修改下面的常量为局域网 IP / 正式域名。
    ///
    /// TODO(联调): 将 `deviceFallbackBaseURLString` 替换为真实可达地址后再进行真机测试。
    static let deviceFallbackBaseURLString = "http://127.0.0.1:8000"
    static var deviceFallbackBaseURL: URL {
        URL(string: deviceFallbackBaseURLString) ?? URL(string: "http://127.0.0.1:8000")!
    }

    /// 从启动参数中解析 `-apiBaseURL <url>`（也兼容 `--apiBaseURL=<url>` 写法）。
    private static func baseURLOverride(fromArguments arguments: [String]) -> URL? {
        for (index, arg) in arguments.enumerated() {
            if arg == "-apiBaseURL" || arg == "--apiBaseURL" {
                if index + 1 < arguments.count,
                   let url = sanitizedURL(arguments[index + 1]) {
                    return url
                }
            }
            if arg.hasPrefix("-apiBaseURL=") || arg.hasPrefix("--apiBaseURL=") {
                let value = String(arg.drop(while: { $0 != "=" }).dropFirst())
                if let url = sanitizedURL(value) { return url }
            }
        }
        return nil
    }

    static func sanitizedURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed),
              ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              url.path.isEmpty || url.path == "/",
              !["github.com", "www.github.com"].contains(host.lowercased()) else {
            return nil
        }
        return url
    }

    // MARK: - API 前缀

    /// 认证路由前缀：`/api/auth`（register / login / me）。
    static let apiPrefixAuth = "/api/auth"
    /// v1 路由前缀：`/api/v1`（chat / chat/stream / multimodal / documents / SSE events）。
    static let apiPrefixV1 = "/api/v1"
    /// 旧版路由前缀：`/api`（patients / health_records / events / tasks / timeline）。
    static let apiPrefixLegacy = "/api"
    /// 玄同生产分支已提供认证、流式对话、多模态、文档与事件进度接口。
    static let supportsExtendedAPI = true

    // MARK: - 超时

    /// 网络请求默认超时（秒）。对话生成可能较慢，统一放宽到 60s。
    static var requestTimeout: TimeInterval { 60 }

    // MARK: - 明文 HTTP 策略

    /// 是否为本地回环地址（localhost / 127.0.0.1 / ::1）。
    static func isLocalDevelopment(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "localhost" || host == "127.0.0.1" || host == "::1" || host == "[::1]"
    }

    /// 是否允许对该地址使用明文 HTTP。
    ///
    /// - DEBUG：放行（便于连接本地开发后端）；
    /// - Release：仅对本地回环地址放行，其余强制 HTTPS。
    static func allowsInsecureHTTP(_ url: URL) -> Bool {
        #if DEBUG
        return true
        #else
        return isLocalDevelopment(url)
        #endif
    }
}

/// API 路由前缀枚举，供 ``APIClient`` / ``SSEClient`` 选择正确的后端分组。
enum APIPrefix: String, Sendable {
    /// `/api/auth` —— 认证（注册 / 登录 / 当前用户）。
    case auth = "/api/auth"
    /// `/api/v1` —— 对话、流式对话、多模态、文档、SSE 事件流。
    case v1 = "/api/v1"
    /// `/api` —— 患者、健康记录、事件、任务、时间线（旧版前缀）。
    case legacy = "/api"
}

extension Notification.Name {
    /// 后端返回 401（token 失效 / 过期）时由 ``APIClient`` 发出。
    ///
    /// 后端**没有 refresh 机制**，收到该通知后应清空本地会话并跳转登录页。
    static let cxSessionExpired = Notification.Name("com.lht.changxi.session.expired")
}

struct BackendProbe {
    struct Response: Decodable {
        struct App: Decodable { let status: String }
        struct LLM: Decodable { let provider: String; let healthy: Bool }
        let app: App
        let llm: LLM
    }
    let provider: String
    static func check(_ baseURL: URL, session: URLSession = .shared) async throws -> BackendProbe {
        var request = URLRequest(url: baseURL.appending(path: "api/health/detail"))
        request.timeoutInterval = 8
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let result = try JSONDecoder().decode(Response.self, from: data)
        guard result.app.status == "ok", result.llm.healthy else { throw URLError(.cannotConnectToHost) }
        return .init(provider: result.llm.provider)
    }
}
