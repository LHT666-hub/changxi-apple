import Foundation
import Observation

struct HealthReading: Codable, Identifiable {
    var id = UUID()
    var kind: MetricKind
    var value: Double
    var secondary: Double?
    var date: Date = .now
    var note = ""
    var display: String {
        if let secondary { return "\(Int(value))/\(Int(secondary))" }
        return value.formatted(.number.precision(.fractionLength(kind == .pressure ? 0 : 1)))
    }
}

enum MetricKind: String, Codable, CaseIterable, Identifiable {
    case pressure = "血压", glucose = "血糖", weight = "体重"
    var id: Self { self }
    var unit: String { switch self { case .pressure: "mmHg"; case .glucose: "mmol/L"; case .weight: "kg" } }
    var icon: String { switch self { case .pressure: "heart.fill"; case .glucose: "drop.fill"; case .weight: "scalemass.fill" } }
    var inputRange: ClosedRange<Double> { switch self { case .pressure: 40...300; case .glucose: 0.5...50; case .weight: 10...400 } }
}

struct DailyPlan: Codable, Identifiable {
    var id = UUID()
    var title: String
    var time: String
    var icon: String
    var detail: String
    var completed = false
    var completedAt: Date?
}

struct MemoryItem: Codable, Identifiable {
    var id = UUID()
    var title: String
    var text: String
    var category: String
    var confirmed = false
    var source = "示例对话 · 9月6日"
}

struct ConversationMessage: Codable, Identifiable {
    var id = UUID()
    var isUser: Bool
    var text: String
    var date: Date = .now
}

struct ServiceBooking: Codable, Identifiable {
    var id = UUID()
    var service: String
    var person: String
    var date: Date
    var note: String
    var cancelled = false
}

struct Medication: Codable, Identifiable {
    var id = UUID()
    var name: String
    var dosage: String
    var instructions: String
    var hour = 20
    var minute = 0
}

struct DoseRecord: Codable, Identifiable {
    var id = UUID()
    var medicationID: UUID
    var medicationName: String
    var date: Date = .now
    var taken: Bool
}

struct ImportedReport: Codable, Identifiable {
    var id = UUID()
    var title: String
    var filename: String
    var date: Date = .now
    var note: String
}

struct LocalState: Codable {
    var name = "张阿姨"
    var person = "张阿姨（本人）"
    var onboarded = false
    var rememberAllowed = true
    var medicationReminders = false
    var healthReminders = false
    var haptics = true
    var largeText = false
    var lastPlanDay = Calendar.current.startOfDay(for: .now)
    var plans = [
        DailyPlan(title: "测血压", time: "08:00", icon: "heart.fill", detail: "记录今天的血压和测量时间。", completed: true),
        DailyPlan(title: "散步20分钟", time: "16:00", icon: "figure.walk", detail: "按自己的节奏，完成后记下一笔。", completed: true),
        DailyPlan(title: "晚间用药", time: "20:00", icon: "pills.fill", detail: "按本人处方核对药名、剂量和时间。此处为演示计划。"),
        DailyPlan(title: "睡前记录", time: "22:00", icon: "moon.zzz.fill", detail: "记下今天的感受，为明天留一份参考。")
    ]
    var memories = [
        MemoryItem(title: "症状自述", text: "最近一周早晨偶尔头晕，通常起床几分钟后缓解。", category: "健康档案"),
        MemoryItem(title: "用药记录", text: "有一份每日晚间用药计划，药名和剂量待本人核对。", category: "健康档案"),
        MemoryItem(title: "交流偏好", text: "喜欢用语音交流，希望提醒简短清楚。", category: "偏好", confirmed: true)
    ]
    var readings: [HealthReading] = Self.sampleReadings
    var messages: [ConversationMessage] = []
    var bookings: [ServiceBooking] = []
    var journal = ""
    var feedback = ""
    var doctorMessageRead = false
    var medications: [Medication] = []
    var doseHistory: [DoseRecord] = []
    var demoSignedIn = false
    var emergencyName = ""
    var emergencyPhone = ""
    var importedReports: [ImportedReport] = []
    static var sampleReadings: [HealthReading] {
        (0..<30).flatMap { day -> [HealthReading] in
            let date = Calendar.current.date(byAdding: .day, value: day - 29, to: .now)!
            return [HealthReading(kind: .pressure, value: Double([124,128,132,126,130,122,128][day % 7]), secondary: Double([76,78,81,77,79][day % 5]), date: date), HealthReading(kind: .glucose, value: 5.4 + Double(day % 5) * 0.1, date: date), HealthReading(kind: .weight, value: 68.4 + Double(day % 4) * 0.1, date: date)]
        }
    }
}

@MainActor @Observable
final class AppStore {
    var data: LocalState { didSet { persist() } }
    var storageError: String?
    private let fileURL: URL
    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? URL.documentsDirectory.appending(path: "changxi-local-demo.json")
        do {
            let bytes = try Data(contentsOf: self.fileURL)
            let defaults = try JSONSerialization.jsonObject(with: JSONEncoder().encode(LocalState())) as! [String: Any]
            guard let saved = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else { throw CocoaError(.fileReadCorruptFile) }
            let merged = defaults.merging(saved) { _, saved in saved }
            data = try JSONDecoder().decode(LocalState.self, from: JSONSerialization.data(withJSONObject: merged))
        } catch {
            data = LocalState()
            if FileManager.default.fileExists(atPath: self.fileURL.path) { storageError = "本地记录未能读取，原文件仍保留。请先导出备份，避免覆盖。" }
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            data = LocalState()
            data.onboarded = true
            if ProcessInfo.processInfo.arguments.contains("--large-text") { data.largeText = true }
        }
        #endif
        refreshDay()
    }
    func persist() {
        guard storageError == nil else { return }
        do {
            let bytes = try JSONEncoder().encode(data)
            try bytes.write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch { storageError = "记录暂时未能保存，请检查设备存储空间。" }
    }
    func refreshDay() {
        let today = Calendar.current.startOfDay(for: .now)
        if data.lastPlanDay != today {
            for index in data.plans.indices { data.plans[index].completed = false; data.plans[index].completedAt = nil }
            data.lastPlanDay = today
        }
    }
    var completed: Int { data.plans.filter(\.completed).count }
    var pendingMemories: Int { data.memories.filter { !$0.confirmed }.count }
    func latest(_ kind: MetricKind) -> HealthReading? { data.readings.filter { $0.kind == kind }.max { $0.date < $1.date } }
    func readings(_ kind: MetricKind, days: Int) -> [HealthReading] {
        let start = Calendar.current.date(byAdding: .day, value: -(days - 1), to: Calendar.current.startOfDay(for: .now))!
        return data.readings.filter { $0.kind == kind && $0.date >= start }.sorted { $0.date < $1.date }
    }
    func togglePlan(_ id: UUID) {
        guard let index = data.plans.firstIndex(where: { $0.id == id }) else { return }
        data.plans[index].completed.toggle()
        data.plans[index].completedAt = data.plans[index].completed ? .now : nil
    }
    func resetDemo() {
        for report in data.importedReports { try? FileManager.default.removeItem(at: reportURL(report)) }
        storageError = nil
        data = LocalState()
    }
    func reportURL(_ report: ImportedReport) -> URL { fileURL.deletingLastPathComponent().appending(path: (report.filename as NSString).lastPathComponent) }
    func saveReport(imageData: Data, title: String, note: String) throws {
        guard storageError == nil else { throw CocoaError(.fileWriteUnknown) }
        let report = ImportedReport(title: title, filename: "report-\(UUID()).jpg", note: note)
        try imageData.write(to: reportURL(report), options: [.atomic, .completeFileProtection])
        data.importedReports.append(report)
    }
    func deleteReport(_ report: ImportedReport) throws {
        let url = reportURL(report)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        data.importedReports.removeAll { $0.id == report.id }
    }
    var exportJSON: String { (try? String(data: JSONEncoder().encode(data), encoding: .utf8)) ?? "{}" }
}
