import SwiftUI

struct HomeView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showChat = false
    private var greeting: String { let hour = Calendar.current.component(.hour, from: .now); return hour < 11 ? "早上好" : hour < 18 ? "下午好" : "晚上好" }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("常 曦").font(.system(.title2, design: .serif, weight: .semibold))
                    Text("C H A N G X I").font(.system(size: 8, weight: .medium)).tracking(2).accessibilityHidden(true)
                    Text("\(greeting)，今天还好吗？").font(.system(.title, design: .serif, weight: .medium)).padding(.top, 8)
                    Text("有月光陪伴的日子，也是更健康的日子。").font(.subheadline).foregroundStyle(CX.muted).fixedSize(horizontal: false, vertical: true)
                }
                MoonPoolView(state: .idle, compact: true)
                LazyVGrid(columns: typeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    if let plan = store.data.plans.first(where: { !$0.completed }) {
                        NavigationLink { PlanDetailView(planID: plan.id) } label: { HomeQuickCard(title: plan.time, subtitle: plan.title, icon: plan.icon, tint: CX.blue) }
                    } else {
                        NavigationLink { PlanView() } label: { HomeQuickCard(title: "已完成", subtitle: "今日计划", icon: "checkmark.circle.fill", tint: CX.teal) }
                    }
                    NavigationLink { MetricDetailView(kind: .pressure) } label: { HomeQuickCard(title: store.latest(.pressure)?.display ?? "—", subtitle: "血压记录", icon: "heart.fill", tint: CX.coral) }
                    NavigationLink { DoctorMessageView() } label: { HomeQuickCard(title: "蒋医生", subtitle: store.data.doctorMessageRead ? "查看回复" : "新回复", icon: "stethoscope", tint: CX.teal) }
                }.buttonStyle(.plain)
                Button { showChat = true } label: {
                    HStack(spacing: 14) { Image(systemName: "mic.fill").font(.title2); VStack(alignment: .leading, spacing: 4) { Text("告诉常曦").font(.title3.bold()); Text("说话，或输入你的问题").font(.subheadline).opacity(0.9) }; Spacer(); Image(systemName: "chevron.right") }.padding(.vertical, 8).padding(.horizontal, 6)
                }.buttonStyle(PrimaryButton()).accessibilityIdentifier("open-chat")
                NavigationLink { PlanView() } label: {
                    RhythmView(completed: store.completed, total: store.data.plans.count).padding(14).background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 22))
                }.buttonStyle(.plain)
                DemoLabel()
            }.frame(maxWidth: 760).padding(.horizontal, 20).padding(.vertical, 14).frame(maxWidth: .infinity)
        }.background { MoonBackground(illustrated: true) }.foregroundStyle(CX.ink)
        .navigationTitle("首页").navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(CX.mist.opacity(0.95), for: .navigationBar).toolbarBackground(.visible, for: .navigationBar)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { NavigationLink { MessagesView() } label: { Image(systemName: store.data.doctorMessageRead ? "envelope" : "envelope.badge").frame(width: 44, height: 44) }.accessibilityLabel("消息中心") } }
        .fullScreenCover(isPresented: $showChat) { NavigationStack { ChatView() } }
    }
}

private struct HomeQuickCard: View {
    var title: String
    var subtitle: String
    var icon: String
    var tint: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).font(.title3).foregroundStyle(tint)
            Text(title).font(.headline).monospacedDigit().minimumScaleFactor(0.9)
            Text(subtitle).font(.subheadline).foregroundStyle(CX.muted)
        }.frame(maxWidth: .infinity, minHeight: 82, alignment: .leading).padding(12)
        .background(.white.opacity(0.93), in: RoundedRectangle(cornerRadius: 22))
        .overlay { RoundedRectangle(cornerRadius: 22).stroke(.white, lineWidth: 1) }
        .accessibilityElement(children: .combine)
    }
}
