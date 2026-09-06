import SwiftUI

struct RootView: View {
    @State private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if store.data.onboarded {
                TabView {
                    Tab("首页", systemImage: "house.fill") {
                        NavigationStack { HomeView() }
                    }
                    Tab("健康", systemImage: "heart.text.square.fill") {
                        NavigationStack { HealthView() }
                    }
                    Tab("服务", systemImage: "cross.case.fill") {
                        NavigationStack { ServicesView() }
                    }
                    Tab("我的", systemImage: "person.crop.circle.fill") {
                        NavigationStack { ProfileView() }
                    }
                }
                .toolbarBackground(.visible, for: .tabBar)
            } else {
                NavigationStack { WelcomeView() }
            }
        }
        .environment(store)
        .tint(CX.blue)
        .transformEnvironment(\.dynamicTypeSize) { size in
            if store.data.largeText && size < .xxxLarge {
                size = .xxxLarge
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.refreshDay() }
        }
        .safeAreaInset(edge: .top) {
            if let error = store.storageError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(.yellow.opacity(0.28))
            }
        }
    }
}

struct WelcomeView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var accepted = false
    @State private var name = "张阿姨"
    @State private var appeared = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                welcomeHeader
                    .welcomeEntrance(index: 0, appeared: appeared, reduceMotion: reduceMotion)

                MoonPoolView()
                    .welcomeEntrance(index: 1, appeared: appeared, reduceMotion: reduceMotion)

                Card {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("先从一句问候开始")
                            .font(.title2.weight(.semibold))
                        Text("健康记录、每日安排和想说的话，都可以慢慢告诉我。")
                            .font(.body)
                            .foregroundStyle(CX.muted)
                    }

                    TextField("希望常曦怎么称呼你", text: $name)
                        .textContentType(.nickname)
                        .submitLabel(.done)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 52)
                        .background(CX.raisedSurface, in: .rect(cornerRadius: 14, style: .continuous))

                    Toggle("我已阅读并了解体验说明", isOn: $accepted)

                    HStack {
                        NavigationLink("体验说明") {
                            InfoView(
                                title: "体验说明",
                                text: "这是常曦的前端体验版本。健康数据、医生消息、预约和对话回复均为示例，不提供真实诊疗、医生通信或挂号服务。你可以不登录直接体验，所有操作保存在此设备。"
                            )
                        }
                        Spacer()
                        NavigationLink("隐私说明") { PrivacyView() }
                    }
                    .font(.subheadline)

                    Button("开始与常曦相伴", action: begin)
                        .buttonStyle(PrimaryButton())
                        .disabled(!accepted)

                    if !accepted {
                        Text("阅读说明并开启上方开关后即可开始")
                            .font(.footnote)
                            .foregroundStyle(CX.muted)
                            .frame(maxWidth: .infinity)
                    }
                }
                .welcomeEntrance(index: 2, appeared: appeared, reduceMotion: reduceMotion)

                DemoLabel()
                    .frame(maxWidth: .infinity)
                    .welcomeEntrance(index: 3, appeared: appeared, reduceMotion: reduceMotion)
            }
            .frame(maxWidth: 620)
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity)
        }
        .background { MoonBackground(illustrated: true) }
        .foregroundStyle(CX.ink)
        .toolbarVisibility(.hidden, for: .navigationBar)
        .onAppear { appeared = true }
    }

    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("常曦", systemImage: "moonphase.waxing.crescent")
                .font(.headline)
                .foregroundStyle(CX.blue)

            Text("有月光陪伴的日子，\n也是更健康的日子。")
                .font(.largeTitle.weight(.semibold))
                .fontDesign(.serif)
                .fixedSize(horizontal: false, vertical: true)

            Text("把照顾自己，变成每天都做得到的小事。")
                .font(.body)
                .foregroundStyle(CX.muted)
        }
    }

    private func begin() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        store.data.name = trimmedName.isEmpty ? "朋友" : trimmedName
        store.data.person = "\(store.data.name)（本人）"
        store.data.onboarded = true
        MoonHaptics.shared.play(success: true, enabled: store.data.haptics)
    }
}

private extension View {
    func welcomeEntrance(index: Int, appeared: Bool, reduceMotion: Bool) -> some View {
        opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 14)
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.18)
                    : .spring(duration: 0.52, bounce: 0.08).delay(Double(index) * 0.055),
                value: appeared
            )
    }
}
