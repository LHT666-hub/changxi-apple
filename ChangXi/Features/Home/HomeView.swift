import SwiftUI

struct HomeView: View {
    @State private var showChat = false
    @State private var showCamera = false
    @State private var showRecorder = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("常曦")
                        .font(.system(size: 42, weight: .semibold, design: .rounded))
                    Text("有什么需要我一起看看？")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Button {
                    showChat = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "waveform.and.sparkles")
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("和常曦说说")
                                .font(.headline)
                            Text("文字、语音、照片都可以")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .foregroundStyle(.secondary)
                    }
                    .padding(20)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                }
                .buttonStyle(.plain)

                HStack(spacing: 14) {
                    quickAction("拍照", systemImage: "camera.fill") { showCamera = true }
                    quickAction("语音", systemImage: "mic.fill") { showRecorder = true }
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("今天")
                        .font(.title2.bold())
                    VStack(spacing: 0) {
                        insightRow(icon: "heart.text.square.fill", title: "健康事项", detail: "后续从常曦业务 API 接入提醒与进度")
                        Divider().padding(.leading, 48)
                        insightRow(icon: "person.2.fill", title: "家庭医生", detail: "后续接入签约团队与服务网络")
                    }
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
            }
            .padding(20)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showChat) { ChatView() }
        .sheet(isPresented: $showCamera) { CameraPlaceholderView() }
        .sheet(isPresented: $showRecorder) { SpeechPlaceholderView() }
    }

    private func quickAction(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: systemImage).font(.title2)
                Text(title).font(.headline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func insightRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .frame(width: 34, height: 34)
                .background(.quaternary, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(18)
    }
}
