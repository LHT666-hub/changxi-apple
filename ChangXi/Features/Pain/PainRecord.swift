import Foundation
import Observation

enum PainRegion: String, CaseIterable, Codable, Identifiable {
    case head = "头部", neck = "肩颈", torso = "胸腹", back = "背腰", arms = "手臂", legs = "腿脚"
    var id: Self { self }
    var crop: CGRect {
        switch self {
        case .head: CGRect(x: 0, y: 0, width: 1, height: 1)
        case .neck: CGRect(x: 0.30, y: 0.10, width: 0.40, height: 0.40)
        case .torso, .back: CGRect(x: 0.28, y: 0.16, width: 0.44, height: 0.44)
        case .arms: CGRect(x: 0.20, y: 0.13, width: 0.60, height: 0.60)
        case .legs: CGRect(x: 0.22, y: 0.40, width: 0.56, height: 0.56)
        }
    }
}

enum PainAngle: String, CaseIterable, Codable, Identifiable {
    case front = "正面", left = "左侧", right = "右侧", back = "背面"
    var id: Self { self }
    var column: CGFloat { self == .left || self == .back ? 1 : 0 }
    var row: CGFloat { self == .right || self == .back ? 1 : 0 }
    var orientation: String {
        switch self {
        case .front: "从正面看：画面左边对应你的右边"
        case .back: "从背后看：画面左边是你的左边"
        case .left: "正在看你身体的左侧"
        case .right: "正在看你身体的右侧"
        }
    }
}

enum PainMarkKind: String, CaseIterable, Codable, Identifiable {
    case point = "一个点", area = "一片", line = "一条"
    var id: Self { self }
    var symbol: String { self == .point ? "smallcircle.filled.circle" : self == .area ? "circle.dashed" : "scribble.variable" }
}

struct PainCoordinate: Codable {
    var x: Double
    var y: Double
}

struct PainMark: Identifiable, Codable {
    var id = UUID()
    var angle: PainAngle
    var kind: PainMarkKind
    var points: [PainCoordinate]
    var name: String? = nil
    var surfacePoint: PainSurfacePoint? = nil
    /// Ordered mesh-local samples for a surface line or enclosed area.
    /// Optional keeps records created by the first point-only model readable.
    var surfacePoints: [PainSurfacePoint]? = nil

    var hasSurfaceLocation: Bool {
        surfacePoint != nil || !(surfacePoints?.isEmpty ?? true)
    }

    var allSurfacePoints: [PainSurfacePoint] {
        if let surfacePoints, !surfacePoints.isEmpty { return surfacePoints }
        return surfacePoint.map { [$0] } ?? []
    }
}

struct PainSurfacePoint: Codable {
    var x: Float
    var y: Float
    var z: Float
    var nx: Float? = nil
    var ny: Float? = nil
    var nz: Float? = nil
    var meshVersion: Int = 1
}

struct PainAssessment: Codable {
    var reporter = "本人描述"
    var intensityWords = "还没选"
    var pattern = "还没选"
    var duration = ""
    var radiation = ""
    var aggravating = ""
    var relieving = ""
    var dailyImpact = "还没选"
    var sleepImpact = "还没选"
}

struct PainRecord: Identifiable, Codable {
    var id = UUID()
    var date = Date.now
    var region: PainRegion = .head
    var marks: [PainMark] = []
    var sensation = "说不清"
    var intensity: Int = 3
    var onset = "开始时间未填写"
    var note = ""
    // Store the illustration version so future artwork changes do not relocate old marks.
    var artworkVersion = 1
    var assessment: PainAssessment?
    var intensityConfirmed: Bool?
    var summary: String {
        let rating = intensityConfirmed == true ? "\(intensity)分" : (assessment?.intensityWords == "还没选" ? nil : assessment?.intensityWords) ?? "程度未填写"
        return "\(region.rawValue)，\(marks.count)处；\(sensation)，\(rating)；\(onset)。"
    }
}

/// Independent local journal until the other computer's app state is synchronized.
/// Does not mutate AppStore or send a health record to any service.
@MainActor @Observable
final class PainJournal {
    private(set) var records: [PainRecord] = []
    private(set) var readError: String?
    private let url: URL

    init(url: URL = URL.documentsDirectory.appending(path: "changxi-pain-v1.json")) {
        self.url = url
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do { records = try JSONDecoder().decode([PainRecord].self, from: Data(contentsOf: url)) }
        catch { readError = "疼痛记录暂时无法读取，原文件已保留。" }
    }

    func save(_ record: PainRecord) throws {
        guard readError == nil else { throw CocoaError(.fileReadCorruptFile) }
        var updated = records
        updated.insert(record, at: 0)
        let bytes = try JSONEncoder().encode(updated)
        try bytes.write(to: url, options: [.atomic, .completeFileProtection])
        records = updated
    }
}
