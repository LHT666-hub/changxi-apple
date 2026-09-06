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
            CX.mist
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

            if illustrated {
                Image(decorative: "MoonGarden")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 520)
                    .clipped()
                    .opacity(colorScheme == .dark ? 0.16 : 0.22)
                    .mask(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.72), .clear],
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
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var meshColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(.displayP3, red: 0.035, green: 0.055, blue: 0.10),
                Color(.displayP3, red: 0.055, green: 0.09, blue: 0.17),
                Color(.displayP3, red: 0.08, green: 0.12, blue: 0.21),
                Color(.displayP3, red: 0.04, green: 0.07, blue: 0.13),
                Color(.displayP3, red: 0.07, green: 0.12, blue: 0.21),
                Color(.displayP3, red: 0.04, green: 0.08, blue: 0.15),
                Color(.displayP3, red: 0.025, green: 0.04, blue: 0.075),
                Color(.displayP3, red: 0.04, green: 0.07, blue: 0.12),
                Color(.displayP3, red: 0.025, green: 0.045, blue: 0.08)
            ]
        }

        return [
            Color(.displayP3, red: 0.91, green: 0.95, blue: 1.0),
            Color(.displayP3, red: 0.95, green: 0.97, blue: 1.0),
            Color(.displayP3, red: 0.86, green: 0.92, blue: 0.99),
            Color(.displayP3, red: 0.97, green: 0.98, blue: 1.0),
            Color(.displayP3, red: 0.91, green: 0.95, blue: 0.99),
            Color(.displayP3, red: 0.96, green: 0.97, blue: 1.0),
            Color(.displayP3, red: 0.98, green: 0.98, blue: 0.99),
            Color(.displayP3, red: 0.96, green: 0.97, blue: 0.99),
            Color(.displayP3, red: 0.98, green: 0.98, blue: 1.0)
        ]
    }
}

struct Page<Content: View>: View {
    var illustrated = false
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                content
            }
            .frame(maxWidth: 720)
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
        .background { MoonBackground(illustrated: illustrated) }
        .foregroundStyle(CX.ink)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct Card<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            reduceTransparency ? AnyShapeStyle(CX.surface) : AnyShapeStyle(.regularMaterial),
            in: .rect(cornerRadius: 22, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(CX.separator.opacity(0.18), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.055), radius: 18, y: 8)
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
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.11), in: .rect(cornerRadius: 13, style: .continuous))

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
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, 20)
            .foregroundStyle(.white)
            .background(CX.blue, in: .rect(cornerRadius: 16, style: .continuous))
            .shadow(color: CX.blue.opacity(configuration.isPressed ? 0.12 : 0.24), radius: 14, y: 8)
            .opacity(isEnabled ? (configuration.isPressed ? 0.86 : 1) : 0.42)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(.spring(duration: 0.18, bounce: 0), value: configuration.isPressed)
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
