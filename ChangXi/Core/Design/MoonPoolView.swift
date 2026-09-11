import SwiftUI

enum MoonPoolState: String, CaseIterable, Identifiable {
    case idle, listening, thinking, responding, success, notification, doctorReply, quietAlert

    var id: Self { self }

    var label: String {
        switch self {
        case .idle: "我在这里"
        case .listening: "我在听"
        case .thinking: "正在整理"
        case .responding: "慢慢说，我陪着你"
        case .success: "已经记下"
        case .notification: "有一件事想提醒你"
        case .doctorReply: "医生有了新回复"
        case .quietAlert: "这件事需要认真处理"
        }
    }

    var symbol: String {
        switch self {
        case .idle: "moon.stars.fill"
        case .listening: "waveform"
        case .thinking: "ellipsis"
        case .responding: "sparkles"
        case .success: "checkmark"
        case .notification: "bell.fill"
        case .doctorReply: "stethoscope"
        case .quietAlert: "exclamationmark"
        }
    }

    var accent: Color {
        switch self {
        case .success: CX.teal
        case .notification, .doctorReply: CX.gold
        case .quietAlert: CX.coral
        default: CX.blue
        }
    }
}

/// The moon communicates process state only. Health meaning remains in data views.
struct MoonPoolView: View {
    var state: MoonPoolState = .idle
    var amplitude: Double = 0
    var character = true
    var compact = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase
    @State private var entered = Date.now

    private var paused: Bool {
        reduceMotion || AppConfiguration.isUITesting || state == .quietAlert || scenePhase != .active
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: paused)) { timeline in
                let time = paused ? 0 : timeline.date.timeIntervalSince(entered)

                ZStack(alignment: .bottom) {
                    celestialMotes(time: time)
                    secondaryBloom(time: time)
                    ambientGlow(time: time)
                    pool(time: time)
                }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }

            if character {
                characterView
            }

            MoonStatusPill(state: state, reduceTransparency: reduceTransparency)
                .padding(.bottom, compact ? 4 : 12)
        }
        .frame(height: compact ? 188 : 292)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("月池，\(state.label)")
        .onChange(of: state) {
            entered = .now
        }
    }

    private func celestialMotes(time: TimeInterval) -> some View {
        Canvas { context, size in
            let motes = compact ? 5 : 9
            for index in 0..<motes {
                let seed = Double(index + 1)
                let orbit = time * (0.10 + seed * 0.006) + seed * 1.71
                let x = size.width * (0.18 + 0.64 * normalizedSine(seed * 2.13))
                    + sin(orbit) * (compact ? 5 : 9)
                let y = size.height * (0.14 + 0.48 * normalizedSine(seed * 3.07))
                    + cos(orbit * 0.82) * (compact ? 3 : 6)
                let pulse = paused ? 0.42 : 0.30 + Double(normalizedSine(time * 0.9 + seed)) * 0.38
                let diameter = compact ? 1.8 : 2.4 + CGFloat(index % 3) * 0.45
                let rect = CGRect(
                    x: x - diameter / 2,
                    y: y - diameter / 2,
                    width: diameter,
                    height: diameter
                )

                var mote = context
                mote.addFilter(.shadow(color: state.accent.opacity(pulse), radius: 4))
                mote.fill(Path(ellipseIn: rect), with: .color(.white.opacity(pulse)))
            }
        }
        .allowsHitTesting(false)
    }

    private func secondaryBloom(time: TimeInterval) -> some View {
        let drift = paused ? 0 : sin(time * 0.24) * (compact ? 5 : 9)
        let scale = paused ? 1 : 1 + sin(time * 0.38 + 1.4) * 0.035

        return Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        .white.opacity(reduceTransparency ? 0.05 : 0.19),
                        CX.moonlight.opacity(reduceTransparency ? 0.02 : 0.10),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: compact ? 84 : 132
                )
            )
            .frame(width: compact ? 190 : 300, height: compact ? 108 : 170)
            .scaleEffect(scale)
            .offset(x: drift, y: compact ? -14 : -22)
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
    }
    private func ambientGlow(time: TimeInterval) -> some View {
        let pulse = paused ? 1 : 1 + sin(time * 0.55) * 0.032
        return Circle()
            .fill(
                RadialGradient(
                    colors: [
                        .white.opacity(reduceTransparency ? 0.04 : 0.16),
                        CX.moonlight.opacity(reduceTransparency ? 0.03 : 0.10),
                        CX.moonlight.opacity(0.02),
                        .clear
                    ],
                    center: .center,
                    startRadius: 2,
                    endRadius: compact ? 78 : 120
                )
            )
            .scaleEffect(pulse)
            .frame(width: compact ? 250 : 360, height: compact ? 170 : 270)
            .blur(radius: 22)
            .offset(y: compact ? 12 : 18)
            .allowsHitTesting(false)
    }

    private func pool(time: TimeInterval) -> some View {
        Canvas { context, size in
            drawPool(context: &context, size: size, time: time)
        }
        .frame(maxWidth: 520)
        .frame(height: compact ? 80 : 120)
        .padding(.horizontal, compact ? 6 : 12)
        .offset(y: compact ? -6 : -10)
        .allowsHitTesting(false)
    }

    private var characterView: some View {
        Image(decorative: "ChangXiCharacter")
            .resizable()
            .scaledToFit()
            .frame(height: compact ? 142 : 226)
            .phaseAnimator(paused ? [CharacterRestPhase.still] : CharacterRestPhase.allCases) { content, phase in
                content
                    .scaleEffect(x: phase.scaleX, y: phase.scaleY, anchor: .bottom)
                    .rotationEffect(.degrees(phase.rotation), anchor: .bottom)
                    .offset(y: phase.offset)
            } animation: { phase in
                phase.animation
            }
            .keyframeAnimator(
                initialValue: CharacterResponse(),
                trigger: reduceMotion ? MoonPoolState.idle : state
            ) { content, value in
                content
                    .scaleEffect(value.scale, anchor: .bottom)
                    .rotationEffect(.degrees(value.rotation), anchor: .bottom)
                    .offset(x: value.x, y: value.y)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    CubicKeyframe(state.response.scale, duration: 0.12)
                    SpringKeyframe(1, duration: 0.36)
                }
                KeyframeTrack(\.rotation) {
                    CubicKeyframe(state.response.rotation, duration: 0.14)
                    SpringKeyframe(0, duration: 0.38)
                }
                KeyframeTrack(\.x) {
                    CubicKeyframe(state.response.x, duration: 0.11)
                    SpringKeyframe(0, duration: 0.34)
                }
                KeyframeTrack(\.y) {
                    CubicKeyframe(state.response.y, duration: 0.14)
                    SpringKeyframe(0, duration: 0.38)
                }
            }
            .offset(x: compact ? -4 : -14, y: compact ? -34 : -55)
            .shadow(color: .white.opacity(reduceTransparency ? 0.04 : 0.32), radius: 7, y: -2)
            .shadow(color: CX.blue.opacity(0.12), radius: 14, y: 8)
            .allowsHitTesting(false)
    }

    private func drawPool(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let center = CGPoint(x: size.width / 2, y: size.height * 0.52)
        let poolWidth = size.width * 0.94
        let poolHeight = size.height * 0.78
        let base = CGRect(
            x: center.x - poolWidth / 2,
            y: center.y - poolHeight / 2,
            width: poolWidth,
            height: poolHeight
        )

        var baseContext = context
        baseContext.addFilter(.blur(radius: 5))
        baseContext.fill(
            Path(ellipseIn: base),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.24, green: 0.51, blue: 0.69).opacity(0.32),
                    Color(red: 0.37, green: 0.67, blue: 0.82).opacity(0.48),
                    CX.moonlight.opacity(0.28),
                    .clear
                ]),
                startPoint: CGPoint(x: center.x, y: base.minY),
                endPoint: CGPoint(x: center.x, y: base.maxY)
            )
        )

        // Broken horizontal reflections suggest a surface, not a solid glass disc.
        var surface = context
        surface.clip(to: Path(ellipseIn: base))
        for row in 0..<18 {
            let depth = Double(row) / 18
            let y = base.minY + base.height * (0.12 + depth * 0.78)
            let halfWidth = poolWidth * (0.12 + sin(depth * .pi) * 0.30)
            var line = Path()
            for step in 0...44 {
                let x = center.x - halfWidth + 2 * halfWidth * Double(step) / 44
                let waveY = y + sin(Double(step) * 0.31 + time * 0.6 + Double(row)) * (0.5 + depth)
                if step == 0 { line.move(to: CGPoint(x: x, y: waveY)) }
                else { line.addLine(to: CGPoint(x: x, y: waveY)) }
            }
            surface.stroke(line, with: .linearGradient(
                Gradient(colors: [.clear, .white.opacity(row.isMultiple(of: 3) ? 0.55 : 0.20), .clear]),
                startPoint: CGPoint(x: center.x - halfWidth, y: y),
                endPoint: CGPoint(x: center.x + halfWidth, y: y)
            ), lineWidth: row.isMultiple(of: 3) ? 0.9 : 0.5)
        }

        let highlight = CGRect(
            x: base.minX + base.width * 0.12,
            y: base.minY + base.height * 0.05,
            width: base.width * 0.76,
            height: base.height * 0.34
        )
        context.stroke(
            Path(ellipseIn: highlight),
            with: .linearGradient(
                Gradient(colors: [.clear, .white.opacity(0.64), .clear]),
                startPoint: CGPoint(x: highlight.minX, y: highlight.midY),
                endPoint: CGPoint(x: highlight.maxX, y: highlight.midY)
            ),
            lineWidth: 1.1
        )

        let speed = state == .listening ? 0.42 : state == .thinking ? 0.20 : 0.11
        let waveCount = state == .quietAlert ? 2 : 5
        for index in 0..<waveCount {
            var phase = (Double(index) / Double(waveCount) + time * speed).truncatingRemainder(dividingBy: 1)
            if state == .thinking { phase = 1 - phase }

            let voiceScale = state == .listening ? 1 + min(max(amplitude, 0), 1) * 0.20 : 1
            let scale = (0.18 + phase * 0.78) * voiceScale
            let rect = CGRect(
                x: center.x - poolWidth * scale / 2,
                y: center.y - poolHeight * scale / 2,
                width: poolWidth * scale,
                height: poolHeight * scale
            )
            let opacity = paused ? 0.22 : (1 - phase) * (state == .listening ? 0.78 : 0.48)

            var wave = context
            wave.addFilter(.shadow(color: .white.opacity(opacity * 0.8), radius: 5))
            wave.stroke(
                Path(ellipseIn: rect),
                with: .linearGradient(
                    Gradient(colors: [
                        CX.blue.opacity(opacity * 0.32),
                        .white.opacity(opacity),
                        CX.blue.opacity(opacity * 0.18)
                    ]),
                    startPoint: CGPoint(x: rect.minX, y: rect.midY),
                    endPoint: CGPoint(x: rect.maxX, y: rect.midY)
                ),
                lineWidth: state == .listening ? 1.2 + amplitude * 1.6 : 1
            )
        }

        let glintTravel = paused ? 0.34 : normalizedSine(time * 0.45)
        let glintX = base.minX + base.width * (0.22 + glintTravel * 0.56)
        let glintRect = CGRect(x: glintX - 2, y: base.minY + base.height * 0.19, width: 4, height: 4)
        var glint = context
        glint.addFilter(.shadow(color: .white.opacity(0.85), radius: 6))
        glint.fill(Path(ellipseIn: glintRect), with: .color(.white.opacity(paused ? 0.38 : 0.74)))

        if state == .success {
            let progress = min(time / 1.6, 1)
            let ring = base.insetBy(dx: (1 - progress) * poolWidth / 2, dy: (1 - progress) * poolHeight / 2)
            context.stroke(Path(ellipseIn: ring), with: .color(CX.teal.opacity(1 - progress)), lineWidth: 2.5)
        }
    }

    private func normalizedSine(_ value: Double) -> CGFloat {
        CGFloat((sin(value) + 1) / 2)
    }
}

private enum CharacterRestPhase: CaseIterable {
    case still, inhale, hover, exhale

    var offset: CGFloat {
        switch self {
        case .still: 0
        case .inhale: -1.5
        case .hover: -3.5
        case .exhale: -1
        }
    }

    var scaleX: CGFloat {
        switch self {
        case .still: 1
        case .inhale: 0.997
        case .hover: 1.002
        case .exhale: 1
        }
    }

    var scaleY: CGFloat {
        switch self {
        case .still: 1
        case .inhale: 1.006
        case .hover: 1.011
        case .exhale: 1.003
        }
    }

    var rotation: Double {
        switch self {
        case .still: 0
        case .inhale: -0.22
        case .hover: 0.26
        case .exhale: 0.08
        }
    }

    var animation: Animation {
        switch self {
        case .still: .easeInOut(duration: 0.9)
        case .inhale: .easeInOut(duration: 1.35)
        case .hover: .easeInOut(duration: 1.65)
        case .exhale: .easeInOut(duration: 1.2)
        }
    }
}

private struct CharacterResponse {
    var scale: CGFloat = 1
    var rotation: Double = 0
    var x: CGFloat = 0
    var y: CGFloat = 0
}

private extension MoonPoolState {
    var response: CharacterResponse {
        switch self {
        case .idle:
            CharacterResponse()
        case .listening:
            CharacterResponse(scale: 1.012, rotation: -1.4, x: -1, y: -2)
        case .thinking:
            CharacterResponse(scale: 1.008, rotation: 1.8, x: 2, y: -1)
        case .responding:
            CharacterResponse(scale: 1.022, rotation: -0.6, x: -1, y: -3)
        case .success:
            CharacterResponse(scale: 1.04, rotation: 0, x: 0, y: -5)
        case .notification:
            CharacterResponse(scale: 1.018, rotation: -1.8, x: -3, y: -2)
        case .doctorReply:
            CharacterResponse(scale: 1.026, rotation: 1.3, x: 2, y: -3)
        case .quietAlert:
            CharacterResponse(scale: 0.995, rotation: 0, x: 0, y: 1)
        }
    }
}

private struct MoonStatusPill: View {
    let state: MoonPoolState
    let reduceTransparency: Bool

    var body: some View {
        Label(state.label, systemImage: state.symbol)
            .font(.subheadline.weight(.semibold))
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .foregroundStyle(CX.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .cxGlassCapsule(reduceTransparency: reduceTransparency)
            .contentTransition(.symbolEffect(.replace))
            .symbolEffect(.bounce, value: state)
            .animation(.snappy(duration: 0.28), value: state)
            .sensoryFeedback(state.feedback, trigger: state)
    }
}

private extension MoonPoolState {
    var feedback: SensoryFeedback {
        switch self {
        case .success: .success
        case .quietAlert: .warning
        case .notification, .doctorReply: .impact(flexibility: .soft)
        default: .selection
        }
    }
}

struct MoonDisc: View {
    let phase: Double
    var body: some View {
        ZStack {
            Circle().fill(
                RadialGradient(colors: [CX.moonlight.opacity(0.36), CX.blue.opacity(0.66)],
                               center: .topLeading, startRadius: 0, endRadius: 100)
            )
            MoonIllumination(phase: phase)
                .fill(LinearGradient(colors: [.white, Color(red: 0.91, green: 0.94, blue: 0.99), CX.moonlight.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().strokeBorder(.white.opacity(0.55), lineWidth: 0.6)
        }
        .shadow(color: CX.moonlight.opacity(0.18), radius: 12, y: 3)
        .accessibilityHidden(true)
    }
}

private struct MoonIllumination: Shape {
    let phase: Double
    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) / 2
        let waxing = phase < 0.5
        let terminator = cos(phase * 2 * .pi)
        var path = Path()
        for index in 0...80 {
            let y = -1 + Double(index) / 40
            let span = sqrt(max(0, 1 - y * y)) * radius
            let point = CGPoint(x: rect.midX + (waxing ? span : -span), y: rect.midY + y * radius)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        for index in (0...80).reversed() {
            let y = -1 + Double(index) / 40
            let span = sqrt(max(0, 1 - y * y)) * radius
            path.addLine(to: CGPoint(x: rect.midX + (waxing ? terminator : -terminator) * span, y: rect.midY + y * radius))
        }
        path.closeSubpath()
        return path
    }
}

struct RhythmView: View {
    var completed: Int
    var total: Int

    private var progress: Double {
        Double(completed) / Double(max(total, 1))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("今日计划进度")
                    .font(.headline)
                Spacer()
                Text("\(completed)/\(total)")
                    .font(.headline)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(completed)))
            }

            HStack(spacing: 14) {
                Image(systemName: progressSymbol)
                    .font(.system(size: 32, weight: .light))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(CX.blue)
                    .contentTransition(.symbolEffect(.replace))
                ProgressView(value: progress)
                    .tint(CX.blue)
                    .animation(.spring(duration: 0.42, bounce: 0.12), value: completed)
            }

            Text(completed == total && total > 0 ? "今天的安排都完成了" : "不必追赶，按自己的节奏来")
                .font(.subheadline)
                .foregroundStyle(CX.muted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("今日计划，已完成\(completed)项，共\(total)项")
    }

    private var progressSymbol: String {
        switch progress {
        case ..<0.13: "moonphase.new.moon"
        case ..<0.38: "moonphase.waxing.crescent"
        case ..<0.63: "moonphase.first.quarter"
        case ..<0.88: "moonphase.waxing.gibbous"
        default: "moonphase.full.moon"
        }
    }
}
