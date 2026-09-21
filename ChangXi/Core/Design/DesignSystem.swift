import SwiftUI
import CoreHaptics

enum CX {
    // MARK: Semantic surfaces
    static let canvas = adaptive(
        light: UIColor(red: 247 / 255, green: 246 / 255, blue: 242 / 255, alpha: 1),
        dark: UIColor(red: 15 / 255, green: 20 / 255, blue: 29 / 255, alpha: 1)
    )
    static let surface = adaptive(
        light: UIColor(red: 252 / 255, green: 252 / 255, blue: 250 / 255, alpha: 1),
        dark: UIColor(red: 22 / 255, green: 28 / 255, blue: 38 / 255, alpha: 1)
    )
    static let raisedSurface = adaptive(
        light: .white,
        dark: UIColor(red: 27 / 255, green: 35 / 255, blue: 48 / 255, alpha: 1)
    )

    // MARK: Semantic text
    static let ink = Color.primary
    static let muted = Color(uiColor: .secondaryLabel)
    static let faint = Color(uiColor: .tertiaryLabel)
    static let separator = Color(uiColor: .separator)

    // MARK: Brand and interaction
    static let actionPrimary = adaptive(
        light: UIColor(red: 53 / 255, green: 104 / 255, blue: 200 / 255, alpha: 1),
        dark: UIColor(red: 105 / 255, green: 151 / 255, blue: 232 / 255, alpha: 1)
    )
    static let actionPrimarySoft = adaptive(
        light: UIColor(red: 220 / 255, green: 232 / 255, blue: 250 / 255, alpha: 1),
        dark: UIColor(red: 32 / 255, green: 50 / 255, blue: 78 / 255, alpha: 1)
    )
    static let brandMoonlight = adaptive(
        light: UIColor(red: 183 / 255, green: 202 / 255, blue: 226 / 255, alpha: 1),
        dark: UIColor(red: 132 / 255, green: 162 / 255, blue: 201 / 255, alpha: 1)
    )
    static let brandIvory = adaptive(
        light: UIColor(red: 232 / 255, green: 220 / 255, blue: 192 / 255, alpha: 1),
        dark: UIColor(red: 176 / 255, green: 159 / 255, blue: 126 / 255, alpha: 1)
    )

    // MARK: State colors
    static let statusPositive = adaptive(
        light: UIColor(red: 47 / 255, green: 128 / 255, blue: 111 / 255, alpha: 1),
        dark: UIColor(red: 90 / 255, green: 171 / 255, blue: 151 / 255, alpha: 1)
    )
    static let statusWarning = adaptive(
        light: UIColor(red: 183 / 255, green: 131 / 255, blue: 59 / 255, alpha: 1),
        dark: UIColor(red: 224 / 255, green: 174 / 255, blue: 94 / 255, alpha: 1)
    )
    static let statusCritical = adaptive(
        light: UIColor(red: 192 / 255, green: 93 / 255, blue: 93 / 255, alpha: 1),
        dark: UIColor(red: 231 / 255, green: 132 / 255, blue: 132 / 255, alpha: 1)
    )

    // Compatibility aliases while the rest of the app migrates to semantic names.
    static let blue = actionPrimary
    static let moonlight = brandMoonlight
    static let moonIvory = brandIvory
    static let mist = canvas
    static let teal = statusPositive
    static let coral = statusCritical
    static let gold = statusWarning

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

enum CXTypography {
    static let brandTitle = Font.system(size: 31, weight: .semibold, design: .default)
    static let display = Font.system(.largeTitle, design: .default, weight: .semibold)
    static let title = Font.system(.title2, design: .default, weight: .semibold)
    static let section = Font.system(.headline, design: .default, weight: .semibold)
    static let body = Font.body
    static let supporting = Font.subheadline
    static let meta = Font.footnote
    static let micro = Font.caption
    static let numeric = Font.system(.title, design: .rounded, weight: .semibold)
}

enum CXSpacing {
    static let micro: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let section: CGFloat = 32
    static let hero: CGFloat = 40
    static let page: CGFloat = 20
}

enum CXRadius {
    static let sm: CGFloat = 12
    static let md: CGFloat = 18
    static let lg: CGFloat = 24
}

enum CXLayout {
    static func adaptiveColumns(
        minimum: CGFloat,
        spacing: CGFloat = 12,
        dynamicTypeSize: DynamicTypeSize
    ) -> [GridItem] {
        if dynamicTypeSize >= .xxxLarge {
            return [GridItem(.flexible())]
        }
        return [GridItem(.adaptive(minimum: minimum), spacing: spacing)]
    }
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
            .opacity(reduceTransparency ? 0 : 0.50)
            .ignoresSafeArea()

            if illustrated {
                Image(decorative: "MoonGarden")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 520)
                    .clipped()
                    .opacity(colorScheme == .dark ? 0.08 : 0.055)
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
                colors: [
                    CX.brandMoonlight.opacity(colorScheme == .dark ? 0.15 : 0.095),
                    CX.brandIvory.opacity(colorScheme == .dark ? 0.025 : 0.045),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 24,
                endRadius: 460
            )
            .mask(topEdgeFade)
            .ignoresSafeArea()
        }
        .accessibilityHidden(true)
    }

    private var meshColors: [Color] {
        // V3 keeps the content plane moon-white. Cool blue only appears as a quiet
        // atmospheric tint around the hero, rather than filling the whole screen.
        if colorScheme == .dark {
            return [
                backgroundTopColor,
                backgroundTopColor,
                backgroundTopColor,
                Color(.displayP3, red: 0.055, green: 0.072, blue: 0.10),
                Color(.displayP3, red: 0.075, green: 0.095, blue: 0.14),
                Color(.displayP3, red: 0.055, green: 0.075, blue: 0.11),
                Color(.displayP3, red: 0.045, green: 0.058, blue: 0.082),
                Color(.displayP3, red: 0.055, green: 0.070, blue: 0.095),
                Color(.displayP3, red: 0.045, green: 0.058, blue: 0.082)
            ]
        }

        return [
            backgroundTopColor,
            backgroundTopColor,
            backgroundTopColor,
            Color(.displayP3, red: 0.982, green: 0.978, blue: 0.958),
            Color(.displayP3, red: 0.952, green: 0.965, blue: 0.978),
            Color(.displayP3, red: 0.978, green: 0.972, blue: 0.952),
            Color(.displayP3, red: 0.972, green: 0.968, blue: 0.952),
            Color(.displayP3, red: 0.965, green: 0.972, blue: 0.982),
            Color(.displayP3, red: 0.978, green: 0.973, blue: 0.958)
        ]
    }

    private var backgroundTopColor: Color {
        CX.canvas
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
                LazyVStack(alignment: .leading, spacing: CXSpacing.lg) {
                    content
                }
                .frame(maxWidth: 720)
                .padding(.horizontal, CXSpacing.page)
                .padding(.vertical, CXSpacing.xl)
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
    @Environment(\.colorScheme) private var colorScheme

    private let cornerRadius: CGFloat = CXRadius.lg

    var body: some View {
        VStack(alignment: .leading, spacing: CXSpacing.md) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CXSpacing.lg)
        .background(CX.surface, in: .rect(cornerRadius: cornerRadius, style: .continuous))
        .overlay { border }
        .shadow(
            color: .black.opacity(colorScheme == .dark ? 0.14 : 0.035),
            radius: colorScheme == .dark ? 16 : 12,
            y: colorScheme == .dark ? 7 : 5
        )
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(CX.separator.opacity(colorScheme == .dark ? 0.18 : 0.10), lineWidth: 0.5)
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
        HStack(spacing: CXSpacing.sm) {
            Image(systemName: icon.replacingOccurrences(of: ".fill", with: ""))
                .font(.title3.weight(.regular))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.05), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(CXTypography.section)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(CXTypography.supporting)
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
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, 20)
            .foregroundStyle(.white)
            .opacity(isEnabled ? (configuration.isPressed ? 0.88 : 1) : 0.42)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .animation(.spring(duration: 0.18, bounce: 0), value: configuration.isPressed)

        label
            .background(
                CX.actionPrimary,
                in: .rect(cornerRadius: CXRadius.md, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: CXRadius.md, style: .continuous)
                    .strokeBorder(.white.opacity(reduceTransparency ? 0 : 0.16), lineWidth: 0.6)
            }
            .shadow(
                color: CX.actionPrimary.opacity(isEnabled ? 0.12 : 0),
                radius: configuration.isPressed ? 2 : 7,
                y: configuration.isPressed ? 1 : 3
            )
            .offset(y: configuration.isPressed && !reduceMotion ? 1 : 0)
    }
}

struct LunarGlyph: View {
    var size: CGFloat = 56
    var tint: Color = CX.actionPrimary

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.14), lineWidth: 0.8)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0.10, to: 0.64)
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: max(1.2, size * 0.035), lineCap: .round)
                )
                .frame(width: size * 0.72, height: size * 0.72)
                .rotationEffect(.degrees(-28))

            Circle()
                .fill(CX.brandIvory)
                .frame(width: max(4, size * 0.09), height: max(4, size * 0.09))
                .offset(x: size * 0.25, y: -size * 0.18)

            Capsule()
                .fill(CX.brandMoonlight.opacity(0.48))
                .frame(width: size * 0.62, height: max(1, size * 0.018))
                .offset(y: size * 0.34)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct MoonLoadingIndicator: View {
    var label = "正在整理"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = 0.08
    @State private var rotation = 0.0

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(CX.moonlight.opacity(0.12), lineWidth: 0.8)
                    .frame(width: 58, height: 58)

                Circle()
                    .trim(from: 0.08, to: 0.68)
                    .stroke(
                        AngularGradient(
                            colors: [.clear, .white.opacity(0.72), CX.moonlight.opacity(0.34), .clear],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 1.2, lineCap: .round)
                    )
                    .frame(width: 58, height: 58)
                    .rotationEffect(.degrees(rotation))

                MoonDisc(phase: phase)
                    .frame(width: 40, height: 40)
            }

            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(CX.muted)
        }
        .onAppear {
            guard !reduceMotion else { return }

            withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) {
                rotation = 360
            }

            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                phase = 0.18
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }
}

struct MoonEmptyState: View {
    let title: String
    let message: String
    var symbol = "moon.stars"

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(CX.blue)
                .frame(width: 70, height: 70)
                .background(CX.blue.opacity(0.055), in: Circle())

            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(CX.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
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
                Text(phase.phaseName).font(CXTypography.display)
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ViewBuilder
    var body: some View {
        if dynamicTypeSize >= .xxxLarge {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.title3.weight(.semibold))
                if let action {
                    Text(action)
                        .font(.subheadline)
                        .foregroundStyle(CX.muted)
                }
            }
        } else {
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
