# Phase 4 — Native Apple Clients

> Design spec for Phase 4 of Kino's roadmap. Authored 2026-05-13.

## 1. Goal and exit bar

Phase 4 delivers three native Apple clients — **iOS**, **tvOS**, **macOS** — each
shippable to TestFlight and sideload-installable, all consuming a shared
`KinoKit` Swift package, all backed by the existing `kino-server` HTTP API plus
modest server additions (pairing, mDNS, TMDB discovery, library search filter).

**Per-platform exit bar (each client must meet it independently):**

A user can install the app, find their server on LAN via mDNS or enter a URL
manually, pair via a 6-digit code shown on the client and approved in the admin
SPA, browse the library, search the library, discover and request un-owned
content, play any item with subtitle support and progress tracking, mark items
watched/unwatched, and on iOS/macOS hand audio off via AirPlay. Direct play is
the default; transcoded variants and live on-the-fly transcoding are honored
when negotiated. Resume positions and watched flags sync across devices because
the server already owns them.

**Phase milestone exit bar:** all three clients meet their per-platform exit
bar; KinoKit is frozen at a tagged version both apps and the server's
`openapi.json` agree on.

## 2. Scope

### In scope (server side, this repo)

- Bonjour / `_kino._tcp` mDNS responder.
- Pairing endpoints under `/api/v1/pairings` and `/api/v1/admin/pairings`.
- TMDB discovery proxy: `GET /api/v1/discover`.
- Library search filter: `q` parameter on `GET /api/v1/library/items`.
- Admin SPA "Pairings" pane.

### In scope (Apple side, `kino-apple` repo)

- `KinoKit` SwiftPM package: API client (generated), models, auth/pairing,
  discovery, playback coordinator, Keychain session storage.
- `Kino-iOS`, `Kino-tvOS`, `Kino-macOS` apps: discovery → pairing → browse →
  search → discover → request → play, per the per-platform exit bar.

### Explicitly out of scope

- Offline downloads.
- Multi-user, per-user accounts, sharing — Phase 5.
- Public App Store release — TestFlight + sideload only.
- Windows or Android clients.
- Apple Watch, CarPlay, picture-in-picture beyond what `AVPlayerViewController`
  gives free, Cast/Chromecast targets.
- Library-management actions from clients (delete, re-OCR, reprobe stay
  admin-only via the SPA).
- Snapshot tests for app UIs in v1.

### Explicitly leaves untouched

- The vision, ADR-0001..0004, and Phase 0–3 specs.
- The existing per-device token model — pairing mints into the existing
  `tokens` table via existing `token.rs` machinery.
- The existing `kino-admin` SPA, except for the new Pairings pane.
- The existing `/api/v1` versioning policy.

## 3. `kino-apple` repository

Single repo containing the SwiftPM package and three Xcode app projects.
Hygiene mirrors Kino's exactly — agents and humans share one workflow.

### Layout

```
kino-apple/
├── AGENTS.md                    # canonical onboarding doc
├── CLAUDE.md → AGENTS.md        # symlink
├── README.md
├── Justfile                     # setup, build, test, fmt, fmt-check, lint
├── .githooks/                   # pre-commit: fmt-check + lint on staged Swift
├── .gitignore
├── .editorconfig
├── docs/
│   ├── kino-apple-vision.md     # narrow restatement of how Apple side relates
│   │                            # to the server-side vision
│   ├── adrs/                    # ADR-0001 onward; same template as Kino
│   │   └── README.md
│   └── agents/
│       ├── README.md
│       ├── specs/               # YYYY-MM-DD-<slug>.md
│       └── plans/               # YYYY-MM-DD-<slug>.md
├── Packages/
│   └── KinoKit/
│       ├── Package.swift
│       ├── Sources/KinoKit/
│       ├── Sources/KinoKitGenerated/   # swift-openapi-generator output
│       └── Tests/KinoKitTests/
├── Apps/
│   ├── Kino-iOS/                # Xcode project + UITests target
│   ├── Kino-tvOS/
│   └── Kino-macOS/
├── Kino.xcworkspace             # references all 3 apps + KinoKit package
└── .github/workflows/ci.yml     # macOS-14 runner: fmt, lint, test, build
```

### Toolchain & gates

- Swift 6.x. Deployment targets: iOS 17 / tvOS 17 / macOS 14.
- **Format:** `swift-format` from the toolchain. `just fmt` writes; `just
  fmt-check` is the gate; pre-commit runs `fmt-check` on staged `.swift` files.
- **Lint:** `swift-format lint --strict`. No SwiftLint dependency unless a
  specific rule we need is missing; if added, recorded in an ADR.
- **Build:** `xcodebuild` per app, `swift build` for KinoKit. `just build` runs
  all four. CI does the same on `macos-14`.
- **Test:** `swift test` for KinoKit + `xcodebuild test` for app smoke tests.
  `just test` runs both.
- **Setup:** `just setup` activates `core.hooksPath .githooks`, verifies Swift
  toolchain. Same contract as Kino — skipping it gets commits rejected.

### Conventions

- **Commits:** semantic prefix, one line, no body, no trailers — same rule as
  Kino. Allowed prefixes: `feat`, `fix`, `chore`, `refactor`, `test`, `docs`,
  `perf`, `build`. Allowed scopes: `kit`, `ios`, `tvos`, `macos`, `ci`, `repo`,
  `agents`, `docs`.
- **Branches:** `fdatoo/f-XXX-short-slug`. Linear issues live in the same
  FynnLabs/Kino project, so `F-` numbering stays continuous across repos.
- **Code style:** every public KinoKit symbol gets a `///` doc comment; tests
  colocated with code or under `Tests/`; no `print` outside the apps' top-level
  (use `os.Logger`); errors are typed `enum`s per module conforming to
  `LocalizedError`.
- **ADRs:** any cross-cutting decision (e.g., `swift-openapi-generator` vs
  hand-written, mDNS library choice, `swift-format` rule overrides) lands as an
  ADR in `docs/adrs/`.

### CI runner reality

GitHub Actions `macos-14` runners (Apple Silicon). One workflow with parallel
jobs per platform target. **No code signing in CI for v1** — release builds
verify they compile, nothing more. TestFlight uploads stay manual until they
hurt enough to automate.

## 4. Server pre-work (this repo)

All additions sit under `/api/v1` per ADR-0004.

### 4.1 Bonjour / mDNS responder

- New config keys (default-on, opt-out via `KINO_SERVER__DISCOVERY__ENABLED`):
  - `KINO_SERVER__DISCOVERY__ENABLED` — default `true`.
  - `KINO_SERVER__DISCOVERY__INSTANCE_NAME` — default = system hostname.
- Service type: `_kino._tcp` on port `KINO_SERVER__LISTEN`'s port.
- TXT record carries `version=<kino semver>`, `api=v1`, `instance_id=<server
  side stable Id>`.
- Implementation depends on a small mDNS crate (likely `mdns-sd`); choice
  recorded in a new ADR.
- Spawns from `kino-server` startup alongside the HTTP listener; respects
  shutdown.

### 4.2 Pairing endpoints

New `pairings` table (single migration in `kino-db`):

```sql
CREATE TABLE pairings (
    id           BLOB PRIMARY KEY,           -- Id (UUID v7)
    code         TEXT NOT NULL UNIQUE,       -- 6-digit, base10
    device_name  TEXT NOT NULL,              -- client-supplied free text
    platform     TEXT NOT NULL,              -- "ios" | "tvos" | "macos"
    status       TEXT NOT NULL,              -- "pending" | "approved"
                                             --  | "expired" | "consumed"
    token_id     BLOB,                       -- FK to tokens(id) once approved
    created_at   TEXT NOT NULL,              -- Timestamp (UTC)
    expires_at   TEXT NOT NULL,              -- created_at + 5 min
    approved_at  TEXT
);
CREATE INDEX pairings_status_expires ON pairings(status, expires_at);
```

Endpoints (all return `ErrorResponse` shape consistent with existing routes):

| Method | Path | Auth | Purpose |
|---|---|---|---|
| `POST` | `/api/v1/pairings` | none | Client requests a code. Body: `{ device_name, platform }`. Returns `{ pairing_id, code, expires_at }`. |
| `GET`  | `/api/v1/pairings/{code}` | none | Client polls. Returns `{ status: "pending" }` (200), or `{ status: "approved", token, token_id, user_id }` (200) on the first read after approval (then status flips to `consumed`), or 410 if expired/consumed. |
| `GET`  | `/api/v1/admin/pairings` | bearer | Admin SPA lists pending pairings. |
| `POST` | `/api/v1/admin/pairings/{id}/approve` | bearer | Admin claims a pairing. No body. Mints a row in `tokens` reusing `token.rs`, owned by the admin caller's `user_id` (single-user model today; Phase 5 will let admins approve into a chosen user). Links the new token, sets status → `approved`. |
| `POST` | `/api/v1/admin/pairings/{id}/reject` | bearer | Admin rejects; sets status → `expired`. No body. |

A reaper task (mirror of `session_reaper.rs`) sweeps expired/consumed rows on a
configurable tick.

**Security notes** (recorded in an ADR):
- Code space 1M; expiry 5 min; one fresh code per attempt.
- `consumed` state prevents replay; the token is a one-shot read.
- No rate limiting in v1 — LAN-only assumption, admin approval is the gate.
- Token is never logged client-side.

### 4.3 TMDB discover endpoint

| Method | Path | Auth | Purpose |
|---|---|---|---|
| `GET` | `/api/v1/discover?q=<query>&kind=movie\|series&page=<n>` | bearer | Server-side TMDB search proxy. Returns `{ candidates: [{ tmdb_id, kind, title, year, overview, poster_url, backdrop_url, popularity }], page, has_more }`. |

- Caches results for 60 s by `(query, kind, page)` to absorb client typeahead.
- Respects existing `KINO_TMDB__MAX_REQUESTS_PER_SECOND`.
- Errors map to `502` for upstream failure; `503` with `Retry-After` for
  TMDB-side rate-limit throttling.
- Reuses `kino_fulfillment::tmdb` — no new HTTP plumbing.

### 4.4 Library search filter

Extend `GET /api/v1/library/items` with optional `q` query param. Server does
SQLite `LIKE` over `MediaItem.title`, `MediaItem.year`, TV series titles, and
episode titles. **No FTS5 in v1** — library size doesn't justify it; revisit
later if needed. Same response shape.

### 4.5 Admin SPA addition

`kino-admin` gains a "Pairings" pane: lists pending pairings (device name,
platform, code), Approve and Reject buttons. Mirrors the existing Tokens and
Sessions panes' style. Existing OpenAPI drift check covers it.

## 5. KinoKit architecture

One SwiftPM package, one public library product (`KinoKit`), Swift 6 strict
concurrency.

### Package targets

```
KinoKitGenerated   -- swift-openapi-generator build-plugin output;
                       generated on build from a vendored openapi.json,
                       not committed to the repo, never hand-edited
KinoKitCore        -- domain models, error types, no generated dependencies
KinoKitTransport   -- URLSession-backed client glue + auth interceptor
KinoKitAuth        -- token storage (Keychain), pairing client, discovery
KinoKitPlayback    -- variant selection, progress reporter, coordinator
KinoKit            -- umbrella; re-exports the public surface
```

The vendored `openapi.json` lives at
`Packages/KinoKit/Sources/KinoKitGenerated/openapi.json` and is the single
file that pins which server contract this version of KinoKit binds to.
Bumping it is a deliberate PR. CI's `openapi-binding-drift` job (§9) refreshes
the file from a tagged `kino` release and fails the build if the diff isn't
intentional.

### Public surface

```swift
// Discovery
public actor ServerDiscovery {
    public func browse() -> AsyncStream<DiscoveredServer>
    public func resolve(_ s: DiscoveredServer) async throws -> ResolvedServer
    // ResolvedServer carries host, port, instance_id
}

// Pairing
public struct PairingClient {
    public init(server: ResolvedServer)
    public func requestCode(deviceName: String,
                            platform: ClientPlatform) async throws
                            -> PairingChallenge
    public func awaitApproval(_ ch: PairingChallenge) async throws
                            -> AuthorizedSession
    // polls GET /pairings/{code} with backoff;
    // throws PairingError.expired / .rejected
}

// Authorized client (the thing apps hold once paired)
public final class KinoClient: Sendable {
    public init(session: AuthorizedSession)
    public var library: LibraryAPI { get }
    public var requests: RequestsAPI { get }
    public var playback: PlaybackAPI { get }
    public var admin: AdminAPI? { get }   // present only with admin scope
}

// Playback
public actor PlaybackCoordinator {
    public init(client: KinoClient, item: MediaItem)
    public func prepare() async throws -> PlaybackPlan
    public func makePlayerItem(_ plan: PlaybackPlan) -> AVPlayerItem
    public func startReporting(player: AVPlayer)
    public func stopReporting() async
}

// Persistence (Keychain-backed)
public protocol SessionStore: Sendable {
    func loadAll() async throws -> [AuthorizedSession]
    func save(_ s: AuthorizedSession) async throws
    func remove(serverInstanceId: UUID) async throws
}
public struct KeychainSessionStore: SessionStore { /* default */ }
```

### Why a hand-written facade over generated code

The generator emits a literal mirror of OpenAPI — fine as transport, terrible
as an app-facing API. The hand-written `KinoClient` facade gives ergonomic
methods, folds error mapping into a single typed `KinoError`, and is the seam
for retry/refresh logic. Generated code stays 100% machine-owned; hand-written
code never edits it.

### Concurrency model

Swift 6 strict mode. `KinoClient` is a class but `Sendable`; per-resource APIs
are structs. `PlaybackCoordinator` and `ServerDiscovery` are actors because
they own mutable state. Everything `async`. No Combine — `AsyncStream` for
ongoing events.

### Error model

```swift
public enum KinoError: Error, Sendable {
    case transport(URLError)
    case server(status: Int, body: ErrorResponse?)   // typed from openapi.json
    case unauthorized                                 // 401 → drop session,
                                                      //   re-pair
    case pairing(PairingError)
    case playback(PlaybackError)
    case decoding(DecodingError)
}
```

`unauthorized` is the case apps must surface visibly. Apps never see the
generator's runtime error type — `KinoError` is the contract.

### Image loading

Thin wrapper around `URLSession` + `URLCache` (disk-backed). No third-party
image library. Sources: `/library/items/{id}/images/{kind}` and TMDB poster
URLs from the discover response.

### What KinoKit does NOT do

- No SwiftUI views. Zero. UI lives in apps.
- No app navigation state, deep-link parsing, view models.
- No persistence beyond Keychain session storage. Watched/resume is server
  owned per existing API; KinoKit is a passthrough.
- No analytics, no crash reporting.

## 6. Platform apps

### iOS (`Kino-iOS`)

- SwiftUI throughout, deployment target iOS 17.
- 5 tabs: Home / Library / Search / Requests / Settings.
- Home: Continue Watching + Recently Added + Recent Requests.
- Library: movies and shows separated, infinite-scrolling poster grids backed
  by `library.list(filter:)`.
- Search: unified field, queries `library.list(q:)` and `discover(q:)` in
  parallel; results render in two sections ("In your library" / "Discover").
- Requests: user's request history with status (resolving / planning /
  fulfilling / satisfied / failed).
- Settings: server connection, paired devices on this server, sign out (=
  delete session), version + build.
- Player: `AVPlayerViewController` host wrapped to drive `PlaybackCoordinator`.
  AirPlay route picker via system controls; PiP via the system video
  controller.
- iPad collapses to a sidebar via `NavigationSplitView`.

### tvOS (`Kino-tvOS`)

- SwiftUI; deployment target tvOS 17.
- Top tab bar (default `TabView`).
- 4 tabs: Home / Library / Search / Requests. Settings lives under a top-right
  gear because tvOS conventions punish more than ~5 focusable tab peers.
- Focus engine drives everything; large focused poster reveals metadata below
  (Apple TV+ idiom).
- Search uses tvOS keyboard `SearchField` — slow to type, which is exactly why
  discovery + Continue Watching + browse have to do most of the work.
- Player: `AVPlayerViewController` (handles Siri Remote chapter scrub, info
  pane, subtitle picker for free).

### macOS (`Kino-macOS`)

- SwiftUI + AppKit hosting where needed; deployment target macOS 14.
- 3-column `NavigationSplitView`: sidebar / content list / detail.
- Sidebar groups: Library, Discover, Servers (multi-server is permitted in v1;
  Phase 5 makes it powerful, Phase 4 just doesn't preclude it).
- Toolbar: search field, connection status badge, account menu.
- Player: `AVPlayer` in an `AVPlayerView` (AppKit) embedded in a SwiftUI
  window. Full-screen via the system control. AirPlay via system route picker.
- Menu bar: standard File/Edit/View/Window/Help plus a Kino menu (Sign In /
  Sign Out, Switch Server, Refresh Library).

### Common across all three

- Each app embeds a `KinoApp` entry-point: `@main`, environment-injected
  `KinoClient`, an unauthenticated state that runs discovery → pairing before
  the main UI.
- **No shared SwiftUI views across apps.** Detail screens, image caching,
  error banners, and loading skeletons are reimplemented per app. Each
  platform's idiom is different enough (focus engine on tvOS,
  `NavigationSplitView` on macOS, sheets on iPhone) that "shared SwiftUI"
  collapses into a tangle of `#if os(...)`. KinoKit owns shared *behavior*
  (data, playback, auth); SwiftUI views are app-local. Duplication is the
  price of keeping each app feeling native.

## 7. Pairing flow

```
 Client (e.g. tvOS)   kino-server          Admin SPA              User
 ──────────────────   ───────────          ─────────              ────
        │                  │                    │                   │
        │ NetService.browse                     │                   │
        │═══════ mDNS _kino._tcp ═══════════════ │                  │
        │ ◀═════ instance_id, host:port ═════════│                  │
        │                  │                    │                   │
        │ POST /api/v1/pairings                  │                   │
        │  { device_name, platform }             │                   │
        │ ─────────────────▶                     │                   │
        │ ◀── 201 { pairing_id, code, expires_at }                  │
        │                  │                    │                   │
        │ display code + "open admin URL"        │                   │
        │ ───────────────────────────────────────────────────────────▶
        │                  │                    │                   │
        │                  │   admin opens Pairings pane            │
        │                  │ ◀── GET /api/v1/admin/pairings ─────── │
        │                  │ ── 200 [{pending, code, ...}] ───────▶ │
        │                  │   admin clicks Approve                 │
        │                  │ ◀── POST /admin/pairings/{id}/approve  │
        │                  │      (no body; token inherits admin's  │
        │                  │       user_id in single-user mode)     │
        │                  │   ┌─ mint Token row, link to pairing ─┐│
        │                  │   │  status → "approved"             ││
        │                  │   └────────────────────────────────────┘│
        │                  │ ── 200 { token_preview, pairing_id } ─▶│
        │                  │                    │                   │
        │ GET /api/v1/pairings/{code}            │                   │
        │  (poll, 2s + jitter, capped at expiry)                     │
        │ ─────────────────▶                     │                   │
        │ ◀── 200 { status: "pending" }          │                   │
        │ ─────────────────▶                     │                   │
        │ ◀── 200 { status: "approved", token, token_id, user_id }   │
        │              ┌──── status flips to "consumed" ─────┐       │
        │              └─── one-shot read; replay → 410 Gone ┘       │
        │                  │                    │                   │
        │ KeychainSessionStore.save(session)     │                   │
        │ now-authorized: KinoClient(session)    │                   │
```

Notes:

- Polling, not WebSockets — simpler server, fits LAN trust model, costs little
  at 2 s cadence.
- Polling cadence: 2 s with ±500 ms jitter, ceiling 5 min (= expiry). On
  expiry, client offers "Get a new code" → restart at `POST /pairings`.
- Token returned exactly once. If the client crashes between the `200
  approved` response and Keychain write, token is unrecoverable; user
  re-pairs. We accept that — strictly safer than retryable token reads.
- The pairing record stays in `consumed` state until the reaper sweeps it. The
  reaper deletes the pairing row but never the linked token.

## 8. Playback variant-selection algorithm

```
 user taps Play on MediaItem
            │
            ▼
 PlaybackCoordinator.prepare(item)
            │
            ▼
 fetch /library/items/{id}  → SourceFiles + TranscodeOutputs (already in payload)
            │
            ▼
 ┌─────────────────────────────────────────────┐
 │  client capabilities (queried locally):     │
 │  - codecs: VTIsHardwareDecodeSupported,     │
 │            AVURLAsset.isPlayable             │
 │  - HDR support: device + connected display  │
 │  - audio: surround / Atmos                  │
 │  (bandwidth not modeled here — HLS does     │
 │   adaptive variant selection internally     │
 │   once a master playlist is chosen)          │
 └─────────────────────────────────────────────┘
            │
            ▼
 Q1. Any TranscodeOutput whose container/codec/HDR match caps?
            │
       ┌────┴────┐
      yes        no
       │         │
       ▼         │
 pick highest-   │
 quality match   │
 (rank: VMAF     │
 target desc,    │
 then height     │
 desc, then      │
 created_at      │
 desc)           │
       │         │
       ▼         ▼
 Plan: HLS for   Q2. Is the SourceFile container/codec directly
 that output via      playable on this client?
 /stream/items/       │
 {id}/                │
 master.m3u8          ┌─────────┴─────────┐
       │             yes                  no
       │              │                    │
       │              ▼                    ▼
       │      Plan: Direct byte-     Plan: Live transcode via
       │      range via /stream/     /stream/live/{source_file_id}/
       │      sourcefile/{id}/       {profile}/master.m3u8;
       │      file.ext               profile chosen from caps
       │              │                    │ (server may still serve
       │              │                    │  a cache hit)
       └──────────────┴────────────────────┘
            │
            ▼
 build AVPlayerItem with chosen URL
            │
            ▼
 attach subtitles: /stream/items/{id}/subtitles/{track}.vtt
 (HLS sidecars; AVPlayer picks them up via master playlist alt-renditions)
            │
            ▼
 startReporting:
   - POST /api/v1/playback/progress every 10s while playing
   - POST /api/v1/playback/watched/{id} when ≥90% complete
   - flush a final progress on stop / app background
            │
            ▼
 on AVPlayer error or stalls → re-prepare:
   - Plan = HLS    → fallback to Live transcode
   - Plan = Direct → fallback to HLS if any output exists, else Live
   - Plan = Live   → surface error; offer retry
```

Notes:

- `ClientCapabilities` is per-platform code that lives in each app
  (AVFoundation calls are platform-specific), but the resulting struct is a
  KinoKit type that `PlaybackCoordinator` consumes. Apps populate it; KinoKit
  picks the variant.
- Decision honors the existing server surface and matches the vision's "direct
  play is the default and the goal."
- Progress cadence (10 s) and watched threshold (90%) live as KinoKit
  constants; tune after measuring real playback.
- Fallback chain is one-shot — no looping.

### What KinoKit owns vs apps own

| Concern | Owner |
|---|---|
| `ClientCapabilities` schema | KinoKit |
| Variant-selection algorithm | KinoKit |
| Progress-report throttle | KinoKit |
| Fallback ladder | KinoKit |
| Capability *detection* | App (per-platform AVFoundation) |
| `AVPlayer` lifecycle and host view | App |
| Player error UI when fallback exhausted | App |

## 9. Testing strategy

### Server-side (this repo)

Same conventions as Phases 1–3.

- **Pairing:** unit tests on the state machine (pending → approved → consumed,
  expiry semantics, replay rejection, code uniqueness collision retries) +
  integration tests through `axum::Router::oneshot` against a
  `kino_db::test_db()`. Reaper gets the same tick-based test treatment as
  `session_reaper`.
- **Discover:** unit tests stub the TMDB client; integration tests verify
  caching + rate-limit error mapping.
- **mDNS responder:** integration test brings the responder up on a high port,
  runs an `mdns-sd` browser in the same test, asserts the service appears with
  the expected TXT record. Gated like `hwaccel-tests` if it doesn't work on CI
  Linux containers.
- **OpenAPI drift:** existing CI check catches all new endpoints.

### KinoKit (`Packages/KinoKit/Tests/`)

- `URLProtocol` stub serves canned JSON derived from `openapi.json`'s response
  examples. Every public method on `KinoClient` gets happy-path + auth-failure
  + transport-failure tests.
- `PlaybackCoordinator`: variant-selection test matrix is exhaustive — every
  combination of (capabilities × available outputs × source codec) gets a
  deterministic expected `PlaybackPlan`.
- `PairingClient`: simulated server flips status on cue, with an injected
  clock to test polling cadence and expiry handling without real time passing.
- `KeychainSessionStore`: real Keychain on the test process. Cleans up after
  itself.
- Coverage targets: ≥80% line on KinoKit; variant-selection module aims for
  100% branch.

### App targets

- One smoke UI test per app via XCUITest: launch → discovery shows mock server
  → enter test pairing code (debug build accepts a deterministic code) → land
  on Library → tap an item → assert player appears. Runs against a stub server
  target.
- **No snapshot tests in v1** — high churn, low payoff at wireframe-fidelity
  initial UI. Add later if visual regressions become a real bug source.
- No XCUITest matrix beyond the smoke flow; the unit test bar lives in
  KinoKit.

### Manual acceptance per platform

Before each platform's Linear milestone closes, a scripted checklist is run
and captured in `docs/agents/plans/<date>-<platform>-acceptance.md`, with
results in a sibling `*-results.md` (mirroring
`2026-05-12-phase-3-acceptance-results.md`):

1. mDNS discovery on real LAN.
2. Pairing happy path + expiry path + reject path.
3. Direct play of a 4K HDR title; transcoded variant of an HEVC source; live
   transcode of an unsupported codec.
4. Resume + watched flag round-trip across two devices on the same server.
5. Subtitle picker for English forced + full + a non-Latin language.
6. AirPlay handoff (iOS, macOS).
7. Network drop mid-playback → graceful recovery.
8. Token revoked from admin SPA → next request shows re-pair prompt.

### CI footprint (`kino-apple`)

- Runner: `macos-14`. Parallel jobs:
  - `kit-test`: `swift test` on KinoKit.
  - `kit-format`: `swift-format lint --strict` on `Packages/KinoKit`.
  - `ios-build`, `tvos-build`, `macos-build`: `xcodebuild build` (no signing).
  - `ios-uitest`, `tvos-uitest`, `macos-uitest`: smoke flow on simulators.
  - `openapi-binding-drift`: regenerates from a vendored copy of the server's
    `openapi.json`, fails on any diff (forces an explicit "I bumped the
    schema" PR).
- Branch protection on `main` requires all of the above.
- Wall-time budget per PR: target ≤15 min; if exceeded, fan out further.

## 10. Milestones and Linear shape

Sequencing follows approach A: server pre-work, then KinoKit, then iOS to
ship-quality (drives the SDK to honesty), then tvOS + macOS in parallel.

| ID | Name | Repo | Notes |
|---|---|---|---|
| M0 | `kino-apple` foundations | `kino-apple` | Hygiene parity. Replaces F-277 scope. |
| M1 | Server pre-work | `kino` | New epic. mDNS, pairing, discover, search filter, admin pane. |
| M2 | KinoKit core | `kino-apple` | Replaces F-277. KinoKit feature-complete + tested. |
| M3 | iOS to shippable | `kino-apple` | Replaces F-278. Drives any KinoKit gaps. |
| M4 | tvOS | `kino-apple` | Replaces F-279. Parallel with M5 after M3. |
| M5 | macOS | `kino-apple` | Replaces F-280. Parallel with M4 after M3. |

### Per-milestone exit bars

- **M0:** `git clone && just setup && just build && just test && just fmt-check
  && just lint` succeeds on a fresh Mac. One PR, no app code yet.
- **M1:** a pairing can be approved via curl; mDNS shows up under `dns-sd -B
  _kino._tcp`; `/api/v1/discover?q=...` returns TMDB candidates. No client
  consumes any of this yet.
- **M2:** `swift test` covers KinoKit's public surface ≥80%, variant selection
  100% branch. A throwaway `KinoKitProbe` command-line target validates
  discovery + pairing + a single playback URL build against a real local
  server.
- **M3:** iOS meets the per-platform exit bar from §1; manual acceptance
  checklist passes. **KinoKit is frozen at this point** — any subsequent
  KinoKit change is treated as a deliberate API bump, not casual refactor.
- **M4 / M5:** their per-platform exit bars + their own acceptance checklists.
  Either can finish first.

### F-281 (API validation spike)

Approach A absorbs F-281's purpose into M3 — iOS is the API-validation work,
but for real. F-281 is closed as superseded with a pointer to the M3 epic. Not
replicated.

### Linear shape

- New epic in this repo: **Phase 4 — Server pre-work** (sub-issues for mDNS,
  pairings, discover, search, admin pane).
- F-277/F-278/F-279/F-280 stay as the Apple-side epics; descriptions are
  refreshed to match M0–M5.
- F-281 closed as superseded.
- New labels added: `apple-shared` (KinoKit), `apple-ios`, `apple-tvos`,
  `apple-macos`. The existing `clients` label stays as the umbrella.
- Server work uses existing crate labels.

### Calendar honesty

This is the largest phase yet — three Apple targets plus material server work.
M0 + M1 + M2 are agent-friendly (server work fits Codex dispatch; M0 is mostly
file scaffolding). M3 / M4 / M5 are not — Apple work needs Xcode and human
hands. Plan accordingly: Rust-side work runs unattended while Apple-side work
is an explicit foreground commitment.

## 11. Open questions deferred

These do not block this spec but should be decided in or before the milestone
that needs them:

- **`swift-format` rule overrides** — handled in M0 as an ADR if any are
  needed; default is stock.
- **mDNS crate choice** — handled in M1 as an ADR.
- **Whether KinoKit ships as a SwiftPM package consumable by external
  projects, or stays internal-only** — defer to Phase 5 alongside
  multi-user / sharing decisions.
- **Public-server (non-LAN) deployment ergonomics** — Phase 5; this spec
  assumes LAN-primary per the vision.
