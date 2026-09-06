import SwiftUI

struct ChatView: View {
    @State private var text = ""
    @State private var messages: [ChatMessage] = [
        ChatMessage(role: .assistant, text: "你好，我是常曦。你可以直接告诉我发生了什么，也可以发语音或照片。")
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(16)
                }
                .onChange(of: messages.count) { _, _ in
                    if let id = messages.last?.id {
                        withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                    }
                }
            }

            ComposerView(text: $text, onSend: send)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
        }
        .navigationTitle("常曦")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func send() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages.append(ChatMessage(role: .user, text: trimmed))
        text = ""
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            messages.append(ChatMessage(role: .assistant, text: "第一版原生界面已经跑起来。下一步这里会直接连接常曦后端，而不是在 App 内硬编码回答。"))
        }
    }
}

struct ChatMessage: Identifiable {
    enum Role: Equatable { case user, assistant }
    let id = UUID()
    let role: Role
    let text: String
}

private struct MessageBubble: View {
    let message: ChatMessage
    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 48) }
            Text(message.text)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(message.role == .user ? AnyShapeStyle(.tint) : AnyShapeStyle(.thinMaterial), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .foregroundStyle(message.role == .user ? .white : .primary)
            if message.role == .assistant { Spacer(minLength: 48) }
        }
    }
}

private struct ComposerView: View {
    @Binding var text: String
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: {}) { Image(systemName: "camera") }
                .buttonStyle(.borderless)
            Button(action: {}) { Image(systemName: "mic") }
                .buttonStyle(.borderless)
            TextField("问常曦…", text: $text, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.plain)
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
