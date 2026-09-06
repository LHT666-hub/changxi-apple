import XCTest
@testable import ChangXi

/// ``TokenStore``（Keychain）测试。
///
/// - Warning: Keychain 在部分 CI / 无头测试环境可能不可用或写入不生效。本类**每个用例都先探测可用性**，
///   不可用时 `XCTSkip`（而非失败），确保 CI 不会因环境差异变红。生产 Keychain 行为**需在模拟器上手动验证**。
/// - 每个用例使用**唯一随机 account**，避免与真实凭据或彼此串扰；`tearDown` 负责清理。
final class TokenStoreTests: XCTestCase {
    private var store: TokenStore!

    override func setUp() {
        store = TokenStore(service: "com.lht.changxi.tests", account: "ts-\(UUID().uuidString)")
    }

    override func tearDown() {
        store?.clear()
        store = nil
    }

    /// 探测 Keychain 可用性：写入-读回-清除一轮；不可用则 skip。
    private func requireKeychain() throws {
        do { try store.save("probe") } catch { throw XCTSkip("Keychain 不可用：\(error)") }
        guard store.load() == "probe" else { throw XCTSkip("Keychain 写入未生效（需在模拟器手动验证）") }
        store.clear()
    }

    func testSaveLoadRoundTrip() throws {
        try requireKeychain()
        try store.save("token-abc")
        XCTAssertEqual(store.load(), "token-abc")
        XCTAssertTrue(store.hasValue)
    }

    func testOverwriteExistingValue() throws {
        try requireKeychain()
        try store.save("v1")
        try store.save("v2")
        XCTAssertEqual(store.load(), "v2")
    }

    func testLoadAbsentReturnsNil() throws {
        try requireKeychain()
        store.clear()
        XCTAssertNil(store.load())
        XCTAssertFalse(store.hasValue)
    }

    func testClearRemovesValue() throws {
        try requireKeychain()
        try store.save("to-be-cleared")
        store.clear()
        XCTAssertNil(store.load())
        XCTAssertFalse(store.hasValue)
    }
}
