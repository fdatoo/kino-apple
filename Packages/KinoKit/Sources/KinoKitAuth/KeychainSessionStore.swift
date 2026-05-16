import Foundation
import KinoKitCore
import Security

/// Keychain-backed multi-server session store.
public struct KeychainSessionStore: SessionStore {
  private let service: String
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  /// Creates a Keychain session store scoped by service name.
  public init(service: String = "kino.session") {
    self.service = service
    self.encoder = JSONEncoder()
    self.decoder = JSONDecoder()
  }

  /// Loads every stored session sorted by creation time.
  public func loadAll() async throws -> [AuthorizedSession] {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecReturnAttributes as String: true,
      kSecMatchLimit as String: kSecMatchLimitAll,
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound {
      return []
    }
    guard status == errSecSuccess else {
      throw KeychainSessionStoreError.unexpectedStatus(status)
    }
    guard let items = result as? [[String: Any]] else {
      throw KeychainSessionStoreError.malformedItem
    }

    let sessions = try items.map { item in
      guard let account = item[kSecAttrAccount as String] as? String else {
        throw KeychainSessionStoreError.malformedItem
      }
      let data = try loadData(account: account)
      do {
        return try decoder.decode(AuthorizedSession.self, from: data)
      } catch {
        throw KinoError.decoding(error)
      }
    }
    return sessions.sorted { $0.createdAt < $1.createdAt }
  }

  /// Saves or replaces the session for its server instance.
  public func save(_ session: AuthorizedSession) async throws {
    let data = try encoder.encode(session)
    let query = baseQuery(account: session.serverInstanceID)
    let attributes: [String: Any] = [
      kSecValueData as String: data
    ]

    let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    switch updateStatus {
    case errSecSuccess:
      return
    case errSecItemNotFound:
      var addQuery = query
      addQuery[kSecValueData as String] = data
      let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
      guard addStatus == errSecSuccess else {
        throw KeychainSessionStoreError.unexpectedStatus(addStatus)
      }
    default:
      throw KeychainSessionStoreError.unexpectedStatus(updateStatus)
    }
  }

  /// Removes the session for a server instance, if one exists.
  public func remove(serverInstanceID: UUID) async throws {
    let status = SecItemDelete(baseQuery(account: serverInstanceID) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw KeychainSessionStoreError.unexpectedStatus(status)
    }
  }

  private func baseQuery(account serverInstanceID: UUID) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: serverInstanceID.uuidString,
    ]
  }

  private func loadData(account: String) throws -> Data {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    guard status == errSecSuccess else {
      throw KeychainSessionStoreError.unexpectedStatus(status)
    }
    guard let data = result as? Data else {
      throw KeychainSessionStoreError.malformedItem
    }
    return data
  }
}

enum KeychainSessionStoreError: Error, Sendable, LocalizedError {
  case malformedItem
  case unexpectedStatus(OSStatus)

  var errorDescription: String? {
    switch self {
    case .malformedItem:
      return "Keychain returned a session item without data."
    case .unexpectedStatus(let status):
      return "Keychain operation failed with status \(status)."
    }
  }
}
