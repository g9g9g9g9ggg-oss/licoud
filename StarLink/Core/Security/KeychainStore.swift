import Foundation
import Security

/// Keychain 封装（设计书 3.2）：kSecClassGenericPassword
/// 键位：auth.token / auth.user
struct KeychainStore: Sendable {
    enum Key: String {
        case token = "auth.token"
        case user = "auth.user"
    }

    enum KeychainError: Error {
        case status(OSStatus)
    }

    let service: String

    init(service: String = "com.starlink.ios") {
        self.service = service
    }

    // MARK: - Data 原始接口

    func save(_ data: Data, for key: Key) throws {
        delete(key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.status(status) }
    }

    func read(for key: Key) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    /// 删除不存在的键不报错（幂等）
    func delete(_ key: Key) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
        ]
        SecItemDelete(query as CFDictionary)
    }

    func deleteAll() {
        for key in [Key.token, .user] {
            delete(key)
        }
    }

    // MARK: - 便捷接口

    func saveString(_ string: String, for key: Key) throws {
        try save(Data(string.utf8), for: key)
    }

    func readString(for key: Key) -> String? {
        read(for: key).flatMap { String(data: $0, encoding: .utf8) }
    }

    func saveUser(_ user: User) throws {
        try save(JSONEncoder().encode(user), for: .user)
    }

    func readUser() -> User? {
        read(for: .user).flatMap { try? JSONDecoder().decode(User.self, from: $0) }
    }
}
