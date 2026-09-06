import SwiftUI

struct DemoAuthView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var mode = "登录"
    @State private var code = ""
    @State private var requested = false
    @State private var agreed = false
    @State private var error: String?
    var body: some View {
        Page {
            Card {
                Text("欢迎回来").font(.largeTitle.bold())
                Text("体验账户流程，继续与常曦相伴。").foregroundStyle(CX.muted)
                Picker("账户操作", selection: $mode) { Text("登录").tag("登录"); Text("注册").tag("注册") }.pickerStyle(.segmented)
                Label("演示手机号：138 **** 0000", systemImage: "iphone")
                Text("无需填写真实手机号，不会发送短信。").font(.footnote).foregroundStyle(CX.muted)
                Button(requested ? "重新获取演示验证码" : "获取演示验证码") { requested = true; error = nil }.frame(minHeight: 44)
                if requested {
                    Text("演示验证码：123456").font(.headline)
                    TextField("输入6位演示验证码", text: $code).keyboardType(.numberPad).textContentType(.oneTimeCode).padding().background(CX.mist, in: RoundedRectangle(cornerRadius: 14))
                }
                Toggle("已了解体验说明与隐私说明", isOn: $agreed)
                NavigationLink("阅读隐私说明") { PrivacyView() }.frame(minHeight: 44)
                if let error { Text(error).foregroundStyle(CX.coral) }
                Button("\(mode)演示账户") {
                    guard code == "123456" else { error = "验证码不正确，请输入页面显示的6位演示验证码。"; return }
                    store.data.demoSignedIn = true
                    dismiss()
                }.buttonStyle(PrimaryButton()).disabled(!agreed || !requested)
            }
        }.navigationTitle("\(mode)体验")
    }
}
