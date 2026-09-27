import SwiftUI

struct PlanView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Page(illustrated: true) {
            VStack(alignment: .leading, spacing: CXSpacing.xs) {
                Text("今日计划")
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.actionPrimary)
                    .tracking(0.6)

                Text(store.completed == store.data.plans.count ? "今天已经完成了" : "把今天的事一件件做完")
                    .font(CXTypography.display)

                Text(
                    store.completed == store.data.plans.count
                        ? "今天的计划都完成了，可以把节奏慢下来。"
                        : "还剩 \(store.data.plans.count - store.completed) 件事，不需要一次做完。"
                )
                .font(CXTypography.body)
                .foregroundStyle(CX.muted)
                .lineSpacing(5)
            }

            VStack(alignment: .leading, spacing: CXSpacing.md) {
                RhythmView(completed: store.completed, total: store.data.plans.count)
            }
            .padding(CXSpacing.lg)
            .cxContentSurface(cornerRadius: CXRadius.lg)

            SectionEyebrow(title: "今天")
            VStack(spacing: CXSpacing.sm) {
                ForEach(store.data.plans) { plan in
                    NavigationLink { PlanDetailView(planID: plan.id) } label: {
                        HStack(spacing: CXSpacing.md) {
                            Image(systemName: plan.completed ? "checkmark.circle.fill" : plan.icon)
                                .font(.title3.weight(.medium))
                                .foregroundStyle(plan.completed ? CX.statusPositive : CX.actionPrimary)
                                .frame(width: 44, height: 44)
                                .background(
                                    (plan.completed ? CX.statusPositive : CX.actionPrimary).opacity(0.08),
                                    in: Circle()
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(plan.title)
                                    .font(CXTypography.section)
                                    .foregroundStyle(CX.ink)
                                Text("\(plan.time) · \(plan.completed ? "已完成" : "待完成")")
                                    .font(CXTypography.supporting)
                                    .foregroundStyle(plan.completed ? CX.statusPositive : CX.muted)
                            }

                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(CX.faint)
                        }
                        .padding(CXSpacing.md)
                        .cxContentSurface(cornerRadius: CXRadius.md)
                    }
                    .buttonStyle(QuietPressButton())
                }
            }

            SectionEyebrow(title: "提醒")
            NavigationLink { NotificationSettingsView() } label: {
                HStack(spacing: CXSpacing.md) {
                    Image(systemName: "bell")
                        .foregroundStyle(CX.statusWarning)
                        .frame(width: 42, height: 42)
                        .background(CX.statusWarning.opacity(0.08), in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text("调整提醒")
                            .font(CXTypography.section)
                        Text("选择适合自己的提醒节奏")
                            .font(CXTypography.supporting)
                            .foregroundStyle(CX.muted)
                    }

                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(CX.faint)
                }
                .padding(CXSpacing.md)
                .cxContentSurface(cornerRadius: CXRadius.md)
            }
            .buttonStyle(QuietPressButton())

            BrandFooter()
        }
        .navigationTitle("今日计划")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PlanDetailView: View {
    let planID: UUID
    @Environment(AppStore.self) private var store
    @Environment(AuthSession.self) private var auth
    @State private var note = ""
    @State private var showRecord = false
    @State private var showUndo = false
    private var plan: DailyPlan? { store.data.plans.first { $0.id == planID } }
    var body: some View {
        Page {
            if let plan {
                MoonPoolView(state: plan.completed ? .success : .idle, character: true, compact: true)
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
        .assistantFormContext(title: "\(plan?.title ?? "计划")备注", draft: note) { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }
            note = trimmed
            return true
        }
    }
    private func complete() {
        store.togglePlan(planID)
        MoonHaptics.shared.play(success: true, enabled: store.data.haptics)
        archiveIfCompleted()
    }

    /// Task #25：计划完成后，尽力把它归档到云端 health-records（record_type = daily_plan）。
    /// 离线不发请求；归档失败静默，绝不影响本地计划状态。
    private func archiveIfCompleted() {
        guard AppConfiguration.useRemoteAPI, let plan, plan.completed else { return }
        let pid = PatientContext.effectiveID(auth)
        let title = plan.title
        let time = plan.time
        let detail = plan.detail
        Task { @MainActor in
            await HealthSyncService.shared.archive(
                recordType: "daily_plan",
                title: title,
                content: ["time": .string(time), "detail": .string(detail), "completed": .bool(true)],
                patientID: pid
            )
        }
    }
}
