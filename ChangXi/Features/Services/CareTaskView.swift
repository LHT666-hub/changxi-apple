import SwiftUI

/// 我的照护任务页（Task #25）。
///
/// 展示玄同会诊工作流（`task_generation` 节点）自动生成的照护任务，支持勾选完成
/// （`POST /api/tasks/{id}/complete`，写回 ServiceOutcome + Timeline）。
///
/// 入口挂在 ``ServicesView``（服务页），仅 `useRemoteAPI == true` 时显示；离线时本页不加载、不发请求，
/// 入口本身也不渲染，因此纯本地演示不受影响。
struct CareTaskView: View {
    @Environment(AuthSession.self) private var auth

    @State private var tasks: [CareTask] = []
    @State private var loading = false
    @State private var errorText: String?
    @State private var notesTask: CareTask?
    @State private var completeNotes = ""
    @State private var completing = false

    private var patientId: String { PatientContext.effectiveID(auth) }

    var body: some View {
        Page(illustrated: true) {
            VStack(alignment: .leading, spacing: CXSpacing.xs) {
                Text("照护任务")
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.statusPositive)
                    .tracking(0.6)

                Text("把需要跟进的事放在一处")
                    .font(CXTypography.display)

                Text("这些任务用于提醒下一步，不代替医生医嘱。")
                    .font(CXTypography.body)
                    .foregroundStyle(CX.muted)
                    .lineSpacing(5)
            }

            if loading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("正在整理照护任务")
                        .font(CXTypography.supporting)
                        .foregroundStyle(CX.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(CXSpacing.xl)
                .cxContentSurface(cornerRadius: CXRadius.lg)
            }

            if let errorText {
                VStack(alignment: .leading, spacing: CXSpacing.md) {
                    Label(errorText, systemImage: "exclamationmark.triangle.fill")
                        .font(CXTypography.supporting)
                        .foregroundStyle(CX.statusCritical)

                    Button("重新加载") {
                        Task { await load() }
                    }
                    .buttonStyle(PrimaryButton())
                }
                .padding(CXSpacing.lg)
                .background(
                    CX.statusCritical.opacity(0.05),
                    in: .rect(cornerRadius: CXRadius.lg, style: .continuous)
                )
            }

            if !loading && errorText == nil && tasks.isEmpty {
                CXEmptyState(
                    title: "暂时没有照护任务",
                    message: "需要跟进的事项会集中出现在这里。",
                    icon: "checklist",
                    tint: CX.statusPositive
                )
            }

            if !tasks.isEmpty {
                SectionEyebrow(title: "待跟进", action: "\(tasks.filter { !$0.isCompleted }.count) 项")
            }

            ForEach(tasks) { task in
                taskCard(task)
            }

            if !tasks.isEmpty {
                Text("完成任务只表示你已处理这一步；涉及诊疗决定时，仍应以医生意见为准。")
                    .font(CXTypography.meta)
                    .foregroundStyle(CX.muted)
                    .lineSpacing(4)
            }
        }
        .navigationTitle("我的照护任务")
        .task { await load() }
        .sheet(item: $notesTask) { task in completeSheet(task) }
    }

    // MARK: - 子视图

    private func taskCard(_ task: CareTask) -> some View {
        VStack(alignment: .leading, spacing: CXSpacing.md) {
            HStack(alignment: .top, spacing: CXSpacing.md) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? CX.teal : CX.muted.opacity(0.5))
                VStack(alignment: .leading, spacing: 6) {
                    Text(task.displayTitle).font(CXTypography.section)
                    if let description = task.description, !description.isEmpty {
                        Text(description).font(CXTypography.supporting).foregroundStyle(CX.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    HStack(spacing: 8) {
                        if let priority = task.priority, !priority.isEmpty {
                            priorityBadge(priority)
                        }
                        Text(roleLabel(task)).font(CXTypography.micro).foregroundStyle(CX.muted)
                    }
                    if let deadline = task.deadline, let date = HealthSyncService.date(fromISO: deadline) {
                        Label("截止 \(date.formatted(date: .abbreviated, time: .shortened))", systemImage: "clock")
                            .font(CXTypography.micro).foregroundStyle(CX.muted)
                    }
                }
                Spacer(minLength: 0)
            }

            if task.isCompleted {
                Label("已完成", systemImage: "checkmark.seal.fill")
                    .font(CXTypography.supporting.weight(.semibold)).foregroundStyle(CX.statusPositive)
            } else {
                Button {
                    completeNotes = ""
                    notesTask = task
                } label: {
                    Text("标记完成").frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButton())
                .disabled(completing)
            }
        }
        .padding(CXSpacing.lg)
        .cxContentSurface(cornerRadius: CXRadius.lg)
    }

    private func completeSheet(_ task: CareTask) -> some View {
        NavigationStack {
            Page(illustrated: true) {
                VStack(alignment: .leading, spacing: CXSpacing.xs) {
                    Text("完成照护任务")
                        .font(CXTypography.micro.weight(.semibold))
                        .foregroundStyle(CX.statusPositive)
                        .tracking(0.6)
                    Text(task.displayTitle)
                        .font(CXTypography.display)
                    Text("如果有需要补充的完成情况，可以在提交前写一句；没有也可以直接完成。")
                        .font(CXTypography.body)
                        .foregroundStyle(CX.muted)
                        .lineSpacing(5)
                }

                SectionEyebrow(title: "完成情况", action: "可选")
                TextField("例如：已预约复诊，等待确认时间", text: $completeNotes, axis: .vertical)
                    .lineLimit(4...8)
                    .padding(CXSpacing.md)
                    .background(CX.surface, in: .rect(cornerRadius: CXRadius.md, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: CXRadius.md, style: .continuous)
                            .strokeBorder(CX.separator.opacity(0.12), lineWidth: 0.5)
                    }

                Button {
                    Task { await complete(task) }
                } label: {
                    if completing {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("正在提交")
                        }
                    } else {
                        Text("标记完成")
                    }
                }
                .buttonStyle(PrimaryButton())
                .disabled(completing)
            }
            .navigationTitle("完成任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { notesTask = nil }
                }
            }
        }
    }

    private func priorityBadge(_ priority: String) -> some View {
        Text(priorityLabel(priority))
            .font(.caption.bold())
            .foregroundStyle(priorityColor(priority))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(priorityColor(priority).opacity(0.12), in: Capsule())
    }

    private func priorityLabel(_ priority: String) -> String {
        switch priority.lowercased() {
        case "high": return "高优先"
        case "medium": return "中优先"
        case "low": return "低优先"
        default: return priority
        }
    }

    private func priorityColor(_ priority: String) -> Color {
        switch priority.lowercased() {
        case "high": return CX.coral
        case "medium": return .orange
        default: return CX.teal
        }
    }

    /// 执行角色中文标签：优先 `assignee_role`，回落 `assignee_type`。
    private func roleLabel(_ task: CareTask) -> String {
        let raw = task.assigneeRole ?? task.assigneeType ?? ""
        switch raw.lowercased() {
        case "assistant": return "常曦助手"
        case "family_doctor": return "家庭医生"
        case "nurse": return "护士"
        case "patient": return "本人"
        case "": return "照护建议"
        default:
            if raw.lowercased().hasPrefix("human") { return "人工照护" }
            return raw
        }
    }

    // MARK: - 数据加载

    @MainActor
    private func load() async {
        guard AppConfiguration.useRemoteAPI else { return }
        loading = true
        errorText = nil
        do {
            let page = try await CareTaskService().listTasks(patientID: patientId, page: 1, size: 50)
            tasks = page.tasks ?? []
        } catch {
            tasks = []
            errorText = (error as? APIError)?.userFacingMessage ?? "照护任务加载失败，请稍后重试。"
        }
        loading = false
    }

    @MainActor
    private func complete(_ task: CareTask) async {
        guard AppConfiguration.useRemoteAPI else { return }
        completing = true
        do {
            _ = try await CareTaskService().completeTask(
                task.id, outcomeType: "resolved", notes: completeNotes, completedBy: patientId
            )
            notesTask = nil
            await load()
        } catch {
            notesTask = nil
            errorText = (error as? APIError)?.userFacingMessage ?? "标记完成失败，请稍后重试。"
        }
        completing = false
    }
}
