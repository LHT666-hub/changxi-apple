import Foundation
import UIKit

// MARK: - 文档分析模式

/// `POST /api/v1/documents/analyze` 的 `mode` 取值。
///
/// 后端响应结构随 mode 变化：`analyze` / `ocr` 返回 `{analysis, document_type, findings, mode}`；
/// `bp` 额外返回 `reading` 结构化血压读数。
enum DocumentMode: String, CaseIterable, Identifiable {
    /// 通用医学文档 / 图片解读（默认）。
    case analyze
    /// 纯文字 OCR 提取。
    case ocr
    /// 血压计读数结构化识别。
    case bp
    var id: Self { self }
}

// MARK: - 血压读数

/// 血压计识别的结构化读数（后端 `reading` 字段，`BPReading.model_dump`）。
///
/// 同时用于：① 解码 analyze(mode=bp) 响应（经 `.convertFromSnakeCase`：`raw_text` → `rawText`）；
/// ② 持久化进 ``ImportedReport/bpReading``（``AppStore`` 用无键策略的 `JSONEncoder`，
/// 直接以驼峰属性名存取，两侧一致）。
/// - Note: `confidence` 为后端识别置信度（0–1），低于 0.6 时应提示用户手动核对。
struct BPReading: Codable {
    /// 收缩压（高压），无法识别时为 `nil`。
    var systolic: Int?
    /// 舒张压（低压），无法识别时为 `nil`。
    var diastolic: Int?
    /// 脉搏，无法识别时为 `nil`。
    var pulse: Int?
    /// 单位（默认 `mmHg`）。
    var unit: String
    /// 识别置信度（0–1）。
    var confidence: Double
    /// 原始识别文本。
    var rawText: String

    /// 是否同时识别到收缩压与舒张压（可存入健康记录的最低条件）。
    var isUsable: Bool { systolic != nil && diastolic != nil }
    /// 置信度是否偏低（< 0.6），UI 需提示手动核对。
    var isLowConfidence: Bool { confidence < 0.6 }
    /// 展示用文本，如 `168/103 mmHg`。
    var display: String {
        guard let systolic, let diastolic else { return rawText.isEmpty ? "未识别到读数" : rawText }
        return "\(systolic)/\(diastolic) \(unit)"
    }
}

// MARK: - 分析响应

/// `POST /api/v1/documents/analyze` 的响应体（兼容三种 mode）。
///
/// `reading` 仅在 `mode == "bp"` 时存在，用 Optional 承接结构差异。
struct DocumentAnalysis: Decodable {
    /// 分析全文（bp 模式为读数摘要，ocr 模式为提取文本）。
    let analysis: String
    /// 文档类型：`medical_document` / `ocr` / `bp_monitor`。
    let documentType: String
    /// 逐条要点（analyze 最多 10 条；ocr 为空数组；bp 为收缩压/舒张压/脉搏条目）。
    let findings: [String]
    /// 回显的 mode。
    let mode: String
    /// 血压结构化读数（仅 bp 模式）。
    let reading: BPReading?
}

// MARK: - 文档归档记录

/// `POST /api/v1/documents`（201）与 `GET /api/v1/documents` 返回的文档元数据记录。
///
/// - Important: 后端未配置 Supabase 时 `storagePath` 为 `local://...` 占位串，**不是可加载 URL**，
///   用 ``isRemoteStorage`` 判断后再决定是否尝试在线加载。
struct DocumentRecord: Decodable, Identifiable {
    /// 文档 ID（后端 `document_id`，与 `id` 相同）。
    let documentId: String
    /// 与 `documentId` 相同，供 `Identifiable` 使用。
    let id: String
    /// 所属患者标识。
    let patientId: String
    /// 文档类型（`lab_report` / `prescription` / `image` / `general` 等）。
    let docType: String
    /// 文件名。
    let fileName: String
    /// 文件字节数。
    let fileSize: Int
    /// MIME 类型。
    let contentType: String
    /// 存储路径；未配云存储时为 `local://...` 占位。
    let storagePath: String
    /// 创建时间（ISO-8601，``APIClient`` 容错解码）。
    let createdAt: Date

    /// 是否为真实远端对象存储（非 `local://` 占位）。
    var isRemoteStorage: Bool { !storagePath.hasPrefix("local://") }
}

/// `GET /api/v1/documents` 的分页响应。
struct DocumentPage: Decodable {
    /// 当前页文档（created_at 新→旧）。
    let documents: [DocumentRecord]
    /// 总条数。
    let total: Int
    /// 当前页码。
    let page: Int
    /// 每页大小。
    let size: Int
}

/// `GET /api/v1/documents/{id}/presign` 的响应。
///
/// - Important: `url` 在未配云存储时为 `local://...` 占位串，用 ``isLoadableURL`` 判断后再加载。
struct PresignedURL: Decodable {
    let documentId: String
    let url: String
    let expiresIn: Int
    let storagePath: String

    /// 是否为可加载的 http(s) URL（排除 `local://` 占位）。
    var isLoadableURL: Bool {
        guard let scheme = URL(string: url)?.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }
}

/// `DELETE /api/v1/documents/{id}` 的响应。
struct DeleteResult: Decodable {
    let deleted: Bool
    let documentId: String
}

// MARK: - 图片预处理

/// 上传前的图片压缩：控制体积（后端不校验大小，iOS 侧自行限制）。
enum ImagePreparer {
    /// 上传体积软上限（20MB）。
    static let maxUploadBytes = 20 * 1024 * 1024

    /// 将图片缩放到长边 ≤ `maxEdge` 并以 JPEG 压缩；超出软上限时进一步降质。
    /// - Returns: 可上传的 JPEG 数据；无法生成时返回 `nil`。
    static func jpegForUpload(_ image: UIImage, maxEdge: CGFloat = 2048, quality: CGFloat = 0.8) -> Data? {
        let size = image.size
        let longest = max(size.width, size.height)
        var prepared = image
        if longest > maxEdge, longest > 0 {
            let scale = maxEdge / longest
            let newSize = CGSize(width: max(1, (size.width * scale).rounded()),
                                 height: max(1, (size.height * scale).rounded()))
            let renderer = UIGraphicsImageRenderer(size: newSize)
            prepared = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        }
        if let data = prepared.jpegData(compressionQuality: quality), data.count <= maxUploadBytes {
            return data
        }
        // 超出软上限：降质重试一次。
        if let data = prepared.jpegData(compressionQuality: 0.5), data.count <= maxUploadBytes {
            return data
        }
        // 仍超限：返回最低质量结果，交由上层决定是否放弃上传。
        return prepared.jpegData(compressionQuality: 0.3)
    }
}

// MARK: - 文档服务

/// 文档服务：桥接玄同后端 `/api/v1/documents` 全套端点。
///
/// 全部经 ``APIClient``（自动注入 Bearer、snake_case↔camelCase、容错日期、统一 ``APIError``），
/// 不自行构造 `URLRequest`。`Sendable`（仅持有 `Sendable` 的 ``APIClient``）。
struct DocumentService: Sendable {
    let api: APIClient
    init(api: APIClient = .shared) { self.api = api }

    /// 图片 / 文档内容分析（`POST /api/v1/documents/analyze`，multipart）。
    /// - Parameters:
    ///   - imageData: 图片字节（建议先经 ``ImagePreparer`` 压缩）。
    ///   - filename: 上传文件名。
    ///   - mime: MIME 类型（后端 fallback 固定 `image/jpeg`）。
    ///   - mode: 分析模式（`analyze` / `ocr` / `bp`）。
    ///   - prompt: 自定义提示词（仅 `analyze` 模式生效）。
    /// - Returns: ``DocumentAnalysis``（`bp` 模式含 `reading`）。
    func analyze(
        imageData: Data,
        filename: String,
        mime: String,
        mode: DocumentMode = .analyze,
        prompt: String? = nil
    ) async throws -> DocumentAnalysis {
        var fields: [String: String] = ["mode": mode.rawValue]
        if let prompt, !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fields["prompt"] = prompt
        }
        return try await api.postMultipart(
            "documents/analyze",
            fields: fields,
            file: (name: "file", filename: filename, mime: mime, data: imageData),
            prefix: .v1
        )
    }

    /// 文档归档上传（`POST /api/v1/documents`，201，multipart）。
    /// - Parameters:
    ///   - fileData: 文件字节（非空，否则后端 422）。
    ///   - filename: 文件名。
    ///   - mime: MIME 类型。
    ///   - patientID: 所属患者标识（Form 字段 `patient_id`，必填，空白 → 422）。
    ///   - docType: 文档类型（Form 字段 `doc_type`，建议 `lab_report` / `prescription` / `image`）。
    /// - Returns: 归档记录 ``DocumentRecord``（含 `documentId`）。
    func uploadDocument(
        fileData: Data,
        filename: String,
        mime: String,
        patientID: String,
        docType: String = "general"
    ) async throws -> DocumentRecord {
        let fields = ["patient_id": patientID, "doc_type": docType]
        return try await api.postMultipart(
            "documents",
            fields: fields,
            file: (name: "file", filename: filename, mime: mime, data: fileData),
            prefix: .v1
        )
    }

    /// 分页列出患者文档（`GET /api/v1/documents?patient_id=&page=&size=`）。
    /// - Returns: ``DocumentPage``（`documents` 按 created_at 新→旧）。
    func listDocuments(patientID: String, page: Int = 1, size: Int = 20) async throws -> DocumentPage {
        try await api.get(
            "documents",
            query: ["patient_id": patientID, "page": String(page), "size": String(size)],
            prefix: .v1
        )
    }

    /// 生成文档对象的预签名下载 URL（`GET /api/v1/documents/{id}/presign`）。
    /// - Parameter expiresIn: 有效期秒数（1–86400，`nil` 时用后端默认）。
    /// - Returns: ``PresignedURL``（`url` 可能是 `local://` 占位，用 `isLoadableURL` 判断）。
    func presignURL(documentID: String, expiresIn: Int? = nil) async throws -> PresignedURL {
        var query: [String: String]?
        if let expiresIn { query = ["expires_in": String(expiresIn)] }
        return try await api.get("documents/\(documentID)/presign", query: query, prefix: .v1)
    }

    /// 删除文档（`DELETE /api/v1/documents/{id}`）。
    /// - Note: 内部解码 ``DeleteResult`` 后丢弃；404 抛 ``APIError``。
    func deleteDocument(documentID: String) async throws {
        let _: DeleteResult = try await api.delete("documents/\(documentID)", prefix: .v1)
    }
}
