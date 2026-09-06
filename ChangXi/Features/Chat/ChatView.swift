import SwiftUI

struct ChatView: View {
    var initialPrompt = ""
    @Environment(AppStore.self) private var store
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
    @FocusState private var keyboard: Bool
    private let service: any ConversationService = DemoConversationService()
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        MoonPoolView(state: speech.isRecording ? .listening : state, amplitude: speech.level, compact: !store.data.messages.isEmpty)
                        if store.data.messages.isEmpty {
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
                                    Text(message.isUser ? "我" : "常曦 · 示例回复").font(.caption).foregroundStyle(CX.muted)
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
                        if state == .thinking { HStack { ProgressView(); Text("常曦正在整理…").foregroundStyle(CX.muted); Spacer(); Button("取消") { activeRequest = nil; state = .idle } }.padding() }
                        if let error { Card { Text(error).foregroundStyle(CX.coral); Button("重试") { requestReply(pendingText) } } }
                        if let error = speech.error { Card { Text(error).foregroundStyle(CX.muted); Button("使用键盘") { keyboard = true } } }
                        Color.clear.frame(height: 1).id("bottom")
                    }.frame(maxWidth: 720).padding(20).frame(maxWidth: .infinity)
                }
                .onChange(of: store.data.messages.count) { _, _ in withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { proxy.scrollTo("bottom", anchor: .bottom) } }
            }
            composer
        }
        .background { MoonBackground(illustrated: true) }.foregroundStyle(CX.ink)
        .navigationTitle("告诉常曦").navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(CX.mist.opacity(0.95), for: .navigationBar).toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("关闭") { speech.stop(); activeRequest = nil; dismiss() } }
            ToolbarItem(placement: .topBarTrailing) { Button { showHistory = true } label: { Image(systemName: "clock.arrow.circlepath").frame(width: 44, height: 44) }.accessibilityLabel("对话历史") }
        }
        .sheet(isPresented: $showCamera) { NavigationStack { ReportImportView(onAttach: { text = $0; keyboard = true }) } }
        .sheet(isPresented: $showHistory) { NavigationStack { ChatHistoryView() } }
        .onAppear { if !initialPrompt.isEmpty { text = initialPrompt } }
        .onDisappear { speech.stop(); activeRequest = nil }
        .onChange(of: scenePhase) { _, phase in if phase != .active { speech.stop(); if state == .thinking { activeRequest = nil; state = .idle } } }
        .onChange(of: speech.transcript) { _, transcript in text = transcript }
        .task(id: activeRequest) {
            guard let id = activeRequest else { return }
            do {
                let reply = try await service.reply(to: pendingText)
                try Task.checkCancellation()
                guard activeRequest == id else { return }
                state = .responding
                store.data.messages.append(ConversationMessage(isUser: false, text: reply))
                try await Task.sleep(for: .seconds(3))
                guard activeRequest == id else { return }
                state = .idle
                activeRequest = nil
            } catch is CancellationError { } catch { self.error = "这次回复没有完成，你的文字已保留。"; state = .idle; activeRequest = nil }
        }
    }
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
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.largeTitle)
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 48, height: 48)
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || state == .thinking || speech.isRecording)
                .accessibilityLabel("发送")
                .accessibilityIdentifier("send-chat")
            }
            HStack(spacing: 12) {
                Button {
                    if speech.isRecording || speech.isStarting { speech.stop() }
                    else { keyboard = false; Task { await speech.start() } }
                } label: { Label(speech.isStarting ? "正在开启…" : speech.isRecording ? "停止录音" : "点击说话", systemImage: speech.isRecording ? "stop.fill" : "mic.fill") }.buttonStyle(PrimaryButton()).disabled(state == .thinking)
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
    private func send() {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, state != .thinking else { return }
        speech.stop()
        store.data.messages.append(ConversationMessage(isUser: true, text: value))
        text = ""; keyboard = false
        requestReply(value)
        MoonHaptics.shared.play(enabled: store.data.haptics)
    }
    private func requestReply(_ value: String) { pendingText = value; error = nil; state = .thinking; activeRequest = UUID() }
}

struct ChatHistoryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var clear = false
    var body: some View {
        List {
            if store.data.messages.isEmpty { ContentUnavailableView("还没有对话", systemImage: "bubble.left.and.bubble.right") }
            ForEach(store.data.messages) { message in VStack(alignment: .leading, spacing: 8) { Text(message.isUser ? "我" : "常曦 · 示例").font(.caption).foregroundStyle(.secondary); Text(message.text); Text(message.date.formatted(date: .abbreviated, time: .shortened)).font(.caption2).foregroundStyle(.secondary) } }
        }.navigationTitle("对话历史")
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }; ToolbarItem(placement: .topBarTrailing) { Button("清空", role: .destructive) { clear = true }.disabled(store.data.messages.isEmpty) } }
        .confirmationDialog("清空本机对话记录？", isPresented: $clear, titleVisibility: .visible) { Button("清空对话", role: .destructive) { store.data.messages = [] } }
    }
}
