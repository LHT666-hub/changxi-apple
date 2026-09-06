import SwiftUI

struct RootView: View {
    @State private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        Group {
            if store.data.onboarded {
                TabView {
                    NavigationStack { HomeView() }.tabItem { Label("首页", systemImage: "house.fill") }
                    NavigationStack { HealthView() }.tabItem { Label("健康", systemImage: "heart.text.square.fill") }
                    NavigationStack { ServicesView() }.tabItem { Label("服务", systemImage: "square.grid.2x2.fill") }
                    NavigationStack { ProfileView() }.tabItem { Label("我的", systemImage: "person.fill") }
                }
            } else { NavigationStack { WelcomeView() } }
        }.environment(store).tint(CX.blue).preferredColorScheme(.light)
        .transformEnvironment(\.dynamicTypeSize) { size in if store.data.largeText && size < .xxxLarge { size = .xxxLarge } }
        .onChange(of: scenePhase) { _, phase in if phase == .active { store.refreshDay() } }
        .safeAreaInset(edge: .top) {
            if let error = store.storageError { Text(error).font(.footnote).padding().frame(maxWidth: .infinity).background(.yellow.opacity(0.25)) }
        }
    }
}

struct WelcomeView: View {
    @Environment(AppStore.self) private var store
    @State private var accepted = false
    @State private var name = "张阿姨"
    var body: some View {
        Page(illustrated: true) {
            VStack(alignment: .leading, spacing: 12) {
                Text("常 曦").font(.system(.largeTitle, design: .serif, weight: .semibold))
                Text("C H A N G X I").font(.caption2).tracking(3)
                Text("有月光陪伴的日子，\n也是更健康的日子。").font(.title2).padding(.top, 20)
            }.padding(.top, 20)
            MoonPoolView()
            Card {
                Text("从一句问候开始").font(.title2.bold())
                Text("记下身体的变化，安排日常计划，也留一点时间照顾自己。").foregroundStyle(CX.muted)
                TextField("希望常曦怎么称呼你", text: $name).textContentType(.nickname).padding(14).background(CX.mist, in: RoundedRectangle(cornerRadius: 14))
                DemoLabel()
                Toggle("我已阅读并了解以下说明", isOn: $accepted)
                HStack {
                    NavigationLink("体验说明") { InfoView(title: "体验说明", text: "这是常曦的前端体验版本。健康数据、医生消息、预约和对话回复均为示例，不提供真实诊疗、医生通信或挂号服务。你可以不登录直接体验，所有操作保存在此设备。") }
                    Spacer()
                    NavigationLink("隐私说明") { PrivacyView() }
                }.font(.subheadline)
                Button("开始与常曦相伴") {
                    store.data.name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "朋友" : name
                    store.data.person = "\(store.data.name)（本人）"
                    store.data.onboarded = true
                }.buttonStyle(PrimaryButton()).disabled(!accepted).opacity(accepted ? 1 : 0.5)
            }
        }.navigationTitle("欢迎来到常曦")
    }
}
