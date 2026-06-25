import Foundation
import Security

protocol APIKeyStoring {
    func saveOpenAIAPIKey(_ key: String) throws
    func loadOpenAIAPIKey() throws -> String?
    func clearOpenAIAPIKey() throws
}

enum APIKeyStoreError: Error {
    case unexpectedStatus(OSStatus)
}

struct KeychainAPIKeyStore: APIKeyStoring {
    private let service = "com.wenttang.pecker.openai"
    private let account = "api-key"

    init() {}

    func saveOpenAIAPIKey(_ key: String) throws {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            try clearOpenAIAPIKey()
            return
        }

        try deleteExistingItem(allowMissing: true)

        let data = Data(trimmedKey.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw APIKeyStoreError.unexpectedStatus(status)
        }
    }

    func loadOpenAIAPIKey() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw APIKeyStoreError.unexpectedStatus(status)
        }
        guard let data = item as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    func clearOpenAIAPIKey() throws {
        try deleteExistingItem(allowMissing: true)
    }

    private func deleteExistingItem(allowMissing: Bool) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        if allowMissing, status == errSecItemNotFound {
            return
        }
        guard status == errSecSuccess else {
            throw APIKeyStoreError.unexpectedStatus(status)
        }
    }
}
