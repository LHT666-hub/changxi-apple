import SwiftUI
import CoreHaptics

enum CX {
    static let ink = Color.primary
    static let muted = Color(uiColor: .secondaryLabel)
    static let faint = Color(uiColor: .tertiaryLabel)
    static let blue = Color(.displayP3, red: 0.16, green: 0.38, blue: 0.72)
    static let moonlight = Color(.displayP3, red: 0.42, green: 0.68, blue: 0.96)
    static let mist = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let raisedSurface = Color(uiColor: .tertiarySystemGroupedBackground)
    static let separator = Color(uiColor: .separator)
    static let teal = Color(.displayP3, red: 0.05, green: 0.48, blue: 0.44)
    static let coral = Color(.displayP3, red: 0.78, green: 0.24, blue: 0.28)
    static let gold = Color(.displayP3, red: 0.91, green: 0.66, blue: 0.20)
}

struct MoonBackground: View {
    var illustrated = false

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack(alignment: .top) {
            (reduceTransparency ? CX.mist : backgroundTopColor)
                .ignoresSafeArea()

            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], [0.52, 0.46], [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1]
                ],
                colors: meshColors
            )
            .opacity(reduceTransparency ? 0 : 0.72)
            .ignoresSafeArea()

            if illustrated {
                Image(decorative: "MoonGarden")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 520)
                    .clipped()
                    .opacity(colorScheme == .dark ? 0.10 : 0.12)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .white, location: 0.10),
                                .init(color: .white.opacity(0.72), location: 0.48),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .blendMode(colorScheme == .dark ? .plusLighter : .normal)
                    .offset(y: 18)
            }

            RadialGradient(
                colors: [CX.moonlight.opacity(colorScheme == .dark ? 0.20 : 0.12), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 420
            )
            .mask(topEdgeFade)
            .ignoresSafeArea()
        }
        .accessibilityHidden(true)
    }

    private var meshColors: [Color] {
        // The mesh begins at the safe-area boundary. Matching its first row to
        // the color extended behind the status bar removes the hard join.
        if colorScheme == .dark {
            return [
                backgroundTopColor,
                backgroundTopColor,
                backgroundTopColor,
                Color(.displayP3, red: 0.04, green: 0.07, blue: 0.13),
                Color(.displayP3, red: 0.07, green: 0.12, blue: 0.21),
                Color(.displayP3, red: 0.04, green: 0.08, blue: 0.15),
                Color(.displayP3, red: 0.025, green: 0.04, blue: 0.075),
                Color(.displayP3, red: 0.04, green: 0.07, blue: 0.12),
                Color(.displayP3, red: 0.025, green: 0.045, blue: 0.08)
            ]
        }

        return [
            backgroundTopColor,
            backgroundTopColor,
            backgroundTopColor,
            Color(.displayP3, red: 0.97, green: 0.98, blue: 1.0),
            Color(.displayP3, red: 0.91, green: 0.95, blue: 0.99),
            Color(.displayP3, red: 0.96, green: 0.97, blue: 1.0),
            Color(.displayP3, red: 0.98, green: 0.98, blue: 0.99),
            Color(.displayP3, red: 0.96, green: 0.97, blue: 0.99),
            Color(.displayP3, red: 0.98, green: 0.98, blue: 1.0)
        ]
    }

    private var backgroundTopColor: Color {
        colorScheme == .dark
            ? Color(.displayP3, red: 0.035, green: 0.055, blue: 0.10)
            : Color(.displayP3, red: 0.91, green: 0.95, blue: 1.0)
    }

    private var topEdgeFade: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .white, location: 0.12),
                .init(color: .white, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

struct Page<Content: View>: View {
    var illustrated = false
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            MoonBackground(illustrated: illustrated)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    content
                }
                .frame(maxWidth: 720)
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(CX.ink)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarVisibility(.visible, for: .navigationBar)
    }
}

struct Card<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let card = VStack(alignment: .leading, spacing: 16) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)

        if reduceTransparency {
            card
                .background(CX.surface, in: .rect(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(CX.separator.opacity(0.18), lineWidth: 0.5)
                }
        } else {
            card
                .background(.regularMaterial, in: .rect(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(CX.separator.opacity(0.18), lineWidth: 0.5)
                }
                .shadow(color: CX.blue.opacity(0.035), radius: 12, y: 5)
        }
    }
}

struct CXGlassGroup<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}

struct RowLabel: View {
    var title: String
    var subtitle = ""
    var icon: String
    var tint: Color = CX.blue
    var chevron = true

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon.replacingOccurrences(of: ".fill", with: ""))
                .font(.title3.weight(.regular))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.05), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(CX.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(CX.faint)
            }
        }
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }
}

struct PrimaryButton: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let label = configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, 20)
            .foregroundStyle(.white)
            .opacity(isEnabled ? (configuration.isPressed ? 0.86 : 1) : 0.42)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(.spring(duration: 0.18, bounce: 0), value: configuration.isPressed)

        label
            .background(
                LinearGradient(colors: reduceTransparency ? [CX.blue, CX.blue] :
                    [Color(red: 0.30, green: 0.48, blue: 0.74), CX.blue, Color(red: 0.13, green: 0.29, blue: 0.54)],
                    startPoint: .topLeading, endPoint: .bottomTrailing),
                in: .rect(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18).strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.42), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom), lineWidth: 0.7)
            }
            .shadow(color: CX.blue.opacity(isEnabled ? 0.16 : 0), radius: configuration.isPressed ? 2 : 8, y: configuration.isPressed ? 1 : 4)
            .offset(y: configuration.isPressed && !reduceMotion ? 1 : 0)
    }
}

struct QuietPressButton: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(reduceMotion ? nil : .spring(duration: 0.24, bounce: 0.12), value: configuration.isPressed)
    }
}

private struct CXInteractiveGlassModifier: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(CX.raisedSurface, in: .rect(cornerRadius: cornerRadius, style: .continuous))
                .overlay { glassBorder }
        } else if #available(iOS 26, *) {
            content.glassEffect(
                .regular.interactive(),
                in: .rect(cornerRadius: cornerRadius, style: .continuous)
            )
        } else {
            content
                .background(.regularMaterial, in: .rect(cornerRadius: cornerRadius, style: .continuous))
                .overlay { glassBorder }
        }
    }

    private var glassBorder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(CX.separator.opacity(0.18), lineWidth: 0.5)
    }
}

private struct CXInteractiveGlassCircleModifier: ViewModifier {
    var prominent = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if prominent && reduceTransparency {
            content.background(CX.blue, in: Circle())
        } else if reduceTransparency {
            content
                .background(CX.raisedSurface, in: Circle())
                .overlay { Circle().strokeBorder(CX.separator.opacity(0.18), lineWidth: 0.5) }
        } else if #available(iOS 26, *) {
            content.glassEffect(
                prominent ? .regular.tint(CX.blue).interactive() : .regular.interactive(),
                in: .circle
            )
        } else if prominent {
            content.background(CX.blue, in: Circle())
        } else {
            content
                .background(.thinMaterial, in: Circle())
                .overlay { Circle().strokeBorder(CX.separator.opacity(0.18), lineWidth: 0.5) }
        }
    }
}

extension View {
    /// Places the moon artwork as a sibling behind the screen content so every
    /// layer shares the same safe-area coordinate space.
    func cxMoonScreenBackground(illustrated: Bool = false) -> some View {
        modifier(CXMoonScreenBackgroundModifier(illustrated: illustrated))
    }

    func cxInteractiveGlass(cornerRadius: CGFloat) -> some View {
        modifier(CXInteractiveGlassModifier(cornerRadius: cornerRadius))
    }

    func cxInteractiveGlassCircle() -> some View {
        modifier(CXInteractiveGlassCircleModifier())
    }

    func cxProminentGlassCircle() -> some View {
        modifier(CXInteractiveGlassCircleModifier(prominent: true))
    }

    @ViewBuilder
    func cxGlassCapsule(reduceTransparency: Bool) -> some View {
        if reduceTransparency {
            self.background(CX.raisedSurface, in: Capsule())
        } else if #available(iOS 26, *) {
            self.glassEffect(.regular, in: .capsule)
        } else {
            self
                .background(.thinMaterial, in: Capsule())
                .overlay { Capsule().strokeBorder(CX.separator.opacity(0.18), lineWidth: 0.5) }
        }
    }

    @ViewBuilder
    func cxAdaptiveTabBar() -> some View {
        if #available(iOS 26, *) {
            self.tabBarMinimizeBehavior(.never)
        } else {
            self.toolbarBackground(.visible, for: .tabBar)
        }
    }

    func assistantFormContext(
        title: String,
        draft: String,
        fill: @escaping @MainActor (String) -> Bool
    ) -> some View {
        modifier(AssistantFormContextModifier(title: title, draft: draft, fill: fill))
    }

    @ViewBuilder
    func cxNavigationChrome() -> some View {
        if #available(iOS 26, *) {
            self
        } else {
            self
                .toolbarBackground(CX.mist.opacity(0.95), for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    @ViewBuilder
    func cxComposerBackground() -> some View {
        if #available(iOS 26, *) {
            self.background(.clear)
        } else {
            self.background(.regularMaterial)
        }
    }
}

private struct CXMoonScreenBackgroundModifier: ViewModifier {
    let illustrated: Bool

    func body(content: Content) -> some View {
        ZStack {
            MoonBackground(illustrated: illustrated)
            content
        }
    }
}

private struct AssistantFormContextModifier: ViewModifier {
    @Environment(AssistantCoordinator.self) private var assistant
    @State private var id = UUID()
    @State private var showChat = false
    let title: String
    let draft: String
    let fill: @MainActor (String) -> Bool

    func body(content: Content) -> some View {
        content
            .onAppear { assistant.register(id: id, title: title, draft: draft, fill: fill) }
            .onChange(of: draft) { _, value in
                assistant.update(id: id, title: title, draft: value, fill: fill)
            }
            .onDisappear { assistant.unregister(id: id) }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    if assistant.activateRegistered() { showChat = true }
                } label: {
                    Label("帮我填", systemImage: "wand.and.stars")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .cxInteractiveGlass(cornerRadius: 22)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("召唤常曦帮助填写\(title)")
                .accessibilityIdentifier("global-assistant")
                .padding(16)
            }
            .fullScreenCover(isPresented: $showChat) {
                NavigationStack { ChatView(initialPrompt: assistant.initialPrompt) }
            }
    }
}

struct LunarPhase {
    let lunarMonth: Int
    let lunarDay: Int

    static var today: LunarPhase {
        let values = Calendar(identifier: .chinese).dateComponents([.month, .day], from: .now)
        return LunarPhase(lunarMonth: values.month ?? 1, lunarDay: values.day ?? 1)
    }

    var dateLabel: String {
        let months = ["正月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "冬月", "腊月"]
        let days = ["初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十", "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十", "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"]
        return "\(months[max(0, min(lunarMonth - 1, months.count - 1))])\(days[max(0, min(lunarDay - 1, days.count - 1))])"
    }

    var phaseName: String {
        switch lunarDay {
        case 1...2: "新月"
        case 3...6: "蛾眉月"
        case 7...9: "上弦月"
        case 10...13: "盈凸月"
        case 14...16: "满月"
        case 17...21: "亏凸月"
        case 22...24: "下弦月"
        default: "残月"
        }
    }

    var rhythmLabel: String { lunarDay <= 15 ? "月光渐盈" : "月光渐隐" }

    var symbol: String {
        switch lunarDay {
        case 1...2: "moonphase.new.moon"
        case 3...6: "moonphase.waxing.crescent"
        case 7...9: "moonphase.first.quarter"
        case 10...13: "moonphase.waxing.gibbous"
        case 14...16: "moonphase.full.moon"
        case 17...21: "moonphase.waning.gibbous"
        case 22...24: "moonphase.last.quarter"
        default: "moonphase.waning.crescent"
        }
    }
}

struct MoonPhaseCard: View {
    private let phase = LunarPhase.today

    var body: some View {
        HStack(spacing: 16) {
            MoonDisc(phase: Double(phase.lunarDay - 1) / 29.53)
                .frame(width: 44, height: 44).padding(5)
            VStack(alignment: .leading, spacing: 4) {
                Text(phase.phaseName).font(.headline)
                Text("\(phase.dateLabel) · \(phase.rhythmLabel)")
                    .font(.subheadline)
                    .foregroundStyle(CX.muted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(CX.faint)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("今日月相，\(phase.phaseName)，\(phase.dateLabel)，\(phase.rhythmLabel)")
    }
}

struct MoonRhythmDetailView: View {
    private let phase = LunarPhase.today

    var body: some View {
        Page(illustrated: true) {
            VStack(spacing: 12) {
                MoonDisc(phase: Double(phase.lunarDay - 1) / 29.53)
                    .frame(width: 108, height: 108).padding(12)
                Text(phase.phaseName).font(.largeTitle.weight(.semibold)).fontDesign(.serif)
                Text("\(phase.dateLabel) · \(phase.rhythmLabel)").foregroundStyle(CX.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)

            Card {
                Text("月相节律").font(.title2.weight(.semibold))
                Text("常曦用月相表达一天一天积累的过程。月光的盈亏只是一种温柔的时间提示，不用于判断健康好坏。")
                    .lineSpacing(6)
                NavigationLink("查看今日计划") { PlanView() }
                    .buttonStyle(PrimaryButton())
            }
        }
        .navigationTitle("今日月相")
    }
}

struct SectionEyebrow: View {
    let title: String
    var action: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title3.weight(.semibold))
            Spacer()
            if let action {
                Text(action)
                    .font(.subheadline)
                    .foregroundStyle(CX.muted)
            }
        }
    }
}

struct BrandFooter: View {
    var body: some View {
        Label("让每一个平凡的日子，都有月光相伴", systemImage: "moon.fill")
            .font(.footnote)
            .foregroundStyle(CX.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
    }
}

struct DemoLabel: View {
    var body: some View {
        Label("体验模式 · 示例数据仅保存在本机", systemImage: "iphone")
            .font(.caption)
            .foregroundStyle(CX.muted)
            .accessibilityIdentifier("demo-label")
    }
}

@MainActor final class MoonHaptics {
    static let shared = MoonHaptics()
    private var engine: CHHapticEngine?

    func play(success: Bool = false, enabled: Bool = true) {
        guard enabled, CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            if engine == nil { engine = try CHHapticEngine() }
            try engine?.start()
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: success ? 0.45 : 0.22),
                    .init(parameterID: .hapticSharpness, value: 0.22)
                ],
                relativeTime: 0
            )
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            try engine?.makePlayer(with: pattern).start(atTime: 0)
        } catch {
            // Haptics are additive and safely ignored on unsupported devices.
        }
    }
}
