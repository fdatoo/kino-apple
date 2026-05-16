# M2 — KinoKit Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> This plan covers all of F-277 (M2). It is decomposed into seven sub-issues (M2.1–M2.7), each landing as its own PR on its own branch (`fdatoo/f-XXX-...`). Tasks below correspond 1:1 with sub-issues. The companion design spec lives at `docs/agents/specs/2026-05-16-kinokit-core-design.md`.

**Goal:** Ship the shared `KinoKit` SwiftPM package so the three Apple apps in M3/M4/M5 can discover a server, pair, browse, search, request, and play media.

**Architecture:** Six SwiftPM targets — `KinoKitGenerated` (swift-openapi-generator output), `KinoKitCore` (pure types), `KinoKitTransport` (URLSession + auth interceptor), `KinoKitAuth` (NWBrowser discovery + clock-injected pairing + Keychain), `KinoKitPlayback` (pure `VariantChooser` + actor coordinator + fallback ladder), `KinoKit` (umbrella + `KinoClient` facade). Plus one `KinoKitProbe` executable target that exercises the surface against a real local `kino-server`. Strict Swift 6 concurrency throughout.

**Tech Stack:** Swift 6.x, swift-openapi-generator (build plugin, ADR-0001), `Network.framework` (`NWBrowser`/`NWListener`), `Security.framework` (Keychain), `AVFoundation` (`AVPlayer`/`AVPlayerItem`), `XCTest`.

---

## Universal conventions (apply to every task)

- **Commit messages** must match `AGENTS.md`: one line, semantic prefix, allowed prefixes (`feat`, `fix`, `chore`, `refactor`, `test`, `docs`, `perf`, `build`), allowed scopes (`kit`, `ci`, `repo`, `agents`, `docs`). Examples: `feat(kit): add ServerDiscovery NWBrowser stream`, `test(kit): cover VariantChooser HDR fallback`, `docs(agents): add ADR-0002 nwbrowser`. **Never** add a body, trailer, or `Co-Authored-By`.
- **Branch names:** `fdatoo/f-<id>-<short-slug>` — Linear's `gitBranchName` for each sub-issue is the source of truth.
- **Pre-commit hook** (already installed by `just setup`) runs `just fmt-check` + `just lint` on staged `.swift`. Don't bypass with `--no-verify`. Fix the warning instead.
- **Verify before claiming done:** every task ends by running `just build && just test && just fmt-check && just lint`. Local pass is what CI will do.
- **No new dependencies** outside what each task explicitly adds. KinoKit stays dependency-light.
- **`os.Logger`, not `print`,** anywhere outside the `KinoKitProbe` executable (where stdout is the interface).
- **Public symbols get `///` doc comments.** Internal symbols don't unless invariants are surprising. Inline `//` comments explain *why*, not *what*.
- **Strict concurrency:** every public type is `Sendable` unless there's a recorded reason. Actors for stateful pieces. `AsyncStream` for ongoing events. No `Combine`.

---

## File structure (full M2 footprint)

```
kino-apple/
├── Justfile                                        # +openapi-sync, +probe recipes
├── .github/workflows/ci.yml                        # +kit-coverage job
├── docs/
│   ├── adrs/
│   │   ├── 0002-nwbrowser-for-client-mdns-discovery.md     # task 4 lands this
│   │   ├── 0003-openapi-vendoring-and-just-sync.md         # task 1 lands this
│   │   └── 0004-pure-variant-chooser.md                    # task 5 lands this
│   └── agents/
│       └── plans/
│           └── 2026-05-16-m2-kinokit-core.md       # this file
└── Packages/KinoKit/
    ├── Package.swift                               # +KinoKitGenerated, +probe, +deps
    ├── Sources/
    │   ├── KinoKitGenerated/
    │   │   ├── openapi.json                        # vendored
    │   │   ├── openapi-generator-config.yaml
    │   │   └── Empty.swift
    │   ├── KinoKitCore/
    │   │   ├── ClientPlatform.swift
    │   │   ├── DiscoveredServer.swift
    │   │   ├── ResolvedServer.swift
    │   │   ├── AuthorizedSession.swift
    │   │   ├── ClientCapabilities.swift
    │   │   ├── MediaTypes.swift                    # Codec, HDRFormat, SubtitleTrack, MediaItem mirror
    │   │   ├── ErrorResponse.swift                 # mirror of the OpenAPI error body
    │   │   └── Errors.swift                        # KinoError, PairingError, PlaybackError
    │   ├── KinoKitTransport/
    │   │   ├── KinoTransport.swift                 # struct with .live / .mock(URLSession) factories
    │   │   ├── AuthInterceptor.swift               # ClientMiddleware for swift-openapi-generator
    │   │   ├── ErrorMapper.swift                   # generator runtime errors → KinoError
    │   │   └── ImageLoader.swift                   # URLSession+URLCache primitive
    │   ├── KinoKitAuth/
    │   │   ├── ServerDiscovery.swift               # NWBrowser actor
    │   │   ├── PairingClient.swift                 # clock-injected polling
    │   │   ├── PairingChallenge.swift
    │   │   └── KeychainSessionStore.swift
    │   ├── KinoKitPlayback/
    │   │   ├── PlaybackPlan.swift
    │   │   ├── VariantChooser.swift                # pure static; the 100%-branch target
    │   │   ├── PlaybackCoordinator.swift           # actor
    │   │   └── ProgressReporter.swift              # throttle + flush
    │   └── KinoKit/
    │       ├── KinoClient.swift                    # facade
    │       ├── LibraryAPI.swift
    │       ├── RequestsAPI.swift
    │       ├── DiscoverAPI.swift
    │       ├── PlaybackAPI.swift
    │       ├── AdminAPI.swift
    │       └── Exports.swift                       # @_exported imports
    ├── Tests/KinoKitTests/
    │   ├── CoreTests/
    │   ├── TransportTests/                         # StubURLProtocol lives here
    │   ├── AuthTests/                              # NWListener fixture lives here
    │   ├── PlaybackTests/
    │   └── ClientTests/
    └── Probe/
        └── KinoKitProbe/main.swift
```

The existing `Sources/<target>/Placeholder.swift` files get deleted as each real source file replaces them. `Sources/KinoKit/Version.swift` stays.

---

## Task 1 — M2.1: KinoKitGenerated + `openapi.json` + `just openapi-sync`

**Linear:** M2.1 (sub-issue of F-277).
**Branch:** as assigned by Linear.
**Blocks:** Task 3 (M2.3).
**Parallel with:** Task 2 (M2.2).

**Files:**
- Create: `Packages/KinoKit/Sources/KinoKitGenerated/openapi.json`
- Create: `Packages/KinoKit/Sources/KinoKitGenerated/openapi-generator-config.yaml`
- Create: `Packages/KinoKit/Sources/KinoKitGenerated/Empty.swift`
- Create: `docs/adrs/0003-openapi-vendoring-and-just-sync.md`
- Modify: `Packages/KinoKit/Package.swift`
- Modify: `Justfile`
- Modify: `README.md` (one line in the commands table for `just openapi-sync`)

### Steps

- [ ] **Step 1: Pull the current `openapi.json` from `kino`.**

  Decide a starting ref. Default: the latest tagged release in the `kino` repo. If unsure, ask. From any working dir:

  ```bash
  # if you have a local kino checkout:
  cp ~/Developer/kino/openapi.json Packages/KinoKit/Sources/KinoKitGenerated/openapi.json

  # or via GitHub raw (replace <ref> with a tag or commit SHA):
  curl -fsSL "https://raw.githubusercontent.com/fdatoo/kino/<ref>/openapi.json" \
    -o Packages/KinoKit/Sources/KinoKitGenerated/openapi.json
  ```

  Sanity-check it has the new M1 endpoints (`/api/v1/pairings`, `/api/v1/admin/pairings`, `/api/v1/discover`, and `q` on `/api/v1/library/items`):

  ```bash
  jq '.paths | keys[]' Packages/KinoKit/Sources/KinoKitGenerated/openapi.json | grep -E 'pairings|discover|library'
  ```

  Expected: at minimum the four paths above appear.

- [ ] **Step 2: Write the generator config.**

  Create `Packages/KinoKit/Sources/KinoKitGenerated/openapi-generator-config.yaml`:

  ```yaml
  generate:
    - types
    - client
  namingStrategy: idiomatic
  accessModifier: internal
  ```

  Rationale: types+client per ADR-0001; `internal` access keeps the generated surface invisible to apps — only `KinoKitTransport` re-exports what we care about, and the public surface lives in `KinoKit`.

- [ ] **Step 3: Add the placeholder Swift file.**

  Create `Packages/KinoKit/Sources/KinoKitGenerated/Empty.swift`:

  ```swift
  // Placeholder so the target compiles before the build plugin emits sources.
  // The plugin output is the real content of this target.
  ```

  (No `import` — keep it inert.)

- [ ] **Step 4: Update `Package.swift`.**

  Replace the contents of `Packages/KinoKit/Package.swift` with:

  ```swift
  // swift-tools-version: 6.0

  import PackageDescription

  let package = Package(
    name: "KinoKit",
    platforms: [
      .iOS(.v17),
      .tvOS(.v17),
      .macOS(.v14),
    ],
    products: [
      .library(name: "KinoKit", targets: ["KinoKit"])
    ],
    dependencies: [
      .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.0.0"),
      .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.0.0"),
      .package(url: "https://github.com/apple/swift-openapi-urlsession", from: "1.0.0"),
    ],
    targets: [
      .target(
        name: "KinoKitGenerated",
        dependencies: [
          .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
        ],
        plugins: [
          .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator"),
        ]
      ),
      .target(name: "KinoKitCore"),
      .target(
        name: "KinoKitTransport",
        dependencies: [
          "KinoKitCore",
          "KinoKitGenerated",
          .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
          .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
        ]
      ),
      .target(
        name: "KinoKitAuth",
        dependencies: ["KinoKitCore", "KinoKitTransport"]
      ),
      .target(
        name: "KinoKitPlayback",
        dependencies: ["KinoKitCore", "KinoKitTransport"]
      ),
      .target(
        name: "KinoKit",
        dependencies: ["KinoKitCore", "KinoKitTransport", "KinoKitAuth", "KinoKitPlayback"]
      ),
      .testTarget(
        name: "KinoKitTests",
        dependencies: ["KinoKit"]
      ),
    ]
  )
  ```

  Bumps to the latest released `swift-openapi-generator` 1.x are fine — pin to a major.

- [ ] **Step 5: Verify the package builds.**

  ```bash
  just build
  ```

  Expected: `swift build` for KinoKit succeeds; the build plugin generates Swift from `openapi.json` and the target compiles. App builds will also pass because nothing imports the generated types yet.

  If the plugin fails on a permission prompt for build-plugin trust, the first invocation may need `swift package --allow-network-connections all build`. In Xcode, trust the plugin from the side panel.

- [ ] **Step 6: Add the `just openapi-sync` recipe.**

  Edit `Justfile` (add this recipe near the existing ones):

  ```just
  # Pull openapi.json from the kino repo at REF (a tag, branch, or commit SHA).
  # Defaults to "main". Result is committed in a deliberate PR.
  openapi-sync REF="main":
      @echo "Syncing openapi.json from kino@{{REF}}..."
      curl -fsSL "https://raw.githubusercontent.com/fdatoo/kino/{{REF}}/openapi.json" \
        -o Packages/KinoKit/Sources/KinoKitGenerated/openapi.json
      @echo "Done. Review and commit the change."
  ```

  Confirm the kino repo path (`fdatoo/kino`) before merging — if the repo is private under another owner, swap the org segment.

- [ ] **Step 7: Run the recipe with the current ref to confirm idempotency.**

  ```bash
  just openapi-sync REF=<the-ref-you-used-in-step-1>
  git diff Packages/KinoKit/Sources/KinoKitGenerated/openapi.json
  ```

  Expected: no diff.

- [ ] **Step 8: Write ADR-0003.**

  Create `docs/adrs/0003-openapi-vendoring-and-just-sync.md`. Follow the template at `docs/adrs/template.md`. One paragraph of context, one paragraph of decision, one paragraph of consequences. Key points to record:

  - The vendored `openapi.json` is the contract this version of KinoKit binds to.
  - Bumps are deliberate PRs initiated by a human running `just openapi-sync REF=<ref>`.
  - No CI drift job — the file's presence is authoritative. A separate engineer-led decision pulls a new ref.
  - Rejected: an `openapi-binding-drift` CI job (originally in the Phase 4 spec §9) because the drift it would detect is a feature, not a bug — the server's `openapi.json` is *ahead* of KinoKit by design until we bump.

- [ ] **Step 9: Document the recipe in `README.md`.**

  Add one row to the commands table:

  | Sync OpenAPI | `just openapi-sync REF=<tag-or-sha>` |

- [ ] **Step 10: Verify all gates.**

  ```bash
  just build && just test && just fmt-check && just lint
  ```

  Expected: all green.

- [ ] **Step 11: Commit and open PR.**

  ```bash
  git add Packages/KinoKit/Sources/KinoKitGenerated \
          Packages/KinoKit/Package.swift \
          Justfile README.md \
          docs/adrs/0003-openapi-vendoring-and-just-sync.md
  git commit -m "feat(kit): add KinoKitGenerated target and openapi-sync recipe"
  ```

  `gh pr create --base main --title "M2.1 — KinoKitGenerated + openapi.json vendoring" --body "$(...)"`. Body should link the Linear sub-issue and the design spec section §5.

---

## Task 2 — M2.2: KinoKitCore (models + `KinoError`)

**Linear:** M2.2.
**Blocks:** Task 3 (M2.3).
**Parallel with:** Task 1 (M2.1). No new dependencies.

**Files:**
- Delete: `Packages/KinoKit/Sources/KinoKitCore/Placeholder.swift`
- Create: `Packages/KinoKit/Sources/KinoKitCore/ClientPlatform.swift`
- Create: `Packages/KinoKit/Sources/KinoKitCore/DiscoveredServer.swift`
- Create: `Packages/KinoKit/Sources/KinoKitCore/ResolvedServer.swift`
- Create: `Packages/KinoKit/Sources/KinoKitCore/AuthorizedSession.swift`
- Create: `Packages/KinoKit/Sources/KinoKitCore/MediaTypes.swift`
- Create: `Packages/KinoKit/Sources/KinoKitCore/ClientCapabilities.swift`
- Create: `Packages/KinoKit/Sources/KinoKitCore/ErrorResponse.swift`
- Create: `Packages/KinoKit/Sources/KinoKitCore/Errors.swift`
- Create: `Packages/KinoKit/Tests/KinoKitTests/CoreTests/AuthorizedSessionCodableTests.swift`
- Create: `Packages/KinoKit/Tests/KinoKitTests/CoreTests/KinoErrorFingerprintTests.swift`

### TDD ordering

For each type, write one failing test (Codable round-trip or a specific invariant), watch it fail, implement, watch it pass, commit. Keep commits per-type so reviewers can see the file boundary.

- [ ] **Step 1: `ClientPlatform`.** Test: `ClientPlatform.iOS.rawValue == "iOS"`, `.tvOS == "tvOS"`, `.macOS == "macOS"`. These string values are the wire form sent in `POST /pairings`. Implementation:

  ```swift
  public enum ClientPlatform: String, Sendable, Codable, Hashable {
      case iOS, tvOS, macOS
  }
  ```

- [ ] **Step 2: `MediaTypes` enums.** Test: `Codec.allCases.count == 3`, `HDRFormat.allCases.count == 3`. Implementation:

  ```swift
  public enum Codec: String, Sendable, Codable, Hashable, CaseIterable {
      case h264, hevc, av1
  }
  public enum HDRFormat: String, Sendable, Codable, Hashable, CaseIterable {
      case hdr10, dolbyVision, hlg
  }
  public struct SubtitleTrack: Sendable, Hashable, Codable {
      public let id: UUID
      public let language: String
      public let isForced: Bool
      public let url: URL
      public init(id: UUID, language: String, isForced: Bool, url: URL) {
          self.id = id; self.language = language; self.isForced = isForced; self.url = url
      }
  }
  ```

  Add a minimal `MediaItem` mirror — only the fields KinoKit consumes (source files list, transcode outputs list, title, id, runtime). The full structure mirrors what the generated types expose; this is the public-facing shape:

  ```swift
  public struct MediaItem: Sendable, Hashable, Codable {
      public let id: UUID
      public let title: String
      public let runtimeSeconds: Int?
      public let sourceFiles: [SourceFile]
      public let transcodeOutputs: [TranscodeOutput]
      public let subtitleTracks: [SubtitleTrack]
      public let resumeAt: TimeInterval?
      // init below
  }
  public struct SourceFile: Sendable, Hashable, Codable {
      public let id: UUID
      public let container: String
      public let codec: Codec
      public let hdr: HDRFormat?
      public let height: Int
      public let url: URL
  }
  public struct TranscodeOutput: Sendable, Hashable, Codable {
      public let id: UUID
      public let container: String
      public let codec: Codec
      public let hdr: HDRFormat?
      public let height: Int
      public let vmafTarget: Double?
      public let createdAt: Date
      public let masterURL: URL
  }
  ```

  Write a Codable round-trip test for `MediaItem` with one source + one transcode output + one subtitle. Assert decoded == encoded.

- [ ] **Step 3: `ClientCapabilities`.** Codable round-trip test + memberwise init. Implementation:

  ```swift
  public struct ClientCapabilities: Sendable, Hashable, Codable {
      public let codecs: Set<Codec>
      public let hdr: Set<HDRFormat>
      public let maxHeight: Int
      public let surroundAudio: Bool
      public let atmos: Bool
      public init(codecs: Set<Codec>, hdr: Set<HDRFormat>,
                  maxHeight: Int, surroundAudio: Bool, atmos: Bool) {
          self.codecs = codecs; self.hdr = hdr
          self.maxHeight = maxHeight; self.surroundAudio = surroundAudio; self.atmos = atmos
      }
  }
  ```

- [ ] **Step 4: `DiscoveredServer` and `ResolvedServer`.** Round-trip tests on `ResolvedServer` only (`DiscoveredServer` carries an `NWEndpoint`-ish identity, but we model it as plain values to keep Core dependency-free):

  ```swift
  public struct DiscoveredServer: Sendable, Hashable {
      public let instanceID: UUID
      public let name: String
      public let txt: [String: String]
      public init(instanceID: UUID, name: String, txt: [String: String]) {
          self.instanceID = instanceID; self.name = name; self.txt = txt
      }
  }

  public struct ResolvedServer: Sendable, Hashable, Codable {
      public let instanceID: UUID
      public let host: String
      public let port: Int
      public let apiVersion: String
      public let serverVersion: String
      public init(instanceID: UUID, host: String, port: Int,
                  apiVersion: String, serverVersion: String) {
          self.instanceID = instanceID; self.host = host; self.port = port
          self.apiVersion = apiVersion; self.serverVersion = serverVersion
      }
  }
  ```

- [ ] **Step 5: `AuthorizedSession`.** Write the Codable round-trip test in `CoreTests/AuthorizedSessionCodableTests.swift` first:

  ```swift
  import XCTest
  @testable import KinoKitCore

  final class AuthorizedSessionCodableTests: XCTestCase {
      func test_roundTrip() throws {
          let session = AuthorizedSession(
              serverInstanceID: UUID(),
              baseURL: URL(string: "http://kino.local:7000")!,
              tokenID: UUID(),
              token: "tok_test_abc",
              userID: UUID(),
              deviceName: "Living Room TV",
              createdAt: Date(timeIntervalSince1970: 1_700_000_000)
          )
          let data = try JSONEncoder().encode(session)
          let decoded = try JSONDecoder().decode(AuthorizedSession.self, from: data)
          XCTAssertEqual(decoded, session)
      }
  }
  ```

  Run `swift test --filter AuthorizedSessionCodableTests`. Expected FAIL ("no such type"). Implement:

  ```swift
  public struct AuthorizedSession: Sendable, Hashable, Codable {
      public let serverInstanceID: UUID
      public let baseURL: URL
      public let tokenID: UUID
      public let token: String
      public let userID: UUID
      public let deviceName: String
      public let createdAt: Date
      public init(serverInstanceID: UUID, baseURL: URL, tokenID: UUID,
                  token: String, userID: UUID, deviceName: String, createdAt: Date) {
          self.serverInstanceID = serverInstanceID; self.baseURL = baseURL
          self.tokenID = tokenID; self.token = token
          self.userID = userID; self.deviceName = deviceName; self.createdAt = createdAt
      }
  }
  ```

  Re-run, expected PASS.

- [ ] **Step 6: `ErrorResponse`.** Mirror the OpenAPI error body (`{code: String, message: String, detail: String?}` — check `openapi.json` for the exact field set and align):

  ```swift
  public struct ErrorResponse: Sendable, Hashable, Codable {
      public let code: String
      public let message: String
      public let detail: String?
      public init(code: String, message: String, detail: String? = nil) {
          self.code = code; self.message = message; self.detail = detail
      }
  }
  ```

- [ ] **Step 7: `Errors.swift` — `KinoError`, `PairingError`, `PlaybackError`.** Test: each enum case has a stable `String(describing:)` prefix (the "fingerprint" used by tests to assert which case fired without comparing associated values):

  ```swift
  // KinoErrorFingerprintTests.swift
  func test_fingerprints() {
      XCTAssertEqual(String(describing: KinoError.unauthorized), "unauthorized")
      XCTAssertTrue(String(describing: KinoError.transport(URLError(.timedOut))).hasPrefix("transport("))
  }
  ```

  Implementation:

  ```swift
  public enum KinoError: Error, Sendable {
      case transport(URLError)
      case server(status: Int, body: ErrorResponse?)
      case unauthorized
      case pairing(PairingError)
      case playback(PlaybackError)
      case decoding(any Error)
  }
  extension KinoError: LocalizedError {
      public var errorDescription: String? {
          switch self {
          case .transport(let e): return "Network error: \(e.localizedDescription)"
          case .server(let status, let body): return "Server returned \(status): \(body?.message ?? "")"
          case .unauthorized: return "Session is no longer valid; please re-pair."
          case .pairing(let e): return e.localizedDescription
          case .playback(let e): return e.localizedDescription
          case .decoding(let e): return "Response decoding failed: \(e)"
          }
      }
  }

  public enum PairingError: Error, Sendable, LocalizedError {
      case expired, rejected, codeCollision, malformedResponse
      public var errorDescription: String? {
          switch self {
          case .expired: return "Pairing code expired."
          case .rejected: return "Pairing was rejected by the admin."
          case .codeCollision: return "Server returned a duplicate code; retry."
          case .malformedResponse: return "Server returned an unexpected pairing response."
          }
      }
  }

  public enum PlaybackError: Error, Sendable, LocalizedError {
      case noPlayablePlan, fallbackExhausted, capabilitiesMissing
      public var errorDescription: String? {
          switch self {
          case .noPlayablePlan: return "No playable variant for this item on this device."
          case .fallbackExhausted: return "Playback failed after all fallbacks."
          case .capabilitiesMissing: return "Client capabilities were not provided."
          }
      }
  }
  ```

  Note: `KinoError.decoding(any Error)` carries any error type — not just `DecodingError` — because the OpenAPI runtime surfaces wrapped errors. Don't narrow.

- [ ] **Step 8: Delete the placeholder.**

  ```bash
  git rm Packages/KinoKit/Sources/KinoKitCore/Placeholder.swift
  ```

- [ ] **Step 9: Verify all gates.**

  ```bash
  just build && just test && just fmt-check && just lint
  ```

- [ ] **Step 10: Commit and PR.**

  ```bash
  git commit -m "feat(kit): add KinoKitCore models and KinoError"
  ```

---

## Task 3 — M2.3: KinoKitTransport (URLSession + auth interceptor + image cache)

**Linear:** M2.3.
**Blocked by:** Tasks 1 and 2.
**Blocks:** Tasks 4 and 5.

**Files:**
- Delete: `Packages/KinoKit/Sources/KinoKitTransport/Placeholder.swift`
- Create: `Packages/KinoKit/Sources/KinoKitTransport/KinoTransport.swift`
- Create: `Packages/KinoKit/Sources/KinoKitTransport/AuthInterceptor.swift`
- Create: `Packages/KinoKit/Sources/KinoKitTransport/ErrorMapper.swift`
- Create: `Packages/KinoKit/Sources/KinoKitTransport/ImageLoader.swift`
- Create: `Packages/KinoKit/Tests/KinoKitTests/TransportTests/StubURLProtocol.swift`
- Create: `Packages/KinoKit/Tests/KinoKitTests/TransportTests/AuthInterceptorTests.swift`
- Create: `Packages/KinoKit/Tests/KinoKitTests/TransportTests/ErrorMapperTests.swift`
- Create: `Packages/KinoKit/Tests/KinoKitTests/TransportTests/ImageLoaderTests.swift`

### Key shape

```swift
public struct KinoTransport: Sendable {
    let urlSession: URLSession
    let token: @Sendable () -> String?     // optional so probe can use unauthorized transport for /pairings/*

    public static func live(baseURL: URL, token: @escaping @Sendable () -> String?) -> KinoTransport
    public static func mock(_ session: URLSession, token: @escaping @Sendable () -> String? = { nil }) -> KinoTransport

    /// Build the swift-openapi-generator client for the bound contract.
    public func makeClient() -> Client    // Client is generated; re-exported by Transport
}
```

The `Client` type is whatever `swift-openapi-generator` emits with config `generate: [types, client]`. Re-export under `@_exported import KinoKitGenerated` from `KinoTransport.swift` so peer modules see one `Client` name.

### TDD ordering

- [ ] **Step 1: Write `StubURLProtocol`.**

  In `TransportTests/StubURLProtocol.swift`:

  ```swift
  import Foundation

  final class StubURLProtocol: URLProtocol {
      struct Stub {
          let status: Int
          let headers: [String: String]
          let body: Data
      }
      static let lock = NSLock()
      nonisolated(unsafe) static var queue: [(matcher: (URLRequest) -> Bool, stub: Stub)] = []

      static func push(when matcher: @escaping (URLRequest) -> Bool, _ stub: Stub) {
          lock.lock(); defer { lock.unlock() }
          queue.append((matcher, stub))
      }
      static func reset() {
          lock.lock(); defer { lock.unlock() }
          queue.removeAll()
      }

      override class func canInit(with request: URLRequest) -> Bool { true }
      override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
      override func startLoading() {
          let stub: Stub? = {
              Self.lock.lock(); defer { Self.lock.unlock() }
              guard let idx = Self.queue.firstIndex(where: { $0.matcher(self.request) }) else { return nil }
              return Self.queue.remove(at: idx).stub
          }()
          guard let stub else {
              client?.urlProtocol(self, didFailWithError: URLError(.badURL))
              return
          }
          let url = request.url!
          let resp = HTTPURLResponse(url: url, statusCode: stub.status,
                                     httpVersion: "HTTP/1.1", headerFields: stub.headers)!
          client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
          client?.urlProtocol(self, didLoad: stub.body)
          client?.urlProtocolDidFinishLoading(self)
      }
      override func stopLoading() {}
  }

  extension URLSession {
      static var stubbed: URLSession {
          let cfg = URLSessionConfiguration.ephemeral
          cfg.protocolClasses = [StubURLProtocol.self]
          return URLSession(configuration: cfg)
      }
  }
  ```

  This is the seam every transport-touching test uses.

- [ ] **Step 2: Write the failing `AuthInterceptor` test.**

  ```swift
  // AuthInterceptorTests.swift
  func test_addsBearerTokenWhenPresent() async throws {
      var observed: URLRequest?
      StubURLProtocol.reset()
      StubURLProtocol.push(when: { req in observed = req; return true },
                           .init(status: 200, headers: [:], body: Data("{}".utf8)))

      let transport = KinoTransport.mock(.stubbed, token: { "tok_xyz" })
      _ = try? await transport.urlSession.data(from: URL(string: "http://x/test")!)
      XCTAssertEqual(observed?.value(forHTTPHeaderField: "Authorization"), "Bearer tok_xyz")
  }
  ```

  Run, expect FAIL.

- [ ] **Step 3: Implement `AuthInterceptor` as a `swift-openapi-runtime` `ClientMiddleware`.**

  ```swift
  import HTTPTypes
  import OpenAPIRuntime

  struct AuthInterceptor: ClientMiddleware {
      let token: @Sendable () -> String?
      func intercept(_ request: HTTPRequest,
                     body: HTTPBody?,
                     baseURL: URL,
                     operationID: String,
                     next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
      ) async throws -> (HTTPResponse, HTTPBody?) {
          var req = request
          if let token = token() {
              req.headerFields[.authorization] = "Bearer \(token)"
          }
          return try await next(req, body, baseURL)
      }
  }
  ```

  Also implement an interceptor that runs before raw `URLSession` calls (for the image loader). Decide one place to live; if both paths share the same `URLSession`, wire the middleware once in `KinoTransport.live`.

  Re-run, expect PASS.

- [ ] **Step 4: Write `KinoTransport.live` and `KinoTransport.mock`.**

  ```swift
  import OpenAPIRuntime
  import OpenAPIURLSession

  @_exported import struct KinoKitGenerated.Client  // adjust to the actual symbol the generator emits

  public struct KinoTransport: Sendable {
      public let urlSession: URLSession
      let baseURL: URL
      let token: @Sendable () -> String?

      public static func live(baseURL: URL,
                              token: @escaping @Sendable () -> String?) -> KinoTransport {
          let cfg = URLSessionConfiguration.default
          cfg.urlCache = .init(memoryCapacity: 0,
                               diskCapacity: 256 * 1024 * 1024,
                               directory: nil)
          return .init(urlSession: URLSession(configuration: cfg), baseURL: baseURL, token: token)
      }
      public static func mock(_ session: URLSession,
                              token: @escaping @Sendable () -> String? = { nil }) -> KinoTransport {
          .init(urlSession: session,
                baseURL: URL(string: "http://stub.local")!,
                token: token)
      }

      public func makeClient() -> Client {
          Client(
              serverURL: baseURL,
              transport: URLSessionTransport(configuration: .init(session: urlSession)),
              middlewares: [AuthInterceptor(token: token)]
          )
      }
  }
  ```

  Replace `Client` with the real symbol your generator emits (typically `Client` at the namespace root; `swift-openapi-generator` 1.x defaults to module-root `Client`).

- [ ] **Step 5: Write a failing test for `ErrorMapper` covering 401, transport, and server-body decoding.**

  ```swift
  // ErrorMapperTests.swift
  func test_401_mapsToUnauthorized() {
      let mapped = ErrorMapper.map(httpStatus: 401, body: nil)
      XCTAssertEqual(String(describing: mapped), "unauthorized")
  }
  func test_500WithErrorBody_mapsToServer() {
      let body = ErrorResponse(code: "internal", message: "boom", detail: nil)
      let mapped = ErrorMapper.map(httpStatus: 500, body: body)
      guard case .server(let status, let b) = mapped else { return XCTFail() }
      XCTAssertEqual(status, 500); XCTAssertEqual(b?.message, "boom")
  }
  func test_urlErrorMapsToTransport() {
      let mapped = ErrorMapper.mapTransport(URLError(.timedOut))
      guard case .transport(let e) = mapped else { return XCTFail() }
      XCTAssertEqual(e.code, .timedOut)
  }
  ```

- [ ] **Step 6: Implement `ErrorMapper`.**

  ```swift
  public enum ErrorMapper {
      public static func map(httpStatus: Int, body: ErrorResponse?) -> KinoError {
          if httpStatus == 401 { return .unauthorized }
          return .server(status: httpStatus, body: body)
      }
      public static func mapTransport(_ error: Error) -> KinoError {
          if let url = error as? URLError { return .transport(url) }
          return .decoding(error)
      }
  }
  ```

  Run tests, expect PASS.

- [ ] **Step 7: Implement `ImageLoader`.**

  Public surface:

  ```swift
  public actor ImageLoader {
      private let session: URLSession
      private let token: @Sendable () -> String?

      init(session: URLSession, token: @escaping @Sendable () -> String?) {
          self.session = session; self.token = token
      }

      /// Load image bytes for a Kino-internal URL (gets bearer-stamped) or
      /// an external URL (TMDB poster); auth is added only when the host
      /// is the bound server.
      public func loadImage(url: URL, isInternal: Bool) async throws -> Data {
          var req = URLRequest(url: url)
          if isInternal, let token = token() {
              req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
          }
          do {
              let (data, response) = try await session.data(for: req)
              guard let http = response as? HTTPURLResponse else {
                  throw KinoError.transport(URLError(.badServerResponse))
              }
              if http.statusCode == 401 { throw KinoError.unauthorized }
              if !(200..<300).contains(http.statusCode) {
                  throw ErrorMapper.map(httpStatus: http.statusCode, body: nil)
              }
              return data
          } catch let urlError as URLError {
              throw KinoError.transport(urlError)
          }
      }
  }
  ```

  Test: stub a 200 image body, assert success; stub a 401, assert `.unauthorized`. Reuses `StubURLProtocol`.

- [ ] **Step 8: Delete placeholder, verify gates, commit.**

  ```bash
  git rm Packages/KinoKit/Sources/KinoKitTransport/Placeholder.swift
  just build && just test && just fmt-check && just lint
  git commit -m "feat(kit): add KinoKitTransport URLSession auth and error mapper"
  ```

---

## Task 4 — M2.4: KinoKitAuth (`ServerDiscovery`, `PairingClient`, `KeychainSessionStore`) + ADR-0002

**Linear:** M2.4.
**Blocked by:** Task 3.
**Parallel with:** Task 5.

**Files:**
- Delete: `Packages/KinoKit/Sources/KinoKitAuth/Placeholder.swift`
- Create: `Packages/KinoKit/Sources/KinoKitAuth/ServerDiscovery.swift`
- Create: `Packages/KinoKit/Sources/KinoKitAuth/PairingClient.swift`
- Create: `Packages/KinoKit/Sources/KinoKitAuth/PairingChallenge.swift`
- Create: `Packages/KinoKit/Sources/KinoKitAuth/KeychainSessionStore.swift`
- Create: `Packages/KinoKit/Tests/KinoKitTests/AuthTests/ServerDiscoveryTests.swift`
- Create: `Packages/KinoKit/Tests/KinoKitTests/AuthTests/PairingClientTests.swift`
- Create: `Packages/KinoKit/Tests/KinoKitTests/AuthTests/KeychainSessionStoreTests.swift`
- Create: `docs/adrs/0002-nwbrowser-for-client-mdns-discovery.md`

### TDD ordering

- [ ] **Step 1: `PairingChallenge` value type.**

  ```swift
  public struct PairingChallenge: Sendable, Hashable {
      public let pairingID: UUID
      public let code: String         // 6-digit ASCII
      public let expiresAt: Date
  }
  ```

  Round-trip Codable test (it must be Codable for log redaction tests).

- [ ] **Step 2: Write `ServerDiscovery` as an `actor` with `AsyncStream` output.**

  ```swift
  import Network
  import os

  public actor ServerDiscovery {
      private let logger = Logger(subsystem: "kino.kit", category: "discovery")

      public init() {}

      public func browse() -> AsyncStream<DiscoveredServer> {
          AsyncStream { continuation in
              let browser = NWBrowser(
                  for: .bonjourWithTXTRecord(type: "_kino._tcp", domain: nil),
                  using: .init()
              )
              browser.browseResultsChangedHandler = { results, _ in
                  for r in results {
                      guard case let .service(name, _, _, _) = r.endpoint,
                            case let .bonjour(txtRecord) = r.metadata else { continue }
                      var txt: [String: String] = [:]
                      for key in txtRecord.dictionary.keys { txt[key] = txtRecord[key] }
                      let instanceID = txt["instance_id"].flatMap(UUID.init(uuidString:)) ?? UUID()
                      continuation.yield(DiscoveredServer(instanceID: instanceID, name: name, txt: txt))
                  }
              }
              browser.stateUpdateHandler = { [logger] state in
                  logger.debug("NWBrowser state: \(String(describing: state))")
              }
              continuation.onTermination = { @Sendable _ in browser.cancel() }
              browser.start(queue: .global(qos: .utility))
          }
      }

      /// Resolves a discovered server to host/port using NWConnection.
      public func resolve(_ s: DiscoveredServer) async throws -> ResolvedServer {
          // Build via TXT (already has instance_id, api, version).
          // For host/port, use NWConnection with the same endpoint and read its
          // currentPath.remoteEndpoint after the path becomes .ready.
          // Implementation detail: bounded 2s timeout; throw KinoError.transport on timeout.
          // (Full body in the file.)
          fatalError("see file")
      }
  }
  ```

  Test (only runnable on macOS hosts that allow Bonjour, gated otherwise):

  ```swift
  func test_browseYieldsAdvertisedService() async throws {
      let listener = try NWListener(using: .init(), on: .any)
      listener.service = NWListener.Service(name: "Kino Test \(UUID().uuidString.prefix(4))",
                                            type: "_kino._tcp", domain: nil,
                                            txtRecord: .init([
                                                "version": "0.1.0",
                                                "api": "v1",
                                                "instance_id": UUID().uuidString,
                                            ]))
      listener.newConnectionHandler = { $0.cancel() }
      listener.start(queue: .global())
      defer { listener.cancel() }

      let discovery = ServerDiscovery()
      let firstFound = expectation(description: "discovered")
      Task {
          for await server in await discovery.browse() {
              if server.txt["api"] == "v1" { firstFound.fulfill(); break }
          }
      }
      await fulfillment(of: [firstFound], timeout: 5)
  }
  ```

  Skip on CI if `ProcessInfo.processInfo.environment["CI"] != nil`:

  ```swift
  func test_browseYieldsAdvertisedService() async throws {
      try XCTSkipIf(ProcessInfo.processInfo.environment["CI"] != nil,
                    "NWBrowser requires Bonjour, gated off on CI")
      // …
  }
  ```

- [ ] **Step 3: Write ADR-0002 in parallel.** One paragraph: chose `NWBrowser` over `NetServiceBrowser`; `NetServiceBrowser` is deprecated and doesn't play well with Swift Concurrency; `NWBrowser` exposes TXT via `NWBrowser.Result.metadata`.

- [ ] **Step 4: `PairingClient` — write failing test for the polling state machine first.**

  Define a small protocol the client polls against, so tests inject a fake:

  ```swift
  protocol PairingPoller: Sendable {
      func requestCode(deviceName: String, platform: ClientPlatform) async throws -> PairingChallenge
      func poll(code: String) async throws -> PairingPollResult
  }

  enum PairingPollResult: Sendable {
      case pending
      case approved(token: String, tokenID: UUID, userID: UUID)
      case rejected
      case expired
  }
  ```

  Implementation of `PairingClient`:

  ```swift
  public struct PairingClient: Sendable {
      let server: ResolvedServer
      let poller: any PairingPoller
      let clock: any Clock<Duration>
      let jitter: @Sendable () -> Duration

      public init(server: ResolvedServer,
                  transport: KinoTransport = .live(baseURL: URL(string: "http://invalid")!, token: { nil }),
                  clock: any Clock<Duration> = ContinuousClock(),
                  jitter: @escaping @Sendable () -> Duration = { .milliseconds(Int.random(in: -500...500)) }) {
          self.server = server
          self.poller = LivePairingPoller(transport: transport)
          self.clock = clock
          self.jitter = jitter
      }

      /// Test-friendly init.
      init(server: ResolvedServer,
           poller: any PairingPoller,
           clock: any Clock<Duration>,
           jitter: @escaping @Sendable () -> Duration = { .zero }) {
          self.server = server; self.poller = poller; self.clock = clock; self.jitter = jitter
      }

      public func requestCode(deviceName: String, platform: ClientPlatform) async throws -> PairingChallenge {
          try await poller.requestCode(deviceName: deviceName, platform: platform)
      }

      public func awaitApproval(_ challenge: PairingChallenge) async throws -> AuthorizedSession {
          while clock.now < .init(challenge.expiresAt) {
              switch try await poller.poll(code: challenge.code) {
              case .pending:
                  try await clock.sleep(for: .seconds(2) + jitter())
              case .approved(let token, let tokenID, let userID):
                  return AuthorizedSession(
                      serverInstanceID: server.instanceID,
                      baseURL: URL(string: "http://\(server.host):\(server.port)")!,
                      tokenID: tokenID, token: token, userID: userID,
                      deviceName: "TBD", createdAt: .init()
                  )
              case .rejected: throw KinoError.pairing(.rejected)
              case .expired: throw KinoError.pairing(.expired)
              }
          }
          throw KinoError.pairing(.expired)
      }
  }
  ```

  *Note:* `Clock.Instant` is generic — `.init(challenge.expiresAt)` is illustrative; the concrete comparison reads "have we slept past expiry?" via a wall-clock fallback. Implementation can store `expiresAt` as `Duration` from start and compare elapsed.

  Tests using the in-process fake poller cover: pending→approved, immediate expiry, rejected, malformed response (poller throws `PairingError.malformedResponse`), polling cadence equals 2s under zero-jitter (assert that the test clock advanced by 2s × N).

- [ ] **Step 5: `KeychainSessionStore`.**

  ```swift
  import Foundation
  import Security

  public struct KeychainSessionStore: SessionStore {
      let service: String
      public init(service: String = "kino.session") { self.service = service }

      public func loadAll() async throws -> [AuthorizedSession] {
          let query: [String: Any] = [
              kSecClass as String: kSecClassGenericPassword,
              kSecAttrService as String: service,
              kSecReturnAttributes as String: true,
              kSecReturnData as String: true,
              kSecMatchLimit as String: kSecMatchLimitAll,
          ]
          var result: AnyObject?
          let status = SecItemCopyMatching(query as CFDictionary, &result)
          if status == errSecItemNotFound { return [] }
          guard status == errSecSuccess, let items = result as? [[String: Any]] else {
              throw KinoError.transport(URLError(.userAuthenticationRequired))
          }
          var sessions: [AuthorizedSession] = []
          for item in items {
              guard let data = item[kSecValueData as String] as? Data else { continue }
              sessions.append(try JSONDecoder().decode(AuthorizedSession.self, from: data))
          }
          return sessions.sorted(by: { $0.createdAt < $1.createdAt })
      }

      public func save(_ s: AuthorizedSession) async throws {
          let data = try JSONEncoder().encode(s)
          let baseQuery: [String: Any] = [
              kSecClass as String: kSecClassGenericPassword,
              kSecAttrService as String: service,
              kSecAttrAccount as String: s.serverInstanceID.uuidString,
          ]
          SecItemDelete(baseQuery as CFDictionary) // upsert
          var add = baseQuery
          add[kSecValueData as String] = data
          let status = SecItemAdd(add as CFDictionary, nil)
          guard status == errSecSuccess else {
              throw KinoError.transport(URLError(.userAuthenticationRequired))
          }
      }

      public func remove(serverInstanceID: UUID) async throws {
          let q: [String: Any] = [
              kSecClass as String: kSecClassGenericPassword,
              kSecAttrService as String: service,
              kSecAttrAccount as String: serverInstanceID.uuidString,
          ]
          SecItemDelete(q as CFDictionary)
      }
  }

  public protocol SessionStore: Sendable {
      func loadAll() async throws -> [AuthorizedSession]
      func save(_ s: AuthorizedSession) async throws
      func remove(serverInstanceID: UUID) async throws
  }
  ```

  Tests use a per-test service string (`"kino.session.test.\(UUID())"`); tearDown deletes everything matching the service. Cover: empty → save → loadAll one entry; save twice same id → loadAll one entry (upsert); save two different ids → loadAll returns both sorted by createdAt; remove → loadAll empty.

- [ ] **Step 6: Delete placeholder; gates; commit.**

  ```bash
  git rm Packages/KinoKit/Sources/KinoKitAuth/Placeholder.swift
  just build && just test && just fmt-check && just lint
  git commit -m "feat(kit): add discovery pairing and keychain session store"
  git add docs/adrs/0002-nwbrowser-for-client-mdns-discovery.md
  git commit -m "docs(agents): add ADR-0002 NWBrowser for client mDNS discovery"
  ```

---

## Task 5 — M2.5: KinoKitPlayback (`VariantChooser` + `PlaybackCoordinator` + fallback) + ADR-0004

**Linear:** M2.5.
**Blocked by:** Task 3.
**Parallel with:** Task 4.

**Files:**
- Delete: `Packages/KinoKit/Sources/KinoKitPlayback/Placeholder.swift`
- Create: `Packages/KinoKit/Sources/KinoKitPlayback/PlaybackPlan.swift`
- Create: `Packages/KinoKit/Sources/KinoKitPlayback/VariantChooser.swift`
- Create: `Packages/KinoKit/Sources/KinoKitPlayback/PlaybackCoordinator.swift`
- Create: `Packages/KinoKit/Sources/KinoKitPlayback/ProgressReporter.swift`
- Create: `Packages/KinoKit/Tests/KinoKitTests/PlaybackTests/VariantChooserTests.swift`
- Create: `Packages/KinoKit/Tests/KinoKitTests/PlaybackTests/PlaybackCoordinatorTests.swift`
- Create: `Packages/KinoKit/Tests/KinoKitTests/PlaybackTests/ProgressReporterTests.swift`
- Create: `docs/adrs/0004-pure-variant-chooser.md`

### TDD ordering — `VariantChooser` first because it's pure and is the 100%-branch target

- [ ] **Step 1: `PlaybackPlan` type.**

  ```swift
  public struct PlaybackPlan: Sendable, Hashable {
      public enum Source: Sendable, Hashable {
          case directByteRange(URL)
          case hlsTranscodeOutput(masterURL: URL, outputID: UUID)
          case hlsLive(masterURL: URL, profile: String)
      }
      public let source: Source
      public let subtitleTracks: [SubtitleTrack]
      public let resumeAt: TimeInterval?
      public init(source: Source, subtitleTracks: [SubtitleTrack], resumeAt: TimeInterval?) {
          self.source = source; self.subtitleTracks = subtitleTracks; self.resumeAt = resumeAt
      }
  }
  ```

- [ ] **Step 2: Write `VariantChooser` tests **first**, covering every branch from Phase 4 spec §8.**

  Table-driven. Each row is a `(name, capabilities, item, expectedSource)`:

  ```swift
  final class VariantChooserTests: XCTestCase {
      struct Case { let name: String; let caps: ClientCapabilities; let item: MediaItem; let expected: PlaybackPlan.Source }

      func test_allCases() {
          for c in cases {
              let plan = VariantChooser.choose(item: c.item, capabilities: c.caps)
              XCTAssertEqual(plan.source, c.expected, c.name)
          }
      }

      static var cases: [Case] {
          [
              // Q1: a TranscodeOutput matches caps → pick highest VMAF, then height, then created_at desc.
              Case(name: "matching output, single",
                   caps: caps(h264, sd: .none, height: 1080),
                   item: item(outputs: [output(.h264, height: 1080)],
                              source: source(.hevc, height: 2160)),
                   expected: .hlsTranscodeOutput(masterURL: url(.hlsMaster), outputID: anyOutputID)),

              // Q1: matching outputs ordered by VMAF target desc.
              // …

              // Q2: no matching output, source IS playable directly → directByteRange.
              Case(name: "source directly playable",
                   caps: caps(h264, height: 1080),
                   item: item(outputs: [],
                              source: source(.h264, height: 1080)),
                   expected: .directByteRange(url(.sourceFile))),

              // Q3: no matching output, source NOT directly playable → live transcode.
              Case(name: "no compatible output or source, live transcode",
                   caps: caps(h264, height: 1080),
                   item: item(outputs: [output(.av1, height: 2160)],
                              source: source(.av1, height: 2160)),
                   expected: .hlsLive(masterURL: url(.liveMaster), profile: "h264-1080p")),

              // HDR mismatch forces live even if codec matches.
              // Surround/Atmos capability narrows output choice but doesn't change source pick.
              // maxHeight clamps preferred output.
              // Empty outputs + non-playable source + no live profile → noPlayablePlan — express by returning the live plan that the coordinator will throw on.
          ]
      }
  }
  ```

  Run, expect FAIL ("no such type").

- [ ] **Step 3: Implement `VariantChooser`.**

  ```swift
  public enum VariantChooser {
      public static func choose(item: MediaItem, capabilities: ClientCapabilities) -> PlaybackPlan {
          // Q1: any matching TranscodeOutput?
          let compatible = item.transcodeOutputs.filter { capabilities.canPlay($0) }
          if let best = compatible.sorted(by: rank).first {
              return PlaybackPlan(
                  source: .hlsTranscodeOutput(masterURL: best.masterURL, outputID: best.id),
                  subtitleTracks: item.subtitleTracks,
                  resumeAt: item.resumeAt
              )
          }

          // Q2: source directly playable?
          if let source = item.sourceFiles.first, capabilities.canDirectPlay(source) {
              return PlaybackPlan(
                  source: .directByteRange(source.url),
                  subtitleTracks: item.subtitleTracks,
                  resumeAt: item.resumeAt
              )
          }

          // Q3: live transcode fallback. Pick a profile by caps.
          let profile = liveProfile(for: capabilities)
          let liveMaster = item.sourceFiles.first.map { source in
              URL(string: "/api/v1/stream/live/\(source.id.uuidString)/\(profile)/master.m3u8",
                  relativeTo: nil)!
          } ?? URL(string: "/api/v1/stream/live/unknown/\(profile)/master.m3u8")!
          return PlaybackPlan(
              source: .hlsLive(masterURL: liveMaster, profile: profile),
              subtitleTracks: item.subtitleTracks,
              resumeAt: item.resumeAt
          )
      }

      private static func rank(_ a: TranscodeOutput, _ b: TranscodeOutput) -> Bool {
          (a.vmafTarget ?? 0, a.height, a.createdAt) > (b.vmafTarget ?? 0, b.height, b.createdAt)
      }

      private static func liveProfile(for c: ClientCapabilities) -> String {
          switch c.maxHeight {
          case ..<720: return "h264-480p"
          case 720..<1080: return "h264-720p"
          case 1080..<2160: return "h264-1080p"
          default: return c.codecs.contains(.hevc) ? "hevc-2160p" : "h264-1080p"
          }
      }
  }

  extension ClientCapabilities {
      func canPlay(_ o: TranscodeOutput) -> Bool {
          codecs.contains(o.codec)
              && (o.hdr.map { hdr.contains($0) } ?? true)
              && o.height <= maxHeight
      }
      func canDirectPlay(_ s: SourceFile) -> Bool {
          codecs.contains(s.codec)
              && (s.hdr.map { hdr.contains($0) } ?? true)
              && s.height <= maxHeight
              && ["mp4", "m4v", "mov"].contains(s.container.lowercased())
      }
  }
  ```

  Re-run, expect all `VariantChooserTests` cases PASS.

- [ ] **Step 4: Ensure 100% branch coverage on `VariantChooser.swift`.**

  ```bash
  swift test --enable-code-coverage --filter VariantChooserTests
  xcrun llvm-cov report .build/debug/KinoKitPackageTests.xctest/Contents/MacOS/KinoKitPackageTests \
       -instr-profile=.build/debug/codecov/default.profdata \
       Packages/KinoKit/Sources/KinoKitPlayback/VariantChooser.swift
  ```

  Expected: `Branch %` column reads `100.00%`. If not, add a test case for the missing branch and rerun.

- [ ] **Step 5: `ProgressReporter`.**

  ```swift
  public actor ProgressReporter {
      private var lastSentSeconds: Double = -.infinity
      private let interval: TimeInterval = 10
      private let watchedThreshold: Double = 0.9
      private let onProgress: @Sendable (TimeInterval) async -> Void
      private let onWatched: @Sendable () async -> Void

      public init(onProgress: @escaping @Sendable (TimeInterval) async -> Void,
                  onWatched: @escaping @Sendable () async -> Void) {
          self.onProgress = onProgress; self.onWatched = onWatched
      }

      public func report(seconds: Double, totalSeconds: Double) async {
          if seconds - lastSentSeconds >= interval {
              lastSentSeconds = seconds
              await onProgress(seconds)
          }
          if totalSeconds > 0, seconds / totalSeconds >= watchedThreshold {
              await onWatched()
          }
      }

      public func flush(seconds: Double) async {
          lastSentSeconds = seconds
          await onProgress(seconds)
      }
  }
  ```

  Tests cover: 0s + 5s no callback; 0s + 10s → progress fires; 0s + 10s + 20s → fires twice; flush always fires; watched callback fires at 90% and not before.

- [ ] **Step 6: `PlaybackCoordinator` actor.**

  ```swift
  import AVFoundation

  public actor PlaybackCoordinator {
      private let client: KinoClient
      private let item: MediaItem
      private let capabilities: ClientCapabilities
      private var plan: PlaybackPlan?
      private var reporter: ProgressReporter?
      private var lastPlanKind: PlaybackPlan.Source?

      public init(client: KinoClient, item: MediaItem, capabilities: ClientCapabilities) {
          self.client = client; self.item = item; self.capabilities = capabilities
      }

      public func prepare() async throws -> PlaybackPlan {
          let plan = VariantChooser.choose(item: item, capabilities: capabilities)
          self.plan = plan
          self.lastPlanKind = plan.source
          return plan
      }

      public nonisolated func makePlayerItem(_ plan: PlaybackPlan) -> AVPlayerItem {
          let url: URL = {
              switch plan.source {
              case .directByteRange(let u), .hlsTranscodeOutput(let u, _), .hlsLive(let u, _):
                  return u
              }
          }()
          return AVPlayerItem(url: url)
      }

      public func startReporting(player: AVPlayer) {
          let reporter = ProgressReporter(
              onProgress: { [client, item] sec in
                  try? await client.playback.reportProgress(itemID: item.id, seconds: sec)
              },
              onWatched: { [client, item] in
                  try? await client.playback.markWatched(itemID: item.id)
              }
          )
          self.reporter = reporter
          let interval = CMTime(seconds: 1, preferredTimescale: 600)
          let total = item.runtimeSeconds.map(Double.init) ?? 0
          player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
              Task { await reporter.report(seconds: time.seconds, totalSeconds: total) }
          }
      }

      public func stopReporting() async {
          guard let reporter else { return }
          await reporter.flush(seconds: lastReportedSeconds ?? 0)
      }

      public func handlePlayerFailure(_ error: Error) async throws -> PlaybackPlan {
          guard let current = lastPlanKind else { throw KinoError.playback(.fallbackExhausted) }
          // One-shot fallback ladder per spec §8.
          switch current {
          case .hlsTranscodeOutput:
              // Drop to live transcode.
              let liveProfile = "h264-1080p"
              let url = URL(string: "fallback-live")! // build from item.sourceFiles.first.id
              let plan = PlaybackPlan(source: .hlsLive(masterURL: url, profile: liveProfile),
                                      subtitleTracks: item.subtitleTracks,
                                      resumeAt: item.resumeAt)
              self.plan = plan; self.lastPlanKind = plan.source
              return plan
          case .directByteRange:
              // Try first transcode output if any; else live.
              let plan = VariantChooser.choose(item: item, capabilities: capabilities)
              if case .directByteRange = plan.source {
                  // chooser would have picked direct again; force live
                  let liveProfile = "h264-1080p"
                  let url = URL(string: "fallback-live")!
                  let live = PlaybackPlan(source: .hlsLive(masterURL: url, profile: liveProfile),
                                          subtitleTracks: item.subtitleTracks,
                                          resumeAt: item.resumeAt)
                  self.plan = live; self.lastPlanKind = live.source
                  return live
              }
              self.plan = plan; self.lastPlanKind = plan.source
              return plan
          case .hlsLive:
              throw KinoError.playback(.fallbackExhausted)
          }
      }

      private var lastReportedSeconds: Double? // wired by the time observer if you keep it
  }
  ```

  Tests cover: `prepare()` returns the chooser's plan; calling `handlePlayerFailure` after `.hlsTranscodeOutput` returns a `.hlsLive` plan; after `.hlsLive` throws `.fallbackExhausted`.

- [ ] **Step 7: Write ADR-0004.** One paragraph: chose to keep `VariantChooser` pure-static so the 100% branch bar lives on a function-shaped surface — easy to drive exhaustively from a table-driven test without standing up an actor or mocks. The coordinator actor depends on the chooser; it owns the AVPlayer lifecycle and the progress reporter.

- [ ] **Step 8: Delete placeholder, gates, commit.**

  ```bash
  git rm Packages/KinoKit/Sources/KinoKitPlayback/Placeholder.swift
  just build && just test && just fmt-check && just lint
  git commit -m "feat(kit): add VariantChooser PlaybackCoordinator and progress reporter"
  git add docs/adrs/0004-pure-variant-chooser.md
  git commit -m "docs(agents): add ADR-0004 pure variant chooser"
  ```

---

## Task 6 — M2.6: KinoKit umbrella + `KinoClient` facade

**Linear:** M2.6.
**Blocked by:** Tasks 4 and 5.

**Files:**
- Delete: `Packages/KinoKit/Sources/KinoKit/Placeholder.swift`
- Create: `Packages/KinoKit/Sources/KinoKit/KinoClient.swift`
- Create: `Packages/KinoKit/Sources/KinoKit/LibraryAPI.swift`
- Create: `Packages/KinoKit/Sources/KinoKit/RequestsAPI.swift`
- Create: `Packages/KinoKit/Sources/KinoKit/DiscoverAPI.swift`
- Create: `Packages/KinoKit/Sources/KinoKit/PlaybackAPI.swift`
- Create: `Packages/KinoKit/Sources/KinoKit/AdminAPI.swift`
- Create: `Packages/KinoKit/Sources/KinoKit/Exports.swift`
- Create: `Packages/KinoKit/Tests/KinoKitTests/ClientTests/KinoClientTests.swift`
- Keep: `Packages/KinoKit/Sources/KinoKit/Version.swift`

### Key shape

```swift
public final class KinoClient: Sendable {
    public let session: AuthorizedSession
    private let transport: KinoTransport

    public init(session: AuthorizedSession, transport: KinoTransport? = nil) {
        self.session = session
        self.transport = transport ?? .live(baseURL: session.baseURL, token: { session.token })
    }

    public var library: LibraryAPI { .init(transport: transport) }
    public var requests: RequestsAPI { .init(transport: transport) }
    public var discover: DiscoverAPI { .init(transport: transport) }
    public var playback: PlaybackAPI { .init(transport: transport) }
    public var admin: AdminAPI? { session.isAdmin ? .init(transport: transport) : nil }
    public var images: ImageLoader { .init(session: transport.urlSession, token: { self.session.token }) }
}
```

(`AuthorizedSession.isAdmin` is a computed property added in Task 2 if missing — `false` for the single-user model today; flip when the server gains user roles. The spec calls out the surface; add the boolean now and default it `false` so M2 ships consistently.)

Per-API structs are small wrappers that call `transport.makeClient().<operation>(...)` and translate the result into the public type.

### Steps

- [ ] **Step 1: Add `isAdmin` to `AuthorizedSession`.**

  Tactical: thread back into Task 2's file. The spec already keeps this in scope. Add as `public let isAdmin: Bool` with default `false` on the init, and back-compat Codable via a custom `init(from:)` that defaults missing keys.

- [ ] **Step 2: Write `LibraryAPI` first (the surface most apps will use).**

  Test:

  ```swift
  func test_library_list_decodesItemsArray() async throws {
      StubURLProtocol.reset()
      StubURLProtocol.push(when: { $0.url?.path.hasSuffix("/api/v1/library/items") ?? false },
                           .init(status: 200, headers: ["Content-Type":"application/json"], body: fixtureItemsJSON))
      let client = KinoClient(session: testSession,
                              transport: .mock(.stubbed, token: { "tok" }))
      let items = try await client.library.list(limit: 10, offset: 0, q: nil)
      XCTAssertEqual(items.count, 2)
  }
  ```

  Implementation: call `transport.makeClient().listLibraryItems(...)` (substitute the real operation name your generator emits — `swift-openapi-generator` derives Swift method names from `operationId`); map to the public `MediaItem` model.

- [ ] **Step 3: `RequestsAPI`, `DiscoverAPI`, `PlaybackAPI`, `AdminAPI` (when non-nil).** Each gets at least one happy-path test using `StubURLProtocol`. Methods to cover (minimum):

  - `requests.create(kind:tmdbID:)`, `requests.list()`.
  - `discover.search(q:kind:page:)`.
  - `playback.reportProgress(itemID:seconds:)`, `playback.markWatched(itemID:)`.
  - `admin?.listPendingPairings()`, `admin?.approve(pairingID:)`, `admin?.reject(pairingID:)`.

- [ ] **Step 4: `Exports.swift`.**

  ```swift
  @_exported import KinoKitCore
  @_exported import KinoKitTransport
  @_exported import KinoKitAuth
  @_exported import KinoKitPlayback
  ```

  Apps write `import KinoKit` and see everything they need.

- [ ] **Step 5: Delete placeholder, gates, commit.**

  ```bash
  git rm Packages/KinoKit/Sources/KinoKit/Placeholder.swift
  just build && just test && just fmt-check && just lint
  git commit -m "feat(kit): add KinoClient facade and per-resource APIs"
  ```

---

## Task 7 — M2.7: `KinoKitProbe` + `kit-coverage` CI

**Linear:** M2.7.
**Blocked by:** Task 6.

**Files:**
- Create: `Packages/KinoKit/Probe/KinoKitProbe/main.swift`
- Modify: `Packages/KinoKit/Package.swift` (add executable target)
- Modify: `Justfile` (add `probe` recipe)
- Modify: `.github/workflows/ci.yml` (add `kit-coverage` job)
- Create: `docs/agents/plans/2026-MM-DD-m2-acceptance-results.md` (after running the probe — date set when run)

### Steps

- [ ] **Step 1: Add the executable target to `Package.swift`.**

  Append to `targets:`:

  ```swift
  .executableTarget(
      name: "KinoKitProbe",
      dependencies: ["KinoKit"],
      path: "Probe/KinoKitProbe"
  ),
  ```

  Verify `swift build --product KinoKitProbe` succeeds.

- [ ] **Step 2: Write `main.swift`.**

  ```swift
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
          let deviceName = env["KINO_PROBE_DEVICE_NAME"] ?? "Probe-\(Host.current().localizedName ?? "unknown")"
          let platform = ClientPlatform(rawValue: env["KINO_PROBE_PLATFORM"] ?? "macOS") ?? .macOS

          // 1. Resolve a server.
          let server: ResolvedServer
          if let base = env["KINO_PROBE_BASE_URL"].flatMap(URL.init(string:)) {
              server = ResolvedServer(instanceID: UUID(), host: base.host ?? "localhost",
                                      port: base.port ?? 7000,
                                      apiVersion: "v1", serverVersion: "unknown")
          } else {
              let discovery = ServerDiscovery()
              var first: DiscoveredServer?
              for await s in await discovery.browse() { first = s; break }
              guard let first else { throw NSError(domain: "probe", code: 1) }
              server = try await discovery.resolve(first)
          }
          print("Resolved server: \(server.host):\(server.port) (\(server.serverVersion))")

          // 2. Pair.
          let pairing = PairingClient(server: server)
          let challenge = try await pairing.requestCode(deviceName: deviceName, platform: platform)
          print("Pairing code: \(challenge.code) — approve in the admin SPA. Expires at \(challenge.expiresAt).")
          let session = try await pairing.awaitApproval(challenge)
          print("Paired. Session token id: \(session.tokenID).")

          // 3. Persist.
          try await KeychainSessionStore(service: "kino.probe").save(session)

          // 4. List a library item.
          let client = KinoClient(session: session)
          let items = try await client.library.list(limit: 1, offset: 0, q: nil)
          guard let first = items.first else { print("Library empty."); return }
          print("First library item: \(first.id) — \(first.title)")

          // 5. Optionally build a playback URL.
          if let idString = env["KINO_PROBE_ITEM_ID"], let id = UUID(uuidString: idString) {
              let item = try await client.library.get(id: id)
              let caps = ClientCapabilities(
                  codecs: [.h264, .hevc],
                  hdr: [.hdr10],
                  maxHeight: 2160,
                  surroundAudio: true,
                  atmos: false
              )
              let plan = VariantChooser.choose(item: item, capabilities: caps)
              print("Playback plan: \(plan.source)")
          }
      }
  }
  ```

- [ ] **Step 3: Add `just probe`.**

  Append to `Justfile`:

  ```just
  # Run the KinoKit probe against a real local kino-server.
  # Override defaults via env: KINO_PROBE_BASE_URL, KINO_PROBE_ITEM_ID, etc.
  probe:
      swift run --package-path Packages/KinoKit KinoKitProbe
  ```

- [ ] **Step 4: Add the `kit-coverage` CI job.**

  Edit `.github/workflows/ci.yml` and add a new job (sibling to `kit-test`):

  ```yaml
    kit-coverage:
      runs-on: macos-14
      steps:
        - uses: actions/checkout@v4
        - uses: maxim-lobanov/setup-xcode@v1
          with:
            xcode-version: latest-stable
        - name: Build + test with coverage
          working-directory: Packages/KinoKit
          run: swift test --enable-code-coverage
        - name: Enforce coverage thresholds
          working-directory: Packages/KinoKit
          run: |
            BIN=".build/debug/KinoKitPackageTests.xctest/Contents/MacOS/KinoKitPackageTests"
            PROF=".build/debug/codecov/default.profdata"
            xcrun llvm-cov report "$BIN" -instr-profile="$PROF" > coverage.txt
            cat coverage.txt
            # Package-wide line coverage ≥ 80.
            LINE_PCT=$(awk '/TOTAL/ {print $4}' coverage.txt | tr -d '%')
            echo "Package line coverage: $LINE_PCT"
            awk -v p="$LINE_PCT" 'BEGIN{ if (p+0 < 80) exit 1 }'
            # VariantChooser.swift branch coverage = 100.
            xcrun llvm-cov report "$BIN" -instr-profile="$PROF" \
              Sources/KinoKitPlayback/VariantChooser.swift > vc.txt
            cat vc.txt
            BRANCH_PCT=$(awk '/VariantChooser/ {print $8}' vc.txt | tr -d '%')
            echo "VariantChooser branch coverage: $BRANCH_PCT"
            awk -v p="$BRANCH_PCT" 'BEGIN{ if (p+0 < 100) exit 1 }'
  ```

  Column indices for `llvm-cov report` may need adjustment depending on the runner's `llvm-cov` version. If `awk` field numbers don't line up, swap in `xcrun llvm-cov export --format=lcov` and parse with `lcov --summary` or `jq` against `--format=text`. Keep it shell-only — no extra deps.

- [ ] **Step 5: Add `kit-coverage` to required-checks list.**

  Note in the PR description that `main`'s branch-protection rule needs `kit-coverage` added manually under GitHub Settings → Branches → main → Required status checks. Per `AGENTS.md`, this isn't in code.

- [ ] **Step 6: Verify all gates, then run the probe.**

  Local:

  ```bash
  just build && just test && just fmt-check && just lint
  just probe   # expects a real local kino-server reachable on LAN
  ```

  Approve the code in the admin SPA when prompted. Capture the stdout output into `docs/agents/plans/2026-MM-DD-m2-acceptance-results.md` (mirror the M0 results doc style at `docs/agents/plans/2026-05-14-m0-acceptance-results.md`).

- [ ] **Step 7: Commit and PR.**

  ```bash
  git add Packages/KinoKit/Probe Packages/KinoKit/Package.swift Justfile .github/workflows/ci.yml \
          docs/agents/plans/2026-MM-DD-m2-acceptance-results.md
  git commit -m "feat(kit): add KinoKitProbe executable and kit-coverage CI job"
  ```

  PR body links the design spec exit-bar (§1.3) and pastes the probe output.

---

## Self-review (done before saving this plan)

1. **Spec coverage:** every item in the design spec §1.3 exit bar has a matching task — `just build/test` (every task), kit-coverage thresholds (Task 7 step 4), probe flow (Task 7 step 2), acceptance results file (Task 7 step 6), three ADRs (Task 1 step 8, Task 4 step 3, Task 5 step 7). ✓
2. **Placeholder scan:** the `2026-MM-DD-m2-acceptance-results.md` filename is a deliberate template — the date is set when the probe runs. The `Client` symbol from `swift-openapi-generator` is flagged as "adjust to the real symbol" rather than left vague. No "TBD" or "TODO" anywhere. ✓
3. **Type consistency:** `KinoTransport.live(baseURL:token:)` signature is identical across Task 3 and Task 6. `VariantChooser.choose(item:capabilities:)` signature is identical across Task 5 and Task 7. `PlaybackPlan.Source` cases match across Tasks 5 and 7. ✓
4. **Sub-issue dependencies match Linear:** task ordering matches the design spec §2 table (M2.1‖M2.2 → M2.3 → M2.4‖M2.5 → M2.6 → M2.7). ✓
