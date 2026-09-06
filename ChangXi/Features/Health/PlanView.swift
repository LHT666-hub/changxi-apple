import SwiftUI

struct PlanView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        Page {
            Card { RhythmView(completed: store.completed, total: store.data.plans.count) }
            Text(store.completed == store.data.plans.count ? "今天的计划都完成了，早点休息。" : "今天还剩 \(store.data.plans.count - store.completed) 件事，我陪你完成。").font(.title2.bold())
            Card {
                ForEach(store.data.plans) { plan in
                    NavigationLink { PlanDetailView(planID: plan.id) } label: {
                        RowLabel(title: plan.title, subtitle: "\(plan.time) · \(plan.completed ? "已完成" : "待完成")", icon: plan.completed ? "checkmark.circle.fill" : plan.icon, tint: plan.completed ? CX.teal : CX.blue)
                    }.buttonStyle(.plain)
                    if plan.id != store.data.plans.last?.id { Divider() }
                }
            }
            NavigationLink { NotificationSettingsView() } label: { Card { RowLabel(title: "调整提醒", subtitle: "选择适合自己的节奏", icon: "bell") } }.buttonStyle(.plain)
            BrandFooter()
        }.navigationTitle("今日计划")
    }
}

struct PlanDetailView: View {
    let planID: UUID
    @Environment(AppStore.self) private var store
    @State private var note = ""
    @State private var showRecord = false
    @State private var showUndo = false
    private var plan: DailyPlan? { store.data.plans.first { $0.id == planID } }
    var body: some View {
        Page {
            if let plan {
                MoonPoolView(state: plan.completed ? .success : .idle, character: false, compact: true)
                Card {
                    RowLabel(title: plan.title, subtitle: "今天 \(plan.time)", icon: plan.icon, chevron: false)
                    Text(plan.detail).foregroundStyle(CX.muted)
                    if let date = plan.completedAt { Text("完成于 \(date.formatted(date: .omitted, time: .shortened))").foregroundStyle(CX.teal) }
                    if plan.title == "睡前记录" { TextField("今天有什么想记下的？", text: $note, axis: .vertical).lineLimit(3...8).padding().background(CX.mist, in: RoundedRectangle(cornerRadius: 16)) }
                    Button(plan.completed ? "撤销完成" : plan.title == "测血压" ? "记录血压" : "标记完成") {
                        if plan.completed { showUndo = true }
                        else if plan.title == "测血压" { showRecord = true }
                        else { if plan.title == "睡前记录" { store.data.journal = note }; complete() }
                    }.buttonStyle(PrimaryButton())
                    if plan.title == "晚间用药" { NavigationLink("查看用药计划与漏服说明") { MedicationView() } }
                }
            }
        }.navigationTitle(plan?.title ?? "计划")
        .onAppear { note = store.data.journal }
        .sheet(isPresented: $showRecord) { NavigationStack { RecordReadingView(kind: .pressure, onSave: { if plan?.completed == false { complete() } }) } }
        .confirmationDialog("撤销这项计划的完成记录？", isPresented: $showUndo, titleVisibility: .visible) { Button("撤销完成", role: .destructive) { store.togglePlan(planID) } }
    }
    private func complete() { store.togglePlan(planID); MoonHaptics.shared.play(success: true, enabled: store.data.haptics) }
}
