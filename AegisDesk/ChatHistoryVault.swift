import Foundation
import CryptoKit

struct ChatHistorySnapshot: Codable {
    var current: [ChatMessage]
    var archived: [ChatHistorySession]
}

enum ChatHistoryVault {
    private static let keyAccount = "chatHistoryEncryptionKey"

    static func load() throws -> ChatHistorySnapshot? {
        let url = try storageURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let sealedData = try Data(contentsOf: url)
        let box = try AES.GCM.SealedBox(combined: sealedData)
        let clearData = try AES.GCM.open(box, using: try encryptionKey())
        return try JSONDecoder().decode(ChatHistorySnapshot.self, from: clearData)
    }

    static func save(_ snapshot: ChatHistorySnapshot) throws {
        let clearData = try JSONEncoder().encode(snapshot)
        let sealed = try AES.GCM.seal(clearData, using: try encryptionKey())
        guard let combined = sealed.combined else { throw VaultError.encryptionFailed }
        try combined.write(to: storageURL(), options: [.atomic, .completeFileProtection])
    }

    private static func encryptionKey() throws -> SymmetricKey {
        if let encoded = try SecureKeychain.read(account: keyAccount), let data = Data(base64Encoded: encoded) {
            return SymmetricKey(data: data)
        }
        let key = SymmetricKey(size: .bits256)
        let data = key.withUnsafeBytes { Data($0) }
        try SecureKeychain.save(data.base64EncodedString(), account: keyAccount)
        return key
    }

    private static func storageURL() throws -> URL {
        let folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("SecureHistory", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("history.aegis")
    }

    enum VaultError: Error { case encryptionFailed }
}
