import SwiftUI

/// 云端文档管理：从 `GET /api/v1/documents` 拉取已归档文档，支持删除（`DELETE`）。
///
/// 入口挂在「我的 → 健康档案」（``HealthArchiveView``），仅联网（`useRemoteAPI`）时展示。
/// 离线 / UI 测试下 `.task` 直接返回，不发任何网络请求。
struct CloudDocumentsView: View {
    @Environment(AuthSession.self) private var auth
    @State private var documents: [DocumentRecord] = []
    @State private var loading = false
    @State private var error: String?
    @State private var pendingDelete: DocumentRecord?

    /// 当前患者标识：登录后用用户 ID，否则用稳定的本地匿名 UUID。
    private var patientId: String { auth.currentUser?.id ?? RemoteConversationService.localPatientId }

    var body: some View {
        Page(illustrated: true) {
            VStack(alignment: .leading, spacing: CXSpacing.xs) {
                Text("云端文档")
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.actionPrimary)
                    .tracking(0.6)
                Text("只保留你主动归档的资料")
                    .font(CXTypography.display)
                Text("云端副本和本机报告彼此独立；删除云端文档不会删除本机原件。")
                    .font(CXTypography.body)
                    .foregroundStyle(CX.muted)
                    .lineSpacing(5)
            }

            if loading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("正在整理云端文档")
                        .font(CXTypography.supporting)
                        .foregroundStyle(CX.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(CXSpacing.xl)
                .cxContentSurface(cornerRadius: CXRadius.lg)
            }

            if let error {
                VStack(alignment: .leading, spacing: CXSpacing.md) {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(CXTypography.supporting)
                        .foregroundStyle(CX.statusCritical)
                    Button("重新加载") { Task { await load() } }
                        .buttonStyle(PrimaryButton())
                }
                .padding(CXSpacing.lg)
                .background(
                    CX.statusCritical.opacity(0.05),
                    in: .rect(cornerRadius: CXRadius.lg, style: .continuous)
                )
            }

            if !loading && error == nil && documents.isEmpty {
                CXEmptyState(
                    title: "还没有云端文档",
                    message: "导入并主动归档报告后，会集中出现在这里。",
                    icon: "externaldrive"
                )
            }

            if !documents.isEmpty {
                SectionEyebrow(title: "已归档", action: "\(documents.count) 份")
            }

            ForEach(documents) { document in
                VStack(alignment: .leading, spacing: CXSpacing.md) {
                    HStack(spacing: CXSpacing.md) {
                        Image(systemName: "doc.fill")
                            .foregroundStyle(CX.actionPrimary)
                            .frame(width: 44, height: 44)
                            .background(CX.actionPrimary.opacity(0.08), in: Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(document.fileName)
                                .font(CXTypography.section)
                            Text("\(document.docType) · \(ByteCountFormatter.string(fromByteCount: Int64(document.fileSize), countStyle: .file))")
                                .font(CXTypography.meta)
                                .foregroundStyle(CX.muted)
                        }

                        Spacer()
                    }

                    HStack {
                        Text(document.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(CXTypography.micro)
                            .foregroundStyle(CX.muted)
                        Spacer()
                        if !document.isRemoteStorage {
                            Label("暂不支持在线预览", systemImage: "info.circle")
                                .font(CXTypography.micro)
                                .foregroundStyle(CX.muted)
                        }
                    }

                    Button(role: .destructive) {
                        pendingDelete = document
                    } label: {
                        Label("删除云端副本", systemImage: "trash")
                            .font(CXTypography.meta.weight(.semibold))
                    }
                }
                .padding(CXSpacing.lg)
                .cxContentSurface(cornerRadius: CXRadius.lg)
            }

            Text("删除云端副本不会影响本机保存的报告原件。")
                .font(CXTypography.meta)
                .foregroundStyle(CX.muted)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .navigationTitle("云端文档")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .confirmationDialog(
            "删除这份云端文档？",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let document = pendingDelete {
                    Task { await delete(document) }
                }
                pendingDelete = nil
            }
        }
    }

    @MainActor private func load() async {
        guard AppConfiguration.useRemoteAPI, AppConfiguration.supportsExtendedAPI else { return }
        loading = true; error = nil
        defer { loading = false }
        do {
            let page = try await DocumentService().listDocuments(patientID: patientId, page: 1, size: 50)
            documents = page.documents
        } catch is CancellationError {
            // 忽略取消
        } catch let e as APIError {
            error = e.userFacingMessage
        } catch {
            self.error = "云端文档加载失败，请稍后重试。"
        }
    }

    @MainActor private func delete(_ document: DocumentRecord) async {
        do {
            try await DocumentService().deleteDocument(documentID: document.documentId)
            documents.removeAll { $0.documentId == document.documentId }
            error = nil
        } catch is CancellationError {
            // 忽略取消
        } catch let e as APIError {
            error = e.userFacingMessage
        } catch {
            self.error = "删除失败，请稍后重试。"
        }
    }
}
