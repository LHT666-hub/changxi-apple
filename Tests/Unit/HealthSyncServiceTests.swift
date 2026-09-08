import XCTest
@testable import ChangXi

/// ``HealthSyncService`` 的**纯静态、离线**逻辑测试：工作流触发阈值、事件 payload 构造、ISO-8601 容错解析。
///
/// 这三个方法都是 `nonisolated static`，无网络、无 Keychain，可确定性单测。
/// 涉及 `AppConfiguration.useRemoteAPI == false`（`--ui-testing`）时零请求的分支，
/// 由代码审查（每个上行/下行/归档方法首行都有 `guard useRemoteAPI else { return }`）+ UI 测试覆盖，
/// 单元测试环境 `useRemoteAPI == true`，无法在此注入，故不在此重复测试。
final class HealthSyncServiceTests: XCTestCase {
    private func reading(_ kind: MetricKind, _ value: Double, _ secondary: Double? = nil, note: String = "") -> HealthReading {
        HealthReading(kind: kind, value: value, secondary: secondary, note: note)
    }

    private func encodedJSON(_ payload: [String: EventPayloadValue]) throws -> String {
        let data = try APIClient.makeEncoder().encode(payload)
        return try XCTUnwrap(String(data: data, encoding: .utf8))
    }

    func testTriggersWorkflowThresholds() {
        // 血压：收缩压 >= 140 或 舒张压 >= 90。
        XCTAssertTrue(HealthSyncService.triggersWorkflow(reading(.pressure, 140, 80)))
        XCTAssertTrue(HealthSyncService.triggersWorkflow(reading(.pressure, 130, 90)))
        XCTAssertFalse(HealthSyncService.triggersWorkflow(reading(.pressure, 139, 89)))
        // 血糖：>= 7.0 或 < 3.9。
        XCTAssertTrue(HealthSyncService.triggersWorkflow(reading(.glucose, 7.0)))
        XCTAssertTrue(HealthSyncService.triggersWorkflow(reading(.glucose, 3.8)))
        XCTAssertFalse(HealthSyncService.triggersWorkflow(reading(.glucose, 5.5)))
        // 体重：从不触发工作流。
        XCTAssertFalse(HealthSyncService.triggersWorkflow(reading(.weight, 200)))
    }

    func testPayloadBloodPressure() throws {
        let payload = HealthSyncService.payload(for: reading(.pressure, 150, 95, note: "头晕"))
        let json = try encodedJSON(payload)
        XCTAssertTrue(json.contains("\"systolic\":150"), json)
        XCTAssertTrue(json.contains("\"diastolic\":95"), json)
        XCTAssertTrue(json.contains("\"symptom\":\"头晕\""), json)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: APIClient.makeEncoder().encode(payload)) as? [String: Any])
        let measurements = try XCTUnwrap(object["measurements"] as? [[String: Any]])
        XCTAssertEqual(measurements.first?["type"] as? String, "blood_pressure")
        XCTAssertEqual(measurements.first?["unit"] as? String, "mmHg")
        XCTAssertEqual(measurements.first?["secondary_value"] as? Double, 95)
    }

    func testPayloadGlucoseAndWeight() throws {
        let glucose = try encodedJSON(HealthSyncService.payload(for: reading(.glucose, 8.2)))
        XCTAssertTrue(glucose.contains("\"value\":8.2"), glucose)
        XCTAssertTrue(glucose.contains("\"unit\":\"mmol/L\""), glucose)

        let weight = try encodedJSON(HealthSyncService.payload(for: reading(.weight, 62.5)))
        XCTAssertTrue(weight.contains("\"value\":62.5"), weight)
        XCTAssertTrue(weight.contains("\"unit\":\"kg\""), weight)
    }

    func testPayloadOmitsBlankSymptom() throws {
        let payload = HealthSyncService.payload(for: reading(.pressure, 120, 80, note: "   "))
        XCTAssertNil(payload["symptom"], "备注为空白时不应写入 symptom")
    }

    func testDateFromISO() throws {
        XCTAssertNotNil(HealthSyncService.date(fromISO: "2026-01-02T03:04:05Z"))
        XCTAssertNotNil(HealthSyncService.date(fromISO: "2026-01-02T03:04:05.500Z"))
        XCTAssertNil(HealthSyncService.date(fromISO: nil))
        XCTAssertNil(HealthSyncService.date(fromISO: ""))
        XCTAssertNil(HealthSyncService.date(fromISO: "不是日期"))
        let a = try XCTUnwrap(HealthSyncService.date(fromISO: "2026-01-02T03:04:05Z"))
        let b = try XCTUnwrap(HealthSyncService.date(fromISO: "2026-01-02T03:04:06Z"))
        XCTAssertEqual(b.timeIntervalSince(a), 1, accuracy: 0.001)
    }
}
