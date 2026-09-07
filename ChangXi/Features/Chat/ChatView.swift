import SwiftUI
import UniformTypeIdentifiers

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
    @State private var lastUserText = ""
    @State private var activeRequest: UUID?
    @State private var pendingText = ""
    @State private var error: String?
    // 流式与会话状态
    @State private var streamingText = ""
    @State private var isStreaming = false
    @State private var sessionID: String?
    @State private var lastMetadata: ChatMetadata?
    @State private var didRestoreHistory = false
    @FocusState private var keyboard: Bool
    private let demo = DemoConversationService()
    private let eventService = XuantongEventConversationService.configured()

    /// 是否有一次问答正在进行（用于禁用输入 / 显示停止按钮）。
    private var isBusy: Bool { activeRequest != nil }
    /// 登录用户优先使用云端 ID，匿名用户使用稳定的本地 UUID。
    private var currentPatientId: String { auth.currentUser?.id ?? store.data.patientID }
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        MoonPoolView(state: speech.isRecording ? .listening : state, amplitude: speech.level, compact: !store.data.messages.isEmpty)
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
                            Card {
                                Text("有什么想和我说的？").font(.title2.bold())
                                Text("说说今天的感受，或一起看看健康记录。").foregroundStyle(CX.muted)
                                ForEach(["我想了解这份体检报告", "看看今天的用药计划", "我想记录今天的感受"], id: \.self) { prompt in Button(prompt) { text = prompt; keyboard = true }.frame(minHeight: 44) }
                            }
                        }
                        ForEach(store.data.messages.suffix(40)) { message in
                            HStack {
                                if message.isUser { Spacer(minLength: 32) }
                                VStack(alignment: .leading, spacing: 7) {
                                    Text(message.isUser ? "我" : "常曦")
                                        .font(.caption)
                                        .foregroundStyle(CX.muted)
                                        .accessibilityIdentifier(message.isUser ? "user-message-label" : "assistant-message-label")
                                    Text(message.text).font(.body).lineSpacing(5).textSelection(.enabled)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    message.isUser ? CX.blue.opacity(0.13) : CX.surface,
                                    in: .rect(cornerRadius: 20, style: .continuous)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .strokeBorder(CX.separator.opacity(0.14), lineWidth: 0.5)
                                }
                                .accessibilityElement(children: .combine)
                                if !message.isUser { Spacer(minLength: 32) }
                            }.id(message.id)
                        }
                        if isStreaming && !streamingText.isEmpty {
                            HStack {
                                VStack(alignment: .leading, spacing: 7) {
                                    Text("常曦").font(.caption).foregroundStyle(CX.muted)
                                    Text(streamingText).font(.body).lineSpacing(5)
                                }.padding(16).background(.white, in: RoundedRectangle(cornerRadius: 22))
                                Spacer(minLength: 32)
                            }.id("streaming-bubble")
                        }
                        if isBusy && streamingText.isEmpty {
                            HStack { ProgressView(); Text("常曦正在整理…").foregroundStyle(CX.muted); Spacer(); Button("停止") { cancelRequest() } }.padding()
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
            composer
        }
        .background { MoonBackground(illustrated: true) }.foregroundStyle(CX.ink)
        .navigationTitle("告诉常曦").navigationBarTitleDisplayMode(.inline)
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
                pendingAttachment = url.lastPathComponent
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
                    Button { self.pendingAttachment = nil } label: { Image(systemName: "xmark.circle.fill") }
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
                            .cxInteractiveGlassCircle()
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
                            .cxInteractiveGlassCircle()
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
        let outgoing = pendingAttachment.map { "\(value)\n附件：\($0)" } ?? value
        store.data.messages.append(ConversationMessage(isUser: true, text: outgoing))
        pendingAttachment = nil
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

    private func requestReply(_ value: String) {
        pendingText = value
        error = nil
        lastMetadata = nil
        streamingText = ""
        isStreaming = false
        state = .thinking
        activeRequest = UUID()
    }

    /// 玄同当前公开契约以 `POST /api/events` 驱动工作流；不可用时明确降级到本地演示。
    @MainActor
    private func performReply(requestId: UUID) async {
        guard AppConfiguration.useRemoteAPI else {
            await demoFallback(requestId: requestId)
            return
        }
        do {
            let reply = try await eventService.reply(to: pendingText, patientID: currentPatientId)
            try Task.checkCancellation()
            guard activeRequest == requestId else { return }
            state = switch reply.clinicalRisk {
            case .red: .quietAlert
            case .yellow: .notification
            default: .responding
            }
            store.data.messages.append(ConversationMessage(isUser: false, text: reply.text))
            try await Task.sleep(for: .seconds(reduceMotion ? 0.3 : 1.2))
            guard activeRequest == requestId else { return }
            finishTurn()
        } catch is CancellationError {
            finishTurn()
        } catch {
            guard activeRequest == requestId else { return }
            await demoFallback(requestId: requestId)
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
        streamingText = ""
        state = .idle
        activeRequest = nil
    }

    private func cancelRequest() {
        activeRequest = nil
        isStreaming = false
        streamingText = ""
        state = .idle
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { proxy.scrollTo("bottom", anchor: .bottom) }
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
