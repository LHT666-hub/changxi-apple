import SwiftUI

struct SpeechPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 76))
                    .symbolRenderingMode(.hierarchical)
                Text("原生语音入口")
                    .font(.title2.bold())
                Text("下一步接 AVAudioRecorder，并上传到常曦后端现有 /api/v1/speech/transcribe，再把确认后的文字送给常曦。")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(28)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
        }
    }
}
