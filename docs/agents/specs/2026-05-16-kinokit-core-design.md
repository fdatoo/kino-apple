# M2 — KinoKit core (F-277) design

> Authored 2026-05-16. Refines `2026-05-13-phase-4-design.md` §5 for the
> specific execution of F-277.

This spec narrows the Phase 4 design to what M2 ships, fixes the open items §5
left for "the start of M2", and decomposes F-277 into seven sub-issues that
match the M0/M1 grain.

## 1. Scope and exit bar

F-277 delivers the shared `KinoKit` SwiftPM package that all three Apple apps
consume. KinoKit is feature-complete but not frozen at the end of M2 — M3
(iOS) is the API-honesty forcing function and may surface follow-up changes;
the freeze lands at the close of M3 per the Phase 4 spec §10.

### In scope

Full §5 surface, no deferrals:

- Generated API client via `swift-openapi-generator` build plugin from a
  vendored `openapi.json` (ADR-0001).
- Hand-written `KinoClient` facade with typed `KinoError`.
- `ServerDiscovery` (NWBrowser), `PairingClient` (clock-injected polling),
  `KeychainSessionStore` (multi-server-shaped: `loadAll`/`save`/`remove`).
- `PlaybackCoordinator` (actor) + pure `VariantChooser` + progress reporter +
  one-shot fallback ladder.
- `LibraryAPI`, `RequestsAPI`, `DiscoverAPI` (TMDB proxy), `PlaybackAPI`,
  `AdminAPI?`, and an `ImageLoader` exposed on `KinoClient`.
- `KinoKitProbe` executable target validating discovery + pairing + playback
  URL build against a real local `kino-server`.

### Out of scope

Same exclusions as the Phase 4 spec §2 (no SwiftUI views, no app navigation,
no offline downloads, no analytics, no snapshot tests). Plus:

- No CI drift check on `openapi.json`. Replaced by a local `just openapi-sync`
  recipe — bumps are deliberate engineer-initiated PRs.

### Exit bar

1. `just build` and `just test` pass locally and in CI on a fresh clone.
2. `kit-coverage` reports **≥80% package line coverage** and **100% branch
   coverage on `KinoKitPlayback/VariantChooser.swift`**.
3. A run of `just probe` against a real local `kino-server`:
   - Discovers the server via `NWBrowser` (or accepts manual
     `KINO_PROBE_BASE_URL`).
   - Pairs successfully (6-digit code approved in admin SPA).
   - Saves the session to Keychain (`service = "kino.probe"`).
   - Lists ≥1 library item.
   - With `KINO_PROBE_ITEM_ID` set, prints a non-empty `PlaybackPlan.source`
     URL.
4. Probe output captured in
   `docs/agents/plans/<date>-m2-acceptance-results.md`.
5. Three ADRs landed: 0002 (NWBrowser), 0003 (openapi-sync), 0004 (pure
   `VariantChooser`).

## 2. Decomposition — F-277 sub-issues

F-277 becomes the M2 epic. Seven sub-issues, layer-bottom-up, mirroring M1's
grain. Each is one PR.

| ID | Title | Blocked by |
|---|---|---|
| M2.1 | KinoKitGenerated + `openapi.json` vendoring + `just openapi-sync` | — |
| M2.2 | KinoKitCore — domain models + `KinoError` | — |
| M2.3 | KinoKitTransport — URLSession glue + auth interceptor + image cache primitive | M2.1, M2.2 |
| M2.4 | KinoKitAuth — `ServerDiscovery` + `PairingClient` + `KeychainSessionStore` | M2.3 |
| M2.5 | KinoKitPlayback — `VariantChooser` + `PlaybackCoordinator` + fallback ladder | M2.3 |
| M2.6 | KinoKit umbrella — `KinoClient` facade + Library/Requests/Discover/Playback/Admin/Images APIs | M2.4, M2.5 |
| M2.7 | KinoKitProbe — executable target validating discovery → pairing → playback URL build | M2.6 |

Parallelism windows: `(M2.1 ‖ M2.2) → M2.3 → (M2.4 ‖ M2.5) → M2.6 → M2.7`.

Labels: `apple-shared`, `clients` (same as M0.x). Branch names:
`fdatoo/f-XXX-short-slug`.

## 3. Package layout

Existing scaffold stays. M2.1 adds `KinoKitGenerated`. The umbrella `KinoKit`
re-exports the public surface.

```
Packages/KinoKit/
├── Package.swift                              # +KinoKitGenerated target with swift-openapi-generator plugin
├── Sources/
│   ├── KinoKitGenerated/
│   │   ├── openapi.json                       # vendored, hand-bumped via `just openapi-sync`
│   │   ├── openapi-generator-config.yaml      # ADR-0001 settings (types+client)
│   │   └── Empty.swift                        # placeholder so the target compiles before plugin runs
│   ├── KinoKitCore/                           # no deps. Domain types + errors. Sendable + strict-concurrency clean.
│   ├── KinoKitTransport/                      # deps: Core, Generated. URLSession transport, auth interceptor,
│   │                                          # error mapping, image cache primitive.
│   ├── KinoKitAuth/                           # deps: Core, Transport. Discovery (NWBrowser), pairing, Keychain store.
│   ├── KinoKitPlayback/                       # deps: Core, Transport. Variant chooser (pure), coordinator (actor),
│   │                                          # progress reporter, fallback ladder.
│   └── KinoKit/                               # deps: all above. Umbrella; re-exports + `KinoClient` facade.
├── Tests/
│   └── KinoKitTests/                          # one test target; sub-folders mirror modules.
│       ├── CoreTests/
│       ├── TransportTests/
│       ├── AuthTests/
│       ├── PlaybackTests/
│       └── ClientTests/
└── Probe/
    └── KinoKitProbe/main.swift                # M2.7: `.executableTarget` under the same package.
```

Module rules:

- `KinoKitCore` is the only public type-origin point. Peer modules import
  Core but never each other (transport→core only; auth→core+transport;
  playback→core+transport; umbrella→all).
- `KinoKitGenerated` is consumed only by `KinoKitTransport`. Apps and other
  modules never see generated types directly.
- `KinoKit` umbrella uses `@_exported import` for the public surface so apps
  write one `import KinoKit`.
- One test target with sub-folders per module — keeps `swift test` fast and
  avoids per-target boilerplate.

## 4. Public surface

Mostly the Phase 4 spec §5, sharpened. Key resolutions inline.

```swift
// ───── KinoKitCore: pure types, no I/O ──────────────────────────────

public enum ClientPlatform: String, Sendable, Codable { case iOS, tvOS, macOS }

public struct DiscoveredServer: Sendable, Hashable {
    public let instanceID: UUID
    public let name: String            // Bonjour instance name
    public let txt: [String: String]   // version=, api=, instance_id=
}

public struct ResolvedServer: Sendable, Hashable {
    public let instanceID: UUID
    public let host: String
    public let port: Int
    public let apiVersion: String      // "v1"
    public let serverVersion: String   // semver from TXT
}

public struct AuthorizedSession: Sendable, Codable, Hashable {
    public let serverInstanceID: UUID
    public let baseURL: URL
    public let tokenID: UUID
    public let token: String           // never logged; Codable for Keychain blob
    public let userID: UUID
    public let deviceName: String
    public let createdAt: Date
}

public struct ClientCapabilities: Sendable, Hashable {
    public let codecs: Set<Codec>      // h264, hevc, av1
    public let hdr: Set<HDRFormat>     // hdr10, dolbyVision, hlg
    public let maxHeight: Int          // 1080 / 2160 / …
    public let surroundAudio: Bool
    public let atmos: Bool
}

public enum KinoError: Error, Sendable {
    case transport(URLError)
    case server(status: Int, body: ErrorResponse?)
    case unauthorized
    case pairing(PairingError)
    case playback(PlaybackError)
    case decoding(any Error)            // `any Error` not DecodingError — URLSession surfaces non-Decoding decode failures too
}

public enum PairingError: Error, Sendable { case expired, rejected, codeCollision, malformedResponse }
public enum PlaybackError: Error, Sendable { case noPlayablePlan, fallbackExhausted, capabilitiesMissing }


// ───── KinoKitAuth: discovery + pairing + storage ──────────────────

public actor ServerDiscovery {
    public init()                                              // NWBrowser-backed
    public func browse() -> AsyncStream<DiscoveredServer>      // hot stream; cancel by dropping the iterator
    public func resolve(_ s: DiscoveredServer) async throws -> ResolvedServer
}

public struct PairingClient: Sendable {
    public init(server: ResolvedServer,
                transport: KinoTransport = .live,
                clock: any Clock<Duration> = ContinuousClock())
    public func requestCode(deviceName: String, platform: ClientPlatform) async throws -> PairingChallenge
    public func awaitApproval(_ ch: PairingChallenge) async throws -> AuthorizedSession
    // Polls GET /pairings/{code}, 2s ± 500ms jitter, ceiling = expires_at.
}

public protocol SessionStore: Sendable {
    func loadAll() async throws -> [AuthorizedSession]
    func save(_ s: AuthorizedSession) async throws
    func remove(serverInstanceID: UUID) async throws
}
public struct KeychainSessionStore: SessionStore { public init(service: String = "kino.session") }


// ───── KinoKit: the authorized facade apps hold ────────────────────

public final class KinoClient: Sendable {
    public init(session: AuthorizedSession, transport: KinoTransport = .live)
    public var library: LibraryAPI { get }
    public var requests: RequestsAPI { get }
    public var discover: DiscoverAPI { get }    // /api/v1/discover (TMDB proxy)
    public var playback: PlaybackAPI { get }
    public var admin: AdminAPI? { get }         // present only with admin scope
    public var images: ImageLoader { get }      // URL+URLCache primitive; inherits session auth for library images
}


// ───── KinoKitPlayback: variant selection + coordinator ────────────

public struct PlaybackPlan: Sendable, Hashable {
    public enum Source: Sendable, Hashable {
        case directByteRange(URL)
        case hlsTranscodeOutput(masterURL: URL, outputID: UUID)
        case hlsLive(masterURL: URL, profile: String)
    }
    public let source: Source
    public let subtitleTracks: [SubtitleTrack]
    public let resumeAt: TimeInterval?
}

public enum VariantChooser {                                    // pure static; 100% branch testable
    public static func choose(item: MediaItem,
                              capabilities: ClientCapabilities) -> PlaybackPlan
}

public actor PlaybackCoordinator {
    public init(client: KinoClient, item: MediaItem, capabilities: ClientCapabilities)
    public func prepare() async throws -> PlaybackPlan
    public func makePlayerItem(_ plan: PlaybackPlan) -> AVPlayerItem
    public func startReporting(player: AVPlayer)
    public func stopReporting() async
    public func handlePlayerFailure(_ error: Error) async throws -> PlaybackPlan   // one-shot fallback
}
```

### Resolutions baked in

- **Discovery API:** `NWBrowser` from `Network.framework`. `NetServiceBrowser`
  is deprecated; `NWBrowser` is the strict-concurrency-friendly choice. TXT
  records come from `NWBrowser.Result.metadata`. → ADR-0002.
- **Clock injection:** `any Clock<Duration>` on `PairingClient` so polling
  cadence/expiry tests are deterministic.
- **Transport injection:** `KinoTransport` is a thin `Sendable` wrapper
  (`.live` and `.mock(URLSession)` factories); same seam used by every test.
- **`VariantChooser` is pure static**, separate from `PlaybackCoordinator`, so
  the 100% branch-coverage bar lives on a function-shaped surface. → ADR-0004.
- **`ImageLoader` belongs on `KinoClient`** (not free-floating) so it inherits
  the session's auth for library-item image URLs.

## 5. OpenAPI vendoring workflow

- `openapi.json` lives at
  `Packages/KinoKit/Sources/KinoKitGenerated/openapi.json`. It is the contract
  this version of KinoKit binds to.
- A `just openapi-sync REF=<tag-or-sha>` recipe pulls the file from the `kino`
  repo at the named ref (default = latest `kino` tag) and writes the local
  copy. The engineer commits the result in a deliberate PR.
- No CI drift check. → ADR-0003.
- `swift-openapi-generator` runs as a build plugin per ADR-0001 with config at
  `Sources/KinoKitGenerated/openapi-generator-config.yaml` (`types + client`,
  matching ADR-0001).

## 6. Testing strategy

### Test seams (already in the surface)

- `KinoTransport.mock(_ session: URLSession)` accepts a `URLSession` whose
  configuration has a `StubURLProtocol` registered to serve canned responses
  derived from `openapi.json`'s response examples.
- `PairingClient.init(..., clock:)` accepts an injected `any Clock<Duration>`
  so polling cadence and 5-min expiry are deterministic.
- `KeychainSessionStore.init(service:)` accepts a per-test Keychain service
  string so tests don't collide.

### Per-module bar

- **CoreTests** — round-trip Codable for `AuthorizedSession`,
  `ClientCapabilities`, `KinoError` fingerprints. No I/O.
- **TransportTests** — happy path, 401 → `KinoError.unauthorized`, transport
  failure → `.transport`, server error body decode → `.server(status:body:)`.
  Verifies the auth interceptor stamps `Authorization: Bearer …` and never
  logs the token.
- **AuthTests**
  - `ServerDiscovery`: end-to-end test spawns a small `NWListener`
    advertising `_kino._tcp` on a high port and asserts the stream yields the
    expected `DiscoveredServer`. Skipped on CI if the runner blocks Bonjour;
    gated like the server-side `hwaccel-tests`.
  - `PairingClient`: simulated server flips status on cue; injected clock
    advances; covers pending→approved, expiry, rejected, code collision,
    malformed response, one-shot replay rejection.
  - `KeychainSessionStore`: real Keychain on the test process; per-test
    service string; tearDown wipes the service. `loadAll` ordering is stable
    by `createdAt`.
- **PlaybackTests**
  - `VariantChooser`: exhaustive matrix — every
    `(capabilities × outputs × source-codec/HDR)` cell gets a deterministic
    expected `PlaybackPlan`. Table-driven. **This is the 100%-branch target.**
  - `PlaybackCoordinator`: progress-throttle behavior (10s cadence, flush on
    stop), one-shot fallback ladder (HLS→Live, Direct→HLS/Live,
    Live→surface), reporting-stop on background.
- **ClientTests** — `KinoClient` wires per-resource APIs to the right
  transport calls; `images` returns auth-stamped URLs; `admin` is `nil` for a
  non-admin session.

### Coverage gates

Enforced via `swift test --enable-code-coverage` + `xccov` in a new CI step:

- Package-wide **≥80% line**.
- `KinoKitPlayback/VariantChooser.swift` **= 100% branch**.

Job name: `kit-coverage`. Fails the PR if either threshold drops.

## 7. KinoKitProbe (M2.7)

`.executableTarget` named `KinoKitProbe` in the same `Package.swift`. Manual
run, not CI.

**Inputs (env vars, all optional with sensible defaults):**

```
KINO_PROBE_BASE_URL        # if set, skip discovery, use this URL directly
KINO_PROBE_DEVICE_NAME     # default = "Probe-${hostname}"
KINO_PROBE_PLATFORM        # default = "macOS"
KINO_PROBE_ITEM_ID         # optional; if set, also resolves a playback URL
```

**Flow:**

```
1. If KINO_PROBE_BASE_URL unset:
     ServerDiscovery().browse() → first DiscoveredServer → resolve()
   Else:
     build a ResolvedServer from the URL.
2. PairingClient.requestCode(...) → print the code; user approves in admin SPA.
3. awaitApproval() → AuthorizedSession.
4. KeychainSessionStore(service: "kino.probe").save(session).
5. KinoClient(session: session)
   - GET /library/items?limit=1 → print first item id + title.
6. If KINO_PROBE_ITEM_ID set, fetch the item, run VariantChooser against
   macOS capabilities, print the chosen PlaybackPlan.source URL.
7. Exit 0 on success; any KinoError is printed and exits non-zero.
```

**Justfile target:** `just probe` runs
`swift run --package-path Packages/KinoKit KinoKitProbe`. The README documents
the env vars.

The probe is the F-277 exit-bar gate (§1.3).

## 8. CI footprint

`.github/workflows/ci.yml` changes for M2:

- **Add `kit-coverage`** job (new): `macos-14` runner; runs
  `swift test --enable-code-coverage`, parses `.xcresult` with `xccov`, fails
  if package line < 80% or `VariantChooser.swift` branch < 100%.
- **Keep `kit-test`** (`swift test`) and **`kit-format`**
  (`swift-format lint --strict`).
- **No `openapi-binding-drift` job** — replaced by `just openapi-sync`.
- **No new uitest jobs** — probe is manual.

Branch protection on `main` adds `kit-coverage` to the required-checks list.
(Reminder per `AGENTS.md`: this is a GitHub-settings change, not in code.)

Wall-time budget: +3 min over today's KinoKit jobs.

## 9. ADRs landing alongside

Three short ADRs (one paragraph each), each its own PR or batched into M2.1:

- **ADR-0002 — NWBrowser for client-side mDNS discovery.** Trade-off vs the
  deprecated `NetServiceBrowser`.
- **ADR-0003 — Vendored `openapi.json` + `just openapi-sync` (no CI drift
  job).** Records the "deliberate bump PR" workflow.
- **ADR-0004 — Pure-function `VariantChooser` separate from
  `PlaybackCoordinator`.** Records why and how the 100% branch-coverage bar
  is reached.

## 10. Open items deferred past M2

These are surfaced by M3+ if at all:

- Whether `ImageLoader` needs a memory cache layer in front of `URLCache`
  (current plan: URLCache disk only; M3 measures).
- Whether `KinoClient` needs an automatic 401-recovery (re-pair prompt) path,
  or whether apps surface `KinoError.unauthorized` themselves. Current plan
  is the latter; M3 may push back.
- Public consumption of KinoKit as an external SwiftPM package — deferred to
  Phase 5 per the Phase 4 spec §11.
