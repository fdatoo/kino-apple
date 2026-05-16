# M3 — Kino-iOS shippable app (F-278) design

> Authored 2026-05-16. Refines `2026-05-13-phase-4-design.md` §6 for the
> specific execution of F-278.

This spec narrows the Phase 4 design to what M3 ships, fixes the open items §6
left for "the start of M3", and decomposes F-278 into ten sub-issues that
match the M0/M1/M2 grain.

## 1. Scope and exit bar

F-278 delivers the iOS app feature-complete against KinoKit. iOS is the
API-honesty forcing function — any KinoKit gap surfaced during the work lands
as a follow-up PR in `kino-apple` while M3 is still open. **At the close of
M3, KinoKit freezes** at a tagged version that M4 (tvOS) and M5 (macOS)
consume as a stable surface.

### In scope (per-platform exit bar, from Phase 4 spec §1)

1. **Discovery + manual URL.** First-launch presents a list of LAN servers
   discovered via `ServerDiscovery.browse()`; manual URL fallback for
   non-Bonjour deployments.
2. **Pairing.** 6-digit code flow per Phase 4 spec §7; client polls until
   admin approves in the admin SPA.
3. **Browse library.** Movies and Shows as separate top-level tabs, each an
   infinite-scrolling poster grid.
4. **Search library.** Dedicated Search tab combining `library.list(q:)` and
   `discover.search(q:)` in parallel.
5. **Discover + request un-owned content.** Discover rows in Search lead to a
   confirmation sheet that calls `requests.create(kind:tmdbID:)`.
6. **Play.** `AVPlayerViewController` host driven by `PlaybackCoordinator`.
   Subtitle picker, scrubber, AirPlay route picker, PiP — all handled by
   AVKit defaults.
7. **Progress + watched sync.** Progress reporter ticks every 10 s; watched
   flips at ≥ 90 %. Sync is server-mediated.
8. **AirPlay handoff.** System route picker; no app-side AirPlay logic.
9. **Direct play default; fallback ladder honored.** `VariantChooser`
   produces the plan; coordinator handles HLS→Live, Direct→Live, Live→error
   per Phase 4 spec §8.

### In scope (this spec adds, per the Phase 4 design §6 full feature set)

- **Home dashboard.** Continue Watching hero + Recently Added + Recent
  Requests poster strips.
- **iPad adaptation.** `NavigationSplitView` collapses the tab bar into a
  sidebar; same code, size-class-driven.
- **Force dark mode** (`.preferredColorScheme(.dark)`). Apple TV+ idiom is
  dark-first; light mode is deferred.

### Out of scope

Same exclusions as the Phase 4 spec §2 (no offline downloads, no multi-user,
no App Store release, no Apple Watch, no snapshot tests). Plus, specific to
M3:

- **TestFlight upload.** Phase 4 spec §3 explicitly defers automation; the
  CI release builds verify compile only.
- **Pixel-perfect tvOS/macOS parity.** SwiftUI views are app-local; M4 and M5
  reimplement screens for their idioms per Phase 4 spec §6.
- **Light mode.** Forced dark in v1; revisit when users ask.

### Exit bar

1. `just build` + `just test` pass locally and in CI.
2. All eight existing CI jobs stay green (`kit-format`, `kit-test`,
   `ios-build`, `tvos-build`, `macos-build`, `ios-uitest`, `tvos-uitest`,
   `macos-uitest`) plus `kit-coverage`.
3. Manual acceptance checklist (Phase 4 spec §9) passes against a physical
   iPhone + iPad on real LAN. Results captured in
   `docs/agents/plans/<date>-m3-acceptance-results.md`.
4. KinoKit tagged at the M3-closing commit (e.g. `kit-1.0.0`); `Version.swift`
   updated.

## 2. Decomposition — F-278 sub-issues

F-278 becomes the M3 epic. Ten sub-issues, including one in the `kino`
(server) repo. Each is one PR.

| ID | Title | Repo | Blocked by |
|---|---|---|---|
| M3.0 | `GET /api/v1/playback/progress` — list in-progress items | `kino` | — |
| M3.1 | App scaffold + 4-tab nav + Liquid Glass styling + `KinoAsyncImage` | `kino-apple` | — |
| M3.2 | Pairing flow UI (discovery → code → polling) | `kino-apple` | M3.1 |
| M3.3 | Movies + Shows tabs + Item Detail | `kino-apple` | M3.1, M3.2 |
| M3.4 | Search tab (active + empty states + request flow) | `kino-apple` | M3.1, M3.2 |
| M3.5 | Home tab (hero + Recently Added + Recent Requests + avatar) | `kino-apple` | M3.0, M3.1, M3.2 |
| M3.6 | Account sheet + Requests list + Settings form + Sign Out | `kino-apple` | M3.1, M3.2 |
| M3.7 | Player host (`AVPlayerViewController` + AirPlay + PiP) | `kino-apple` | M3.3 |
| M3.8 | iPad `NavigationSplitView` adaptation | `kino-apple` | M3.3, M3.4, M3.5, M3.6 |
| M3.9 | M3 manual acceptance + KinoKit freeze | `kino-apple` | M3.0–M3.8 |

Parallelism windows:

```
M3.0 (kino) ──┐
              ├─ openapi-sync ──┐
M3.1 ─────────┴─────────────────┤
                                ↓
                              M3.2
                                │
              ┌──────┬──────────┼──────────┬──────┐
              ↓      ↓          ↓          ↓      ↓
            M3.3   M3.4       M3.5       M3.6   (sibling)
          (M+S)  (search)    (home)    (account)
              │
              ↓
            M3.7
          (player)
              │
              ↓
            M3.8 (iPad)
              │
              ↓
            M3.9 (acceptance + freeze)
```

Labels on each Linear sub-issue: `apple-ios`, `clients`.

## 3. Visual direction — Apple TV+ idiom on iOS 26

### Color and materials

- **Forced dark mode** via `.preferredColorScheme(.dark)` on `KinoApp.body`
  and `UIUserInterfaceStyle = Dark` in `Info.plist`.
- **Background:** `Color.black` for content; `Color(.systemBackground)`
  renders as near-black `#1C1C1E` for cards and sheets.
- **Liquid Glass surfaces:** every translucent nav element uses
  `backdrop-filter: blur(28px) saturate(180%)` semantics — in SwiftUI this is
  `.background(.ultraThinMaterial)` for the tab bar capsule and
  `.thinMaterial` for sheets. Specular highlight on the top edge via a 1pt
  inner shadow (`overlay { … }` with `inset` styling).
- **Hero backdrops:** server-provided `MediaItem.backdrop` URL rendered
  edge-to-edge with a bottom-to-top gradient overlay (95 % black at bottom →
  0 % at top) so titles stay readable.

### Typography

- **Title hero** (Home Continue Watching, Detail screen):
  `.system(.largeTitle, weight: .heavy)` — ≈ 28–32 pt.
- **Row labels** ("Recently Added"): `.system(.headline, weight: .bold)` —
  ≈ 17 pt.
- **Body / overviews:** `.system(.body)`.
- **Pairing code:** `.system(size: 52, weight: .bold, design: .monospaced)`
  with a vertical white-to-grey gradient fill via
  `.foregroundStyle(LinearGradient(…))`.

### Navigation shell

- **4-tab Liquid Glass capsule** at the bottom, inset 16 pt from each edge
  with a 30 pt corner radius. Tabs: **Home / Movies / Shows / Search**.
- **Avatar circle** (32 pt) in the top-right of every primary tab. Tapping it
  presents the **Account sheet** (Phase 4 §6's Settings + Requests live
  inside, drilling into their full views from there).
- Tab bar auto-hides during full-screen player presentation (free with
  `.fullScreenCover`).

### Account sheet contents

- **Header:** avatar (gradient circle with first initial), device name,
  server connection status (green dot + hostname + version).
- **Section "Your Stuff":** *Your Requests* (with red badge count when any
  requests are mid-flight) → drills into Requests list view.
- **Section "Configuration":** *Settings* → drills into the Settings Form;
  *Sign Out* (red, calls `KeychainSessionStore.remove(serverInstanceID:)` and
  flips `AppState` back to unauth).
- **Footer:** version + build + iOS version.

### Per-screen treatment

**Home** — hero block (≈ 48 % of screen height) showing top Continue Watching
item with backdrop + gradient + eyebrow + bold title + progress bar + Resume
button. Two poster strips below: Recently Added (4–5 visible posters,
horizontal scroll), Recent Requests (last 3–4 from `requests.list()`). Avatar
top-right. Pull-to-refresh on the scroll container.

**Movies tab / Shows tab** — same shape, different `kind` filter. Large
title at top. 3-column `LazyVGrid` of posters with `aspect-ratio: 2/3`.
Infinite scroll triggered by `.onAppear` on the last row. No segmented
control — content type is the tab itself.

**Item Detail** — backdrop dominates (≈ 56 % of screen height) with title
logo + meta row bottom-aligned over a fade-to-black gradient. Full-width
white Play button below the hero. Capability tags (`4K HDR10`, `Atmos 7.1`,
`Direct play`) as small pills. Synopsis below.

**Search** — large title, search field (Liquid Glass material), two-section
results. *Active state:* "In Your Library" poster strip + "Discover" rich
rows (poster + title + year + 2-line overview + `+` request affordance).
*Empty state* (before typing or after clearing): recent search chips +
"Trending on TMDB" poster strip so the tab never reads as blank.

**Pairing flow** — three sub-states with no tab bar:
- *Server list:* "Find your server" header + glowing-dot rows for each
  discovered server in a glass-card group + "Enter URL manually" CTA.
- *Manual URL entry:* sheet with text field, validates the URL is reachable
  before continuing.
- *Code shown:* "Approve to pair" header + large monospaced code with
  gradient fill + countdown timer + numbered approval steps + pulsing "Waiting
  for approval…" indicator.
- *Approved:* dismiss the pairing stack; `AppState` flips to authenticated.

**Requests list** (drilled into from Account sheet) — chronological list with
poster thumbnail + title + relative time + color-coded `StatusPill`
(`resolving` grey, `planning` blue, `fulfilling` orange, `satisfied` green,
`failed` red).

**Request Detail** — back link → list. Header: title + year + TMDB id +
current `StatusPill`. Below: a vertical timeline of `RequestStatusEvent`s
with a connecting line and glowing dots colored per state. Cancel Request CTA
at the bottom when state allows.

**Settings** (drilled into from Account sheet) — grouped `Form` with three
sections: *Server* (hostname, version, instance ID, paired devices count
drill-in), *Account* (current device name, Sign Out — duplicated for users
who navigate this far), *About* (version, build, link to Phase 4 spec).
Standard iOS 26 inset list style.

**Player** — `AVPlayerViewController` presented full-screen modally. App
does not theme the player surface — the AVKit defaults (scrubber, time, skip
buttons, subtitle picker, AirPlay route picker, PiP control) are the polish.

### iPad adaptation

- **`NavigationSplitView`** replaces the tab bar in regular-width size class.
- **Sidebar** lists the four tabs as rows (Home / Movies / Shows / Search)
  plus the avatar at the bottom (still opens the Account sheet, presented as
  a centered sheet instead of bottom).
- **Detail column** renders the active tab's content full-width; Item Detail
  inside Movies/Shows uses a split inside the column (poster left, metadata
  right) on wider iPads.
- **Player** still presents full-screen modally; no inline iPad player in v1
  (avoids dealing with simultaneous-content / multi-window edge cases).

## 4. Architecture — `Apps/Kino-iOS/Sources/`

Existing scaffold from M0 has `App.swift` (placeholder) and `ContentView.swift`
(stub). M3.1 replaces both and lays the directory.

```
Sources/
├── App.swift                       # @main KinoApp; AppState; force .preferredColorScheme(.dark)
├── AppState.swift                  # @Observable. Auth state (unauth / authenticated). Current KinoClient. Global error banner. Sign-out action.
├── Components/                     # Shared in-iOS views (NOT shared with tvOS/macOS per Phase 4 §6).
│   ├── KinoAsyncImage.swift        # AsyncImage wrapper using a URLSession that injects auth on internal hosts.
│   ├── PosterCell.swift            # Single poster — corner radius, shadow, optional title overlay, loading skeleton.
│   ├── PosterRow.swift             # Horizontal-scrolling poster strip with row label.
│   ├── PosterGrid.swift            # LazyVGrid for tab grids with infinite-scroll trigger.
│   ├── StatusPill.swift            # Color-coded request status capsule.
│   ├── ErrorBanner.swift           # Top-edge banner driven by AppState.errorBanner.
│   └── AvatarButton.swift          # Gradient circle with initial + optional red badge dot.
├── Navigation/
│   ├── MainTabView.swift           # iPhone — 4-tab TabView with the Liquid Glass capsule applied.
│   ├── MainSplitView.swift         # iPad — NavigationSplitView with sidebar + detail.
│   └── AccountSheet.swift          # Avatar-tapped bottom sheet; routes to Requests / Settings.
├── Pairing/                        # M3.2
│   ├── PairingFlow.swift           # Top-level coordinator; routes between sub-states.
│   ├── PairingViewModel.swift      # @Observable. Owns ServerDiscovery + PairingClient + current state enum.
│   ├── ServerListView.swift
│   ├── ManualURLEntryView.swift
│   └── CodeView.swift
├── Home/                           # M3.5
│   ├── HomeView.swift              # Hero + 2 strips + avatar.
│   └── HomeViewModel.swift         # @Observable. Loads Continue Watching, Recently Added, Recent Requests.
├── Movies/                         # M3.3 (Shows reuses these via parameterization)
│   ├── MoviesView.swift            # = LibraryGridView(kind: .movie).
│   ├── ShowsView.swift             # = LibraryGridView(kind: .series).
│   ├── LibraryGridView.swift       # Shared underlying grid implementation.
│   ├── LibraryGridViewModel.swift  # @Observable. Paginated library.list(kind:limit:offset:).
│   ├── ItemDetailView.swift        # Backdrop hero + Play + tags + synopsis.
│   └── ItemDetailViewModel.swift   # @Observable. Loads MediaItem via library.get(id:).
├── Search/                         # M3.4
│   ├── SearchView.swift            # Two-section results + empty state.
│   └── SearchViewModel.swift       # @Observable. Debounce + parallel library/discover queries.
├── Requests/                       # M3.6
│   ├── RequestsView.swift          # List with status pills.
│   ├── RequestsViewModel.swift     # @Observable. Pull-to-refresh; polls list.
│   ├── RequestDetailView.swift     # Timeline + cancel CTA.
│   └── RequestDetailViewModel.swift
├── Settings/                       # M3.6
│   ├── SettingsView.swift          # Sectioned Form.
│   └── SettingsViewModel.swift     # @Observable. Sign-out action.
└── Player/                         # M3.7
    ├── PlayerContainer.swift       # SwiftUI shell — presents AVPlayerViewControllerRepresentable as fullScreenCover.
    └── AVPlayerViewControllerRepresentable.swift  # UIViewControllerRepresentable bridge driving PlaybackCoordinator.
```

### View-model pattern

Every screen has a paired `@Observable` view-model. The view-model:

- Holds the `KinoClient` reference, injected via `@Environment(\.kinoClient)`.
- Owns loading / error / data state as plain Swift properties.
- Exposes `async` action methods (`load()`, `loadMore()`, `submit()`).
- Is `View`-free (no `SwiftUI` imports beyond `Observation`), so unit-testable
  without UIKit.

Views inject the view-model via `@State private var vm = ScreenViewModel()`
at the root of each screen. Navigation pops dispose the view-model cleanly.

### Auth state machine

`AppState` is one `@Observable` with a top-level `phase: AppPhase` enum:

```swift
enum AppPhase: Sendable {
    case loading                    // Cold launch; checking Keychain.
    case unauthenticated            // No session in Keychain. Show PairingFlow.
    case authenticated(KinoClient)  // Session loaded. Show MainTabView.
    case error(KinoError)           // Cold-launch error; offer retry.
}
```

Cold launch sequence:

1. `KinoApp.body` reads `AppState.phase`.
2. `AppState.init` triggers a `Task { await loadSession() }`.
3. `loadSession()` calls `KeychainSessionStore().loadAll()`, picks the
   most-recent session (sorted by `createdAt` descending), and builds a
   `KinoClient`. `phase = .authenticated(client)` or `.unauthenticated`.
4. View switch via a `switch AppState.phase` at the root.

Sign-out: `AppState.signOut(serverInstanceID:)` calls `store.remove(...)`,
flips `phase = .unauthenticated`.

### Image loading

`KinoAsyncImage(url:isInternal:)` is the only image-loading API the app uses:

```swift
struct KinoAsyncImage: View {
    let url: URL
    let isInternal: Bool                    // true for kino-server URLs; false for TMDB
    @Environment(\.kinoClient) var client

    var body: some View {
        AsyncImage(url: url, urlSession: client.images.urlSession) { phase in
            // .empty → tinted skeleton; .success → image; .failure → placeholder
        }
    }
}
```

The `URLSession` injects `Authorization: Bearer …` only when the host
matches `client.session.baseURL.host`. TMDB URLs go bare. Matches M2's
`ImageLoader` actor design (Phase 4 spec §5).

### Concurrency

- All view-models are `@MainActor`.
- `KinoClient` calls hop off-main via the actor.
- `Task { … }` for fire-and-forget side effects.
- No Combine. No Future. `async/await` and `AsyncStream` only.

## 5. Testing

### KinoKit tests

Unchanged — M2 already established the test floor. M3 may add new tests for
any KinoKit gaps surfaced during iOS work (this is the API-honesty forcing
function; new tests land in the same sub-issue PR that needed the change).

### iOS app tests

`Apps/Kino-iOS/UITests/` has one launch smoke test from M0. M3 keeps the
smoke test floor; it does **not** introduce a full XCUITest matrix.

Per Phase 4 spec §9: "One smoke UI test per app via XCUITest: launch →
discovery shows mock server → enter test pairing code (debug build accepts a
deterministic code) → land on Library → tap an item → assert player
appears." The M0 smoke is just "launch successfully"; M3.2 (Pairing) extends
the smoke to "launch + reach Pairing screen". The remaining smoke flow (pair
→ library → tap → player) is added in M3.9 when all the pieces exist.

**No view-model unit tests in v1.** View-models are thin wrappers over
KinoKit calls; KinoKit's own tests cover the call paths. If a view-model
acquires meaningful logic (debounce timing, state machine), that logic gets
extracted to a pure-function helper with unit tests — same pattern as
`VariantChooser`.

### Manual acceptance

The M3.9 sub-issue runs Phase 4 spec §9's full checklist against a physical
iPhone 17 + iPad on real LAN, capturing into
`docs/agents/plans/<date>-m3-acceptance-results.md`. Items:

1. mDNS discovery on real LAN.
2. Pairing happy path + expiry path + reject path.
3. Direct play of a 4K HDR title; transcoded variant of an HEVC source; live
   transcode of an unsupported codec.
4. Resume + watched round-trip across two devices on the same server.
5. Subtitle picker for English forced + full + a non-Latin language.
6. AirPlay handoff.
7. Network drop mid-playback → graceful recovery.
8. Token revoked from admin SPA → next request shows re-pair prompt.
9. iPad split-view layout renders correctly at 12.9" + 11" + Split View
   half-screen.

## 6. CI footprint

No new CI jobs in M3. Existing nine jobs continue to gate every PR:

- `kit-format`, `kit-test`, `kit-coverage` — KinoKit gates.
- `ios-build`, `tvos-build`, `macos-build` — app compile checks.
- `ios-uitest`, `tvos-uitest`, `macos-uitest` — smoke tests.

`ios-uitest` becomes substantive in M3.2 (Pairing reaches a real screen) and
M3.9 (full smoke flow). The other two `*-uitest` jobs stay as launch smokes
until M4 and M5.

## 7. Open items deferred past M3

Surfaced by M4/M5 or later if at all:

- **TestFlight upload automation.** Phase 4 spec §3 defers; manual upload
  remains the path until friction hurts.
- **Light mode.** Forced dark in v1; revisit when users ask.
- **Inline iPad player.** v1 presents full-screen modally on all sizes;
  iPad-specific inline player is a polish pass.
- **Multi-server switching from the Account sheet.** `KeychainSessionStore`
  supports multiple sessions; the sheet shows only the current one. Multi-
  server is the macOS sweet spot (M5).
- **Continue Watching client-side filtering.** M3.0 lands a server endpoint;
  if it's slow at scale, revisit with cursor-based pagination later.

## 8. Visual artifacts

The brainstorm mockups (under `.superpowers/brainstorm/<session>/content/`)
are gitignored intentionally — they are exploration, not contract. This spec
plus the per-sub-issue Linear scope sections are authoritative. Codex prompts
should describe the screen treatment textually rather than rely on a mockup
URL.

The decisive design moves the mockups produced and that this spec records:

- 4-tab nav with iOS 26 Liquid Glass capsule, not 5 tabs.
- Avatar in top-right → Account sheet for Requests + Settings + Sign Out.
- Movies + Shows as top-level tabs (not Library/segmented control).
- Search as a full tab (not a sheet), to keep it one-tap.
- Cinematic radial backdrops with vignette, not flat gradients.
- Specular highlights on every glass surface.
- Hero backdrop dominates the Detail screen; title overlays the fade.
