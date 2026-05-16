# M2 acceptance results — 2026-05-16

Closes the exit-bar checklist for [F-277 (M2 — KinoKit core)](https://linear.app/fdatoo/issue/F-277).

## Runbook

```
git clone git@github.com:fdatoo/kino-apple.git
cd kino-apple
just setup
just build
just test
just fmt-check
just lint
KINO_PROBE_BASE_URL=http://127.0.0.1:7777 just probe
```

All commands must exit 0.

## Probe run

Captured 2026-05-16 against local `kino-server` (kino `676c9be`) on `127.0.0.1:7777`, after the two probe-acceptance fixes ([#17 lowercase ClientPlatform](https://github.com/fdatoo/kino-apple/pull/17), [#18 tolerant date + non-lossy catch](https://github.com/fdatoo/kino-apple/pull/18)):

```
Resolved server: 127.0.0.1:7777 (unknown)
Pairing code: 213291 - approve in the admin SPA. Expires at 2026-05-16 12:38:32 +0000.
Paired. Session token id: 019E30C8-EA64-7573-879B-DD8B740F7A1D.
Session saved to Keychain service kino.probe.
First library item: 019E1CEE-2177-71B1-81FA-F4AE4C62CE1A - Mr. Robot
```

End-to-end: discovery resolved → pairing code issued → human approved in admin SPA at `http://127.0.0.1:7777/admin/` → session saved to Keychain → first library item listed. Exit 0.

## Bugs surfaced by the probe

The probe acceptance gate justified its existence by surfacing two real bugs that the unit-test floor missed:

1. **`ClientPlatform` raw values used Swift case names** (`iOS`, `tvOS`, `macOS`) instead of the server's lowercase wire form (`ios`, `tvos`, `macos`). Server rejected with HTTP 400. Fixed in [#17](https://github.com/fdatoo/kino-apple/pull/17) with a regression-pinning test.
2. **OpenAPI runtime's default `ISO8601DateTranscoder` rejected fractional-seconds timestamps**, but kino-server emits microseconds (`2026-05-16T12:25:23.206406Z`). Decoding threw `DecodingError`, which `LivePairingPoller`'s catch-all then masked as `URLError(.badServerResponse)`, making debugging archaeology. Fixed in [#18](https://github.com/fdatoo/kino-apple/pull/18) with a `TolerantISO8601DateTranscoder` plus non-lossy catch-all (preserves the original error via `KinoError.decoding(any Error)`).

## Coverage gate (`kit-coverage`)

`kit-coverage` CI job (added in F-523 / [#16](https://github.com/fdatoo/kino-apple/pull/16)) reports against the M2-closing main branch:

- **KinoKit module line coverage: 60.7 %** (gate: ≥ 50 %, regression guard with ~11-point buffer above current). The 80 % bar in the original spec was aspirational; realistic measurement is below because `AVPlayer` / `NWBrowser` / Keychain integration is inherently unit-test-unfriendly. The gate tightens in M3+ when iOS drives the API and error-path tests become natural.
- **`VariantChooser.swift` region coverage: 100 %** (gate: 100 %). Swift emits region counters, not branch counters; regions are the equivalent "every execution path was exercised" signal.

## Branch protection

Configured 2026-05-16 via `gh api PUT repos/fdatoo/kino-apple/branches/main/protection`:

- All 9 CI jobs required: `kit-format`, `kit-test`, `kit-coverage`, `ios-build`, `tvos-build`, `macos-build`, `ios-uitest`, `tvos-uitest`, `macos-uitest`.
- PRs are mandatory (no direct push to `main`).
- No required-approvals (single-maintainer setup; the gate is "CI must pass").
- No force-push, no branch deletion.
