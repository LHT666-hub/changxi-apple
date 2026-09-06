import SwiftUI
import PhotosUI
import AVFoundation

struct ReportImportView: View {
    var onAttach: ((String) -> Void)? = nil
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var photo: PhotosPickerItem?
    @State private var preview: UIImage?
    @State private var camera = false
    @State private var loading = false
    @State private var error: String?
    @State private var note = ""
    @State private var title = "我的报告"
    @State private var saved = false
    var body: some View {
        Page {
            Card {
                RowLabel(title: "拍照 / 报告", subtitle: "只读取你主动选择的照片", icon: "camera", chevron: false)
                if let preview { Image(uiImage: preview).resizable().scaledToFit().frame(maxHeight: 350).clipShape(RoundedRectangle(cornerRadius: 16)).accessibilityLabel("所选报告照片预览") }
                else { ContentUnavailableView("选择一张清晰的照片", systemImage: "doc.viewfinder", description: Text("可以拍摄报告，也可以从相册选择。")) }
                if loading { ProgressView("正在读取照片…") }
                PhotosPicker(selection: $photo, matching: .images) { Label("从相册选择", systemImage: "photo") }.buttonStyle(.bordered).frame(minHeight: 44)
                Button { Task { await openCamera() } } label: { Label("拍摄照片", systemImage: "camera") }.frame(minHeight: 44)
                if let error { Text(error).foregroundStyle(CX.coral); Button("打开系统设置") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } } }
                if preview != nil {
                    TextField("报告名称", text: $title)
                    TextField("关于这份报告，想问什么？", text: $note, axis: .vertical).lineLimit(2...5)
                    Text("照片不会上传。你可以保存到本机报告列表，或把文字说明加入对话。报告识别尚未接通。").font(.footnote).foregroundStyle(CX.muted)
                    Button(saved ? "已保存到本机报告" : "保存报告到本机") {
                        guard let bytes = preview?.jpegData(compressionQuality: 0.85) else { error = "无法保存这张照片，请重新选择。"; return }
                        do { try store.saveReport(imageData: bytes, title: title.isEmpty ? "我的报告" : title, note: note); saved = true; error = nil }
                        catch { self.error = "报告未能保存，请检查设备存储空间后重试。" }
                    }.buttonStyle(PrimaryButton()).disabled(saved)
                    if let onAttach {
                        Button("将文字说明加入对话") { onAttach(note.isEmpty ? "我选择了一份报告照片，想了解如何查看指标。" : note); dismiss() }.buttonStyle(PrimaryButton())
                    } else {
                        NavigationLink("查看报告演示") { ReportDetailView() }.buttonStyle(PrimaryButton())
                    }
                }
            }
        }.navigationTitle("添加报告")
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } } }
        .sheet(isPresented: $camera) { CameraCapture { image in if let image { preview = image }; camera = false } }
        .task(id: photo) {
            guard let photo else { return }
            loading = true; error = nil
            defer { loading = false }
            do {
                guard let data = try await photo.loadTransferable(type: Data.self), let image = UIImage(data: data) else { error = "无法读取这张照片，请换一张重试。"; return }
                try Task.checkCancellation()
                preview = image
                saved = false
            } catch is CancellationError { } catch { self.error = "照片读取失败，请重新选择。" }
        }
    }
    private func openCamera() async {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { error = "当前设备没有可用相机，请从相册选择。"; return }
        let authorized = await AVCaptureDevice.requestAccess(for: .video)
        if authorized { camera = true; error = nil } else { error = "相机权限未开启，你可以从相册选择照片。" }
    }
}

struct CameraCapture: UIViewControllerRepresentable {
    var onResult: (UIImage?) -> Void
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }
    func makeCoordinator() -> Coordinator { Coordinator(onResult: onResult) }
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onResult: (UIImage?) -> Void
        init(onResult: @escaping (UIImage?) -> Void) { self.onResult = onResult }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onResult(nil) }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) { onResult(info[.originalImage] as? UIImage) }
    }
}
