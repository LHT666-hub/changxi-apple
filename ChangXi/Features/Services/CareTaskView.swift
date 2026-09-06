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
        Page {
            if loading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("正在加载照护任务…").foregroundStyle(CX.muted)
                }
            }

            if let errorText {
                Card {
                    Label(errorText, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(CX.coral)
                    Button("重试") { Task { await load() } }
                        .buttonStyle(PrimaryButton())
                }
            }

            if !loading && errorText == nil && tasks.isEmpty {
                ContentUnavailableView(
                    "暂无照护任务",
                    systemImage: "checklist",
                    description: Text("当玄同会诊发现需要跟进的健康问题时，会在这里生成照护建议。")
                )
            }

            ForEach(tasks) { task in
                taskCard(task)
            }

            if !tasks.isEmpty {
                Text("照护任务由玄同会诊自动生成，完成后可勾选标记。AI 建议不能代替医生医嘱。")
                    .font(.footnote).foregroundStyle(CX.muted)
            }
        }
        .navigationTitle("我的照护任务")
        .task { await load() }
        .sheet(item: $notesTask) { task in completeSheet(task) }
    }

    // MARK: - 子视图

    private func taskCard(_ task: CareTask) -> some View {
        Card {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? CX.teal : CX.muted.opacity(0.5))
                VStack(alignment: .leading, spacing: 6) {
                    Text(task.displayTitle).font(.headline)
                    if let description = task.description, !description.isEmpty {
                        Text(description).font(.subheadline).foregroundStyle(CX.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    HStack(spacing: 8) {
                        if let priority = task.priority, !priority.isEmpty {
                            priorityBadge(priority)
                        }
                        Text(roleLabel(task)).font(.caption).foregroundStyle(CX.muted)
                    }
                    if let deadline = task.deadline, let date = HealthSyncService.date(fromISO: deadline) {
                        Label("截止 \(date.formatted(date: .abbreviated, time: .shortened))", systemImage: "clock")
                            .font(.caption).foregroundStyle(CX.muted)
                    }
                }
                Spacer(minLength: 0)
            }

            if task.isCompleted {
                Label("已完成", systemImage: "checkmark.seal.fill")
                    .font(.subheadline).foregroundStyle(CX.teal)
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
    }

    private func completeSheet(_ task: CareTask) -> some View {
        NavigationStack {
            Form {
                Section(task.displayTitle) {
                    TextField("完成情况备注（可选）", text: $completeNotes, axis: .vertical)
                }
                Section {
                    Button {
                        Task { await complete(task) }
                    } label: {
                        if completing {
                            HStack(spacing: 8) { ProgressView(); Text("提交中…") }
                        } else {
                            Text("标记完成")
                        }
                    }
                    .disabled(completing)
                }
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
