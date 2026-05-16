import Foundation
import KinoKitAuth
import KinoKitCore
import Security
import XCTest

final class KeychainSessionStoreTests: XCTestCase {
  private var service: String!

  override func setUp() {
    super.setUp()
    service = "kino.session.test.\(UUID().uuidString)"
  }

  override func tearDown() {
    deleteService(service)
    service = nil
    super.tearDown()
  }

  func test_loadAllReturnsSavedSession() async throws {
    let store = KeychainSessionStore(service: service)
    let session = makeSession(createdAt: Date(timeIntervalSince1970: 100))

    let emptySessions = try await store.loadAll()
    XCTAssertEqual(emptySessions, [])
    try await store.save(session)

    let loadedSessions = try await store.loadAll()
    XCTAssertEqual(loadedSessions, [session])
  }

  func test_saveUpsertsExistingServerSession() async throws {
    let store = KeychainSessionStore(service: service)
    let serverInstanceID = UUID()
    let first = makeSession(serverInstanceID: serverInstanceID, token: "first")
    let second = makeSession(serverInstanceID: serverInstanceID, token: "second")

    try await store.save(first)
    try await store.save(second)

    let sessions = try await store.loadAll()
    XCTAssertEqual(sessions.count, 1)
    XCTAssertEqual(sessions.first, second)
  }

  func test_loadAllSortsByCreatedAt() async throws {
    let store = KeychainSessionStore(service: service)
    let later = makeSession(createdAt: Date(timeIntervalSince1970: 200))
    let earlier = makeSession(createdAt: Date(timeIntervalSince1970: 100))

    try await store.save(later)
    try await store.save(earlier)

    let sessions = try await store.loadAll()
    XCTAssertEqual(sessions, [earlier, later])
  }

  func test_removeDeletesServerSession() async throws {
    let store = KeychainSessionStore(service: service)
    let session = makeSession()

    try await store.save(session)
    try await store.remove(serverInstanceID: session.serverInstanceID)

    let sessions = try await store.loadAll()
    XCTAssertEqual(sessions, [])
  }
}

private func deleteService(_ service: String?) {
  guard let service else {
    return
  }
  let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: service,
  ]
  SecItemDelete(query as CFDictionary)
}

private func makeSession(
  serverInstanceID: UUID = UUID(),
  token: String = "token",
  createdAt: Date = Date(timeIntervalSince1970: 100)
) -> AuthorizedSession {
  AuthorizedSession(
    serverInstanceID: serverInstanceID,
    baseURL: URL(string: "http://127.0.0.1:3000")!,
    tokenID: UUID(),
    token: token,
    userID: UUID(),
    deviceName: "Test Mac",
    createdAt: createdAt
  )
}
