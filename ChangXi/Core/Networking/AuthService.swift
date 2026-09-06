import Foundation

/// 玄同后端用户信息（`GET /api/auth/me`、`POST /api/auth/register` 的响应体）。
///
/// 后端字段为 snake_case，经 ``APIClient`` 的 `.convertFromSnakeCase` 解码后：
/// `is_active` → `isActive`；`id` 为用户 UUID 字符串。
struct User: Codable, Sendable, Identifiable, Equatable {
    /// 用户 UUID（后端序列化为字符串）。
    let id: String
    let username: String
    let email: String
    /// 角色：`patient` / `doctor` / `nurse` / `admin`。
    let role: String
    /// 对应后端 `is_active`。
    let isActive: Bool
}

/// `POST /api/auth/register` 请求体（JSON）。
///
/// 经 `.convertToSnakeCase` 编码；字段均为单词，无下划线转换问题。
private struct RegisterRequest: Encodable {
    let username: String   // 3–60 字符
    let email: String      // 合法邮箱
    let password: String   // 6–128 字符
    let role: String       // patient / doctor / nurse / admin（大小写不敏感）
}

/// `POST /api/auth/login` 响应体：`{access_token, token_type}`。
private struct TokenResponse: Decodable {
    let accessToken: String   // access_token
    let tokenType: String     // token_type，通常为 "bearer"
}

/// 认证网络服务：封装注册 / 登录 / 当前用户三个端点（前缀 `/api/auth`）。
///
/// 后端契约要点：
/// - `POST /api/auth/register`（JSON）→ 201 返回用户信息；409 用户名/邮箱重复；422 角色非法或字段校验失败。
/// - `POST /api/auth/login`（**form-encoded**，OAuth2PasswordRequestForm）→ 200 `{access_token, token_type}`；
///   401 用户名或密码错误（`username` 字段可填用户名或邮箱）。
/// - `GET /api/auth/me`（需 `Authorization: Bearer`）→ 200 用户信息；401 token 失效。
/// - token 为 JWT(HS256)，默认有效期 60 分钟；**后端无 refresh 机制**，过期只能重新登录。
struct AuthService: Sendable {
    let api: APIClient

    init(api: APIClient = .shared) {
        self.api = api
    }

    /// 注册新用户。成功后返回后端创建的用户信息（尚未登录）。
    ///
    /// - Parameter role: 默认 `patient`；仅 `patient/doctor/nurse/admin` 合法（大小写不敏感）。
    func register(username: String, email: String, password: String, role: String = "patient") async throws -> User {
        let body = RegisterRequest(username: username, email: email, password: password, role: role)
        return try await api.post("/register", body: body, prefix: .auth)
    }

    /// 登录并返回 access token（**form-encoded**）。
    ///
    /// - Parameter identifier: 用户名或邮箱。
    func login(identifier: String, password: String) async throws -> String {
        let token: TokenResponse = try await api.postForm(
            "/login",
            form: ["username": identifier, "password": password],
            prefix: .auth
        )
        return token.accessToken
    }

    /// 获取当前登录用户（需已保存有效 token）。
    func currentUser() async throws -> User {
        try await api.get("/me", prefix: .auth)
    }
}
