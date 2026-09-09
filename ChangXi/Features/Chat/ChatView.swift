import SwiftUI
import UniformTypeIdentifiers
import PDFKit

struct ChatView: View {
    var initialPrompt = ""
    @Environment(AppStore.self) private var store
    @Environment(AuthSession.self) private var auth
    @Environment(AssistantCoordinator.self) private var assistant
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var speech = SpeechController()
    @State private var text = ""
    @State private var state = MoonPoolState.idle
    @State private var showCamera = false
    @State private var showHistory = false
    @State private var showFiles = false
    @State private var pendingAttachment: String?
    @State private var pendingAttachmentText: String?
    @State private var lastUserText = ""
    @State private var activeRequest: UUID?
    @State private var pendingText = ""
    @State private var error: String?
    // 流式与会话状态
    @State private var streamingText = ""
    @State private var isStreaming = false
    @State private var sessionID: String?
    @State private var lastMetadata: ChatMetadata?
    @State private var isEnriching = false
    @State private var didRestoreHistory = false
    @FocusState private var keyboard: Bool
    private let demo = DemoConversationService()
    private var eventService: XuantongEventConversationService { .configured() }

    /// 是否有一次问答正在进行（用于禁用输入 / 显示停止按钮）。
    private var isBusy: Bool { activeRequest != nil }
    /// 登录用户优先使用云端 ID，匿名用户使用稳定的本地 UUID。
    private var currentPatientId: String { auth.currentUser?.id ?? store.data.patientID }
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        if store.data.messages.isEmpty && !keyboard {
                            MoonPoolView(state: speech.isRecording ? .listening : state, amplitude: speech.level, compact: true)
                        }
                        if let context = assistant.activeContext {
                            Card {
                                Label("正在帮你填写\(context.title)", systemImage: "wand.and.stars")
                                    .font(.headline)
                                Text("可以用语音或文字告诉我，填回后会留在原页面供你核对，不会自动提交。")
                                    .font(.subheadline)
                                    .foregroundStyle(CX.muted)
                                Button("填回\(context.title)") { fillBack() }
                                    .buttonStyle(PrimaryButton())
                                    .disabled(lastUserText.isEmpty && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                    .accessibilityIdentifier("fill-back")
                            }
                        }
                        if store.data.messages.isEmpty && !isStreaming {
                            VStack(alignment: .leading, spacing: 18) {
                                Text("此刻，想聊些什么？").font(.title2.weight(.medium)).fontDesign(.serif)
                                Text("一段心事，一次记录，或一个小小的疑问。")
                                    .font(.subheadline).foregroundStyle(CX.muted)
                                ForEach(["我想了解这份体检报告", "看看今天的用药计划", "我想记录今天的感受"], id: \.self) { prompt in
                                    Button { text = prompt; keyboard = true } label: {
                                        HStack { Text(prompt).font(.subheadline); Spacer(); Image(systemName: "arrow.up.left").font(.caption).foregroundStyle(CX.muted) }
                                            .frame(minHeight: 44).contentShape(Rectangle())
                                    }.buttonStyle(QuietPressButton())
                                }
                            }
                            .padding(.horizontal, 8)
                        }
                        ForEach(store.data.messages.suffix(40)) { message in
                            ConversationTurnView(message: message).id(message.id)
                        }
                        if isStreaming && !streamingText.isEmpty {
                            AssistantAnswerCard(text: streamingText, detail: nil, isStreaming: true)
                                .id("streaming-bubble")
                        }
                        if isBusy && streamingText.isEmpty {
                            ThinkingRibbon(isEnriching: isEnriching) { cancelRequest() }
                        }
                        if let badge = lastMetadata?.badge { metadataBanner(badge) }
                        if let error { Card { Text(error).foregroundStyle(CX.coral); Button("重试") { requestReply(pendingText) } } }
                        if let error = speech.error { Card { Text(error).foregroundStyle(CX.muted); Button("使用键盘") { keyboard = true } } }
                        Color.clear.frame(height: 1).id("bottom")
                    }.frame(maxWidth: 720).padding(20).frame(maxWidth: .infinity)
                }
                .onChange(of: store.data.messages.count) { _, _ in scrollToBottom(proxy) }
                .onChange(of: streamingText) { _, _ in scrollToBottom(proxy) }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { composer }
        .background { MoonBackground() }.foregroundStyle(CX.ink)
        .navigationTitle("常曦").navigationBarTitleDisplayMode(.inline)
        .cxNavigationChrome()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("关闭") { speech.stop(); cancelRequest(); dismiss() } }
            ToolbarItem(placement: .topBarTrailing) { Button { showHistory = true } label: { Image(systemName: "clock.arrow.circlepath").frame(width: 44, height: 44) }.accessibilityLabel("对话历史") }
        }
        .sheet(isPresented: $showCamera) { NavigationStack { ReportImportView(onAttach: { text = $0; keyboard = true }) } }
        .sheet(isPresented: $showHistory) { NavigationStack { ChatHistoryView() } }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.pdf, .plainText], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                guard readAttachment(url) else { return }
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    text = "我想请你帮我看看这个附件"
                }
                keyboard = true
            case .failure:
                error = "没有读取到文件，请重新选择。"
            }
        }
        .onAppear { if !initialPrompt.isEmpty { text = initialPrompt } }
        .onDisappear { speech.stop(); cancelRequest(); assistant.finish() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { speech.stop(); if isBusy { cancelRequest() } } }
        .onChange(of: speech.transcript) { _, transcript in text = transcript }
        .task(id: activeRequest) {
            guard let id = activeRequest else { return }
            await performReply(requestId: id)
        }
    }

    // MARK: - 输入区

    private var composer: some View {
        VStack(spacing: 8) {
            if speech.isRecording { Text("正在听 · 停止后可修改文字再发送").font(.caption).foregroundStyle(CX.muted) }
            if let pendingAttachment {
                HStack(spacing: 8) {
                    Image(systemName: "doc")
                    Text(pendingAttachment).lineLimit(1)
                    Spacer()
                    Button { self.pendingAttachment = nil; pendingAttachmentText = nil } label: { Image(systemName: "xmark.circle.fill") }
                        .accessibilityLabel("移除附件")
                }
                .font(.caption)
                .foregroundStyle(CX.muted)
                .padding(.horizontal, 12)
            }
            CXGlassGroup(spacing: 10) {
                HStack(alignment: .bottom, spacing: 8) {
                    Menu {
                        Button { speech.stop(); showCamera = true } label: {
                            Label("拍照或选择照片", systemImage: "camera")
                        }
                        Button { speech.stop(); showFiles = true } label: {
                            Label("选择 PDF 或文本", systemImage: "doc.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline.weight(.medium))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("添加照片或文件")

                    TextField("输入想说的话…", text: $text, axis: .vertical)
                        .lineLimit(1...5)
                        .focused($keyboard)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("chat-input")

                    Button {
                        if speech.isRecording || speech.isStarting { speech.stop() }
                        else { keyboard = false; Task { await speech.start() } }
                    } label: {
                        Image(systemName: speech.isRecording ? "stop.fill" : "mic")
                            .font(.headline.weight(.medium))
                            .frame(width: 44, height: 44)
                            .foregroundStyle(speech.isRecording ? CX.coral : CX.ink)
                    }
                    .disabled(isBusy)
                    .accessibilityLabel(speech.isRecording ? "停止录音" : "语音输入")

                    Button(action: send) {
                        Image(systemName: isBusy ? "stop.fill" : "arrow.up")
                            .font(.headline.weight(.bold))
                            .frame(width: 44, height: 44)
                            .foregroundStyle(.white)
                            .cxProminentGlassCircle()
                    }
                    .disabled((text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isBusy) || speech.isRecording)
                    .accessibilityLabel(isBusy ? "停止" : "发送")
                    .accessibilityIdentifier("send-chat")
                }
                .padding(6)
                .cxInteractiveGlass(cornerRadius: 24)
            }
        }
        .frame(maxWidth: 720)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .cxComposerBackground()
    }

    // MARK: - 安全护栏 / 降级提示

    @ViewBuilder
    private func metadataBanner(_ badge: String) -> some View {
        let urgent = lastMetadata?.isGuarded ?? false
        HStack(spacing: 8) {
            Image(systemName: urgent ? "exclamationmark.triangle.fill" : "info.circle")
            VStack(alignment: .leading, spacing: 2) {
                Text(badge).font(.footnote.bold())
                if lastMetadata?.isEmergency == true {
                    Text("如情况紧急，请立即拨打 120 或前往就近医院急诊。").font(.caption2)
                } else if lastMetadata?.degraded == true {
                    Text("智能助手暂时繁忙，已为你提供简化回复。").font(.caption2)
                }
            }
            Spacer()
        }
        .padding(12)
        .background((urgent ? CX.coral : CX.muted).opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        .foregroundStyle(urgent ? CX.coral : CX.muted)
        .accessibilityIdentifier("reply-metadata-banner")
    }

    // MARK: - 发送与问答编排

    private func send() {
        if isBusy { cancelRequest(); return }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        speech.stop()
        lastUserText = value
        let outgoing = pendingAttachment.map { "\(value)\n附件：\($0)\n\(pendingAttachmentText ?? "")" } ?? value
        store.data.messages.append(ConversationMessage(isUser: true, text: outgoing))
        pendingAttachment = nil
        pendingAttachmentText = nil
        text = ""; keyboard = false
        requestReply(outgoing)
        MoonHaptics.shared.play(enabled: store.data.haptics)
    }

    private func fillBack() {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? lastUserText
            : text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        if assistant.fillActive(with: value) {
            MoonHaptics.shared.play(success: true, enabled: store.data.haptics)
            assistant.finish()
            dismiss()
        } else {
            error = "这段内容还不能安全填入当前表单，请只提供一组明确的数值或更具体的说明。"
        }
    }

    private func readAttachment(_ url: URL) -> Bool {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) < 10_000_000 else {
                error = "请选择小于 10 MB 的文件。"; return false
            }
            let content = url.pathExtension.lowercased() == "pdf" ? (PDFDocument(url: url)?.string ?? "") : try String(contentsOf: url, encoding: .utf8)
            guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                error = "这个文件没有可提取的文字，扫描版 PDF 请先转换成文字。"; return false
            }
            pendingAttachment = url.lastPathComponent
            pendingAttachmentText = String(content.prefix(12000))
            if content.count > 12000 { pendingAttachmentText? += "\n（文件较长，本次附上前 12000 字）" }
            return true
        } catch { self.error = "文件读取失败，请重新选择 PDF 或 UTF-8 文本。"; return false }
    }

    private func requestReply(_ value: String) {
        pendingText = value
        error = nil
        lastMetadata = nil
        streamingText = ""
        isStreaming = false
        isEnriching = false
        state = .thinking
        activeRequest = UUID()
    }

    /// 对话正文走 Novita 真流式；玄同完整工作流并行补充工单、风险和参考资料。
    @MainActor
    private func performReply(requestId: UUID) async {
        guard AppConfiguration.useRemoteAPI else {
            await demoFallback(requestId: requestId)
            return
        }
        do {
            let request = assistant.activeContext.map { "当前页面：\($0.title)。请只根据我提供的事实协助整理，不要编造数据。\n\(pendingText)" } ?? pendingText
            let remote = RemoteConversationService(patientId: currentPatientId)
            isStreaming = true
            let final: ChatFinal
            do {
                final = try await remote.streamReply(
                    message: request,
                    patientId: currentPatientId,
                    sessionId: sessionID
                ) { chunk in
                    guard activeRequest == requestId else { return }
                    streamingText += chunk
                }
            } catch {
                throw error
            }
            try Task.checkCancellation()
            guard activeRequest == requestId else { return }
            sessionID = final.sessionId ?? sessionID
            lastMetadata = final.metadata
            let assistantMessageID = UUID()
            store.data.messages.append(
                ConversationMessage(id: assistantMessageID, isUser: false, text: final.reply)
            )
            streamingText = ""
            isStreaming = false
            isEnriching = true
            state = .responding

            if let workflow = try? await eventService.reply(
                to: request,
                patientID: currentPatientId
            ),
               activeRequest == requestId {
                state = switch workflow.clinicalRisk {
                case .red: .quietAlert
                case .yellow: .notification
                default: .responding
                }
                var references = final.references
                let known = Set(references.map(\.source))
                references.append(contentsOf: workflow.references.filter { !known.contains($0.source) })
                if let index = store.data.messages.firstIndex(where: { $0.id == assistantMessageID }) {
                    store.data.messages[index].responseDetail = ConversationResponseDetail(
                        clinicalRisk: workflow.clinicalRisk?.rawValue,
                        actionSummary: workflow.actionSummary,
                        workflowSteps: workflow.steps,
                        references: references,
                        workOrders: workflow.workOrders
                    )
                }
            } else if let index = store.data.messages.firstIndex(where: { $0.id == assistantMessageID }),
                      !final.references.isEmpty {
                store.data.messages[index].responseDetail = ConversationResponseDetail(
                    clinicalRisk: nil,
                    actionSummary: nil,
                    workflowSteps: [],
                    references: final.references,
                    workOrders: []
                )
            }
            isEnriching = false
            try await Task.sleep(for: .seconds(reduceMotion ? 0.2 : 0.65))
            guard activeRequest == requestId else { return }
            finishTurn()
        } catch is CancellationError {
            finishTurn()
        } catch {
            guard activeRequest == requestId else { return }
            self.error = "暂时没有连接上玄同，未生成云端回复。请在「我的 → 玄同连接」检查服务地址，然后重试。"
            finishTurn()
        }
    }

    /// 演示服务回复（离线 / UI 测试 / 后端不可达时使用）。
    @MainActor
    private func demoFallback(requestId: UUID) async {
        isStreaming = false; streamingText = ""
        state = .thinking
        do {
            let reply = try await demo.reply(to: pendingText)
            try Task.checkCancellation()
            guard activeRequest == requestId else { return }
            state = .responding
            store.data.messages.append(ConversationMessage(isUser: false, text: reply))
            try await Task.sleep(for: .seconds(1.2))
            guard activeRequest == requestId else { return }
            finishTurn()
        } catch is CancellationError {
            finishTurn()
        } catch {
            self.error = "这次回复没有完成，你的文字已保留。"
            finishTurn()
        }
    }

    @MainActor
    private func finishTurn() {
        isStreaming = false
        isEnriching = false
        streamingText = ""
        state = .idle
        activeRequest = nil
    }

    private func cancelRequest() {
        activeRequest = nil
        isStreaming = false
        isEnriching = false
        streamingText = ""
        state = .idle
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { proxy.scrollTo("bottom", anchor: .bottom) }
    }

}

// MARK: - 回答、工单与参考资料

private struct ConversationTurnView: View {
    let message: ConversationMessage

    var body: some View {
        if message.isUser {
            HStack {
                Spacer(minLength: 44)
                VStack(alignment: .leading, spacing: 7) {
                    Text("我")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(CX.muted)
                        .accessibilityIdentifier("user-message-label")
                    Text(message.text)
                        .font(.body)
                        .lineSpacing(5)
                        .textSelection(.enabled)
                }
                .padding(.horizontal, 17)
                .padding(.vertical, 14)
                .background(CX.blue.opacity(0.12), in: .rect(cornerRadius: 21, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 21, style: .continuous)
                        .strokeBorder(CX.moonlight.opacity(0.20), lineWidth: 0.5)
                }
            }
        } else {
            AssistantAnswerCard(text: message.text, detail: message.responseDetail)
        }
    }
}

private struct AssistantAnswerCard: View {
    let text: String
    let detail: ConversationResponseDetail?
    var isStreaming = false

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 9) {
                    ZStack {
                        Circle().fill(CX.blue.opacity(0.11))
                        Image(systemName: "moonphase.waning.crescent")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(CX.blue)
                    }
                    .frame(width: 28, height: 28)
                    Text("常曦")
                        .font(.subheadline.weight(.semibold))
                        .accessibilityIdentifier("assistant-message-label")
                    if isStreaming {
                        Text("正在回答")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(CX.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(CX.blue.opacity(0.09), in: Capsule())
                    }
                    Spacer()
                }

                MarkdownBody(text: text)

                if let detail {
                    Divider().opacity(0.45)
                    if detail.references.isEmpty {
                        Label("本回答未引用外部资料", systemImage: "books.vertical")
                            .font(.caption)
                            .foregroundStyle(CX.muted)
                            .accessibilityIdentifier("no-references")
                    } else {
                        NavigationLink {
                            ReferenceLibraryView(references: detail.references)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "books.vertical.fill")
                                    .foregroundStyle(CX.blue)
                                let citedCount = detail.references.filter { $0.cited == true }.count
                                Text(citedCount > 0
                                     ? "回答引用 \(citedCount) 篇"
                                     : "查看相关资料 \(detail.references.count) 篇")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                HStack(spacing: 4) {
                                    ForEach(Array(detail.references.prefix(3).enumerated()), id: \.element.id) { index, _ in
                                        Text("\(index + 1)")
                                            .font(.caption2.weight(.bold))
                                            .frame(width: 22, height: 22)
                                            .background(CX.blue.opacity(0.10), in: Circle())
                                    }
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(CX.faint)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("open-references")
                    }
                    if !detail.workOrders.isEmpty {
                        Divider().opacity(0.45)
                        WorkOrderSummary(orders: detail.workOrders)
                    }
                }
            }
            .padding(18)
            .background(.regularMaterial, in: .rect(cornerRadius: 24, style: .continuous))
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [CX.moonlight.opacity(0.75), CX.blue.opacity(0.18)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3)
                    .padding(.vertical, 20)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.white.opacity(0.30), lineWidth: 0.6)
            }
            .shadow(color: CX.blue.opacity(0.055), radius: 18, y: 8)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("assistant-response")
            Spacer(minLength: 28)
        }
    }
}

private struct MarkdownBody: View {
    let text: String

    var body: some View {
        if let attributed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            Text(attributed)
                .font(.body)
                .lineSpacing(6)
                .textSelection(.enabled)
        } else {
            Text(text).font(.body).lineSpacing(6).textSelection(.enabled)
        }
    }
}

private struct ThinkingRibbon: View {
    let isEnriching: Bool
    let stop: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(CX.blue.opacity(0.10))
                Image(systemName: isEnriching ? "doc.text.magnifyingglass" : "sparkles")
                    .foregroundStyle(CX.blue)
                    .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(isEnriching ? "回答好了，正在生成照护工单" : "常曦正在理解")
                    .font(.subheadline.weight(.semibold))
                Text(isEnriching ? "核对风险、资料与下一步安排" : "连接家庭医生智能体")
                    .font(.caption)
                    .foregroundStyle(CX.muted)
            }
            Spacer()
            Button("停止", action: stop)
                .font(.caption.weight(.medium))
                .foregroundStyle(CX.muted)
        }
        .padding(14)
        .background(.thinMaterial, in: .rect(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(CX.moonlight.opacity(0.16), lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct WorkOrderSummary: View {
    let orders: [ConversationWorkOrder]
    @State private var acceptedIDs: Set<String> = []
    @State private var declinedIDs: Set<String> = []
    @State private var acceptingID: String?
    @State private var error: String?

    private var proposals: [ConversationWorkOrder] {
        orders.filter {
            $0.status == "proposed" && !acceptedIDs.contains($0.id) && !declinedIDs.contains($0.id)
        }
    }

    private var activeOrders: [ConversationWorkOrder] {
        orders.filter { $0.status != "proposed" || acceptedIDs.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            if !proposals.isEmpty {
                HStack {
                    Label("常曦建议为你安排", systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("需你确认")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(CX.blue)
                }
                Text("以下安排会进入你的照护计划，请选择是否需要。")
                    .font(.caption)
                    .foregroundStyle(CX.muted)
                ForEach(proposals.prefix(3)) { order in
                    proposalCard(order)
                }
            }

            if !activeOrders.isEmpty {
                HStack {
                    Label("照护工单", systemImage: "checklist.checked")
                    .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(activeOrders.count) 项")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(CX.teal)
                }
                ForEach(activeOrders.prefix(3)) { order in
                    NavigationLink {
                        WorkOrderDetailView(order: activated(order))
                    } label: {
                        HStack(spacing: 11) {
                            Circle()
                                .fill(order.priority == "high" ? CX.coral.opacity(0.14) : CX.teal.opacity(0.12))
                                .frame(width: 30, height: 30)
                                .overlay {
                                    Image(systemName: order.priority == "high" ? "bell.badge.fill" : "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(order.priority == "high" ? CX.coral : CX.teal)
                                }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(order.title).font(.subheadline.weight(.medium))
                                if !order.description.isEmpty {
                                    Text(order.description).font(.caption).foregroundStyle(CX.muted).lineLimit(1)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(CX.faint)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            if let error {
                Text(error).font(.caption).foregroundStyle(CX.coral)
            }
        }
        .accessibilityIdentifier("work-order-summary")
    }

    private func activated(_ order: ConversationWorkOrder) -> ConversationWorkOrder {
        guard acceptedIDs.contains(order.id) else { return order }
        var copy = order
        copy.status = "pending"
        return copy
    }

    private func proposalCard(_ order: ConversationWorkOrder) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(order.title).font(.subheadline.weight(.semibold))
            Text(order.description).font(.caption).foregroundStyle(CX.muted)
            HStack(spacing: 10) {
                Button("需要，创建") { accept(order) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(acceptingID != nil)
                Button("暂不需要") {
                    _ = withAnimation(.snappy(duration: 0.24)) { declinedIDs.insert(order.id) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            if acceptingID == order.id { ProgressView().controlSize(.small) }
        }
        .padding(13)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(CX.blue.opacity(0.055))
        }
        .accessibilityElement(children: .contain)
    }

    private func accept(_ order: ConversationWorkOrder) {
        acceptingID = order.id
        error = nil
        Task { @MainActor in
            do {
                try await XuantongEventConversationService.configured().acceptTask(id: order.id)
                _ = withAnimation(.spring(duration: 0.32, bounce: 0.16)) {
                    acceptedIDs.insert(order.id)
                }
            } catch {
                self.error = "暂时没能创建这项安排，请稍后重试。"
            }
            acceptingID = nil
        }
    }
}

private struct ReferenceLibraryView: View {
    let references: [ConversationReference]

    private var citedCount: Int { references.filter { $0.cited == true }.count }

    var body: some View {
        List {
            Section {
                ForEach(Array(references.enumerated()), id: \.element.id) { index, reference in
                    NavigationLink {
                        ReferenceDetailView(number: index + 1, reference: reference)
                    } label: {
                        HStack(alignment: .top, spacing: 13) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(CX.blue)
                                .frame(width: 28, height: 28)
                                .background(CX.blue.opacity(0.10), in: Circle())
                            VStack(alignment: .leading, spacing: 6) {
                                Text(reference.title).font(.body.weight(.semibold))
                                Text(reference.cited == true ? "回答已引用" : "相关资料")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(reference.cited == true ? CX.teal : CX.blue)
                                Text(reference.excerpt)
                                    .font(.subheadline)
                                    .foregroundStyle(CX.muted)
                                    .lineLimit(3)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            } header: {
                Text(citedCount > 0
                     ? "正文已引用 \(citedCount) 篇，其余为相关资料"
                     : "玄同为本次问题检索到的相关资料")
            } footer: {
                Text("资料用于辅助说明，不替代医生面诊、诊断或处方。")
            }
        }
        .navigationTitle("参考资料 · \(references.count)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ReferenceDetailView: View {
    let number: Int
    let reference: ConversationReference

    var body: some View {
        Page {
            HStack(spacing: 12) {
                Text("\(number)")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(CX.blue)
                    .frame(width: 38, height: 38)
                    .background(CX.blue.opacity(0.10), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(reference.title).font(.title3.weight(.semibold))
                    Text("玄同医学知识库").font(.caption).foregroundStyle(CX.muted)
                }
            }
            Card {
                Text("与本次回答相关的内容").font(.headline)
                Text(reference.excerpt).font(.body).lineSpacing(6).textSelection(.enabled)
            }
            Card {
                Label("资料边界", systemImage: "shield.lefthalf.filled")
                    .font(.headline)
                Text("这是知识库摘录，不是针对你的诊断。需要改变药物或治疗方案时，请由医生结合完整病史确认。")
                    .font(.subheadline)
                    .foregroundStyle(CX.muted)
            }
        }
        .navigationTitle("资料 \(number)")
    }
}

private struct WorkOrderDetailView: View {
    let order: ConversationWorkOrder

    var body: some View {
        Page {
            Card {
                Label(order.title, systemImage: "checklist.checked")
                    .font(.title3.weight(.semibold))
                if !order.description.isEmpty {
                    Text(order.description).font(.body).lineSpacing(5)
                }
                LabeledContent("状态", value: order.status == "pending" ? "待处理" : order.status)
                LabeledContent("优先级", value: order.priority == "high" ? "较高" : "常规")
                if let role = order.assigneeRole, !role.isEmpty {
                    LabeledContent("负责角色", value: WorkflowNodeName.roleDisplay(role))
                }
            }
            Card {
                Label("接下来", systemImage: "arrow.triangle.branch")
                    .font(.headline)
                Text("工单已由玄同记录。涉及医疗判断或处方调整的事项仍需医生确认，常曦不会自动替你提交不可逆操作。")
                    .font(.subheadline)
                    .foregroundStyle(CX.muted)
            }
        }
        .navigationTitle("照护工单")
    }
}

// MARK: - 对话历史

struct ChatHistoryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var clear = false

    var body: some View {
        List {
            Section("本机对话记录") {
                if store.data.messages.isEmpty {
                    ContentUnavailableView("还没有对话", systemImage: "bubble.left.and.bubble.right")
                } else {
                    ForEach(store.data.messages) { message in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(message.isUser ? "我" : "常曦").font(.caption).foregroundStyle(.secondary)
                            Text(message.text)
                            Text(message.date.formatted(date: .abbreviated, time: .shortened)).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("对话历史")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) { Button("清空", role: .destructive) { clear = true }.disabled(store.data.messages.isEmpty) }
        }
        .confirmationDialog("清空本机对话记录？", isPresented: $clear, titleVisibility: .visible) {
            Button("清空对话", role: .destructive) { store.data.messages = [] }
        }
    }
}
