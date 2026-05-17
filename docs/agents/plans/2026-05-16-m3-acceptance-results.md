# M3 acceptance results — 2026-05-16

Closes the exit-bar checklist for [F-278 (M3 — Kino-iOS)](https://linear.app/fdatoo/issue/F-278).

## Runbook

```
git clone git@github.com:fdatoo/kino-apple.git
cd kino-apple
just setup
just build
just test
just fmt-check
just lint
```

All commands must exit 0. Then archive and install on a physical iPhone + iPad and walk the per-item checklist below against a real local `kino-server` on the LAN.

## Environment

| Tool / device     | Version                                                  |
|-------------------|----------------------------------------------------------|
| macOS             | Darwin 25.4.0 (arm64)                                    |
| Xcode             | 16+ (default selection via `xcode-select -p`)            |
| Swift             | Apple Swift 6.2.4                                        |
| iOS device        | _(filled in during walk)_                                |
| iPadOS device     | _(filled in during walk)_                                |
| kino-server build | _(filled in during walk — record commit SHA)_            |

## Phase 4 spec §9 — per-item results

Each item below corresponds to one numbered acceptance check. Mark `pass`, `fail`, or `n/a` and add a one-line note.

| # | Check | Result | Notes |
|---|-------|--------|-------|
| 1 | mDNS discovery on real LAN — pairing screen shows the server. |  |  |
| 2 | Pairing happy path + expiry path + reject path. |  |  |
| 3 | Direct play of 4K HDR; transcoded variant; live transcode. |  |  |
| 4 | Resume + watched flag round-trip across two devices. |  |  |
| 5 | Subtitle picker English forced + full + non-Latin. |  |  |
| 6 | AirPlay handoff to Apple TV / AirPlay 2 speaker. |  |  |
| 7 | Network drop mid-playback → recovery. |  |  |
| 8 | Token revoked from admin SPA → next request prompts re-pair. |  |  |
| 9 | iPad split-view layout at 12.9" + 11" + Slide Over + Split View. |  |  |

## KinoKit freeze

`Packages/KinoKit/Sources/KinoKit/Version.swift` bumped to `1.0.0` in this PR. After this PR merges, tag the commit:

```bash
git checkout main && git pull
git tag -a kit-1.0.0 -m "KinoKit 1.0.0 — feature-complete frozen surface (M3 close)"
git push origin kit-1.0.0
```

## Notes

_(filled in during walk — list any bugs surfaced, deferred follow-ups, or design observations to file as new Linear issues)_
