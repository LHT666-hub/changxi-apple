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
                LazyVStack(alignment: .leading, spacing: CXSpacing.xl) {
                    HomeHeader(
                        name: store.data.name,
                        greeting: greeting,
                        hasUnreadMessage: !store.data.doctorMessageRead
                    )
                    .entrance(index: 0, appeared: appeared, reduceMotion: reduceMotion)

                    moonPool
                        .entrance(index: 1, appeared: appeared, reduceMotion: reduceMotion)

                    talkButton
                        .entrance(index: 2, appeared: appeared, reduceMotion: reduceMotion)

                    SectionEyebrow(title: "常用")
                        .entrance(index: 3, appeared: appeared, reduceMotion: reduceMotion)

                    HomeQuickActions()
                        .entrance(index: 4, appeared: appeared, reduceMotion: reduceMotion)

                    SectionEyebrow(
                        title: "今天",
                        action: Date.now.formatted(
                            .dateTime
                                .locale(Locale(identifier: "zh_CN"))
                                .month()
                                .day()
                                .weekday(.abbreviated)
                        )
                    )
                    .entrance(index: 5, appeared: appeared, reduceMotion: reduceMotion)

                    TodaySummaryCard(nextPlan: nextPlan)
                        .entrance(index: 6, appeared: appeared, reduceMotion: reduceMotion)

                    NavigationLink { RefinedMoonRhythmDetailView() } label: {
                        RefinedMoonPhaseCard()
                            .padding(CXSpacing.md)
                            .background(CX.surface, in: .rect(cornerRadius: CXRadius.lg, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: CXRadius.lg, style: .continuous)
                                    .strokeBorder(CX.separator.opacity(0.10), lineWidth: 0.5)
                            }
                    }
                    .buttonStyle(.plain)
                    .entrance(index: 7, appeared: appeared, reduceMotion: reduceMotion)

                    SectionEyebrow(title: "更多照护")
                        .entrance(index: 8, appeared: appeared, reduceMotion: reduceMotion)

                    ShiyangEntryCard()
                        .entrance(index: 9, appeared: appeared, reduceMotion: reduceMotion)

                    ConstitutionEntryCard()
                        .entrance(index: 10, appeared: appeared, reduceMotion: reduceMotion)

                    DemoLabel()
                        .frame(maxWidth: .infinity)
                        .entrance(index: 11, appeared: appeared, reduceMotion: reduceMotion)
                }
                .frame(maxWidth: 700)
                .padding(.horizontal, CXSpacing.page)
                .padding(.top, CXSpacing.md)
                .padding(.bottom, CXSpacing.section)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
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

    @ViewBuilder
    private var moonPool: some View {
        if store.data.doctorMessageRead {
            MoonPoolView(state: .idle, character: false)
        } else {
            NavigationLink { DoctorMessageView() } label: {
                MoonPoolView(state: .doctorReply, character: false)
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
                    .font(CXTypography.title)
                    .symbolRenderingMode(.hierarchical)

                VStack(alignment: .leading, spacing: 3) {
                    Text("和常曦说说")
                        .font(CXTypography.section)
                    Text("语音或文字都可以")
                        .font(CXTypography.supporting)
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
                HStack(spacing: CXSpacing.xs) {
                    LunarGlyph(size: 22, tint: CX.actionPrimary)

                    Text("常曦")
                        .font(CXTypography.section)
                        .foregroundStyle(CX.muted)
                }

                Text("\(greeting)，\(name)")
                    .font(CXTypography.display)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)

                Text("照顾自己，不用一次做很多。")
                    .font(CXTypography.body)
                    .foregroundStyle(CX.muted)
            }

            Spacer(minLength: 8)

            NavigationLink {
                MessagesView()
            } label: {
                Image(systemName: hasUnreadMessage ? "envelope.badge.fill" : "envelope.fill")
                    .font(.title3.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(CX.actionPrimary)
                    .frame(width: 46, height: 46)
                    .contentTransition(.symbolEffect(.replace))
                    .cxInteractiveGlassCircle()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(hasUnreadMessage ? "消息中心，有新消息" : "消息中心")
        }
    }
}

private struct HomeQuickActions: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        LazyVGrid(
            columns: CXLayout.adaptiveColumns(
                minimum: dynamicTypeSize.isAccessibilitySize ? 230 : 150,
                spacing: 12,
                dynamicTypeSize: dynamicTypeSize
            ),
            spacing: 12
        ) {
            NavigationLink {
                MetricDetailView(kind: .pressure)
            } label: {
                HomeQuickActionTile(
                    icon: "heart.text.square",
                    title: "记健康",
                    subtitle: "血压与日常记录",
                    tint: CX.statusCritical
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                ReportImportView()
            } label: {
                HomeQuickActionTile(
                    icon: "doc.viewfinder",
                    title: "导入报告",
                    subtitle: "拍照或选择文件",
                    tint: CX.actionPrimary
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                DoctorMessageView()
            } label: {
                HomeQuickActionTile(
                    icon: "stethoscope",
                    title: "医生消息",
                    subtitle: "查看回复与建议",
                    tint: CX.statusPositive
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                PlanView()
            } label: {
                HomeQuickActionTile(
                    icon: "calendar.badge.checkmark",
                    title: "今日计划",
                    subtitle: "用药与日常安排",
                    tint: CX.statusWarning
                )
            }
            .buttonStyle(.plain)
        }
    }
}

private struct HomeQuickActionTile: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: icon)
                    .font(.title3.weight(.medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tint)
                    .frame(width: 42, height: 42)
                    .background(tint.opacity(0.07), in: Circle())

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CX.faint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(CXTypography.micro)
                    .foregroundStyle(CX.muted)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
        .padding(CXSpacing.md)
        .background(CX.surface, in: .rect(cornerRadius: CXRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CXRadius.md, style: .continuous)
                .strokeBorder(CX.separator.opacity(0.10), lineWidth: 0.5)
        }
        .contentShape(Rectangle())
    }
}

private struct RefinedMoonPhaseCard: View {
    private let phase = LunarPhase.today

    var body: some View {
        HStack(spacing: 16) {
            HomeMoonBadge(phase: normalizedPhase)
                .frame(width: 68, height: 68)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(phase.phaseName)
                        .font(.headline)

                    Text("今日月相")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(CX.actionPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(CX.actionPrimary.opacity(0.08), in: Capsule())
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

private struct HomeMoonBadge: View {
    let phase: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(0.32),
                            CX.brandMoonlight.opacity(0.14),
                            .clear
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 40
                    )
                )
                .scaleEffect(reduceMotion ? 1 : (breathing ? 1.06 : 0.94))
                .blur(radius: 4)

            MoonDisc(phase: phase)
                .frame(width: 52, height: 52)
                .shadow(color: CX.brandMoonlight.opacity(0.18), radius: 9, y: 4)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 4.6).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
        .accessibilityHidden(true)
    }
}

private struct RefinedMoonRhythmDetailView: View {
    private let phase = LunarPhase.today

    var body: some View {
        Page(illustrated: true) {
            MoonDetailHero(phase: normalizedPhase)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

            VStack(spacing: 6) {
                Text(phase.phaseName)
                    .font(CXTypography.display)

                Text("\(phase.dateLabel) · \(phase.rhythmLabel)")
                    .font(.body)
                    .foregroundStyle(CX.muted)
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 10) {
                MoonFactPill(icon: "calendar", text: "农历 \(phase.dateLabel)")
                MoonFactPill(icon: phase.symbol, text: phase.rhythmLabel)
            }
            .frame(maxWidth: .infinity)

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

private struct MoonDetailHero: View {
    let phase: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false
    @State private var rotation = -22.0

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(0.34),
                            CX.brandMoonlight.opacity(0.15),
                            .clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 132
                    )
                )
                .frame(width: 270, height: 270)
                .blur(radius: 10)
                .scaleEffect(reduceMotion ? 1 : (breathing ? 1.04 : 0.97))

            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.60),
                            CX.brandMoonlight.opacity(0.24),
                            .clear
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 1, lineCap: .round)
                )
                .frame(width: 232, height: 232)
                .rotationEffect(.degrees(rotation))

            MoonDisc(phase: phase)
                .frame(width: 180, height: 180)
                .shadow(color: .white.opacity(0.24), radius: 14, y: -2)
                .shadow(color: CX.brandMoonlight.opacity(0.22), radius: 24, y: 10)
        }
        .frame(height: 250)
        .onAppear {
            guard !reduceMotion else { return }

            withAnimation(.easeInOut(duration: 4.8).repeatForever(autoreverses: true)) {
                breathing = true
            }

            withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
                rotation = 338
            }
        }
        .accessibilityHidden(true)
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
            .background(CX.actionPrimary.opacity(0.055), in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(CX.actionPrimary.opacity(0.08), lineWidth: 0.5)
            }
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
                        tint: CX.statusPositive
                    )
                }
            }

            Divider().overlay(CX.separator.opacity(0.18))

            NavigationLink {
                MetricDetailView(kind: .pressure)
            } label: {
                RowLabel(
                    title: store.latest(.pressure)?.display ?? "还没有记录",
                    subtitle: "最近一次血压 · mmHg",
                    icon: "heart.fill",
                    tint: CX.statusCritical
                )
            }

            Divider().overlay(CX.separator.opacity(0.18))

            NavigationLink {
                DoctorMessageView()
            } label: {
                RowLabel(
                    title: "蒋医生",
                    subtitle: store.data.doctorMessageRead ? "查看上次回复" : "有一条新回复",
                    icon: "stethoscope",
                    tint: CX.statusPositive
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
