import Foundation
import KinoKit

@main
struct KinoKitProbe {
  static func main() async {
    do {
      try await run()
      exit(0)
    } catch {
      FileHandle.standardError.write(Data("ERROR: \(error)\n".utf8))
      exit(1)
    }
  }

  static func run() async throws {
    let env = ProcessInfo.processInfo.environment
    let deviceName =
      env["KINO_PROBE_DEVICE_NAME"] ?? "Probe-\(Host.current().localizedName ?? "unknown")"
    let platform = ClientPlatform(rawValue: env["KINO_PROBE_PLATFORM"] ?? "macOS") ?? .macOS

    let server = try await resolveServer(env: env)
    print("Resolved server: \(server.host):\(server.port) (\(server.serverVersion))")

    let pairing = PairingClient(server: server)
    let challenge = try await pairing.requestCode(deviceName: deviceName, platform: platform)
    print(
      "Pairing code: \(challenge.code) - approve in the admin SPA. Expires at \(challenge.expiresAt)."
    )

    let session = try await pairing.awaitApproval(challenge)
    print("Paired. Session token id: \(session.tokenID).")

    try await KeychainSessionStore(service: "kino.probe").save(session)
    print("Session saved to Keychain service kino.probe.")

    let client = KinoClient(session: session)
    let items = try await client.library.list(limit: 1, offset: 0, q: nil)
    guard let first = items.first else {
      print("Library empty.")
      return
    }
    print("First library item: \(first.id) - \(first.title)")

    guard let itemID = env["KINO_PROBE_ITEM_ID"] else {
      return
    }

    guard let id = UUID(uuidString: itemID) else {
      throw ProbeError.invalidItemID(itemID)
    }

    let item = try await client.library.get(id: id)
    let plan = VariantChooser.choose(item: item, capabilities: macCapabilities)
    print("Playback plan: \(plan.source.probeDescription)")
  }

  private static func resolveServer(env: [String: String]) async throws -> ResolvedServer {
    if let rawBaseURL = env["KINO_PROBE_BASE_URL"] {
      guard let baseURL = URL(string: rawBaseURL),
        let host = baseURL.host
      else {
        throw ProbeError.invalidBaseURL(rawBaseURL)
      }

      return ResolvedServer(
        instanceID: UUID(),
        host: host,
        port: baseURL.port ?? 7000,
        apiVersion: "v1",
        serverVersion: "unknown"
      )
    }

    let discovery = ServerDiscovery()
    var first: DiscoveredServer?
    for await server in await discovery.browse() {
      first = server
      break
    }

    guard let first else {
      throw ProbeError.noDiscoveredServer
    }

    return try await discovery.resolve(first)
  }

  private static let macCapabilities = ClientCapabilities(
    codecs: [.h264, .hevc],
    hdr: [.hdr10],
    maxHeight: 2160,
    surroundAudio: true,
    atmos: false
  )
}

private enum ProbeError: Error, LocalizedError {
  case invalidBaseURL(String)
  case invalidItemID(String)
  case noDiscoveredServer

  var errorDescription: String? {
    switch self {
    case .invalidBaseURL(let value):
      return "Invalid KINO_PROBE_BASE_URL: \(value)"
    case .invalidItemID(let value):
      return "Invalid KINO_PROBE_ITEM_ID UUID: \(value)"
    case .noDiscoveredServer:
      return "No kino-server instance discovered on the local network."
    }
  }
}

extension PlaybackPlan.Source {
  fileprivate var probeDescription: String {
    switch self {
    case .directByteRange(let url):
      return url.absoluteString
    case .hlsTranscodeOutput(let masterURL, let outputID):
      return "\(masterURL.absoluteString) (transcode output \(outputID))"
    case .hlsLive(let masterURL, let profile):
      return "\(masterURL.absoluteString) (live profile \(profile))"
    }
  }
}
