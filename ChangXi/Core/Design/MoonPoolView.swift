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
        reduceMotion || state == .quietAlert || scenePhase != .active
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: paused)) { timeline in
            let time = paused ? 0 : timeline.date.timeIntervalSince(entered)

            ZStack(alignment: .bottom) {
                ambientGlow(time: time)
                pool(time: time)

                if character {
                    characterView(time: time)
                }

                if state == .notification || state == .doctorReply {
                    notificationLights(time: time)
                }

                MoonStatusPill(state: state, reduceTransparency: reduceTransparency)
                    .padding(.bottom, compact ? 4 : 12)
            }
        }
        .frame(height: compact ? 188 : 292)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("月池，\(state.label)")
        .onChange(of: state) {
            entered = .now
        }
    }

    private func ambientGlow(time: TimeInterval) -> some View {
        let pulse = paused ? 1 : 1 + sin(time * 0.7) * 0.025
        return Circle()
            .fill(
                RadialGradient(
                    colors: [state.accent.opacity(0.22), state.accent.opacity(0.06), .clear],
                    center: .center,
                    startRadius: 2,
                    endRadius: compact ? 116 : 178
                )
            )
            .scaleEffect(pulse)
            .frame(width: compact ? 250 : 360, height: compact ? 170 : 270)
            .offset(y: compact ? 12 : 18)
            .allowsHitTesting(false)
    }

    private func pool(time: TimeInterval) -> some View {
        Canvas { context, size in
            drawPool(context: &context, size: size, time: time)
        }
        .frame(maxWidth: 520)
        .frame(height: compact ? 92 : 142)
        .padding(.horizontal, compact ? 6 : 12)
        .offset(y: compact ? -4 : -8)
        .allowsHitTesting(false)
    }

    private func characterView(time: TimeInterval) -> some View {
        let restingOffset = paused ? 0 : sin(time * 0.72) * 1.5
        let stateRotation: Double = state == .listening ? 1.4 : state == .thinking ? 2.2 : 0

        return Image(decorative: "ChangXiCharacter")
            .resizable()
            .scaledToFit()
            .frame(height: compact ? 142 : 226)
            .rotationEffect(.degrees(stateRotation), anchor: .bottom)
            .offset(x: compact ? -4 : -14, y: (compact ? -34 : -55) + restingOffset)
            .shadow(color: state.accent.opacity(0.14), radius: 18, y: 10)
            .animation(reduceMotion ? nil : .spring(duration: 0.42, bounce: 0.12), value: state)
            .allowsHitTesting(false)
    }

    private func notificationLights(time: TimeInterval) -> some View {
        HStack(spacing: compact ? 54 : 84) {
            ForEach(0..<(state == .doctorReply ? 2 : 1), id: \.self) { index in
                Circle()
                    .fill(CX.gold)
                    .frame(width: 8, height: 8)
                    .shadow(color: CX.gold.opacity(0.8), radius: 8)
                    .offset(y: paused ? 0 : sin(time * 1.2 + Double(index)) * 3)
            }
        }
        .offset(y: compact ? -55 : -88)
        .allowsHitTesting(false)
    }

    private func drawPool(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let center = CGPoint(x: size.width / 2, y: size.height * 0.52)
        let poolWidth = size.width * 0.94
        let poolHeight = size.height * 0.70
        let base = CGRect(
            x: center.x - poolWidth / 2,
            y: center.y - poolHeight / 2,
            width: poolWidth,
            height: poolHeight
        )

        var baseContext = context
        baseContext.addFilter(.shadow(color: state.accent.opacity(0.20), radius: 18, x: 0, y: 10))
        baseContext.fill(
            Path(ellipseIn: base),
            with: .radialGradient(
                Gradient(colors: [
                    .white.opacity(0.92),
                    CX.moonlight.opacity(state == .responding ? 0.58 : 0.36),
                    state.accent.opacity(0.10)
                ]),
                center: CGPoint(x: center.x, y: base.minY + base.height * 0.36),
                startRadius: 0,
                endRadius: poolWidth * 0.56
            )
        )

        context.stroke(
            Path(ellipseIn: base),
            with: .linearGradient(
                Gradient(colors: [.white.opacity(0.88), state.accent.opacity(0.34), .white.opacity(0.26)]),
                startPoint: CGPoint(x: base.minX, y: base.minY),
                endPoint: CGPoint(x: base.maxX, y: base.maxY)
            ),
            lineWidth: 0.8
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
                with: .color(.white.opacity(opacity)),
                lineWidth: state == .listening ? 1.2 + amplitude * 1.6 : 1
            )
        }

        if state == .success {
            let progress = min(time / 1.6, 1)
            let ring = base.insetBy(dx: (1 - progress) * poolWidth / 2, dy: (1 - progress) * poolHeight / 2)
            context.stroke(Path(ellipseIn: ring), with: .color(CX.teal.opacity(1 - progress)), lineWidth: 2.5)
        }
    }
}

private struct MoonStatusPill: View {
    let state: MoonPoolState
    let reduceTransparency: Bool

    var body: some View {
        Label(state.label, systemImage: state.symbol)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(CX.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .cxGlassCapsule(reduceTransparency: reduceTransparency)
            .contentTransition(.symbolEffect(.replace))
            .symbolEffect(.bounce, value: state)
            .animation(.snappy(duration: 0.28), value: state)
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
                Text("今日节律")
                    .font(.headline)
                Spacer()
                Text("\(completed)/\(total)")
                    .font(.headline)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(completed)))
            }

            ProgressView(value: progress)
                .tint(CX.blue)
                .animation(.spring(duration: 0.42, bounce: 0.12), value: completed)

            Text(completed == total && total > 0 ? "今天的安排都完成了" : "不必追赶，按自己的节奏来")
                .font(.subheadline)
                .foregroundStyle(CX.muted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("今日计划，已完成\(completed)项，共\(total)项")
    }
}
