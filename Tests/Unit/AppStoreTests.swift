import XCTest
@testable import ChangXi

@MainActor final class AppStoreTests: XCTestCase {
    private var file: URL!
    override func setUp() { file = FileManager.default.temporaryDirectory.appending(path: "changxi-test-\(UUID()).json") }
    override func tearDown() { try? FileManager.default.removeItem(at: file) }
    func testMutationsPersistAndReload() {
        let store = AppStore(fileURL: file)
        store.data.name = "测试用户"
        let id = store.data.plans[2].id
        store.togglePlan(id)
        store.data.memories[0].confirmed = true
        store.data.readings.append(HealthReading(kind: .pressure, value: 121, secondary: 76))
        let reload = AppStore(fileURL: file)
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
}
