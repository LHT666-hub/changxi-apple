import Foundation
import Observation

/// 认证会话状态机。
enum AuthState: Sendable, Equatable {
    /// 未登录。
    case signedOut
    /// 登录 / 注册 / 恢复会话进行中。
    case signingIn
    /// 已登录，携带后端用户信息。
    case signedIn(User)
    /// 认证失败，携带面向用户的中文错误文案。
    case failed(String)
}

/// 可观察的认证会话（`@Observable`，主线程隔离）。
///
/// 职责：
/// - 驱动登录 / 注册 / 登出 / 启动恢复会话；
/// - 从 Keychain 读取 JWT 并在启动时用 `GET /me` 校验（失败则静默登出）；
/// - 监听 ``Notification.Name/cxSessionExpired``（后端无 refresh，401 即需重新登录）自动置为 `signedOut`；
/// - 兼容既有 UI：真实登录成功后同步置 `AppStore.data.demoSignedIn = true`，
///   使依赖该布尔量的现有界面（如 ProfileView 账户区）无需改动。
@MainActor
@Observable
final class AuthSession {
    /// 当前认证状态。
    private(set) var state: AuthState = .signedOut

    private let auth: AuthService
    private let tokenStore: TokenStore
    private let appStore: AppStore?
    private var expiryObserver: NSObjectProtocol?

    /// 已登录用户（`state == .signedIn` 时非空）。
    var currentUser: User? {
        if case .signedIn(let user) = state { return user }
        return nil
    }
    /// 是否已登录。
    var isAuthenticated: Bool {
        if case .signedIn = state { return true }
        return false
    }
    /// 是否正在处理认证请求。
    var isBusy: Bool {
        if case .signingIn = state { return true }
        return false
    }
    /// 失败文案（`state == .failed` 时非空）。
    var errorMessage: String? {
        if case .failed(let message) = state { return message }
        return nil
    }

    init(auth: AuthService = AuthService(), tokenStore: TokenStore = TokenStore(), appStore: AppStore? = nil) {
        self.auth = auth
        self.tokenStore = tokenStore
        self.appStore = appStore
        // 后端 401 → APIClient 发出 cxSessionExpired；在主线程回调中静默登出。
        expiryObserver = NotificationCenter.default.addObserver(
            forName: .cxSessionExpired,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleSessionExpired()
            }
        }
    }

    deinit {
        if let expiryObserver {
            NotificationCenter.default.removeObserver(expiryObserver)
        }
    }

    // MARK: - 认证动作

    /// 登录（用户名或邮箱 + 密码）。成功后拉取 `GET /me` 填充用户信息。
    func login(username: String, password: String) async {
        state = .signingIn
        do {
            let token = try await auth.login(identifier: username, password: password)
            try tokenStore.save(token)
            let user = try await auth.currentUser()
            completeSignIn(user)
        } catch is CancellationError {
            state = .signedOut
        } catch {
            tokenStore.clear()
            state = .failed(Self.message(for: error))
        }
    }

    /// 注册新账户，成功后自动登录。
    func register(username: String, email: String, password: String) async {
        state = .signingIn
        do {
            _ = try await auth.register(username: username, email: email, password: password, role: "patient")
            let token = try await auth.login(identifier: username, password: password)
            try tokenStore.save(token)
            let user = try await auth.currentUser()
            completeSignIn(user)
        } catch is CancellationError {
            state = .signedOut
        } catch {
            tokenStore.clear()
            state = .failed(Self.message(for: error))
        }
    }

    /// 登出：清空 Keychain token 并复位状态。
    func logout() {
        tokenStore.clear()
        state = .signedOut
        appStore?.data.demoSignedIn = false
    }

    /// App 启动时恢复会话：从 Keychain 读 token 并用 `GET /me` 校验；失败则静默登出。
    ///
    /// - Note: `--ui-testing` / 离线（`useRemoteAPI == false`）下不发起网络请求，直接保持 `signedOut`。
    func restoreSession() async {
        guard AppConfiguration.useRemoteAPI else {
            state = .signedOut
            return
        }
        guard let token = tokenStore.load(), !token.isEmpty else {
            state = .signedOut
            return
        }
        state = .signingIn
        do {
            let user = try await auth.currentUser()
            completeSignIn(user)
        } catch {
            // token 失效或网络异常：静默登出，不打扰用户。
            tokenStore.clear()
            state = .signedOut
        }
    }

    /// 清除失败提示（用户重新编辑表单时调用），仅在 `failed` 态生效。
    func clearError() {
        if case .failed = state { state = .signedOut }
    }

    // MARK: - Private

    private func completeSignIn(_ user: User) {
        state = .signedIn(user)
        // 兼容既有 UI：真实登录成功后同步置演示登录标记。
        appStore?.data.demoSignedIn = true
    }

    private func handleSessionExpired() {
        // 不打断进行中的登录流程（登录失败自身会设置 .failed）。
        if case .signingIn = state { return }
        tokenStore.clear()
        state = .signedOut
        appStore?.data.demoSignedIn = false
    }

    private static func message(for error: Error) -> String {
        if let apiError = error as? APIError { return apiError.userFacingMessage }
        if let tokenError = error as? TokenStoreError { return tokenError.localizedDescription }
        return "登录失败，请稍后再试。"
    }
}
