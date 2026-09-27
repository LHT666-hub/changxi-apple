import SwiftUI
import PhotosUI
import AVFoundation

struct ReportImportView: View {
    var onAttach: ((String) -> Void)? = nil
    @Environment(AppStore.self) private var store
    @Environment(AuthSession.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var photo: PhotosPickerItem?
    @State private var preview: UIImage?
    @State private var camera = false
    @State private var loading = false
    @State private var error: String?
    @State private var note = ""
    @State private var title = "我的报告"
    @State private var saved = false
    // 云端识别 / 归档状态
    @State private var mode: DocumentMode = .analyze
    @State private var analyzing = false
    @State private var analysis: DocumentAnalysis?
    @State private var analysisError: String?
    @State private var archiving = false
    @State private var archivedDocumentID: String?
    @State private var readingSaved = false

    /// 当前患者标识：登录后用用户 ID，否则用稳定的本地匿名 UUID（与对话页一致）。
    private var patientId: String { auth.currentUser?.id ?? RemoteConversationService.localPatientId }

    var body: some View {
        Page(illustrated: true) {
            VStack(alignment: .leading, spacing: CXSpacing.xs) {
                Text("健康资料")
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.actionPrimary)
                    .textCase(.uppercase)
                    .tracking(0.8)

                Text("添加体检报告")
                    .font(CXTypography.display)

                Text("拍摄或选择一张报告图片，常曦会帮你整理重点。")
                    .font(CXTypography.body)
                    .foregroundStyle(CX.muted)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, CXSpacing.xs)

            if AppConfiguration.useRemoteAPI && AppConfiguration.supportsExtendedAPI {
                VStack(alignment: .leading, spacing: CXSpacing.sm) {
                    SectionEyebrow(title: "识别方式", action: mode == .bp ? "血压计" : "体检报告")
                    Picker("识别类型", selection: $mode) {
                        Text("体检报告").tag(DocumentMode.analyze)
                        Text("血压计").tag(DocumentMode.bp)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(CXSpacing.lg)
                .cxContentSurface(cornerRadius: CXRadius.lg)
            }

            SectionEyebrow(title: preview == nil ? "选择报告" : "报告预览", action: preview == nil ? "照片或拍摄" : "可重新选择")

            if let preview {
                reportPreview(preview)
                analysisSection
                reportDetails

                privacyNote

                Button(saved ? "已保存到本机报告" : "保存这份报告") {
                    saveReport()
                }
                .buttonStyle(PrimaryButton())
                .disabled(saved)
                .accessibilityIdentifier("report-import-save")

                if archiving {
                    HStack(spacing: 10) {
                        ProgressView().scaleEffect(0.84)
                        Text("正在同步报告")
                            .font(CXTypography.supporting)
                            .foregroundStyle(CX.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                } else if archivedDocumentID != nil {
                    Label("报告已同步", systemImage: "checkmark.seal.fill")
                        .font(CXTypography.supporting)
                        .foregroundStyle(CX.statusPositive)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                if let onAttach {
                    Button {
                        onAttach(note.isEmpty ? "我选择了一份报告照片，想了解如何查看指标。" : note)
                        dismiss()
                    } label: {
                        Label("带着这份报告去问常曦", systemImage: "bubble.left.and.text.bubble.right")
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.bordered)
                } else {
                    NavigationLink {
                        ReportDetailView()
                    } label: {
                        Label("查看报告整理", systemImage: "doc.text.magnifyingglass")
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                reportSourcePicker
            }

            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(CXTypography.supporting)
                    .foregroundStyle(CX.statusCritical)
                    .padding(CXSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(CX.statusCritical.opacity(0.07), in: .rect(cornerRadius: CXRadius.md, style: .continuous))

                Button("打开系统设置") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(CXTypography.supporting.weight(.semibold))
            }
        }
        .navigationTitle("添加报告")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") { dismiss() }
            }
        }
        .sheet(isPresented: $camera) {
            CameraCapture { image in
                if let image {
                    preview = image
                    afterImageLoaded()
                }
                camera = false
            }
        }
        .task(id: photo) {
            guard let photo else { return }
            loading = true
            error = nil
            defer { loading = false }
            do {
                guard let data = try await photo.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    error = "无法读取这张照片，请换一张重试。"
                    return
                }
                try Task.checkCancellation()
                preview = image
                afterImageLoaded()
            } catch is CancellationError {
            } catch {
                self.error = "照片读取失败，请重新选择。"
            }
        }
        .onChange(of: mode) { _, _ in
            if preview != nil {
                readingSaved = false
                runAnalysis()
            }
        }
        .assistantFormContext(title: "报告问题", draft: note) { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }
            note = trimmed
            return true
        }
    }

    private var reportSourcePicker: some View {
        VStack(spacing: CXSpacing.lg) {
            ZStack {
                Circle()
                    .fill(CX.actionPrimary.opacity(0.055))
                    .frame(width: 112, height: 112)

                Circle()
                    .stroke(CX.brandMoonlight.opacity(0.18), lineWidth: 1)
                    .frame(width: 138, height: 138)

                Image(systemName: "doc.viewfinder")
                    .font(.system(size: 42, weight: .light))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(CX.actionPrimary)
            }

            VStack(spacing: CXSpacing.xs) {
                Text("选择一张清晰的报告图片")
                    .font(CXTypography.title)
                    .multilineTextAlignment(.center)

                Text("尽量拍全四角、避免反光。")
                    .font(CXTypography.supporting)
                    .foregroundStyle(CX.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 420)
            }

            if loading {
                MoonLoadingIndicator(label: "正在读取照片")
                    .padding(.vertical, CXSpacing.sm)
            } else {
                VStack(spacing: CXSpacing.sm) {
                    PhotosPicker(selection: $photo, matching: .images) {
                        Label("从相册选择", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButton())
                    .accessibilityIdentifier("report-import-photo")

                    Button {
                        Task { await openCamera() }
                    } label: {
                        Label("拍摄报告", systemImage: "camera")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 54)
                    }
                    .buttonStyle(.plain)
                    .cxInteractiveGlass(cornerRadius: CXRadius.md)
                    .accessibilityIdentifier("report-import-camera")
                }
                .frame(maxWidth: 460)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CXSpacing.xl)
        .padding(.horizontal, CXSpacing.lg)
        .cxContentSurface(cornerRadius: CXRadius.lg)
    }

    private func reportPreview(_ image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: CXSpacing.md) {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 360)
                    .clipShape(.rect(cornerRadius: CXRadius.md, style: .continuous))
                    .accessibilityLabel("所选报告照片预览")

                Label("已选择", systemImage: "checkmark.circle.fill")
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.ink)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 30)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(12)
            }

            HStack(spacing: CXSpacing.sm) {
                PhotosPicker(selection: $photo, matching: .images) {
                    Label("换一张", systemImage: "photo")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await openCamera() }
                } label: {
                    Label("重新拍", systemImage: "camera")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(CXSpacing.md)
        .cxContentSurface(cornerRadius: CXRadius.lg)
    }

    private var reportDetails: some View {
        VStack(alignment: .leading, spacing: CXSpacing.md) {
            SectionEyebrow(title: "报告信息", action: "可以稍后修改")

            VStack(alignment: .leading, spacing: 7) {
                Text("报告名称")
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.muted)
                TextField("例如：年度体检报告", text: $title)
                    .padding(.horizontal, CXSpacing.md)
                    .frame(minHeight: 52)
                    .background(CX.raisedSurface, in: .rect(cornerRadius: CXRadius.sm, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("想重点了解什么？")
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.muted)
                TextField("例如：哪些指标需要继续关注？", text: $note, axis: .vertical)
                    .lineLimit(3...6)
                    .padding(CXSpacing.md)
                    .background(CX.raisedSurface, in: .rect(cornerRadius: CXRadius.sm, style: .continuous))
            }
        }
        .padding(CXSpacing.lg)
        .cxContentSurface(cornerRadius: CXRadius.lg)
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: CXSpacing.sm) {
            Image(systemName: "lock.shield")
                .foregroundStyle(CX.actionPrimary)
            Text("只有你主动导入的报告才会被处理。")
                .font(CXTypography.meta)
                .foregroundStyle(CX.muted)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, CXSpacing.xs)
    }

    // MARK: - 识别结果

    @ViewBuilder private var analysisSection: some View {
        if (AppConfiguration.useRemoteAPI && AppConfiguration.supportsExtendedAPI) {
            if analyzing {
                HStack(spacing: 10) { ProgressView(); Text(mode == .bp ? "正在识别血压读数…" : "正在识别报告…").foregroundStyle(CX.muted) }
            } else if let analysisError {
                VStack(alignment: .leading, spacing: 10) {
                    Label(analysisError, systemImage: "exclamationmark.triangle.fill").foregroundStyle(CX.coral)
                    Button("重新识别") { runAnalysis() }.buttonStyle(.bordered).frame(minHeight: 44)
                    Text("识别失败不影响照片保存，你仍可以保存到本机。").font(.footnote).foregroundStyle(CX.muted)
                }
            } else if let analysis {
                if mode == .bp, let reading = analysis.reading { bpResult(reading) }
                else { analysisResult(analysis) }
            }
        }
    }

    @ViewBuilder private func analysisResult(_ analysis: DocumentAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            Label("识别结果", systemImage: "sparkles").font(.headline)
            if analysis.analysis.isEmpty { Text("未能从这张照片中提取到文字信息。").foregroundStyle(CX.muted) }
            else { Text(analysis.analysis).lineSpacing(5) }
            if !analysis.findings.isEmpty {
                Text("关注要点").font(.subheadline).foregroundStyle(CX.muted)
                ForEach(Array(analysis.findings.enumerated()), id: \.offset) { _, finding in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "circle.fill").font(.system(size: 6)).foregroundStyle(CX.teal).padding(.top, 7)
                        Text(finding).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                    .background(CX.mist.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
                }
            }
            Text("识别结果仅供参考，不能代替医生诊断。请对照原始报告核对。").font(.footnote).foregroundStyle(CX.muted)
        }
    }

    @ViewBuilder private func bpResult(_ reading: BPReading) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            Label("血压读数", systemImage: "heart.fill").font(.headline)
            Text(reading.display).font(.largeTitle.bold()).monospacedDigit()
            if let pulse = reading.pulse { Text("脉搏 \(pulse) 次/分").foregroundStyle(CX.muted) }
            if reading.isLowConfidence {
                Label("识别置信度较低（\(Int((reading.confidence * 100).rounded()))%），请对照血压计手动核对。", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote).foregroundStyle(CX.coral)
            }
            if reading.isUsable {
                Button(readingSaved ? "已存入健康记录" : "一键存入健康记录") { saveReading(reading) }
                    .buttonStyle(PrimaryButton()).disabled(readingSaved)
            } else {
                Text("未能识别到完整的收缩压 / 舒张压，请手动记录。").font(.footnote).foregroundStyle(CX.muted)
            }
        }
    }

    // MARK: - 动作

    private func afterImageLoaded() {
        saved = false
        readingSaved = false
        analysis = nil
        analysisError = nil
        archivedDocumentID = nil
        runAnalysis()
    }

    /// 调用后端 analyze 做识别。离线（`useRemoteAPI == false`，含 UI 测试）时不发任何网络请求。
    private func runAnalysis() {
        guard (AppConfiguration.useRemoteAPI && AppConfiguration.supportsExtendedAPI), let image = preview else { return }
        analyzing = true; analysisError = nil; analysis = nil
        let currentMode = mode
        Task { @MainActor in
            defer { analyzing = false }
            guard let upload = ImagePreparer.jpegForUpload(image) else { analysisError = "无法处理这张照片，请重新选择。"; return }
            do {
                let result = try await DocumentService().analyze(imageData: upload, filename: "report.jpg", mime: "image/jpeg", mode: currentMode)
                try Task.checkCancellation()
                analysis = result
            } catch is CancellationError {
                return
            } catch let e as APIError {
                analysisError = e.userFacingMessage
            } catch {
                analysisError = "识别失败，请稍后重试。照片会保留在本机。"
            }
        }
    }

    /// 保存报告：先本机落盘（照片绝不丢），再尽力归档到云端并回填 documentID。
    private func saveReport() {
        guard let image = preview else { error = "无法保存这张照片，请重新选择。"; return }
        guard let bytes = image.jpegData(compressionQuality: 0.85) else { error = "无法保存这张照片，请重新选择。"; return }
        do {
            try store.saveReport(imageData: bytes, title: title.isEmpty ? "我的报告" : title, note: note)
        } catch {
            self.error = "报告未能保存，请检查设备存储空间后重试。"; return
        }
        guard let savedID = store.data.importedReports.last?.id,
              let index = store.data.importedReports.firstIndex(where: { $0.id == savedID }) else {
            saved = true; error = nil; return
        }
        store.data.importedReports[index].analysisText = analysis?.analysis
        store.data.importedReports[index].findings = analysis?.findings
        if mode == .bp { store.data.importedReports[index].bpReading = analysis?.reading }
        saved = true; error = nil
        // 云端归档：离线时完全不发请求；失败静默（本机已保存）。
        guard (AppConfiguration.useRemoteAPI && AppConfiguration.supportsExtendedAPI) else { return }
        archiving = true
        Task { @MainActor in
            defer { archiving = false }
            guard let upload = ImagePreparer.jpegForUpload(image) else { return }
            do {
                let record = try await DocumentService().uploadDocument(fileData: upload, filename: "report.jpg", mime: "image/jpeg", patientID: patientId, docType: "lab_report")
                archivedDocumentID = record.documentId
                if let i = store.data.importedReports.firstIndex(where: { $0.id == savedID }) {
                    store.data.importedReports[i].documentID = record.documentId
                }
            } catch {
                // 静默：本机照片已保存，云端归档失败不打断用户。
            }
        }
    }

    /// 一键把识别到的血压写入本机健康记录（``MetricKind/pressure``）。
    private func saveReading(_ reading: BPReading) {
        guard let systolic = reading.systolic, let diastolic = reading.diastolic else { return }
        store.data.readings.append(HealthReading(kind: .pressure, value: Double(systolic), secondary: Double(diastolic), note: "来自血压计拍照识别"))
        readingSaved = true
        MoonHaptics.shared.play(success: true, enabled: store.data.haptics)
        // Task #25 移交3：本地写入成功后，尽力把这条血压同步到云端（离线不发请求，失败只标记「待同步」）。
        if let saved = store.data.readings.last {
            HealthSyncService.shared.enqueueUpload(saved, store: store, patientID: patientId)
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
