import SwiftUI

struct ChatView: View {
    var initialPrompt = ""
    @Environment(AppStore.self) private var store
    @Environment(AuthSession.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var speech = SpeechController()
    @State private var text = ""
    @State private var state = MoonPoolState.idle
    @State private var showCamera = false
    @State private var showHistory = false
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

    /// 是否有一次问答正在进行（用于禁用输入 / 显示停止按钮）。
    private var isBusy: Bool { activeRequest != nil }
    /// 助手消息的署名：联网时为“常曦”，离线演示时保留“常曦 · 示例回复”（UI 测试依赖）。
    private var assistantLabel: String { AppConfiguration.useRemoteAPI ? "常曦" : "常曦 · 示例回复" }
    /// 当前患者标识：登录后用用户 ID 作为绑定标识，否则用稳定的本地匿名 UUID。
    private var currentPatientId: String { auth.currentUser?.id ?? RemoteConversationService.localPatientId }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        MoonPoolView(state: speech.isRecording ? .listening : state, amplitude: speech.level, compact: !store.data.messages.isEmpty)
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
                                    Text(message.isUser ? "我" : assistantLabel).font(.caption).foregroundStyle(CX.muted)
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
        .toolbarBackground(CX.mist.opacity(0.95), for: .navigationBar).toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("关闭") { speech.stop(); cancelRequest(); dismiss() } }
            ToolbarItem(placement: .topBarTrailing) { Button { showHistory = true } label: { Image(systemName: "clock.arrow.circlepath").frame(width: 44, height: 44) }.accessibilityLabel("对话历史") }
        }
        .sheet(isPresented: $showCamera) { NavigationStack { ReportImportView(onAttach: { text = $0; keyboard = true }) } }
        .sheet(isPresented: $showHistory) { NavigationStack { ChatHistoryView() } }
        .onAppear { if !initialPrompt.isEmpty { text = initialPrompt } }
        .onDisappear { speech.stop(); cancelRequest() }
        .task { await restoreLatestSession() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { speech.stop(); if isBusy { cancelRequest() } } }
        .onChange(of: speech.transcript) { _, transcript in text = transcript }
        .task(id: activeRequest) {
            guard let id = activeRequest else { return }
            await performReply(requestId: id)
        }
    }

    // MARK: - 输入区

    private var composer: some View {
        VStack(spacing: 12) {
            if speech.isRecording { Text("正在听 · 停止后可修改文字再发送").font(.caption).foregroundStyle(CX.muted) }
            HStack(alignment: .bottom, spacing: 10) {
                TextField("输入想说的话…", text: $text, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($keyboard)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(CX.raisedSurface, in: .rect(cornerRadius: 16, style: .continuous))
                    .accessibilityIdentifier("chat-input")
                Button(action: send) {
                    Image(systemName: isBusy ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.largeTitle)
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 48, height: 48)
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isBusy || speech.isRecording)
                .accessibilityLabel(isBusy ? "停止" : "发送")
                .accessibilityIdentifier("send-chat")
            }
            HStack(spacing: 12) {
                Button {
                    if speech.isRecording || speech.isStarting { speech.stop() }
                    else { keyboard = false; Task { await speech.start() } }
                } label: { Label(speech.isStarting ? "正在开启…" : speech.isRecording ? "停止录音" : "点击说话", systemImage: speech.isRecording ? "stop.fill" : "mic.fill") }.buttonStyle(PrimaryButton()).disabled(isBusy)
                Button { speech.stop(); showCamera = true } label: {
                    Image(systemName: "camera.fill")
                        .font(.title3.weight(.semibold))
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 54, height: 52)
                        .background(CX.raisedSurface, in: .rect(cornerRadius: 16, style: .continuous))
                }
                .accessibilityLabel("拍照或选择报告")
            }
        }
        .frame(maxWidth: 720)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
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
        store.data.messages.append(ConversationMessage(isUser: true, text: value))
        text = ""; keyboard = false
        requestReply(value)
        MoonHaptics.shared.play(enabled: store.data.haptics)
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

    /// 三级降级：① POST-SSE 流式 → ② 非流式 `POST /chat` → ③ 本地演示服务。
    @MainActor
    private func performReply(requestId: UUID) async {
        guard AppConfiguration.useRemoteAPI else {
            await demoFallback(requestId: requestId)
            return
        }
        let service = RemoteConversationService(patientId: currentPatientId)
        let context = recentContext()

        // ① 流式（打字机）
        do {
            isStreaming = true
            let final = try await service.streamReply(
                message: pendingText,
                sessionId: sessionID,
                context: context
            ) { chunk in
                guard activeRequest == requestId else { return }
                if streamingText.isEmpty { state = .responding }
                streamingText += chunk
            }
            try Task.checkCancellation()
            guard activeRequest == requestId else { return }
            commit(reply: final.reply, sessionId: final.sessionId, metadata: final.metadata)
            briefRespondingThenFinish(requestId: requestId)
            return
        } catch is CancellationError {
            finishTurn()
            return
        } catch {
            guard activeRequest == requestId else { return }
            streamingText = ""; isStreaming = false; state = .thinking
        }

        // ② 非流式兜底
        do {
            let reply = try await service.send(message: pendingText, sessionId: sessionID, context: context)
            try Task.checkCancellation()
            guard activeRequest == requestId else { return }
            commit(reply: reply.reply, sessionId: reply.sessionId, metadata: reply.metadata)
            briefRespondingThenFinish(requestId: requestId)
            return
        } catch is CancellationError {
            finishTurn()
            return
        } catch {
            guard activeRequest == requestId else { return }
        }

        // ③ 本地演示兜底
        await demoFallback(requestId: requestId)
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

    /// 采纳一次成功回复：写入会话、记录 sessionID 与 metadata。
    @MainActor
    private func commit(reply: String, sessionId: String?, metadata: ChatMetadata?) {
        if let sessionId { sessionID = sessionId }
        lastMetadata = metadata
        let finalText = reply.isEmpty ? streamingText : reply
        store.data.messages.append(ConversationMessage(isUser: false, text: finalText))
    }

    /// 让月池短暂停留在“回应”态后复位，形成完整的动画节奏。
    @MainActor
    private func briefRespondingThenFinish(requestId: UUID) {
        state = .responding
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.3 : 1.0))
            guard activeRequest == requestId else { return }
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

    /// 取最近若干轮历史作为上下文（排除刚发送的当前用户消息）。
    private func recentContext(limit: Int = 6) -> [ChatContextTurn] {
        let prior = store.data.messages.dropLast()
        return prior.suffix(limit).compactMap { message in
            let content = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty else { return nil }
            return ChatContextTurn(role: message.isUser ? "user" : "assistant", content: content)
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { proxy.scrollTo("bottom", anchor: .bottom) }
    }

    // MARK: - 会话恢复

    /// 进入页面时若后端可达，恢复最近会话并（在本机消息为空时）拉取历史消息。
    @MainActor
    private func restoreLatestSession() async {
        guard AppConfiguration.useRemoteAPI, !didRestoreHistory else { return }
        didRestoreHistory = true
        let service = RemoteConversationService(patientId: currentPatientId)
        guard let sessions = try? await service.listSessions(), let latest = sessions.first else { return }
        sessionID = latest.id
        guard store.data.messages.isEmpty else { return }
        guard let messages = try? await service.listMessages(sessionId: latest.id, limit: 50) else { return }
        let mapped = messages.compactMap { message -> ConversationMessage? in
            guard message.role == "user" || message.role == "assistant", !message.content.isEmpty else { return nil }
            return ConversationMessage(isUser: message.isUser, text: message.content, date: message.createdAt)
        }
        if !mapped.isEmpty { store.data.messages.append(contentsOf: mapped) }
    }
}

// MARK: - 对话历史

struct ChatHistoryView: View {
    @Environment(AppStore.self) private var store
    @Environment(AuthSession.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var clear = false
    @State private var sessions: [ChatSession] = []
    @State private var loadingSessions = false
    @State private var sessionError: String?

    private var currentPatientId: String { auth.currentUser?.id ?? RemoteConversationService.localPatientId }

    var body: some View {
        List {
            if AppConfiguration.useRemoteAPI {
                Section("云端会话") {
                    if loadingSessions {
                        HStack { ProgressView(); Text("正在加载会话…").foregroundStyle(CX.muted) }
                    } else if let sessionError {
                        Text(sessionError).foregroundStyle(CX.muted).font(.footnote)
                    } else if sessions.isEmpty {
                        Text("暂无云端会话记录。").foregroundStyle(CX.muted).font(.footnote)
                    } else {
                        ForEach(sessions) { session in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(sessionTitle(session)).font(.subheadline)
                                Text("\(session.messageCount) 条消息 · \(session.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption2).foregroundStyle(CX.muted)
                            }
                        }
                    }
                }
            }
            Section(AppConfiguration.useRemoteAPI ? "本机记录（离线回退）" : "本机对话记录") {
                if store.data.messages.isEmpty {
                    ContentUnavailableView("还没有对话", systemImage: "bubble.left.and.bubble.right")
                } else {
                    ForEach(store.data.messages) { message in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(message.isUser ? "我" : (AppConfiguration.useRemoteAPI ? "常曦" : "常曦 · 示例")).font(.caption).foregroundStyle(.secondary)
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
        .task { await loadSessions() }
    }

    private func sessionTitle(_ session: ChatSession) -> String {
        "会话 \(String(session.id.prefix(8)))"
    }

    @MainActor
    private func loadSessions() async {
        guard AppConfiguration.useRemoteAPI else { return }
        loadingSessions = true
        sessionError = nil
        defer { loadingSessions = false }
        let service = RemoteConversationService(patientId: currentPatientId)
        do {
            sessions = try await service.listSessions()
        } catch is CancellationError {
            // 忽略取消
        } catch let error as APIError {
            sessionError = error.userFacingMessage
        } catch {
            sessionError = "云端会话加载失败。"
        }
    }
}
