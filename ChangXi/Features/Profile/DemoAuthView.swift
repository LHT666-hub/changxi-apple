import SwiftUI

/// 登录 / 注册界面。
///
/// - **联网模式**（`AppConfiguration.useRemoteAPI == true`）：对接玄同后端 `/api/auth`，
///   登录 / 注册双 Tab，前端校验与后端约束逐字对齐，展示后端返回的错误文案；
/// - **离线演示模式**：始终保留一个入口，当后端不可达或 UI 测试（`useRemoteAPI == false`）时，
///   可走原来的本地演示登录（验证码 123456），不破坏既有体验与测试。
struct DemoAuthView: View {
    @Environment(AppStore.self) private var store
    @Environment(AuthSession.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var mode = "登录"
    @State private var identifier = ""       // 登录：用户名或邮箱；注册：用户名
    @State private var email = ""            // 注册用
    @State private var password = ""
    @State private var confirmPassword = ""   // 注册用
    @State private var agreed = false
    @State private var localError: String?

    // 离线演示模式
    @State private var showOffline = false
    @State private var offlineRequested = false
    @State private var offlineCode = ""

    private var isLogin: Bool { mode == "登录" }

    var body: some View {
        Page {
            if AppConfiguration.useRemoteAPI && AppConfiguration.supportsExtendedAPI {
                remoteCard
            }
            offlineCard
        }
        .navigationTitle(isLogin ? "登录" : "注册")
        .onChange(of: auth.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated { dismiss() }
        }
    }

    // MARK: - 联网登录 / 注册

    private var remoteCard: some View {
        Card {
            Text(isLogin ? "欢迎回来" : "创建账户").font(.largeTitle.bold())
            Text(isLogin ? "登录玄同账户，与常曦继续相伴。" : "注册后即可与家庭医生团队对话。")
                .foregroundStyle(CX.muted)

            Picker("账户操作", selection: $mode) {
                Text("登录").tag("登录")
                Text("注册").tag("注册")
            }
            .pickerStyle(.segmented)
            .onChange(of: mode) { _, _ in localError = nil; auth.clearError() }

            if isLogin {
                field("用户名或邮箱", text: $identifier, contentType: .username, keyboard: .default)
                field("密码", text: $password, contentType: .password, keyboard: .default, secure: true)
            } else {
                field("用户名（3–60 字符）", text: $identifier, contentType: .username, keyboard: .default)
                field("邮箱", text: $email, contentType: .emailAddress, keyboard: .emailAddress)
                field("密码（6–128 字符）", text: $password, contentType: .newPassword, keyboard: .default, secure: true)
                field("确认密码", text: $confirmPassword, contentType: .newPassword, keyboard: .default, secure: true)
            }

            Toggle("已了解体验说明与隐私说明", isOn: $agreed)
            NavigationLink("阅读隐私说明") { PrivacyView() }.frame(minHeight: 44)

            if let error = displayError {
                Text(error).foregroundStyle(CX.coral).font(.footnote)
                    .accessibilityIdentifier("auth-error")
            }

            Button {
                submit()
            } label: {
                if auth.isBusy {
                    HStack(spacing: 10) { ProgressView().tint(.white); Text(isLogin ? "登录中…" : "注册中…") }
                } else {
                    Text(isLogin ? "登录" : "注册并登录")
                }
            }
            .buttonStyle(PrimaryButton())
            .disabled(!agreed || auth.isBusy)
            .opacity(agreed && !auth.isBusy ? 1 : 0.5)
            .accessibilityIdentifier("auth-submit")

            Text("演示账户数据保存在玄同后端；如遇连接问题，可使用下方离线演示模式。")
                .font(.caption2).foregroundStyle(CX.muted)
        }
    }

    // MARK: - 离线演示模式

    private var offlineCard: some View {
        Card {
            Button {
                showOffline.toggle()
            } label: {
                HStack {
                    Label("离线演示模式", systemImage: "moon.zzz.fill")
                    Spacer()
                    Image(systemName: showOffline ? "chevron.up" : "chevron.down").foregroundStyle(CX.muted)
                }
            }
            .frame(minHeight: 44)
            .accessibilityIdentifier("offline-demo-toggle")

            if showOffline || !AppConfiguration.useRemoteAPI || !AppConfiguration.supportsExtendedAPI {
                VStack(alignment: .leading, spacing: 12) {
                    Text("无需真实账户，验证码固定为 123456，仅在本机体验。")
                        .font(.footnote).foregroundStyle(CX.muted)
                    Button(offlineRequested ? "重新获取演示验证码" : "获取演示验证码") {
                        offlineRequested = true
                    }
                    .frame(minHeight: 44)
                    if offlineRequested {
                        Text("演示验证码：123456").font(.headline)
                        TextField("输入 6 位演示验证码", text: $offlineCode)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .padding().background(CX.mist, in: RoundedRectangle(cornerRadius: 14))
                    }
                    Button("登录演示账户") {
                        guard offlineCode == "123456" else {
                            localError = "验证码不正确，请输入页面显示的 6 位演示验证码。"
                            return
                        }
                        store.data.demoSignedIn = true
                        dismiss()
                    }
                    .buttonStyle(PrimaryButton())
                    .disabled(!offlineRequested)
                    .opacity(offlineRequested ? 1 : 0.5)
                    .accessibilityIdentifier("offline-demo-submit")
                }
            }
        }
    }

    // MARK: - 辅助

    @ViewBuilder
    private func field(
        _ title: String,
        text: Binding<String>,
        contentType: UITextContentType,
        keyboard: UIKeyboardType,
        secure: Bool = false
    ) -> some View {
        Group {
            if secure {
                SecureField(title, text: text)
            } else {
                TextField(title, text: text).keyboardType(keyboard)
            }
        }
        .textContentType(contentType)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .padding().background(CX.mist, in: RoundedRectangle(cornerRadius: 14))
        .onChange(of: text.wrappedValue) { _, _ in localError = nil; auth.clearError() }
    }

    private var displayError: String? {
        localError ?? auth.errorMessage
    }

    private func submit() {
        localError = nil
        if isLogin {
            guard validateLogin() else { return }
            let name = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
            Task { await auth.login(username: name, password: password) }
        } else {
            guard validateRegister() else { return }
            let name = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
            let mail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            Task { await auth.register(username: name, email: mail, password: password) }
        }
    }

    // MARK: 前端校验（与后端约束逐字对齐）

    private func validateLogin() -> Bool {
        let name = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { localError = "请输入用户名或邮箱。"; return false }
        guard !password.isEmpty else { localError = "请输入密码。"; return false }
        return true
    }

    private func validateRegister() -> Bool {
        let name = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        // username 3–60 字符
        guard name.count >= 3, name.count <= 60 else {
            localError = "用户名需为 3–60 个字符。"; return false
        }
        // email 合法
        let mail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidEmail(mail) else { localError = "请输入有效的邮箱地址。"; return false }
        // password 6–128 字符
        guard password.count >= 6, password.count <= 128 else {
            localError = "密码需为 6–128 个字符。"; return false
        }
        // 两次密码一致
        guard password == confirmPassword else { localError = "两次输入的密码不一致。"; return false }
        return true
    }

    private func isValidEmail(_ value: String) -> Bool {
        guard value.count >= 5, let at = value.firstIndex(of: "@") else { return false }
        let domain = value[value.index(after: at)...]
        guard domain.contains("."), !domain.hasPrefix("."), !domain.hasSuffix(".") else { return false }
        // 本地部分非空
        return value.distance(from: value.startIndex, to: at) >= 1
    }
}
