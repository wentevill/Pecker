import Security
import XCTest
@testable import Pecker

final class APIKeyStoreTests: XCTestCase {
    func testExistingKeyUsesUpdateWithoutDelete() throws {
        let client = RecordingKeychainClient(copyStatus: errSecSuccess)
        let store = KeychainAPIKeyStore(client: client)

        try store.saveOpenAIAPIKey("new-key")

        XCTAssertEqual(client.updateCalls, 1)
        XCTAssertEqual(client.addCalls, 0)
        XCTAssertEqual(client.deleteCalls, 0)
    }

    func testFailedUpdateNeverDeletesExistingKey() {
        let client = RecordingKeychainClient(
            copyStatus: errSecSuccess,
            updateStatus: errSecInteractionNotAllowed
        )
        let store = KeychainAPIKeyStore(client: client)

        XCTAssertThrowsError(try store.saveOpenAIAPIKey("new-key"))
        XCTAssertEqual(client.deleteCalls, 0)
    }
}

private final class RecordingKeychainClient:
    KeychainClient,
    @unchecked Sendable
{
    let copyStatus: OSStatus
    let updateStatus: OSStatus
    let addStatus: OSStatus
    var updateCalls = 0
    var addCalls = 0
    var deleteCalls = 0

    init(
        copyStatus: OSStatus,
        updateStatus: OSStatus = errSecSuccess,
        addStatus: OSStatus = errSecSuccess
    ) {
        self.copyStatus = copyStatus
        self.updateStatus = updateStatus
        self.addStatus = addStatus
    }

    func add(_ query: CFDictionary) -> OSStatus {
        addCalls += 1
        return addStatus
    }

    func update(
        _ query: CFDictionary,
        attributes: CFDictionary
    ) -> OSStatus {
        updateCalls += 1
        return updateStatus
    }

    func copy(
        _ query: CFDictionary,
        result: UnsafeMutablePointer<CFTypeRef?>
    ) -> OSStatus {
        if copyStatus == errSecSuccess {
            result.pointee = Data("old-key".utf8) as CFData
        }
        return copyStatus
    }

    func delete(_ query: CFDictionary) -> OSStatus {
        deleteCalls += 1
        return errSecSuccess
    }
}
