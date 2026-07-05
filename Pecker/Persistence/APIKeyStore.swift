import Foundation
import Security

protocol APIKeyStoring: Sendable {
    func saveOpenAIAPIKey(_ key: String) throws
    func loadOpenAIAPIKey() throws -> String?
    func clearOpenAIAPIKey() throws
}

enum APIKeyStoreError: Error {
    case unexpectedStatus(OSStatus)
}

protocol KeychainClient: Sendable {
    func add(_ query: CFDictionary) -> OSStatus
    func update(
        _ query: CFDictionary,
        attributes: CFDictionary
    ) -> OSStatus
    func copy(
        _ query: CFDictionary,
        result: UnsafeMutablePointer<CFTypeRef?>
    ) -> OSStatus
    func delete(_ query: CFDictionary) -> OSStatus
}

struct SystemKeychainClient: KeychainClient {
    func add(_ query: CFDictionary) -> OSStatus {
        SecItemAdd(query, nil)
    }

    func update(
        _ query: CFDictionary,
        attributes: CFDictionary
    ) -> OSStatus {
        SecItemUpdate(query, attributes)
    }

    func copy(
        _ query: CFDictionary,
        result: UnsafeMutablePointer<CFTypeRef?>
    ) -> OSStatus {
        SecItemCopyMatching(query, result)
    }

    func delete(_ query: CFDictionary) -> OSStatus {
        SecItemDelete(query)
    }
}

struct KeychainAPIKeyStore: APIKeyStoring {
    private let service = "com.wenttang.pecker.openai"
    private let account = "api-key"
    private let client: any KeychainClient

    init(client: any KeychainClient = SystemKeychainClient()) {
        self.client = client
    }

    func saveOpenAIAPIKey(_ key: String) throws {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            try clearOpenAIAPIKey()
            return
        }

        let identity = baseQuery()
        var item: CFTypeRef?
        let lookup = client.copy(
            loadQuery() as CFDictionary,
            result: &item
        )
        let data = Data(trimmedKey.utf8)
        let status: OSStatus
        if lookup == errSecSuccess {
            status = client.update(
                identity as CFDictionary,
                attributes: [
                    kSecValueData as String: data
                ] as CFDictionary
            )
        } else if lookup == errSecItemNotFound {
            var query = identity
            query[kSecValueData as String] = data
            status = client.add(query as CFDictionary)
        } else {
            throw APIKeyStoreError.unexpectedStatus(lookup)
        }
        guard status == errSecSuccess else {
            throw APIKeyStoreError.unexpectedStatus(status)
        }
    }

    func loadOpenAIAPIKey() throws -> String? {
        var item: CFTypeRef?
        let status = client.copy(
            loadQuery() as CFDictionary,
            result: &item
        )
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
        let status = client.delete(baseQuery() as CFDictionary)
        if status == errSecItemNotFound {
            return
        }
        guard status == errSecSuccess else {
            throw APIKeyStoreError.unexpectedStatus(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private func loadQuery() -> [String: Any] {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        return query
    }
}
