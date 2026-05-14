# Kino Apple — Vision

> Native Apple clients for Kino, consuming the server contract instead of
> replacing it.

## 1. Relationship to Kino

The Apple clients are the consumption side of Kino's broader server-side vision:
[Kino — Vision](https://github.com/fdatoo/Kino/blob/main/docs/kino-vision.md).
That document owns the product shape: one server, one data model, one source of
truth for the media library, playback state, tokens, requests, discovery, and
streaming.

This repository exists to make that server feel first-class on iOS, tvOS, and
macOS. The Apple side should be native where the platform matters, shared where
the product contract matters, and deliberately small where the server already
owns the problem.

## 2. Goals

- **Native first-class clients.** iOS, tvOS, and macOS are real clients, not web
  shells. They use platform playback, storage, navigation, and accessibility
  primitives directly.
- **Direct play is the default.** The apps should prefer streams the device can
  play natively and honor server-provided variants when direct play is not the
  right choice.
- **KinoKit is the shared surface.** API bindings, models, pairing, discovery,
  session storage, playback coordination, and cross-platform client logic live
  in one Swift package consumed by all three apps.
- **Consume the server contract.** KinoKit binds to the server's `openapi.json`.
  The clients exercise the contract and help keep it honest; they do not invent
  a parallel API or local source of truth.

## 3. Non-goals

- Windows, Android, Apple Watch, CarPlay, Cast, and Chromecast clients.
- Offline downloads.
- Multi-user client behavior in this phase; that is deferred to Phase 5.
- Library-management actions from clients. Delete, re-OCR, reprobe, and other
  administrative flows stay server-admin concerns.
- Public App Store distribution. TestFlight and sideloaded builds are enough for
  this phase.

## 4. Dependence on the server

KinoKit consumes the server's `openapi.json` as the pinned API contract for a
given client release. Generated bindings should move when that contract moves,
not from hand-written guesses about server routes or response shapes.

Pairing mints device tokens into the existing server `tokens` table. The client
requests a pairing code, the admin approves it, and the server returns a
per-device token. Session authority remains server-side.

mDNS discovery, pairing, TMDB-backed discover, and library search filtering are
server capabilities described in Phase 4 section 4. The apps use those
capabilities through KinoKit. They should not grow their own discovery registry,
metadata search client, or library index.

## 5. Platform sequencing

M0 lays the repository foundations: docs, formatting, CI shape, package layout,
and project hygiene. M1 is server pre-work for the client-facing API gaps:
mDNS, pairing, discover, and library search filtering.

M2 builds the KinoKit core so all clients share one contract and one set of
behaviors. M3 then ships iOS first because it is the fastest way to exercise the
API, pairing flow, browsing, search, discovery, request, and playback loops in
daily use.

M4 tvOS and M5 macOS follow in parallel once KinoKit has been tested by iOS.
tvOS is the long-term living-room target; macOS broadens playback and testing
coverage without forking the shared client surface.

## 6. Where to look next

- [Phase 4 design spec](agents/specs/2026-05-13-phase-4-design.md) for the
  detailed Apple-client and server pre-work plan.
- [M0 epic F-499](https://linear.app/fdatoo/issue/F-499) for the foundation
  milestone this repository is currently executing.
