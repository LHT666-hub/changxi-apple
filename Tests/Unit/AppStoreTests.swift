import XCTest
@testable import ChangXi

@MainActor final class AppStoreTests: XCTestCase {
    private var file: URL!
    override func setUp() { file = FileManager.default.temporaryDirectory.appending(path: "changxi-test-\(UUID()).json") }
    override func tearDown() { try? FileManager.default.removeItem(at: file) }
    func testMutationsPersistAndReload() {
        let store = AppStore(fileURL: file)
        let patientID = store.data.patientID
        store.data.name = "测试用户"
        let id = store.data.plans[2].id
        store.togglePlan(id)
        store.data.memories[0].confirmed = true
        store.data.readings.append(HealthReading(kind: .pressure, value: 121, secondary: 76))
        let reload = AppStore(fileURL: file)
        XCTAssertEqual(reload.data.patientID, patientID)
        XCTAssertEqual(reload.data.name, "测试用户")
        XCTAssertTrue(reload.data.plans.first { $0.id == id }!.completed)
        XCTAssertTrue(reload.data.memories[0].confirmed)
        XCTAssertEqual(reload.latest(.pressure)?.display, "121/76")
    }
    func testNewDayResetsPlanButPreservesReadings() {
        let store = AppStore(fileURL: file)
        store.data.lastPlanDay = .distantPast
        let count = store.data.readings.count
        store.refreshDay()
        XCTAssertEqual(store.completed, 0)
        XCTAssertEqual(store.data.readings.count, count)
        XCTAssertTrue(store.data.plans.allSatisfy { $0.completedAt == nil })
    }
    func testCorruptStoreIsNotOverwritten() throws {
        let original = Data("invalid-json".utf8)
        try original.write(to: file)
        let store = AppStore(fileURL: file)
        XCTAssertNotNil(store.storageError)
        store.data.name = "不会覆盖"
        XCTAssertEqual(try Data(contentsOf: file), original)
    }
    func testTrendFiltersAndDeletionPersist() {
        let store = AppStore(fileURL: file)
        XCTAssertEqual(store.readings(.pressure, days: 7).count, 7)
        XCTAssertEqual(store.readings(.pressure, days: 30).count, 30)
        let id = store.data.memories[0].id
        store.data.memories.removeAll { $0.id == id }
        XCTAssertFalse(AppStore(fileURL: file).data.memories.contains { $0.id == id })
    }
    func testMedicationAndBookingHistoryPersistIndependently() {
        let store = AppStore(fileURL: file)
        let medication = Medication(name: "测试药品", dosage: "依本人处方", instructions: "测试记录")
        store.data.medications.append(medication)
        store.data.doseHistory.append(DoseRecord(medicationID: medication.id, medicationName: medication.name, taken: false))
        store.data.medications.removeAll()
        store.data.bookings.append(ServiceBooking(service: "检查预约", person: "本人", date: .now, note: "测试"))
        store.data.bookings[0].cancelled = true
        let reload = AppStore(fileURL: file)
        XCTAssertEqual(reload.data.doseHistory.count, 1)
        XCTAssertFalse(reload.data.doseHistory[0].taken)
        XCTAssertTrue(reload.data.medications.isEmpty)
        XCTAssertTrue(reload.data.bookings[0].cancelled)
    }
    func testReportFileAndMetadataLifecycle() throws {
        let store = AppStore(fileURL: file)
        try store.saveReport(imageData: Data([1, 2, 3]), title: "测试报告", note: "本机")
        let report = try XCTUnwrap(store.data.importedReports.first)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.reportURL(report).path))
        XCTAssertEqual(AppStore(fileURL: file).data.importedReports.count, 1)
        try store.deleteReport(report)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.reportURL(report).path))
        XCTAssertTrue(AppStore(fileURL: file).data.importedReports.isEmpty)
    }

    func testAssistantFillAcceptsOneClearBloodPressureReading() {
        let reading = AssistantFillParser.bloodPressure(from: "今天晨起血压 123/77 mmHg")
        XCTAssertEqual(reading?.systolic, "123")
        XCTAssertEqual(reading?.diastolic, "77")
    }

    func testAssistantFillRejectsAmbiguousOrInvalidBloodPressure() {
        XCTAssertNil(AssistantFillParser.bloodPressure(from: "早上 123/77，晚上 128/80"))
        XCTAssertNil(AssistantFillParser.bloodPressure(from: "血压 80/120"))
        XCTAssertNil(AssistantFillParser.bloodPressure(from: "日期 2026/09/07"))
    }
}
