import SwiftUI

struct HomeView: View {
    @Environment(AppStore.self) private var store
    @Environment(AssistantCoordinator.self) private var assistant
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var showChat = false

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        return hour < 11 ? "早上好" : hour < 18 ? "下午好" : "晚上好"
    }

    private var nextPlan: DailyPlan? {
        store.data.plans.first { !$0.completed }
    }

    var body: some View {
        ZStack {
            MoonBackground(illustrated: true)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    HomeHeader(name: store.data.name, greeting: greeting, hasUnreadMessage: !store.data.doctorMessageRead)
                        .entrance(index: 0, appeared: appeared, reduceMotion: reduceMotion)

                    moonPool
                        .entrance(index: 1, appeared: appeared, reduceMotion: reduceMotion)

                    talkButton
                        .entrance(index: 2, appeared: appeared, reduceMotion: reduceMotion)

                    ShiyangEntryCard()
                        .entrance(index: 3, appeared: appeared, reduceMotion: reduceMotion)

                    ConstitutionEntryCard()
                        .entrance(index: 4, appeared: appeared, reduceMotion: reduceMotion)

                    NavigationLink { RefinedMoonRhythmDetailView() } label: {
                        RefinedMoonPhaseCard()
                            .padding(16)
                            .cxInteractiveGlass(cornerRadius: 20)
                    }
                    .buttonStyle(.plain)
                    .entrance(index: 5, appeared: appeared, reduceMotion: reduceMotion)

                    SectionEyebrow(title: "今天", action: Date.now.formatted(.dateTime.locale(Locale(identifier: "zh_CN")).month().day().weekday(.abbreviated)))
                        .entrance(index: 6, appeared: appeared, reduceMotion: reduceMotion)

                    TodaySummaryCard(nextPlan: nextPlan)
                        .entrance(index: 7, appeared: appeared, reduceMotion: reduceMotion)

                    DemoLabel()
                        .frame(maxWidth: .infinity)
                        .entrance(index: 8, appeared: appeared, reduceMotion: reduceMotion)
                }
                .frame(maxWidth: 680)
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(CX.ink)
        .toolbarVisibility(.hidden, for: .navigationBar)
        .onAppear {
            appeared = true
        }
        .fullScreenCover(isPresented: $showChat) {
            NavigationStack { ChatView(initialPrompt: assistant.initialPrompt) }
        }
    }

    @ViewBuilder private var moonPool: some View {
        if store.data.doctorMessageRead {
            MoonPoolView(state: .idle)
        } else {
            NavigationLink { DoctorMessageView() } label: {
                MoonPoolView(state: .doctorReply)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("医生有了新回复，点按查看")
            .accessibilityIdentifier("doctor-reply-pool")
        }
    }

    private var talkButton: some View {
        Button {
            assistant.activateGeneral()
            showChat = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "waveform")
                    .font(.title2.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                VStack(alignment: .leading, spacing: 3) {
                    Text("和常曦说说")
                        .font(.headline)
                    Text("语音或文字都可以")
                        .font(.subheadline)
                        .opacity(0.82)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .buttonStyle(PrimaryButton())
        .accessibilityIdentifier("open-chat")
    }
}

private struct HomeHeader: View {
    let name: String
    let greeting: String
    let hasUnreadMessage: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "moonphase.waxing.crescent")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(CX.blue)
                    Text("常曦")
                        .font(.headline)
                        .foregroundStyle(CX.muted)
                }

                Text("\(greeting)，\(name)")
                    .font(.largeTitle.weight(.semibold))
                    .fontDesign(.serif)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)

                Text("今天也慢慢来。")
                    .font(.body)
                    .foregroundStyle(CX.muted)
            }

            Spacer(minLength: 8)

            NavigationLink {
                MessagesView()
            } label: {
                Image(systemName: hasUnreadMessage ? "envelope.badge.fill" : "envelope.fill")
                    .font(.title3.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(CX.blue)
                    .frame(width: 46, height: 46)
                    .contentTransition(.symbolEffect(.replace))
                    .cxInteractiveGlassCircle()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(hasUnreadMessage ? "消息中心，有新消息" : "消息中心")
        }
    }
}


private struct RefinedMoonPhaseCard: View {
    private let phase = LunarPhase.today

    var body: some View {
        HStack(spacing: 16) {
            RefinedMoonDisc(
                phase: normalizedPhase,
                size: 58,
                showsOrbit: false
            )
            .frame(width: 66, height: 66)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(phase.phaseName)
                        .font(.headline)

                    Text("今日月相")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(CX.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(CX.blue.opacity(0.08), in: Capsule())
                }

                Text("\(phase.dateLabel) · \(phase.rhythmLabel)")
                    .font(.subheadline)
                    .foregroundStyle(CX.muted)

                Text("月光只记录时间，不定义你的状态")
                    .font(.caption)
                    .foregroundStyle(CX.faint)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(CX.faint)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("今日月相，\(phase.phaseName)，\(phase.dateLabel)，\(phase.rhythmLabel)")
    }

    private var normalizedPhase: Double {
        min(max(Double(phase.lunarDay - 1) / 29.53, 0), 1)
    }
}

private struct RefinedMoonRhythmDetailView: View {
    private let phase = LunarPhase.today

    var body: some View {
        Page(illustrated: true) {
            VStack(spacing: 18) {
                RefinedMoonDisc(
                    phase: normalizedPhase,
                    size: 190,
                    showsOrbit: true
                )
                .frame(height: 230)

                VStack(spacing: 6) {
                    Text(phase.phaseName)
                        .font(.largeTitle.weight(.semibold))
                        .fontDesign(.serif)

                    Text("\(phase.dateLabel) · \(phase.rhythmLabel)")
                        .font(.body)
                        .foregroundStyle(CX.muted)
                }

                HStack(spacing: 10) {
                    MoonFactPill(icon: "calendar", text: "农历 \(phase.dateLabel)")
                    MoonFactPill(icon: phase.symbol, text: phase.rhythmLabel)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 12)

            Card {
                Text("月相节律")
                    .font(.title2.weight(.semibold))

                Text("常曦用月光的盈亏表达时间缓慢推进的过程。它是一种视觉节律，也是一种温柔的时间提示，不用于判断健康好坏。")
                    .lineSpacing(6)

                NavigationLink("查看今日计划") { PlanView() }
                    .buttonStyle(PrimaryButton())
            }
        }
        .navigationTitle("今日月相")
    }

    private var normalizedPhase: Double {
        min(max(Double(phase.lunarDay - 1) / 29.53, 0), 1)
    }
}

private struct MoonFactPill: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.medium))
            .foregroundStyle(CX.muted)
            .padding(.horizontal, 12)
            .frame(minHeight: 34)
            .background(CX.blue.opacity(0.055), in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(CX.blue.opacity(0.08), lineWidth: 0.5)
            }
    }
}

private struct RefinedMoonDisc: View {
    let phase: Double
    let size: CGFloat
    var showsOrbit = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    @State private var breathing = false
    @State private var orbitAngle = 0.0

    private var normalizedPhase: Double {
        let value = phase.truncatingRemainder(dividingBy: 1)
        return value < 0 ? value + 1 : value
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(reduceTransparency ? 0.03 : 0.30),
                            CX.moonlight.opacity(reduceTransparency ? 0.02 : 0.16),
                            CX.blue.opacity(reduceTransparency ? 0.01 : 0.05),
                            .clear
                        ],
                        center: .center,
                        startRadius: size * 0.10,
                        endRadius: size * 0.72
                    )
                )
                .frame(width: size * 1.44, height: size * 1.44)
                .blur(radius: size * 0.055)
                .scaleEffect(reduceMotion ? 1 : (breathing ? 1.045 : 0.98))
                .blendMode(.plusLighter)

            if showsOrbit {
                ZStack {
                    Circle()
                        .stroke(CX.moonlight.opacity(0.08), lineWidth: 0.7)

                    Circle()
                        .trim(from: 0.08, to: 0.72)
                        .stroke(
                            AngularGradient(
                                colors: [.clear, .white.opacity(0.70), CX.moonlight.opacity(0.30), .clear],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 1.05, lineCap: .round)
                        )
                        .rotationEffect(.degrees(orbitAngle))

                    Circle()
                        .fill(.white.opacity(0.72))
                        .frame(width: 3.2, height: 3.2)
                        .shadow(color: .white.opacity(0.65), radius: 4)
                        .offset(y: -size * 0.60)
                        .rotationEffect(.degrees(orbitAngle * 0.72 + 34))
                }
                .frame(width: size * 1.22, height: size * 1.22)
            }

            moonBody
                .scaleEffect(reduceMotion ? 1 : (breathing ? 1.018 : 0.992))
        }
        .frame(width: size * 1.46, height: size * 1.46)
        .onAppear {
            guard !reduceMotion else { return }

            withAnimation(.easeInOut(duration: 4.8).repeatForever(autoreverses: true)) {
                breathing = true
            }

            withAnimation(.linear(duration: 28).repeatForever(autoreverses: false)) {
                orbitAngle = 360
            }
        }
        .accessibilityHidden(true)
    }

    private var moonBody: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(.displayP3, red: 0.22, green: 0.29, blue: 0.40)
                                .opacity(colorScheme == .dark ? 0.95 : 0.84),
                            Color(.displayP3, red: 0.08, green: 0.12, blue: 0.20)
                                .opacity(0.98)
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: size * 0.72
                    )
                )

            RefinedMoonIllumination(phase: normalizedPhase)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.displayP3, red: 1.00, green: 0.995, blue: 0.965),
                            Color(.displayP3, red: 0.94, green: 0.96, blue: 0.995),
                            Color(.displayP3, red: 0.78, green: 0.85, blue: 0.94)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            MoonSurfaceTexture()
                .mask(RefinedMoonIllumination(phase: normalizedPhase))
                .blendMode(.multiply)
                .opacity(colorScheme == .dark ? 0.48 : 0.38)

            RefinedMoonIllumination(phase: normalizedPhase)
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.58), .white.opacity(0.08), .clear],
                        center: UnitPoint(x: 0.28, y: 0.22),
                        startRadius: 0,
                        endRadius: size * 0.78
                    )
                )
                .blendMode(.screen)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [.clear, Color.black.opacity(0.04), Color.black.opacity(0.18)],
                        center: .center,
                        startRadius: size * 0.28,
                        endRadius: size * 0.58
                    )
                )
                .blendMode(.multiply)

            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.86), .white.opacity(0.20), CX.moonlight.opacity(0.16), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: max(0.7, size * 0.006)
                )
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .shadow(color: .white.opacity(colorScheme == .dark ? 0.18 : 0.30), radius: size * 0.07, y: -size * 0.01)
        .shadow(color: CX.moonlight.opacity(0.24), radius: size * 0.14, y: size * 0.05)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.16), radius: size * 0.12, y: size * 0.10)
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

private struct RefinedMoonIllumination: Shape {
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

private struct TodaySummaryCard: View {
    @Environment(AppStore.self) private var store
    let nextPlan: DailyPlan?

    var body: some View {
        Card {
            if let nextPlan {
                NavigationLink {
                    PlanDetailView(planID: nextPlan.id)
                } label: {
                    RowLabel(
                        title: nextPlan.title,
                        subtitle: "\(nextPlan.time) · 下一项安排",
                        icon: nextPlan.icon
                    )
                }
            } else {
                NavigationLink {
                    PlanView()
                } label: {
                    RowLabel(
                        title: "今天的安排已完成",
                        subtitle: "给自己留一点轻松的时间",
                        icon: "checkmark.circle.fill",
                        tint: CX.teal
                    )
                }
            }

            Divider().overlay(CX.separator.opacity(0.22))

            NavigationLink {
                MetricDetailView(kind: .pressure)
            } label: {
                RowLabel(
                    title: store.latest(.pressure)?.display ?? "还没有记录",
                    subtitle: "最近一次血压 · mmHg",
                    icon: "heart.fill",
                    tint: CX.coral
                )
            }

            Divider().overlay(CX.separator.opacity(0.22))

            NavigationLink {
                DoctorMessageView()
            } label: {
                RowLabel(
                    title: "蒋医生",
                    subtitle: store.data.doctorMessageRead ? "查看上次回复" : "有一条新回复",
                    icon: "stethoscope",
                    tint: CX.teal
                )
            }
        }
        .buttonStyle(.plain)
    }
}

private extension View {
    func entrance(index: Int, appeared: Bool, reduceMotion: Bool) -> some View {
        opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 12)
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.18)
                    : .spring(duration: 0.50, bounce: 0.08).delay(Double(index) * 0.045),
                value: appeared
            )
    }
}
