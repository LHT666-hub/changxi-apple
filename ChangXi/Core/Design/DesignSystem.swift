import SwiftUI
import CoreHaptics

enum CX {
    static let ink = Color(red: 0.07, green: 0.17, blue: 0.34)
    static let muted = Color(red: 0.32, green: 0.42, blue: 0.57)
    static let blue = Color(red: 0.17, green: 0.36, blue: 0.65)
    static let mist = Color(red: 0.90, green: 0.95, blue: 1)
    static let teal = Color(red: 0.12, green: 0.48, blue: 0.46)
    static let coral = Color(red: 0.73, green: 0.25, blue: 0.30)
}

struct MoonBackground: View {
    var illustrated = false
    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [CX.mist, Color(red: 0.97, green: 0.98, blue: 1)], startPoint: .topLeading, endPoint: .bottomTrailing)
            if illustrated {
                Image("MoonGarden").resizable().scaledToFill().frame(height: 620).clipped()
                    .mask(LinearGradient(stops: [.init(color: .white, location: 0), .init(color: .white.opacity(0.85), location: 0.48), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom)).offset(y: 54)
                LinearGradient(colors: [.white.opacity(0.62), .white.opacity(0.15), .clear], startPoint: .topLeading, endPoint: .bottomTrailing).frame(height: 350)
            }
        }.ignoresSafeArea().accessibilityHidden(true)
    }
}

struct Page<Content: View>: View {
    var illustrated = false
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 20) { content }.frame(maxWidth: 760).padding(20).frame(maxWidth: .infinity) }
            .background { MoonBackground(illustrated: illustrated) }
            .foregroundStyle(CX.ink)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(CX.mist.opacity(0.95), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 16) { content }
            .frame(maxWidth: .infinity, alignment: .leading).padding(20)
            .background(.white.opacity(0.91), in: RoundedRectangle(cornerRadius: 26))
            .overlay { RoundedRectangle(cornerRadius: 26).stroke(.white, lineWidth: 1) }
            .shadow(color: CX.blue.opacity(0.055), radius: 16, y: 6)
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
            Image(systemName: icon).font(.title3).foregroundStyle(tint).frame(width: 46, height: 46).background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                if !subtitle.isEmpty { Text(subtitle).font(.subheadline).foregroundStyle(CX.muted).fixedSize(horizontal: false, vertical: true) }
            }
            Spacer(minLength: 0)
            if chevron { Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(CX.muted) }
        }.frame(minHeight: 48).contentShape(Rectangle())
    }
}

struct PrimaryButton: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).frame(maxWidth: .infinity).frame(minHeight: 52).padding(.horizontal, 12)
            .foregroundStyle(.white)
            .background(LinearGradient(colors: [Color(red: 0.35, green: 0.57, blue: 0.82), CX.blue], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24))
            .overlay { RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.55), lineWidth: 1) }
            .shadow(color: CX.blue.opacity(0.18), radius: 10, y: 4)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
    }
}

struct BrandFooter: View {
    var body: some View { Label("让每一个平凡的日子，都有月光相伴", systemImage: "moon.fill").font(.footnote).foregroundStyle(CX.muted).frame(maxWidth: .infinity).padding(.vertical, 16) }
}

struct DemoLabel: View {
    var body: some View { Label("体验模式 · 示例数据仅保存在本机", systemImage: "iphone").font(.caption).foregroundStyle(CX.muted).accessibilityIdentifier("demo-label") }
}

@MainActor final class MoonHaptics {
    static let shared = MoonHaptics()
    private var engine: CHHapticEngine?
    func play(success: Bool = false, enabled: Bool = true) {
        guard enabled, CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            if engine == nil { engine = try CHHapticEngine() }
            try engine?.start()
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [.init(parameterID: .hapticIntensity, value: success ? 0.45 : 0.22), .init(parameterID: .hapticSharpness, value: 0.22)], relativeTime: 0)
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            try engine?.makePlayer(with: pattern).start(atTime: 0)
        } catch { /* Haptics are optional on unsupported devices. */ }
    }
}
