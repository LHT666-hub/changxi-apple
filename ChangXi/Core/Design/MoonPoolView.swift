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

/// 常曦 UI 2.0 的核心月池视觉。
/// 月体承担“在场感”，月池承担状态反馈；健康含义仍由业务数据表达。
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

    private var stageHeight: CGFloat { compact ? 200 : 292 }

    var body: some View {
        ZStack(alignment: .bottom) {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: paused)) { timeline in
                let time = paused ? 0 : timeline.date.timeIntervalSince(entered)

                ZStack(alignment: .bottom) {
                    celestialMotes(time: time)
                    waterSurface(time: time)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }

            if character {
                characterView
            }

            if state != .idle {
                MoonStatusPill(state: state, reduceTransparency: reduceTransparency)
                    .padding(.bottom, compact ? 2 : 8)
            }
        }
        .frame(height: stageHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("月池，\(state.label)")
        .onChange(of: state) {
            entered = .now
        }
    }

    private func celestialMotes(time: TimeInterval) -> some View {
        Canvas { context, size in
            let count = compact ? 6 : 11
            for index in 0..<count {
                let seed = Double(index + 1)
                let travel = time * (0.055 + seed * 0.0035) + seed * 1.31
                let x = size.width * (0.12 + 0.76 * normalizedSine(seed * 2.37))
                    + sin(travel) * (compact ? 4 : 8)
                let y = size.height * (0.10 + 0.50 * normalizedSine(seed * 3.11))
                    + cos(travel * 0.74) * (compact ? 3 : 6)
                let pulse = paused ? 0.26 : 0.16 + Double(normalizedSine(time * 0.58 + seed)) * 0.36
                let diameter = compact ? 1.4 : 1.8 + CGFloat(index % 3) * 0.35
                let rect = CGRect(x: x - diameter / 2, y: y - diameter / 2, width: diameter, height: diameter)

                var mote = context
                mote.addFilter(.shadow(color: state.accent.opacity(pulse * 0.72), radius: compact ? 3 : 5))
                mote.fill(Path(ellipseIn: rect), with: .color(.white.opacity(pulse)))
            }
        }
        .allowsHitTesting(false)
    }

    private func waterSurface(time: TimeInterval) -> some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height - (compact ? 47 : 58))
            let width = min(size.width * 0.96, compact ? 380 : 520)
            let surfaceHeight = compact ? 72.0 : 112.0

            let pool = CGRect(
                x: center.x - width / 2,
                y: center.y - surfaceHeight / 2,
                width: width,
                height: surfaceHeight
            )
            context.fill(
                Path(ellipseIn: pool),
                with: .radialGradient(
                    Gradient(colors: [
                        .white.opacity(reduceTransparency ? 0.62 : 0.86),
                        CX.brandMoonlight.opacity(reduceTransparency ? 0.20 : 0.42),
                        CX.actionPrimary.opacity(reduceTransparency ? 0.08 : 0.18),
                        .clear
                    ]),
                    center: CGPoint(x: center.x, y: center.y - surfaceHeight * 0.12),
                    startRadius: 2,
                    endRadius: width * 0.52
                )
            )
            context.stroke(
                Path(ellipseIn: pool.insetBy(dx: 1, dy: 1)),
                with: .linearGradient(
                    Gradient(colors: [.clear, .white.opacity(0.72), CX.brandMoonlight.opacity(0.30), .clear]),
                    startPoint: CGPoint(x: pool.minX, y: pool.midY),
                    endPoint: CGPoint(x: pool.maxX, y: pool.midY)
                ),
                lineWidth: 1
            )

            // 不再铺一整块“玻璃圆盘”，只保留破碎反射和极弱水纹。
            for row in 0..<9 {
                let depth = Double(row) / 8
                let y = center.y - surfaceHeight * 0.34 + depth * surfaceHeight * 0.68
                let halfWidth = width * (0.12 + sin(depth * .pi) * 0.34)
                let drift = paused ? 0 : time * (0.26 + depth * 0.10)

                var line = Path()
                var hasPreviousPoint = false
                for step in 0...52 {
                    let p = Double(step) / 52
                    let x = center.x - halfWidth + 2 * halfWidth * p
                    let wave = sin(p * .pi * 4.2 + drift + Double(row) * 0.52) * (0.32 + depth * 0.74)
                    let visible = sin(p * .pi * 9 + Double(row)) > -0.72

                    guard visible else {
                        hasPreviousPoint = false
                        continue
                    }

                    if hasPreviousPoint {
                        line.addLine(to: CGPoint(x: x, y: y + wave))
                    } else {
                        line.move(to: CGPoint(x: x, y: y + wave))
                        hasPreviousPoint = true
                    }
                }

                context.stroke(
                    line,
                    with: .linearGradient(
                        Gradient(colors: [
                            .clear,
                            .white.opacity(row.isMultiple(of: 3) ? 0.34 : 0.12),
                            state.accent.opacity(row.isMultiple(of: 4) ? 0.10 : 0.03),
                            .clear
                        ]),
                        startPoint: CGPoint(x: center.x - halfWidth, y: y),
                        endPoint: CGPoint(x: center.x + halfWidth, y: y)
                    ),
                    lineWidth: row.isMultiple(of: 3) ? 0.85 : 0.45
                )
            }

            let waveCount = state == .quietAlert ? 1 : (state == .listening ? 4 : 3)
            let baseSpeed = state == .listening ? 0.58 : state == .thinking ? 0.24 : 0.14
            let amplitudeBoost = state == .listening ? min(max(amplitude, 0), 1) * 0.22 : 0

            for index in 0..<waveCount {
                let phase = paused
                    ? Double(index) / Double(max(waveCount, 1))
                    : (Double(index) / Double(max(waveCount, 1)) + time * baseSpeed)
                        .truncatingRemainder(dividingBy: 1)

                let scale = 0.16 + phase * (0.70 + amplitudeBoost)
                let rect = CGRect(
                    x: center.x - width * scale / 2,
                    y: center.y - surfaceHeight * scale / 2,
                    width: width * scale,
                    height: surfaceHeight * scale
                )
                let opacity = paused ? 0.12 : (1 - phase) * (state == .listening ? 0.42 : 0.24)

                context.stroke(
                    Path(ellipseIn: rect),
                    with: .linearGradient(
                        Gradient(colors: [
                            .clear,
                            .white.opacity(opacity),
                            state.accent.opacity(opacity * 0.48),
                            .clear
                        ]),
                        startPoint: CGPoint(x: rect.minX, y: rect.midY),
                        endPoint: CGPoint(x: rect.maxX, y: rect.midY)
                    ),
                    lineWidth: state == .listening ? 0.9 + amplitude * 0.8 : 0.7
                )
            }

            if state == .success {
                let progress = min(time / 1.4, 1)
                let scale = 0.18 + progress * 0.72
                let ring = CGRect(
                    x: center.x - width * scale / 2,
                    y: center.y - surfaceHeight * scale / 2,
                    width: width * scale,
                    height: surfaceHeight * scale
                )
                context.stroke(
                    Path(ellipseIn: ring),
                    with: .color(CX.teal.opacity((1 - progress) * 0.70)),
                    lineWidth: 1.8
                )
            }
        }
        .frame(maxWidth: 540)
        .frame(height: compact ? 94 : 136)
        .padding(.horizontal, 8)
        .offset(y: compact ? -4 : -4)
        .allowsHitTesting(false)
    }

    private var characterView: some View {
        Image(decorative: "ChangXiCharacter")
            .resizable()
            .scaledToFit()
            .frame(height: compact ? 142 : 226)
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
            .offset(x: compact ? -4 : -14, y: compact ? -30 : -42)
            .shadow(color: .white.opacity(reduceTransparency ? 0.04 : 0.28), radius: 7, y: -2)
            .shadow(color: state.accent.opacity(0.12), radius: 14, y: 8)
            .allowsHitTesting(false)
    }

    private func normalizedSine(_ value: Double) -> CGFloat {
        CGFloat((sin(value) + 1) / 2)
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

/// 高级月相本体：保留真实盈亏关系，同时加入月面层次和球体边缘光。
struct MoonDisc: View {
    let phase: Double

    @Environment(\.colorScheme) private var colorScheme

    private var normalizedPhase: Double {
        let value = phase.truncatingRemainder(dividingBy: 1)
        return value < 0 ? value + 1 : value
    }

    var body: some View {
        GeometryReader { proxy in
            let diameter = min(proxy.size.width, proxy.size.height)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(.displayP3, red: 0.22, green: 0.29, blue: 0.40)
                                    .opacity(colorScheme == .dark ? 0.96 : 0.86),
                                Color(.displayP3, red: 0.07, green: 0.10, blue: 0.17)
                                    .opacity(0.99)
                            ],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: diameter * 0.72
                        )
                    )

                MoonIllumination(phase: normalizedPhase)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(.displayP3, red: 1.00, green: 0.995, blue: 0.965),
                                Color(.displayP3, red: 0.94, green: 0.96, blue: 0.995),
                                Color(.displayP3, red: 0.77, green: 0.84, blue: 0.94)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                MoonSurfaceTexture()
                    .mask(MoonIllumination(phase: normalizedPhase))
                    .blendMode(.multiply)
                    .opacity(colorScheme == .dark ? 0.48 : 0.36)

                MoonIllumination(phase: normalizedPhase)
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.56), .white.opacity(0.08), .clear],
                            center: UnitPoint(x: 0.28, y: 0.22),
                            startRadius: 0,
                            endRadius: diameter * 0.78
                        )
                    )
                    .blendMode(.screen)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.clear, .black.opacity(0.035), .black.opacity(0.19)],
                            center: .center,
                            startRadius: diameter * 0.30,
                            endRadius: diameter * 0.58
                        )
                    )
                    .blendMode(.multiply)

                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.86),
                                .white.opacity(0.20),
                                CX.moonlight.opacity(0.14),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: max(0.7, diameter * 0.006)
                    )
            }
            .clipShape(Circle())
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

private struct MoonSurfaceTexture: View {
    var body: some View {
        Canvas { context, size in
            let craters: [(Double, Double, Double, Double)] = [
                (0.26, 0.30, 0.17, 0.10),
                (0.62, 0.25, 0.10, 0.08),
                (0.72, 0.54, 0.19, 0.07),
                (0.40, 0.63, 0.12, 0.08),
                (0.24, 0.73, 0.08, 0.06),
                (0.54, 0.46, 0.055, 0.055),
                (0.78, 0.76, 0.065, 0.05),
                (0.46, 0.18, 0.045, 0.045)
            ]

            for crater in craters {
                let diameter = size.width * crater.2
                let rect = CGRect(
                    x: size.width * crater.0 - diameter / 2,
                    y: size.height * crater.1 - diameter / 2,
                    width: diameter,
                    height: diameter
                )

                context.fill(
                    Path(ellipseIn: rect),
                    with: .radialGradient(
                        Gradient(colors: [
                            Color.black.opacity(crater.3),
                            Color.black.opacity(crater.3 * 0.28),
                            .clear
                        ]),
                        center: CGPoint(
                            x: rect.midX - diameter * 0.10,
                            y: rect.midY - diameter * 0.12
                        ),
                        startRadius: 0,
                        endRadius: diameter * 0.58
                    )
                )
            }
        }
    }
}

private struct MoonIllumination: Shape {
    var phase: Double

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let normalized = max(0, min(phase, 1))
        let radius = min(rect.width, rect.height) / 2
        let waxing = normalized < 0.5
        let terminator = cos(normalized * 2 * .pi)
        let samples = 96

        var path = Path()

        for index in 0...samples {
            let unitY = -1 + (2 * Double(index) / Double(samples))
            let span = sqrt(max(0, 1 - unitY * unitY)) * radius
            let x = rect.midX + (waxing ? span : -span)
            let y = rect.midY + unitY * radius
            let point = CGPoint(x: x, y: y)

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        for index in (0...samples).reversed() {
            let unitY = -1 + (2 * Double(index) / Double(samples))
            let span = sqrt(max(0, 1 - unitY * unitY)) * radius
            let x = rect.midX + (waxing ? terminator : -terminator) * span
            let y = rect.midY + unitY * radius
            path.addLine(to: CGPoint(x: x, y: y))
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
