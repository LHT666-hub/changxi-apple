import SwiftUI

enum MoonPoolState: String, CaseIterable, Identifiable {
    case idle, listening, thinking, responding, success, notification, doctorReply, quietAlert
    var id: Self { self }
    var label: String {
        switch self {
        case .idle: "我在这里"
        case .listening: "我在听"
        case .thinking: "让我想一想"
        case .responding: "慢慢说，我陪着你"
        case .success: "已记下这一刻"
        case .notification: "有一件事想提醒你"
        case .doctorReply: "医生有了新回复"
        case .quietAlert: "这件事需要认真处理"
        }
    }
}

/// Moon phases encode process only. Health interpretation belongs to data views.
struct MoonPoolView: View {
    var state: MoonPoolState = .idle
    var amplitude: Double = 0
    var character = true
    var compact = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var entered = Date.now
    private var still: Bool { reduceMotion || state == .quietAlert || scenePhase != .active }
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: still)) { timeline in
            let t = still ? 0.0 : timeline.date.timeIntervalSince(entered)
            ZStack(alignment: .bottom) {
                Canvas { context, size in drawPool(context: &context, size: size, time: t) }
                    .frame(height: compact ? 85 : 150)
                if character {
                    Image("ChangXiCharacter").resizable().scaledToFit()
                        .frame(height: compact ? 135 : 235)
                        .rotationEffect(.degrees(state == .listening ? 3 : state == .thinking ? 5 : 0), anchor: .bottom)
                        .offset(x: compact ? 0 : -18, y: (compact ? -28 : -45) + (still ? 0 : sin(t * 1.25) * 2.2))
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.7), value: state)
                        .accessibilityHidden(true)
                }
                if state == .thinking {
                    Image(systemName: ["moonphase.waxing.crescent", "moonphase.first.quarter", "moonphase.waxing.gibbous"][Int(t / 1.2) % 3])
                        .font(.title2).foregroundStyle(CX.blue).offset(y: compact ? -60 : -88).accessibilityHidden(true)
                }
                Text(state.label).font(compact ? .subheadline : .headline).tracking(3).padding(.bottom, compact ? 15 : 30)
                    .foregroundStyle(CX.ink)
            }
        }
        .frame(height: compact ? 170 : 285)
        .accessibilityElement(children: .ignore).accessibilityLabel("月池，\(state.label)")
        .onChange(of: state) { _, _ in entered = .now }
    }
    private func drawPool(context: inout GraphicsContext, size: CGSize, time t: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height * 0.52)
        let width = size.width * 0.96
        let height = size.height * 0.78
        let base = CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
        let responseGlow = state == .responding ? 0.8 + min(t / 1.4, 1) * 0.2 : 0.8
        context.fill(Path(ellipseIn: base), with: .radialGradient(Gradient(colors: [.white.opacity(responseGlow), Color(red: 0.48, green: 0.73, blue: 0.94).opacity(0.45), .white.opacity(0.05)]), center: center, startRadius: 0, endRadius: width / 2))
        let speed = state == .listening ? 0.40 : state == .thinking ? 0.22 : 0.12
        for i in 0..<7 {
            var phase = (Double(i) / 7 + t * speed).truncatingRemainder(dividingBy: 1)
            if state == .thinking { phase = 1 - phase }
            let pulse = state == .listening ? 1 + min(max(amplitude, 0), 1) * 0.16 : 1
            let scale = (0.1 + phase * 0.9) * pulse
            let rect = CGRect(x: center.x - width * scale / 2, y: center.y - height * scale / 2, width: width * scale, height: height * scale)
            let opacity = still ? 0.28 : (1 - phase) * (state == .listening ? 0.9 : 0.65)
            var glow = context
            glow.addFilter(.shadow(color: .white.opacity(opacity), radius: 4))
            glow.stroke(Path(ellipseIn: rect), with: .linearGradient(Gradient(colors: [.white.opacity(opacity), Color(red: 0.64, green: 0.85, blue: 1).opacity(opacity * 0.8), .white.opacity(opacity)]), startPoint: CGPoint(x: rect.minX, y: rect.minY), endPoint: CGPoint(x: rect.maxX, y: rect.maxY)), lineWidth: state == .listening ? 1.5 + amplitude * 1.8 : 1.4)
        }
        if state == .success {
            let p = min(t / 2.4, 1)
            let rect = base.insetBy(dx: (1 - p) * width / 2, dy: (1 - p) * height / 2)
            context.stroke(Path(ellipseIn: rect), with: .color(CX.teal.opacity(1 - p)), lineWidth: 3)
        }
        if state == .notification || state == .doctorReply {
            let count = state == .doctorReply ? 2 : 1
            for i in 0..<count {
                let point = CGPoint(x: center.x + (i == 0 ? -45 : 45), y: center.y - 12 + sin(t) * 2)
                let rect = CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)
                context.fill(Path(ellipseIn: rect), with: .color(Color(red: 1, green: 0.88, blue: 0.58)))
            }
        }
    }
}

struct RhythmView: View {
    var completed: Int
    var total: Int
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("今日节律").font(.subheadline)
                Spacer()
                ForEach(0..<max(total, 1), id: \.self) { index in
                    Image(systemName: index < completed ? "moonphase.full.moon" : "moonphase.first.quarter").foregroundStyle(index < completed ? CX.blue : CX.muted.opacity(0.4))
                }
                Spacer()
                Text("\(completed)/\(total)").font(.headline).monospacedDigit()
            }
            ProgressView(value: Double(completed), total: Double(max(total, 1))).tint(CX.blue)
        }.accessibilityElement(children: .ignore).accessibilityLabel("今日计划，已完成\(completed)项，共\(total)项")
    }
}
