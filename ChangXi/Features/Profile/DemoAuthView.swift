import SwiftUI

/// 登录 / 注册界面。
///
/// 对接账户服务的登录 / 注册界面。游客入口由首次启动页单独提供，
/// 这里不再伪造验证码或本地账户。
struct DemoAuthView: View {
    @Environment(AppStore.self) private var store
    @Environment(AuthSession.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var mode: String
    @State private var identifier = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var agreed = false
    @State private var localError: String?

    init(initialMode: String = "登录") {
        _mode = State(initialValue: initialMode == "注册" ? "注册" : "登录")
    }

    private var isLogin: Bool { mode == "登录" }

    var body: some View {
        Page(illustrated: true) {
            VStack(alignment: .leading, spacing: CXSpacing.xs) {
                Text(isLogin ? "登录常曦" : "创建账户")
                    .font(CXTypography.display)

                Text(isLogin ? "使用用户名或邮箱登录。" : "创建账户后即可保存并同步资料。")
                .font(CXTypography.body)
                .foregroundStyle(CX.muted)
            }

            if AppConfiguration.useRemoteAPI && AppConfiguration.supportsExtendedAPI {
                remoteSection
            } else {
                ContentUnavailableView(
                    "账户服务暂不可用",
                    systemImage: "wifi.slash",
                    description: Text("请稍后重试，或返回选择游客使用。")
                )
            }
        }
        .navigationTitle(isLogin ? "登录" : "注册")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: auth.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated { dismiss() }
        }
    }

    private var remoteSection: some View {
        VStack(alignment: .leading, spacing: CXSpacing.lg) {
            Picker("账户操作", selection: $mode) {
                Text("登录").tag("登录")
                Text("注册").tag("注册")
            }
            .pickerStyle(.segmented)
            .onChange(of: mode) { _, _ in
                localError = nil
                auth.clearError()
            }

            VStack(alignment: .leading, spacing: CXSpacing.md) {
                if isLogin {
                    AuthField(title: "用户名或邮箱") {
                        field("用户名或邮箱", text: $identifier, contentType: .username, keyboard: .default)
                    }
                    AuthField(title: "密码") {
                        field("密码", text: $password, contentType: .password, keyboard: .default, secure: true)
                    }
                } else {
                    AuthField(title: "用户名", hint: "3–60 字符") {
                        field("用户名", text: $identifier, contentType: .username, keyboard: .default)
                    }
                    AuthField(title: "邮箱") {
                        field("邮箱", text: $email, contentType: .emailAddress, keyboard: .emailAddress)
                    }
                    AuthField(title: "密码", hint: "6–128 字符") {
                        field("密码", text: $password, contentType: .newPassword, keyboard: .default, secure: true)
                    }
                    AuthField(title: "确认密码") {
                        field("确认密码", text: $confirmPassword, contentType: .newPassword, keyboard: .default, secure: true)
                    }
                }

                Toggle(isOn: $agreed) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("我同意使用说明与隐私政策")
                            .font(CXTypography.section)
                    }
                }

                NavigationLink("阅读隐私说明") { PrivacyView() }
                    .font(CXTypography.supporting.weight(.semibold))
            }
            .padding(CXSpacing.lg)
            .cxContentSurface(cornerRadius: CXRadius.lg)

            if let error = displayError {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(CXTypography.supporting)
                    .foregroundStyle(CX.statusCritical)
                    .padding(CXSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        CX.statusCritical.opacity(0.05),
                        in: .rect(cornerRadius: CXRadius.md, style: .continuous)
                    )
                    .accessibilityIdentifier("auth-error")
            }

            Button {
                submit()
            } label: {
                if auth.isBusy {
                    HStack(spacing: 10) {
                        ProgressView().tint(.white)
                        Text(isLogin ? "正在登录" : "正在注册")
                    }
                } else {
                    Text(isLogin ? "登录" : "注册并登录")
                }
            }
            .buttonStyle(PrimaryButton())
            .disabled(!agreed || auth.isBusy)
            .opacity(agreed && !auth.isBusy ? 1 : 0.5)
            .accessibilityIdentifier("auth-submit")
        }
    }

private struct AuthField<Content: View>: View {
    let title: String
    var hint: String? = nil
    @ViewBuilder let content: Content

    init(title: String, hint: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.hint = hint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title)
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.muted)
                Spacer()
                if let hint {
                    Text(hint)
                        .font(CXTypography.micro)
                        .foregroundStyle(CX.faint)
                }
            }

            content
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
        .padding(.horizontal, CXSpacing.md)
        .frame(minHeight: 52)
        .background(CX.raisedSurface, in: .rect(cornerRadius: CXRadius.sm, style: .continuous))
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
