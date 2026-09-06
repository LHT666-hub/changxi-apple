import SwiftUI

struct HomeView: View {
    @Environment(AppStore.self) private var store
    @State private var showChat = false
    private var greeting: String { let hour = Calendar.current.component(.hour, from: .now); return hour < 11 ? "早上好" : hour < 18 ? "下午好" : "晚上好" }
    var body: some View {
        Page(illustrated: true) {
            VStack(alignment: .leading, spacing: 10) {
                Text("常 曦").font(.system(.title, design: .serif, weight: .semibold))
                Text("C H A N G X I").font(.caption2).tracking(3)
                Text("\(greeting)，\n今天还好吗？").font(.system(.largeTitle, design: .serif, weight: .medium)).padding(.top, 20)
                Text("有月光陪伴的日子，\n也是更健康的日子。").foregroundStyle(CX.muted).lineSpacing(5)
            }
            MoonPoolView(state: store.data.doctorMessageRead ? .idle : .doctorReply)
            Card {
                if let plan = store.data.plans.first(where: { !$0.completed }) {
                    NavigationLink { PlanDetailView(planID: plan.id) } label: { RowLabel(title: plan.title, subtitle: "今天 \(plan.time) · 待完成", icon: plan.icon) }
                    Divider()
                }
                NavigationLink { MetricDetailView(kind: .pressure) } label: { RowLabel(title: "\(store.latest(.pressure)?.display ?? "—") mmHg", subtitle: "最近一次血压记录", icon: "heart.fill", tint: CX.coral) }
                if !store.data.doctorMessageRead {
                    Divider()
                    NavigationLink { DoctorMessageView() } label: { RowLabel(title: "蒋医生回复了你", subtitle: "家庭医生 · 示例消息", icon: "stethoscope", tint: CX.teal) }
                }
            }.buttonStyle(.plain)
            Button { showChat = true } label: {
                HStack(spacing: 16) { Image(systemName: "mic.fill").font(.title); VStack(alignment: .leading, spacing: 5) { Text("告诉常曦").font(.title2.bold()); Text("说话，或输入你的问题").font(.subheadline).opacity(0.85) }; Spacer(); Image(systemName: "chevron.right") }.padding(12)
            }.buttonStyle(PrimaryButton()).accessibilityIdentifier("open-chat")
            NavigationLink { PlanView() } label: { Card { RhythmView(completed: store.completed, total: store.data.plans.count) } }.buttonStyle(.plain)
            DemoLabel()
        }.navigationTitle("首页")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { NavigationLink { MessagesView() } label: { Image(systemName: store.data.doctorMessageRead ? "envelope" : "envelope.badge").frame(width: 44, height: 44) }.accessibilityLabel("消息中心") } }
        .fullScreenCover(isPresented: $showChat) { NavigationStack { ChatView() } }
    }
}
