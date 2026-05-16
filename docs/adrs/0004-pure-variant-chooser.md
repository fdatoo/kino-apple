# ADR-0004 — Pure `VariantChooser` separate from `PlaybackCoordinator`

## Status
Accepted

## Date
2026-05-16

## Context

Playback variant selection has a compact but important branch structure:
prefer a compatible cached HLS transcode output, otherwise direct-play the
first compatible source file, otherwise request a live transcode profile
derived from client capabilities. The same playback surface also has
AVFoundation coordination, progress reporting, and fallback behavior. Keeping
those concerns in one actor would force deterministic selection tests to stand
up actor state, callback fakes, and player lifecycle details that are unrelated
to the variant decision.

## Decision

KinoKit keeps `VariantChooser` as a pure enum with a single static
`choose(item:capabilities:)` function. `PlaybackCoordinator` depends on that
function for initial planning and owns AVPlayer item creation, periodic
progress reporting, and one-shot fallback transitions. The chooser is tested
with an exhaustive table-driven matrix, and
`KinoKitPlayback/VariantChooser.swift` carries a 100 percent branch coverage
bar because the algorithm is small enough to exercise directly without mocks
or actor scheduling.

## Consequences

The variant algorithm remains cheap to reason about and cheap to verify:
adding a capability, output rank field, or live profile tier requires adding
table rows instead of expanding coordinator fixtures. The coordinator tests can
stay focused on state transitions and reporting behavior. The split does mean
fallback logic duplicates the live-profile URL construction path through
shared internal helpers, but that keeps the public API narrow while preserving
identical live-plan behavior.
