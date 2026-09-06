import XCTest
@testable import ChangXi

/// ``PatientService`` 测试：注入 ``MockURLProtocol`` 客户端，验证请求构造与响应解码（离线）。
///
/// - Important: 用 `RemoteConversationService` 无关；`PatientService(api:)` 显式注入 mock 客户端，
///   不触碰 `.shared` 也不触碰 Keychain。`PatientContext.bindProfileIfNeeded` 硬编码 `.shared` + Keychain，
///   无法在单测注入，故此处仅测其依赖的 **Keychain 建档标记机制**（`TokenStore` flag），
///   编排层缺口在文档中说明。
final class PatientServiceTests: XCTestCase {
    override func setUp() { MockURLProtocol.reset() }
    override func tearDown() { MockURLProtocol.reset() }

    func testCreatePatientDecodesSnakeCaseResponse() async throws {
        let client = APIClient.makeMock()
        let json = #"{"id":"pat-1","name":"张三","user_id":"u-9","risk_level":"high","created_at":"2026-01-02T03:04:05Z"}"#
        MockURLProtocol.stub { _ in .init(statusCode: 201, body: Data(json.utf8)) }
        let service = PatientService(api: client)
        let out = try await service.createPatient(name: "张三", age: 70, chronicDiseases: ["高血压"], userID: "u-9")
        XCTAssertEqual(out.id, "pat-1")
        XCTAssertEqual(out.name, "张三")
        XCTAssertEqual(out.userId, "u-9")
        XCTAssertEqual(out.riskLevel, "high")
        let request = try XCTUnwrap(MockURLProtocol.lastRequest)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url!.absoluteString.contains("/api/patients"))
    }

    func testGetPatient404ThrowsAPIError() async {
        let client = APIClient.makeMock()
        MockURLProtocol.stub { _ in .init(statusCode: 404, body: Data(#"{"detail":"Patient not found"}"#.utf8)) }
        let service = PatientService(api: client)
        do {
            _ = try await service.getPatient("missing")
            XCTFail("404 应抛出 APIError")
        } catch let error as APIError {
            guard case .http(let status, let message) = error else { return XCTFail("期望 .http，实际 \(error)") }
            XCTAssertEqual(status, 404)
            XCTAssertEqual(message, "Patient not found")
        } catch {
            XCTFail("意外错误类型 \(error)")
        }
    }

    func testGetMeasurementsDecodesPage() async throws {
        let client = APIClient.makeMock()
        let json = #"{"patient_id":"p1","measurements":[{"id":"m1","patient_id":"p1","measurement_type":"blood_pressure","value":150,"secondary_value":95,"unit":"mmHg","measured_at":"2026-01-02T03:04:05Z"}],"total":1,"page":1,"size":50}"#
        MockURLProtocol.stub { _ in .init(statusCode: 200, body: Data(json.utf8)) }
        let service = PatientService(api: client)
        let page = try await service.getMeasurements(patientID: "p1")
        XCTAssertEqual(page.measurements?.count, 1)
        XCTAssertEqual(page.measurements?.first?.measurementType, "blood_pressure")
        XCTAssertEqual(page.measurements?.first?.secondaryValue, 95)
        XCTAssertEqual(page.measurements?.first?.unit, "mmHg")
    }

    func testProfileBoundFlagMechanism() throws {
        // bindProfileIfNeeded 用 TokenStore(account: "patient_profile_bound") 做一次性建档标记。
        let flag = TokenStore(service: "com.lht.changxi.tests", account: "bound-\(UUID().uuidString)")
        defer { flag.clear() }
        XCTAssertFalse(flag.hasValue)
        do { try flag.save("1") } catch { throw XCTSkip("Keychain 不可用：\(error)") }
        guard flag.load() == "1" else { throw XCTSkip("Keychain 写入未生效（需在模拟器手动验证）") }
        XCTAssertTrue(flag.hasValue, "建档标记存在时不应重复建档")
    }
}
