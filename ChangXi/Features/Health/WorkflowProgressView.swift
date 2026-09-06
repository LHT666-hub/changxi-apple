import SwiftUI

/// 玄同会诊工作流**实时进度页**（Task #25 核心业务链路的呈现层）。
///
/// 用户在 ``RecordReadingView`` 记录一条**异常**读数（如血压 168/103）后，
/// ``HealthSyncService`` 上行触发 `POST /api/events`（阻塞至工作流完成）拿到 ``EventWorkflowResult``，
/// 随后本页通过 `GET /api/v1/events/{id}/stream` 的 SSE **逐节点回放** 8 位 AI 专家的会诊过程，
/// 并在结束后展示会诊结论（患者沟通语、严重程度、临床风险、参与专家数、生成任务数、处置建议）。
///
/// 健壮性设计：
/// - **两级回落**：SSE 实时点亮的节点（``litNodes``）优先；SSE 不可用时回落到 `POST` 已返回的 `workflow.steps`；
///   两者都没有时显示连接中 / 已结束文案，绝不崩溃、绝不留白。
/// - **离线零请求**：`useRemoteAPI == false` 或无 `eventID` 时不发起 SSE，直接呈现 `POST` 结论（或空态）。
/// - **可跳过**：用户可随时点「跳过动画，直接查看结论」，`streaming = false` 即点亮全部并展示结论卡。
struct WorkflowProgressView: View {
    /// 事件上报 + 工作流执行的聚合结果（含最终 `workflow`，作 SSE 失败时的回落数据源）。
    let result: EventWorkflowResult
    /// 关闭回调（由呈现方注入，通常 dismiss 回健康页）。
    var onClose: () -> Void

    @State private var litNodes: [String] = []
    @State private var streaming = true
    @State private var timedOut = false

    private var workflow: WorkflowSummary? { result.workflow }

    /// 完整有序节点列表：优先用 `POST /api/events` 阻塞返回的 `workflow.steps`；
    /// 无则用 SSE 实时累积的 ``litNodes``（降级路径）。
    private var allNodes: [String] {
        if let steps = workflow?.steps, !steps.isEmpty { return steps }
        return litNodes
    }

    /// 某节点是否已「点亮」（执行到）。流式结束后全部点亮；流式中仅点亮 SSE 已确认的节点。
    private func isLit(_ node: String) -> Bool {
        guard streaming else { return true }
        return litNodes.contains(node)
    }

    private var poolState: MoonPoolState {
        if timedOut || (workflow?.isFailed ?? false) { return .quietAlert }
        if streaming { return .thinking }
        if workflow?.isPendingHuman ?? false { return .notification }
        return .success
    }

    private var statusText: String {
        if timedOut { return "实时进度连接超时，以下为会诊返回的结论" }
        if streaming { return "8 位 AI 专家正在实时会诊，请稍候…" }
        if workflow?.isPendingHuman ?? false { return "已转人工审核，家庭医生会尽快联系您" }
        if workflow?.isFailed ?? false { return "会诊流程未能完整完成，已保留您的记录" }
        return "会诊已完成"
    }

    var body: some View {
        Page {
            MoonPoolView(state: poolState, character: true, compact: true)

            Card {
                Text("玄同正在为您分析").font(.title2.bold())
                Text(statusText).foregroundStyle(CX.muted)
                if allNodes.isEmpty {
                    if streaming {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("正在连接会诊进度…").foregroundStyle(CX.muted)
                        }
                    } else {
                        Text("会诊已结束。").foregroundStyle(CX.muted)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(allNodes.enumerated()), id: \.offset) { _, node in
                            nodeRow(node)
                        }
                    }
                }
            }

            if !streaming, let workflow {
                resultCard(workflow)
            }

            if timedOut {
                Card {
                    Label("实时进度连接超时，以下结论来自会诊的最终返回结果。", systemImage: "wifi.exclamationmark")
                        .font(.footnote).foregroundStyle(CX.muted)
                }
            }

            Button(streaming ? "跳过动画，直接查看结论" : "完成") {
                if streaming { streaming = false } else { onClose() }
            }
            .buttonStyle(PrimaryButton())
            .accessibilityIdentifier("workflow-done")
        }
        .navigationTitle("玄同会诊")
        .task { await run() }
    }

    // MARK: - 子视图

    private func nodeRow(_ node: String) -> some View {
        let lit = isLit(node)
        let name = WorkflowNodeName.display(node)
        return HStack(spacing: 12) {
            Image(systemName: lit ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(lit ? CX.teal : CX.muted.opacity(0.4))
            Text(name).foregroundStyle(lit ? CX.ink : CX.muted)
            Spacer(minLength: 0)
        }
        .accessibilityLabel(lit ? "\(name)，已完成" : "\(name)，等待中")
    }

    private func resultCard(_ wf: WorkflowSummary) -> some View {
        Card {
            Text("会诊结论").font(.title2.bold())

            if let communication = wf.patientCommunication, !communication.isEmpty {
                Text(communication).lineSpacing(5)
            }

            if (wf.severity?.isEmpty == false) || (wf.clinicalRisk?.isEmpty == false) {
                HStack(spacing: 10) {
                    if let severity = wf.severity, !severity.isEmpty {
                        riskBadge(title: "严重程度", level: severity)
                    }
                    if let risk = wf.clinicalRisk, !risk.isEmpty {
                        riskBadge(title: "临床风险", level: risk)
                    }
                    Spacer(minLength: 0)
                }
            }

            if let consultations = wf.consultations {
                Label("参与会诊专家 \(consultations) 位", systemImage: "person.3.fill")
            }
            if let tasks = wf.tasksGenerated, tasks > 0 {
                Label("生成照护任务 \(tasks) 项", systemImage: "checklist")
            }

            if let summary = wf.actionSummary, !summary.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("处置建议").font(.headline)
                    Text(summary).foregroundStyle(CX.muted).lineSpacing(4)
                }
            }

            if wf.isPendingHuman {
                Label("本次会诊已转人工审核，家庭医生会联系您。", systemImage: "person.crop.circle.badge.questionmark")
                    .font(.subheadline).foregroundStyle(CX.blue)
            }
            if wf.isFailed {
                Label("会诊流程部分降级，结论可能不完整。", systemImage: "exclamationmark.triangle")
                    .font(.subheadline).foregroundStyle(CX.coral)
            }

            Text("以上为 AI 辅助分析，不能代替医生诊断。如有不适请及时就医。")
                .font(.footnote).foregroundStyle(CX.muted)
        }
    }

    private func riskBadge(title: String, level: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(CX.muted)
            Text(riskLabel(level)).font(.headline).foregroundStyle(riskColor(level))
        }
        .padding(10)
        .background(riskColor(level).opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
    }

    private func riskColor(_ level: String) -> Color {
        switch level.lowercased() {
        case "critical", "severe", "high": return CX.coral
        case "medium", "moderate": return .orange
        default: return CX.teal
        }
    }

    private func riskLabel(_ level: String) -> String {
        switch level.lowercased() {
        case "low": return "低"
        case "medium", "moderate": return "中"
        case "high": return "高"
        case "critical", "severe": return "危急"
        default: return level
        }
    }

    // MARK: - 流式驱动

    /// 订阅 SSE 进度流。离线 / 无 `eventID` 时直接呈现 `POST` 已返回的结论，不发任何请求。
    @MainActor
    private func run() async {
        guard AppConfiguration.useRemoteAPI, let eventID = result.eventID else {
            streaming = false
            return
        }
        do {
            try await EventWorkflowService().streamEventProgress(eventID: eventID) { event in
                handle(event)
            }
        } catch is CancellationError {
            // 页面消失被取消：正常结束，展示已有结论。
        } catch {
            // SSE 建连 / 传输失败：回落到 POST 已返回的 workflow.steps 与结论。
        }
        streaming = false
    }

    /// 处理一帧 SSE 事件（主线程）。`complete` / `timeout` 结束流；其余尝试解析节点名并点亮。
    @MainActor
    private func handle(_ event: SSEEvent) {
        switch event.name {
        case "complete":
            streaming = false
        case "timeout":
            timedOut = true
            streaming = false
        default:
            if let frame = try? event.decodeData(WorkflowStreamFrame.self),
               let node = frame.node, !node.isEmpty, !litNodes.contains(node) {
                litNodes.append(node)
            }
        }
    }
}
