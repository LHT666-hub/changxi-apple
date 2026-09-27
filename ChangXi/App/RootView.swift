import SwiftUI
import UIKit

struct RootView: View {
    @State private var store = AppStore()
    @State private var assistant = AssistantCoordinator()
    @State private var selectedTab = RootTab.home
    @State private var showGeneralChat = false
    @State private var isKeyboardVisible = false
    @State private var showLaunchExperience = !AppConfiguration.isUITesting || AppConfiguration.isLaunchTesting
    /// 认证会话：与 `store` 同为 `@MainActor @Observable`，在此创建并注入环境，
    /// 供 `DemoAuthView` / `ChatView` / `ProfileView` 等下游视图通过
    /// `@Environment(AuthSession.self)` 读取。
    @State private var auth = AuthSession()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ZStack {
            Group {
            if store.data.onboarded {
                ZStack(alignment: .bottomTrailing) {
                    ZStack {
                        tabLayer(.home) {
                            NavigationStack { HomeView() }
                        }
                        tabLayer(.health) { NavigationStack { HealthView() } }
                        tabLayer(.services) { NavigationStack { ServicesView() } }
                        tabLayer(.profile) { NavigationStack { ProfileView() } }
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        if !isKeyboardVisible {
                            PersistentTabBar(selection: $selectedTab)
                                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                                .padding(.bottom, -8)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }

                    if assistant.registeredContext == nil && !isKeyboardVisible {
                        Button {
                            assistant.activateGeneral()
                            showGeneralChat = true
                        } label: {
                            globalAssistantLabel
                        }
                        .buttonStyle(.plain)
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .accessibilityLabel("召唤常曦")
                        .accessibilityIdentifier("global-assistant")
                        .padding(.trailing, 16)
                        .padding(.bottom, 78)
                    }
                }
                .fullScreenCover(isPresented: $showGeneralChat) {
                    NavigationStack { ChatView(initialPrompt: assistant.initialPrompt) }
                        .environment(store)
                        .environment(auth)
                        .environment(assistant)
                }
            } else {
                NavigationStack { WelcomeView() }
            }
            }

            if showLaunchExperience {
                ChangXiLaunchExperience()
                    .transition(.opacity)
                    .zIndex(100)
                    .allowsHitTesting(true)
            }
        }
        .environment(store)
        .environment(auth)
        .environment(assistant)
        .tint(CX.actionPrimary)
        .transformEnvironment(\.dynamicTypeSize) { size in
            if store.data.largeText && size < .xxxLarge {
                size = .xxxLarge
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.refreshDay() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeOut(duration: 0.18)) { isKeyboardVisible = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.18)) { isKeyboardVisible = false }
        }
        // 真实认证状态与既有 `demoSignedIn` 布尔量保持同步，令依赖它的旧界面无需改动。
        .onChange(of: auth.isAuthenticated) { _, isAuthenticated in store.data.demoSignedIn = isAuthenticated }
        // 启动时尝试用 Keychain 中的 JWT 恢复会话；视觉启动页独立计时，不等待网络。
        .task {
            await auth.restoreSession()
        }
        .task {
            if showLaunchExperience {
                try? await Task.sleep(
                    nanoseconds: AppConfiguration.isLaunchTesting ? 45_000_000_000 : 1_650_000_000
                )
                withAnimation(.easeOut(duration: 0.42)) {
                    showLaunchExperience = false
                }
            }
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

    @ViewBuilder
    private var globalAssistantLabel: some View {
        if dynamicTypeSize.isAccessibilitySize {
            Image(systemName: "moonphase.waxing.crescent")
                .font(.title3.weight(.semibold))
                .frame(width: 52, height: 52)
                .cxInteractiveGlassCircle()
        } else {
            Label("常曦", systemImage: "moonphase.waxing.crescent")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .cxInteractiveGlass(cornerRadius: 22)
        }
    }

    private func tabLayer<Content: View>(_ tab: RootTab, @ViewBuilder content: () -> Content) -> some View {
        content()
            .opacity(selectedTab == tab ? 1 : 0)
            .allowsHitTesting(selectedTab == tab)
            .accessibilityHidden(selectedTab != tab)
    }
}


private struct ChangXiLaunchExperience: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    @State private var moonRevealed = false
    @State private var characterRevealed = false
    @State private var brandRevealed = false
    @State private var displayedPhase = 0.02
    @State private var haloRotation = -16.0

    private var todayPhase: Double {
        min(max(Double(LunarPhase.today.lunarDay - 1) / 29.53, 0), 1)
    }

    var body: some View {
        ZStack {
            MoonBackground()

            RadialGradient(
                colors: [
                    .white.opacity(colorScheme == .dark ? 0.05 : 0.44),
                    CX.brandMoonlight.opacity(colorScheme == .dark ? 0.08 : 0.16),
                    .clear
                ],
                center: UnitPoint(x: 0.5, y: 0.42),
                startRadius: 8,
                endRadius: 290
            )
            .scaleEffect(moonRevealed ? 1.08 : 0.64)
            .opacity(moonRevealed ? 1 : 0.10)
            .blur(radius: 12)
            .ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer(minLength: 54)

                ZStack(alignment: .bottom) {
                    ZStack {
                        Circle()
                            .stroke(
                                AngularGradient(
                                    colors: [
                                        .clear,
                                        .white.opacity(0.68),
                                        CX.brandMoonlight.opacity(0.32),
                                        .clear
                                    ],
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 1.05, lineCap: .round)
                            )
                            .frame(width: 196, height: 196)
                            .rotationEffect(.degrees(haloRotation))

                        Circle()
                            .stroke(.white.opacity(0.10), lineWidth: 0.7)
                            .frame(width: 168, height: 168)

                        MoonDisc(phase: displayedPhase)
                            .frame(width: 118, height: 118)
                            .shadow(color: .white.opacity(0.24), radius: 14, y: -2)
                            .shadow(color: CX.brandMoonlight.opacity(0.24), radius: 24, y: 8)
                    }
                    .offset(y: -62)
                    .scaleEffect(moonRevealed ? 1 : 0.78)
                    .opacity(moonRevealed ? 0.94 : 0.14)

                    Image(decorative: "ChangXiCharacter")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 224)
                        .opacity(characterRevealed ? 1 : 0)
                        .scaleEffect(characterRevealed ? 1 : 0.94, anchor: .bottom)
                        .offset(y: characterRevealed ? 0 : 12)
                        .shadow(color: .white.opacity(colorScheme == .dark ? 0.08 : 0.28), radius: 10, y: -3)
                        .shadow(color: CX.brandMoonlight.opacity(0.16), radius: 18, y: 8)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.clear, CX.brandMoonlight.opacity(0.34), .white.opacity(0.46), CX.brandMoonlight.opacity(0.26), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 220, height: 1)
                        .blur(radius: 0.6)
                        .opacity(characterRevealed ? 0.84 : 0)
                        .offset(y: 5)
                }
                .frame(height: 285)

                VStack(spacing: 7) {
                    Text("常曦")
                        .font(CXTypography.brandTitle)
                        .tracking(2.8)

                    Text("让日常健康，有人一起慢慢照看")
                        .font(CXTypography.supporting)
                        .foregroundStyle(CX.muted)
                }
                .opacity(brandRevealed ? 1 : 0)
                .offset(y: brandRevealed || reduceMotion ? 0 : 7)

                Spacer()
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 32)
        }
        .foregroundStyle(CX.ink)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("常曦正在启动")
        .accessibilityIdentifier("launch-experience")
        .onAppear {
            guard !reduceMotion else {
                moonRevealed = true
                characterRevealed = true
                brandRevealed = true
                displayedPhase = todayPhase
                haloRotation = 26
                return
            }

            withAnimation(.easeOut(duration: 0.62)) {
                moonRevealed = true
            }
            withAnimation(.easeInOut(duration: 1.05)) {
                displayedPhase = todayPhase
            }
            withAnimation(.easeInOut(duration: 1.35)) {
                haloRotation = 30
            }
            withAnimation(.spring(duration: 0.70, bounce: 0.03).delay(0.16)) {
                characterRevealed = true
            }
            withAnimation(.easeOut(duration: 0.46).delay(0.48)) {
                brandRevealed = true
            }
        }
    }
}


private enum RootTab: String, CaseIterable, Identifiable {
    case home = "首页"
    case health = "健康"
    case services = "服务"
    case profile = "我的"

    var id: Self { self }
    var symbol: String {
        switch self {
        case .home: "house"
        case .health: "heart.text.square"
        case .services: "cross.case"
        case .profile: "person.crop.circle"
        }
    }

}

private struct PersistentTabBar: View {
    @Binding var selection: RootTab
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var trackingX: CGFloat?
    @State private var previewSelection: RootTab?
    @State private var isTrackingSelection = false

    @ViewBuilder
    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: 4) {
                tabBar
            }
        } else {
            tabBar
        }
    }

    private var tabBar: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 4
            let count = CGFloat(RootTab.allCases.count)
            let itemWidth = (proxy.size.width - spacing * (count - 1)) / count
            let activeSelection = previewSelection ?? selection

            ZStack(alignment: .leading) {
                selectionSurface
                    .frame(width: itemWidth, height: itemHeight)
                    .scaleEffect(
                        x: isTrackingSelection && !reduceMotion ? 1.08 : 1,
                        y: isTrackingSelection && !reduceMotion ? 0.97 : 1
                    )
                    .animation(
                        reduceMotion ? nil : .smooth(duration: 0.18),
                        value: isTrackingSelection
                    )
                    .offset(x: indicatorLeadingOffset(itemWidth: itemWidth, spacing: spacing))
                    .animation(
                        reduceMotion ? nil : .smooth(duration: 0.30),
                        value: selection
                    )

                HStack(spacing: spacing) {
                    ForEach(RootTab.allCases) { tab in
                        let isSelected = activeSelection == tab

                        Button {
                            select(tab)
                        } label: {
                            VStack(spacing: 3) {
                                Image(systemName: isSelected ? "\(tab.symbol).fill" : tab.symbol)
                                    .font(.body.weight(.medium))
                                    .contentTransition(.symbolEffect(.replace))
                                Text(tab.rawValue).font(.caption2.weight(.semibold))
                            }
                            .foregroundStyle(isSelected ? CX.actionPrimary : CX.ink.opacity(0.70))
                            .frame(maxWidth: .infinity, minHeight: itemHeight)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(tab.rawValue)
                        .accessibilityHint(selection == tab ? "当前页面" : "切换到\(tab.rawValue)")
                        .accessibilityIdentifier("root-tab-\(tab.rawValue)")
                        .accessibilityAddTraits(selection == tab ? .isSelected : [])
                    }
                }
                .animation(
                    reduceMotion ? nil : .easeOut(duration: 0.14),
                    value: activeSelection
                )
            }
            .contentShape(Rectangle())
            .highPriorityGesture(selectionGesture(width: proxy.size.width, itemWidth: itemWidth, spacing: spacing))
        }
        .frame(height: itemHeight)
        .padding(7)
        .frame(maxWidth: 520)
        .modifier(FrostedTabBarSurface(reduceTransparency: reduceTransparency))
        .background(alignment: .bottom) {
            BottomSafeAreaFrost(reduceTransparency: reduceTransparency)
                .frame(height: 126)
                .padding(.horizontal, -16)
                .offset(y: 42)
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .frame(maxWidth: .infinity)
    }

    private var itemHeight: CGFloat {
        if dynamicTypeSize.isAccessibilitySize { return 76 }
        if dynamicTypeSize >= .xxLarge { return 60 }
        return 52
    }

    @ViewBuilder
    private var selectionSurface: some View {
        if #available(iOS 26, *) {
            Capsule()
                .fill(.clear)
                .glassEffect(
                    .regular.tint(CX.actionPrimary.opacity(0.10)),
                    in: .capsule
                )
                .allowsHitTesting(false)
        } else {
            legacySelectionSurface
                .allowsHitTesting(false)
        }
    }

    private func select(_ tab: RootTab) {
        guard selection != tab else { return }
        selection = tab
    }

    private func indicatorLeadingOffset(itemWidth: CGFloat, spacing: CGFloat) -> CGFloat {
        if let trackingX {
            let maximum = (itemWidth + spacing) * CGFloat(RootTab.allCases.count - 1)
            return min(max(trackingX - itemWidth / 2, 0), maximum)
        }

        let index = RootTab.allCases.firstIndex(of: selection) ?? 0
        return CGFloat(index) * (itemWidth + spacing)
    }

    private func selectionGesture(width: CGFloat, itemWidth: CGFloat, spacing: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let distance = hypot(value.translation.width, value.translation.height)
                guard isTrackingSelection || distance > 3 else { return }

                if !isTrackingSelection {
                    let index = RootTab.allCases.firstIndex(of: selection) ?? 0
                    let selectedCenter = CGFloat(index) * (itemWidth + spacing) + itemWidth / 2
                    guard abs(value.startLocation.x - selectedCenter) <= itemWidth * 0.62 else { return }
                    isTrackingSelection = true
                }

                let clampedX = min(max(value.location.x, itemWidth / 2), width - itemWidth / 2)
                trackingX = clampedX
                previewSelection = tab(at: clampedX, width: width)
            }
            .onEnded { value in
                let target = isTrackingSelection
                    ? tab(at: value.location.x, width: width)
                    : tab(at: value.startLocation.x, width: width)

                // Commit the page change outside the animation transaction. Only the
                // glass focus should animate; heavy tab contents switch immediately.
                selection = target
                withAnimation(reduceMotion ? nil : .smooth(duration: 0.26)) {
                    trackingX = nil
                    previewSelection = nil
                    isTrackingSelection = false
                }
            }
    }

    private func tab(at locationX: CGFloat, width: CGFloat) -> RootTab {
        let normalized = min(max(locationX / max(width, 1), 0), 0.999)
        let index = min(Int(normalized * CGFloat(RootTab.allCases.count)), RootTab.allCases.count - 1)
        return RootTab.allCases[index]
    }

    private var legacySelectionSurface: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.72),
                        Color(.displayP3, red: 0.82, green: 0.85, blue: 0.89).opacity(0.82)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                Capsule().strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.94), CX.actionPrimary.opacity(0.10)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
            }
            .shadow(color: .black.opacity(0.08), radius: 9, y: 4)
    }
}

private struct BottomSafeAreaFrost: View {
    let reduceTransparency: Bool

    var body: some View {
        Rectangle()
            .fill(reduceTransparency ? AnyShapeStyle(CX.surface.opacity(0.96)) : AnyShapeStyle(.regularMaterial))
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .white.opacity(0.68), location: 0.30),
                        .init(color: .white, location: 0.58)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [.clear, Color.white.opacity(0.36), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 0.7)
                .padding(.horizontal, 28)
                .padding(.top, 38)
            }
    }
}

private struct FrostedTabBarSurface: ViewModifier {
    let reduceTransparency: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(CX.surface, in: Capsule())
                .overlay { border }
                .shadow(color: .black.opacity(0.10), radius: 20, y: 10)
        } else if #available(iOS 26, *) {
            content
                .glassEffect(
                    .regular.tint(Color.white.opacity(0.10)),
                    in: .capsule
                )
                .overlay { border }
                .overlay { highlight }
                .shadow(color: .black.opacity(0.09), radius: 24, y: 12)
                .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
        } else {
            content
                .background(.regularMaterial, in: Capsule())
                .overlay { border }
                .overlay { highlight }
                .shadow(color: .black.opacity(0.12), radius: 20, y: 10)
        }
    }

    private var border: some View {
        Capsule().strokeBorder(Color.white.opacity(0.64), lineWidth: 0.7)
    }

    private var highlight: some View {
        Capsule()
            .strokeBorder(
                LinearGradient(
                    colors: [Color.white.opacity(0.72), Color.white.opacity(0.08)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 0.8
            )
            .padding(0.5)
    }
}

struct WelcomeView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var stage = 0
    @State private var accepted = false
    @State private var name = "张阿姨"
    @State private var useLargeText = false

    private let stageCount = 5
    private let stageTitles = ["相识", "日常", "照护", "隐私", "设置"]

    var body: some View {
        ZStack {
            MoonBackground(illustrated: true)

            VStack(spacing: 0) {
                onboardingHeader
                    .padding(.horizontal, CXSpacing.xl)
                    .padding(.top, CXSpacing.sm)

                TabView(selection: $stage) {
                    welcomePage.tag(0)
                    assistantPage.tag(1)
                    connectionPage.tag(2)
                    privacyPage.tag(3)
                    setupPage.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(reduceMotion ? nil : .smooth(duration: 0.38), value: stage)

                onboardingControls
                    .padding(.horizontal, CXSpacing.xl)
                    .padding(.bottom, CXSpacing.md)
            }
        }
        .foregroundStyle(CX.ink)
        .toolbarVisibility(.hidden, for: .navigationBar)
        .onAppear {
            useLargeText = store.data.largeText
        }
    }

    private var onboardingHeader: some View {
        HStack {
            HStack(spacing: CXSpacing.xs) {
                LunarGlyph(size: 22, tint: CX.actionPrimary)
                Text("常曦")
                    .font(CXTypography.section)
                    .foregroundStyle(CX.muted)
            }

            Spacer()

            HStack(spacing: 8) {
                Text(stageTitles[stage])
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.ink.opacity(0.72))

                Text("\(stage + 1) / \(stageCount)")
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.muted)
                    .monospacedDigit()
            }
        }
        .frame(minHeight: 44)
    }

    private var welcomePage: some View {
        onboardingScroll {
            MoonPoolView(state: .idle, character: true, compact: true)
                .frame(maxWidth: 520)
                .frame(height: 280)

            VStack(spacing: CXSpacing.sm) {
                Text("欢迎来到常曦")
                    .font(CXTypography.display)
                    .multilineTextAlignment(.center)

                Text("从今天起，把健康记录、日常提醒和想问的事，慢慢交给常曦一起整理。")
                    .font(CXTypography.body)
                    .foregroundStyle(CX.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .frame(maxWidth: 430)
            }

            Label("不用一次设置很多，先从最常用的开始。", systemImage: "sparkles")
                .font(CXTypography.supporting)
                .foregroundStyle(CX.muted)
                .padding(.horizontal, CXSpacing.md)
                .frame(minHeight: 42)
                .background(CX.surface.opacity(0.84), in: Capsule())
        }
    }

    private var assistantPage: some View {
        onboardingScroll {
            onboardingSymbol("sparkles", tint: CX.actionPrimary)

            VStack(spacing: CXSpacing.sm) {
                Text("先从每天都会遇到的事开始")
                    .font(CXTypography.title)
                    .multilineTextAlignment(.center)

                Text("说一句、记一笔、看一份报告，都从同一套清晰的入口开始。")
                    .font(CXTypography.body)
                    .foregroundStyle(CX.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .frame(maxWidth: 430)
            }

            Card {
                OnboardingFeatureRow(
                    icon: "bubble.left.and.text.bubble.right",
                    title: "说出来就可以",
                    subtitle: "文字或语音描述近况，不必先学复杂操作。"
                )
                Divider().overlay(CX.separator.opacity(0.16))
                OnboardingFeatureRow(
                    icon: "waveform.path.ecg",
                    title: "记录每天的变化",
                    subtitle: "血压、体重、用药和每日计划逐步沉淀。"
                )
                Divider().overlay(CX.separator.opacity(0.16))
                OnboardingFeatureRow(
                    icon: "doc.text.magnifyingglass",
                    title: "把报告变得更容易理解",
                    subtitle: "导入、整理并持续回看你的健康资料。"
                )
            }
            .frame(maxWidth: 520)
        }
    }

    private var connectionPage: some View {
        onboardingScroll {
            onboardingSymbol("person.2.wave.2", tint: CX.statusPositive)

            VStack(spacing: CXSpacing.sm) {
                Text("需要的时候，让照护有人接住")
                    .font(CXTypography.title)
                    .multilineTextAlignment(.center)

                Text("常曦把家人、家庭医生和服务放在同一条照护路径里，让下一步始终清楚。")
                    .font(CXTypography.body)
                    .foregroundStyle(CX.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .frame(maxWidth: 450)
            }

            HStack(spacing: 0) {
                OnboardingConnectionNode(icon: "person.fill", title: "你")
                connectionLine
                OnboardingConnectionNode(icon: "figure.2.and.child.holdinghands", title: "家人")
                connectionLine
                OnboardingConnectionNode(icon: "stethoscope", title: "家医")
            }
            .frame(maxWidth: 500)

            Text("从一次提醒，到一次随访，再到一次服务协同，都保留清晰的下一步。")
                .font(CXTypography.supporting)
                .foregroundStyle(CX.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
        }
    }

    private var privacyPage: some View {
        onboardingScroll {
            ZStack {
                Circle()
                    .fill(CX.actionPrimary.opacity(0.08))
                    .frame(width: 148, height: 148)
                Circle()
                    .stroke(CX.brandMoonlight.opacity(0.20), lineWidth: 1)
                    .frame(width: 176, height: 176)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 58, weight: .light))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(CX.actionPrimary)
            }
            .padding(.vertical, 10)

            VStack(spacing: CXSpacing.sm) {
                Text("你的健康信息，由你决定")
                    .font(CXTypography.title)
                    .multilineTextAlignment(.center)

                Text("数据默认先留在本机。只有真正需要某项能力时，常曦才会说明原因并请求对应权限。")
                    .font(CXTypography.body)
                    .foregroundStyle(CX.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .frame(maxWidth: 460)
            }

            Card {
                OnboardingFeatureRow(
                    icon: "iphone",
                    title: "本机优先",
                    subtitle: "示例数据与操作先保留在当前设备。"
                )
                Divider().overlay(CX.separator.opacity(0.16))
                OnboardingFeatureRow(
                    icon: "hand.raised.fill",
                    title: "按需授权",
                    subtitle: "权限不在第一次打开时一次性索取。"
                )
            }
            .frame(maxWidth: 520)
        }
    }

    private var setupPage: some View {
        onboardingScroll {
            onboardingSymbol("moon.stars.fill", tint: CX.actionPrimary)

            VStack(spacing: CXSpacing.sm) {
                Text("最后，告诉常曦该怎么陪你")
                    .font(CXTypography.title)
                    .multilineTextAlignment(.center)

                Text("只需要一个称呼和阅读偏好，其他设置以后都能慢慢补充。")
                    .font(CXTypography.body)
                    .foregroundStyle(CX.muted)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: CXSpacing.sm) {
                VStack(alignment: .leading, spacing: CXSpacing.sm) {
                    HStack(spacing: 10) {
                        Image(systemName: "person.crop.circle")
                            .foregroundStyle(CX.actionPrimary)
                        Text("怎么称呼你")
                            .font(CXTypography.section)
                    }

                    TextField("例如：张阿姨", text: $name)
                        .textContentType(.nickname)
                        .submitLabel(.done)
                        .padding(.horizontal, CXSpacing.md)
                        .frame(minHeight: 54)
                        .background(CX.raisedSurface, in: .rect(cornerRadius: CXRadius.sm, style: .continuous))

                    Text("这个称呼只用于常曦与你对话时的表达。")
                        .font(CXTypography.meta)
                        .foregroundStyle(CX.muted)
                }
                .padding(CXSpacing.lg)
                .cxContentSurface(cornerRadius: CXRadius.lg)

                VStack(alignment: .leading, spacing: CXSpacing.md) {
                    Toggle(isOn: $useLargeText) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("大字阅读")
                                .font(CXTypography.section)
                            Text("需要更大的阅读尺寸时可以直接开启")
                                .font(CXTypography.meta)
                                .foregroundStyle(CX.muted)
                        }
                    }

                    Divider().overlay(CX.separator.opacity(0.16))

                    Toggle(isOn: $accepted) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("我已了解体验说明")
                                .font(CXTypography.section)
                            Text("这一步只确认你知道当前版本的使用边界")
                                .font(CXTypography.meta)
                                .foregroundStyle(CX.muted)
                        }
                    }
                    .accessibilityLabel("我已阅读并了解体验说明")

                    HStack(spacing: CXSpacing.md) {
                        NavigationLink("体验说明") {
                            InfoView(
                                title: "体验说明",
                                text: "这是常曦的前端体验版本。健康数据、医生消息、预约和对话回复均可能包含示例内容，不提供真实诊疗、医生通信或挂号服务。你可以不登录直接体验。"
                            )
                        }

                        NavigationLink("隐私说明") { PrivacyView() }
                    }
                    .font(CXTypography.supporting.weight(.semibold))
                }
                .padding(CXSpacing.lg)
                .cxContentSurface(cornerRadius: CXRadius.lg)
            }
            .frame(maxWidth: 540)
        }
    }

    private var onboardingControls: some View {
        VStack(spacing: 14) {
            HStack(spacing: 7) {
                ForEach(0..<stageCount, id: \.self) { index in
                    Capsule()
                        .fill(index == stage ? CX.actionPrimary : CX.actionPrimary.opacity(0.14))
                        .frame(width: index == stage ? 24 : 7, height: 7)
                        .animation(reduceMotion ? nil : .smooth(duration: 0.26), value: stage)
                }
            }

            HStack(spacing: 12) {
                if stage > 0 {
                    Button {
                        move(to: stage - 1)
                    } label: {
                        Label("上一步", systemImage: "chevron.left")
                            .font(.headline)
                            .frame(minHeight: 52)
                            .padding(.horizontal, 16)
                    }
                    .buttonStyle(.plain)
                    .cxInteractiveGlass(cornerRadius: CXRadius.md)
                }

                if stage < stageCount - 1 {
                    Button {
                        move(to: stage + 1)
                    } label: {
                        HStack {
                            Text(stage == 0 ? "认识常曦" : "继续")
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                    }
                    .buttonStyle(PrimaryButton())
                } else {
                    Button("开始与常曦相伴", action: begin)
                        .buttonStyle(PrimaryButton())
                        .disabled(!accepted)
                        .accessibilityIdentifier("finish-onboarding")
                }
            }
            .frame(maxWidth: 560)
        }
        .frame(maxWidth: .infinity)
    }

    private var connectionLine: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [CX.brandMoonlight.opacity(0.10), CX.actionPrimary.opacity(0.32), CX.brandMoonlight.opacity(0.10)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(maxWidth: 54, minHeight: 1, maxHeight: 1)
            .padding(.horizontal, 6)
    }

    private func onboardingSymbol(_ name: String, tint: Color) -> some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.07))
                .frame(width: 150, height: 150)
            Circle()
                .stroke(tint.opacity(0.12), lineWidth: 1)
                .frame(width: 178, height: 178)
            Image(systemName: name)
                .font(.system(size: 56, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
        }
        .padding(.vertical, 8)
    }

    private func onboardingScroll<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(spacing: CXSpacing.xl) {
                content()
            }
            .frame(maxWidth: 620)
            .padding(.horizontal, CXSpacing.xl)
            .padding(.top, CXSpacing.md)
            .padding(.bottom, CXSpacing.xl)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private func move(to nextStage: Int) {
        guard (0..<stageCount).contains(nextStage) else { return }
        MoonHaptics.shared.play(success: false, enabled: store.data.haptics)
        if reduceMotion {
            stage = nextStage
        } else {
            withAnimation(.smooth(duration: 0.36)) {
                stage = nextStage
            }
        }
    }

    private func begin() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        store.data.name = trimmedName.isEmpty ? "朋友" : trimmedName
        store.data.person = "\(store.data.name)（本人）"
        store.data.largeText = useLargeText
        store.data.onboarded = true
        MoonHaptics.shared.play(success: true, enabled: store.data.haptics)
    }
}

private struct OnboardingFeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3.weight(.medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(CX.actionPrimary)
                .frame(width: 42, height: 42)
                .background(CX.actionPrimary.opacity(0.055), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(CXTypography.supporting)
                    .foregroundStyle(CX.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct OnboardingConnectionNode: View {
    let icon: String
    let title: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2.weight(.medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(CX.actionPrimary)
                .frame(width: 58, height: 58)
                .background(.thinMaterial, in: Circle())
                .overlay {
                    Circle().strokeBorder(.white.opacity(0.58), lineWidth: 0.7)
                }

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(CX.muted)
        }
        .frame(width: 74)
    }
}

