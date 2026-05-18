import Foundation
import KinoKitCore
@preconcurrency import Network
import os

/// Local network discovery for Kino servers advertised over Bonjour.
public actor ServerDiscovery {
  private let logger = Logger(subsystem: "kino.kit", category: "discovery")
  private let cache = DiscoveryEndpointCache()

  /// Creates an NWBrowser-backed server discovery actor.
  public init() {}

  /// Starts browsing for `_kino._tcp` services until the returned stream terminates.
  public func browse() -> AsyncStream<DiscoveredServer> {
    AsyncStream { continuation in
      let browser = NWBrowser(
        for: .bonjourWithTXTRecord(type: "_kino._tcp", domain: nil),
        using: .init()
      )

      browser.browseResultsChangedHandler = { [cache] results, _ in
        for result in results {
          guard case .service(let name, _, _, _) = result.endpoint else {
            continue
          }
          let txt = Self.txtValues(from: result.metadata)
          let instanceID = txt["instance_id"].flatMap(UUID.init(uuidString:)) ?? UUID()
          let server = DiscoveredServer(instanceID: instanceID, name: name, txt: txt)

          Task {
            await cache.store(endpoint: result.endpoint, for: server)
            continuation.yield(server)
          }
        }
      }

      browser.stateUpdateHandler = { [logger] state in
        logger.debug("NWBrowser state: \(String(describing: state), privacy: .public)")
      }

      continuation.onTermination = { @Sendable _ in
        browser.cancel()
      }
      browser.start(queue: .global(qos: .utility))
    }
  }

  /// Resolves a discovered server advertisement to a connectable host and port.
  public func resolve(_ server: DiscoveredServer) async throws -> ResolvedServer {
    guard let endpoint = await cache.endpoint(for: server) else {
      throw KinoError.transport(URLError(.cannotFindHost))
    }

    let resolved = try await resolveEndpoint(endpoint)
    return ResolvedServer(
      instanceID: server.instanceID,
      host: resolved.host,
      port: resolved.port,
      apiVersion: server.txt["api"] ?? "v1",
      serverVersion: server.txt["version"] ?? "unknown"
    )
  }

  private nonisolated static func txtValues(from metadata: NWBrowser.Result.Metadata) -> [String:
    String]
  {
    guard case .bonjour(let txtRecord) = metadata else {
      return [:]
    }

    var values: [String: String] = [:]
    for key in txtRecord.dictionary.keys {
      values[key] = txtRecord[key]
    }
    return values
  }

  private func resolveEndpoint(_ endpoint: NWEndpoint) async throws -> (host: String, port: Int) {
    try await withThrowingTaskGroup(of: (host: String, port: Int).self) { group in
      group.addTask {
        try await Self.connectAndResolve(endpoint)
      }
      group.addTask {
        try await Task.sleep(for: .seconds(2))
        throw KinoError.transport(URLError(.timedOut))
      }

      guard let result = try await group.next() else {
        throw KinoError.transport(URLError(.cannotFindHost))
      }
      group.cancelAll()
      return result
    }
  }

  private nonisolated static func connectAndResolve(_ endpoint: NWEndpoint) async throws -> (
    host: String, port: Int
  ) {
    let connection = NWConnection(to: endpoint, using: .tcp)
    defer { connection.cancel() }

    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        let resolver = DiscoveryResolution(continuation: continuation)

        connection.stateUpdateHandler = { state in
          switch state {
          case .ready:
            if let resolved = connection.currentPath?.remoteEndpoint?.hostPortValue {
              resolver.resume(returning: resolved)
            } else if let resolved = connection.endpoint.hostPortValue {
              resolver.resume(returning: resolved)
            } else {
              resolver.resume(throwing: KinoError.transport(URLError(.cannotFindHost)))
            }
          case .failed:
            resolver.resume(throwing: KinoError.transport(URLError(.cannotConnectToHost)))
          case .cancelled:
            resolver.resume(throwing: KinoError.transport(URLError(.cancelled)))
          default:
            break
          }
        }
        connection.start(queue: .global(qos: .utility))
      }
    } onCancel: {
      connection.cancel()
    }
  }
}

private actor DiscoveryEndpointCache {
  private var endpoints: [DiscoveredServer: NWEndpoint] = [:]

  func store(endpoint: NWEndpoint, for server: DiscoveredServer) {
    endpoints[server] = endpoint
  }

  func endpoint(for server: DiscoveredServer) -> NWEndpoint? {
    endpoints[server]
  }
}

private final class DiscoveryResolution: @unchecked Sendable {
  private let lock = NSLock()
  private var didResume = false
  private let continuation: CheckedContinuation<(host: String, port: Int), any Error>

  init(continuation: CheckedContinuation<(host: String, port: Int), any Error>) {
    self.continuation = continuation
  }

  func resume(returning value: (host: String, port: Int)) {
    resume {
      continuation.resume(returning: value)
    }
  }

  func resume(throwing error: any Error) {
    resume {
      continuation.resume(throwing: error)
    }
  }

  private func resume(_ body: () -> Void) {
    lock.lock()
    defer { lock.unlock() }
    guard !didResume else {
      return
    }
    didResume = true
    body()
  }
}

extension NWEndpoint {
  fileprivate var hostPortValue: (host: String, port: Int)? {
    guard case .hostPort(let host, let port) = self else {
      return nil
    }
    return ("\(host)", Int(port.rawValue))
  }
}
