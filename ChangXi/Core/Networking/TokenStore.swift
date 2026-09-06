import Foundation
import Security

/// 基于 Keychain 的安全字符串存储（零第三方依赖，仅用 Security 框架原生 API）。
///
/// 默认用于存取 JWT access token（`service = com.lht.changxi.auth`，`account = access_token`）；
/// 也可通过自定义 `account` 复用为其它敏感标识（如匿名患者 ID `account = patient_id`）。
///
/// 访问级别固定为 `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`：
/// 设备首次解锁后可读、且不随备份迁移到其它设备，兼顾后台可用性与安全性。
struct TokenStore: Sendable {
    /// Keychain 服务名（`kSecClassGenericPassword` 的 service）。
    let service: String
    /// 账户名（`kSecClassGenericPassword` 的 account）。
    let account: String

    /// 默认构造：存取登录 JWT。
    init(service: String = "com.lht.changxi.auth", account: String = "access_token") {
        self.service = service
        self.account = account
    }

    /// 保存字符串。已存在时先尝试 `SecItemUpdate`，失败或不存在再 `SecItemAdd`。
    ///
    /// - Throws: 当 Keychain 返回非 `errSecSuccess` / `errSecDuplicateItem` 之外的错误时抛出 ``TokenStoreError``。
    func save(_ value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw TokenStoreError.encodingFailed
        }

        let query = baseQuery()

        // 先更新已存在项；不存在（errSecItemNotFound）时再新增。
        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: data
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        if updateStatus == errSecSuccess { return }
        if updateStatus != errSecItemNotFound && updateStatus != errSecDuplicateItem {
            // 更新遇到意外错误，仍尝试走新增流程（部分模拟器/首次写入场景）。
        }

        var addQuery = baseQuery()
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecSuccess || addStatus == errSecDuplicateItem {
            // 新增成功，或并发下已存在（此时上面的 update 通常已生效）。
            if addStatus == errSecDuplicateItem {
                let retry = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
                if retry != errSecSuccess {
                    throw TokenStoreError.keychain(status: Int(retry))
                }
            }
            return
        }
        throw TokenStoreError.keychain(status: Int(addStatus))
    }

    /// 读取字符串；不存在或读取失败返回 `nil`（不抛错，便于静默降级）。
    func load() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// 删除存储项；不存在视为成功。
    func clear() {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        // errSecItemNotFound 表示本就不存在，忽略即可。
        _ = status
    }

    /// 是否已存在非空值。
    var hasValue: Bool { !(load()?.isEmpty ?? true) }

    // MARK: - Private

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

/// ``TokenStore`` 操作失败错误。
enum TokenStoreError: Error, LocalizedError {
    /// 待存字符串无法编码为 UTF-8。
    case encodingFailed
    /// Keychain 返回了非预期的 OSStatus。
    case keychain(status: Int)

    var errorDescription: String? {
        switch self {
        case .encodingFailed: return "无法编码要保存的凭据。"
        case .keychain(let status): return "Keychain 操作失败（OSStatus \(status)）。"
        }
    }
}
