import Foundation
import KinoKitAuth
import KinoKitCore
@preconcurrency import Network
import XCTest

final class ServerDiscoveryTests: XCTestCase {
  func test_browseYieldsAdvertisedService() async throws {
    try XCTSkipIf(
      ProcessInfo.processInfo.environment["CI"] != nil,
      "NWBrowser requires Bonjour"
    )

    let instanceID = UUID()
    let serviceName = "Kino Test \(UUID().uuidString.prefix(8))"
    let listener = try NWListener(using: .tcp, on: .any)
    listener.service = NWListener.Service(
      name: serviceName,
      type: "_kino._tcp",
      domain: nil,
      txtRecord: NWTXTRecord([
        "version": "0.1.0",
        "api": "v1",
        "instance_id": instanceID.uuidString,
      ])
    )
    listener.newConnectionHandler = { connection in
      connection.cancel()
    }
    listener.start(queue: .global(qos: .utility))
    defer { listener.cancel() }

    let discovery = ServerDiscovery()
    let server = try await firstDiscoveredServer(named: serviceName, discovery: discovery)

    XCTAssertEqual(server.name, serviceName)
    XCTAssertEqual(server.instanceID, instanceID)
    XCTAssertEqual(server.txt["version"], "0.1.0")
    XCTAssertEqual(server.txt["api"], "v1")
  }
}

private func firstDiscoveredServer(
  named name: String,
  discovery: ServerDiscovery
) async throws -> DiscoveredServer {
  try await withThrowingTaskGroup(of: DiscoveredServer.self) { group in
    group.addTask {
      for await server in await discovery.browse() where server.name == name {
        return server
      }
      throw CancellationError()
    }
    group.addTask {
      try await Task.sleep(for: .seconds(5))
      throw URLError(.timedOut)
    }

    guard let server = try await group.next() else {
      throw URLError(.timedOut)
    }
    group.cancelAll()
    return server
  }
}
