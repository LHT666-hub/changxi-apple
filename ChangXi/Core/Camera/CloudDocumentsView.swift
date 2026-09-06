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
        Page {
            if loading {
                HStack(spacing: 10) { ProgressView(); Text("正在加载云端文档…").foregroundStyle(CX.muted) }
            }
            if let error {
                Card {
                    Text(error).foregroundStyle(CX.coral)
                    Button("重试") { Task { await load() } }.buttonStyle(.bordered).frame(minHeight: 44)
                }
            }
            if !loading && error == nil && documents.isEmpty {
                ContentUnavailableView("还没有云端文档", systemImage: "externaldrive",
                                       description: Text("导入并识别报告后，会自动归档到这里。"))
            }
            ForEach(documents) { document in
                Card {
                    RowLabel(title: document.fileName,
                             subtitle: "\(document.docType) · \(ByteCountFormatter.string(fromByteCount: Int64(document.fileSize), countStyle: .file))",
                             icon: "doc.fill", chevron: false)
                    Text(document.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption).foregroundStyle(CX.muted)
                    if !document.isRemoteStorage {
                        Label("存储在本机占位路径，暂不支持在线预览。", systemImage: "info.circle")
                            .font(.caption).foregroundStyle(CX.muted)
                    }
                    Button(role: .destructive) { pendingDelete = document } label: {
                        Label("删除云端文档", systemImage: "trash")
                    }.frame(minHeight: 44)
                }
            }
            Text("云端文档由你主动导入并归档。删除只移除云端副本，不影响本机报告。")
                .font(.footnote).foregroundStyle(CX.muted)
        }.navigationTitle("云端文档")
        .task { await load() }
        .confirmationDialog("删除这份云端文档？",
                            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                if let document = pendingDelete { Task { await delete(document) } }
                pendingDelete = nil
            }
        }
    }

    @MainActor private func load() async {
        guard AppConfiguration.useRemoteAPI else { return }
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
            error = "云端文档加载失败，请稍后重试。"
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
            error = "删除失败，请稍后重试。"
        }
    }
}
