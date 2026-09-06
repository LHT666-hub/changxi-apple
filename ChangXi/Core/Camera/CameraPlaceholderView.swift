import SwiftUI

struct CameraPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "camera.circle.fill")
                    .font(.system(size: 76))
                    .symbolRenderingMode(.hierarchical)
                Text("原生相机入口")
                    .font(.title2.bold())
                Text("下一步接 PhotosUI / AVFoundation，相片上传到常曦后端现有 /api/v1/documents/analyze。")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(28)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
        }
    }
}
