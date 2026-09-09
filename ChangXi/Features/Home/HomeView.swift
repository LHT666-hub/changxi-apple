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

                    NavigationLink { MoonRhythmDetailView() } label: {
                        MoonPhaseCard()
                            .padding(16)
                            .cxInteractiveGlass(cornerRadius: 20)
                    }
                    .buttonStyle(.plain)
                    .entrance(index: 3, appeared: appeared, reduceMotion: reduceMotion)

                    SectionEyebrow(title: "今天", action: Date.now.formatted(.dateTime.locale(Locale(identifier: "zh_CN")).month().day().weekday(.abbreviated)))
                        .entrance(index: 4, appeared: appeared, reduceMotion: reduceMotion)

                    TodaySummaryCard(nextPlan: nextPlan)
                        .entrance(index: 5, appeared: appeared, reduceMotion: reduceMotion)

                    DemoLabel()
                        .frame(maxWidth: .infinity)
                        .entrance(index: 6, appeared: appeared, reduceMotion: reduceMotion)
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
