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

    var glowStrength: Double {
        switch self {
        case .idle: 0.86
        case .listening: 1.10
        case .thinking: 0.98
        case .responding: 1.06
        case .success: 1.14
        case .notification, .doctorReply: 1.08
        case .quietAlert: 0.82
        }
    }

    var orbitSpeed: Double {
        switch self {
        case .thinking: 0.92
        case .listening: 0.72
        case .responding: 0.60
        case .success: 0.42
        case .notification, .doctorReply: 0.48
        case .idle: 0.30
        case .quietAlert: 0
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
    @Environment(\.colorScheme) private var colorScheme

    @State private var entered = Date.now

    private var paused: Bool {
        reduceMotion || AppConfiguration.isUITesting || state == .quietAlert || scenePhase != .active
    }

    private var moonSize: CGFloat { compact ? 94 : 142 }
    private var stageHeight: CGFloat { compact ? 200 : 292 }

    private var lunarPhase: Double {
        let day = LunarPhase.today.lunarDay
        return min(max(Double(day - 1) / 29.53, 0), 1)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: paused)) { timeline in
                let time = paused ? 0 : timeline.date.timeIntervalSince(entered)

                ZStack(alignment: .bottom) {
                    celestialMotes(time: time)
                    halo(time: time)
                    orbit(time: time)
                    moon(time: time)
                    reflection(time: time)
                    waterSurface(time: time)

                    if character {
                        signatureMark(time: time)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }

            MoonStatusPill(state: state, reduceTransparency: reduceTransparency)
                .padding(.bottom, compact ? 2 : 8)
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

    private func halo(time: TimeInterval) -> some View {
        let breath = paused ? 1 : 1 + sin(time * 0.52) * 0.035
        let voice = state == .listening ? min(max(amplitude, 0), 1) * 0.12 : 0

        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(reduceTransparency ? 0.04 : 0.30 * state.glowStrength),
                            CX.moonlight.opacity(reduceTransparency ? 0.02 : 0.16 * state.glowStrength),
                            state.accent.opacity(reduceTransparency ? 0.01 : 0.055 * state.glowStrength),
                            .clear
                        ],
                        center: .center,
                        startRadius: moonSize * 0.14,
                        endRadius: moonSize * 0.92
                    )
                )
                .frame(width: moonSize * 2.02, height: moonSize * 2.02)
                .blur(radius: compact ? 8 : 12)

            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.34),
                            state.accent.opacity(0.10),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.7
                )
                .frame(width: moonSize * 1.42, height: moonSize * 1.42)
                .opacity(reduceTransparency ? 0.25 : 0.72)
        }
        .scaleEffect(breath + voice)
        .offset(y: compact ? -58 : -88)
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }

    private func orbit(time: TimeInterval) -> some View {
        let rotation = paused ? 18 : time * 18 * state.orbitSpeed
        let secondary = paused ? 110 : -time * 11 * max(state.orbitSpeed, 0.18)

        return ZStack {
            Circle()
                .trim(from: 0.06, to: state == .thinking ? 0.82 : 0.58)
                .stroke(
                    AngularGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.54),
                            state.accent.opacity(0.26),
                            .clear
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: state == .thinking ? 1.15 : 0.8, lineCap: .round)
                )
                .rotationEffect(.degrees(rotation))

            Circle()
                .trim(from: 0.54, to: 0.86)
                .stroke(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.26), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 0.55, lineCap: .round)
                )
                .rotationEffect(.degrees(secondary))

            if state == .notification || state == .doctorReply || state == .success {
                Circle()
                    .fill(state.accent.opacity(0.88))
                    .frame(width: compact ? 3 : 4, height: compact ? 3 : 4)
                    .shadow(color: state.accent.opacity(0.62), radius: 5)
                    .offset(y: -moonSize * 0.73)
                    .rotationEffect(.degrees(rotation * 1.24 + 28))
            }
        }
        .frame(width: moonSize * 1.52, height: moonSize * 1.52)
        .offset(y: compact ? -58 : -88)
        .opacity(state == .quietAlert ? 0.30 : 0.82)
        .allowsHitTesting(false)
    }

    private func moon(time: TimeInterval) -> some View {
        let float = paused ? 0 : sin(time * 0.63) * (compact ? 1.8 : 3.0)
        let voiceScale = state == .listening ? 1 + min(max(amplitude, 0), 1) * 0.035 : 1
        let thinkingTilt = state == .thinking && !paused ? sin(time * 0.8) * 0.65 : 0

        return MoonDisc(phase: lunarPhase)
            .frame(width: moonSize, height: moonSize)
            .scaleEffect(voiceScale)
            .rotationEffect(.degrees(thinkingTilt))
            .offset(y: (compact ? -58 : -88) + float)
            .overlay {
                if state == .quietAlert {
                    Circle()
                        .strokeBorder(CX.coral.opacity(0.34), lineWidth: 1.4)
                        .frame(width: moonSize, height: moonSize)
                        .offset(y: (compact ? -58 : -88) + float)
                }
            }
            .shadow(color: .white.opacity(colorScheme == .dark ? 0.16 : 0.26), radius: compact ? 8 : 12, y: -2)
            .shadow(color: state.accent.opacity(0.18 * state.glowStrength), radius: compact ? 14 : 22, y: 8)
            .allowsHitTesting(false)
    }

    private func reflection(time: TimeInterval) -> some View {
        let shimmer = paused ? 0.54 : 0.42 + normalizedSine(time * 0.72) * 0.22

        return ZStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(reduceTransparency ? 0.04 : Double(shimmer) * 0.28),
                            CX.moonlight.opacity(reduceTransparency ? 0.02 : Double(shimmer) * 0.14),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: compact ? 64 : 100
                    )
                )
                .frame(width: compact ? 154 : 236, height: compact ? 30 : 44)
                .blur(radius: compact ? 5 : 8)

            RoundedRectangle(cornerRadius: 1)
                .fill(
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(reduceTransparency ? 0.04 : 0.22),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: compact ? 106 : 164, height: 1)
                .blur(radius: 0.4)
        }
        .offset(y: compact ? -26 : -35)
        .allowsHitTesting(false)
    }

    private func waterSurface(time: TimeInterval) -> some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height - (compact ? 47 : 58))
            let width = min(size.width * 0.86, compact ? 360 : 500)
            let surfaceHeight = compact ? 54.0 : 72.0

            // 不再铺一整块“玻璃圆盘”，只保留破碎反射和极弱水纹。
            for row in 0..<9 {
                let depth = Double(row) / 8
                let y = center.y - surfaceHeight * 0.34 + depth * surfaceHeight * 0.68
                let halfWidth = width * (0.12 + sin(depth * .pi) * 0.34)
                let drift = paused ? 0 : time * (0.26 + depth * 0.10)

                var line = Path()
                for step in 0...52 {
                    let p = Double(step) / 52
                    let x = center.x - halfWidth + 2 * halfWidth * p
                    let wave = sin(p * .pi * 4.2 + drift + Double(row) * 0.52) * (0.32 + depth * 0.74)
                    let broken = sin(p * .pi * 9 + Double(row)) > -0.72
                    guard broken else { continue }
                    if line.isEmpty {
                        line.move(to: CGPoint(x: x, y: y + wave))
                    } else {
                        line.addLine(to: CGPoint(x: x, y: y + wave))
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
        .frame(height: compact ? 78 : 104)
        .padding(.horizontal, 8)
        .offset(y: compact ? -4 : -4)
        .allowsHitTesting(false)
    }

    private func signatureMark(time: TimeInterval) -> some View {
        let opacity = reduceTransparency ? 0.06 : 0.12
        let drift = paused ? 0 : sin(time * 0.34 + 1.2) * 2

        return Image(decorative: "ChangXiCharacter")
            .resizable()
            .scaledToFit()
            .frame(height: compact ? 42 : 58)
            .opacity(opacity)
            .saturation(0.18)
            .blur(radius: 0.15)
            .offset(x: compact ? moonSize * 0.58 : moonSize * 0.66, y: (compact ? -48 : -68) + drift)
            .allowsHitTesting(false)
    }

    private func normalizedSine(_ value: Double) -> CGFloat {
        CGFloat((sin(value) + 1) / 2)
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
