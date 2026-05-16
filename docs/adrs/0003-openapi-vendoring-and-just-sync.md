# ADR-0003 — Vendor `openapi.json` and refresh via `just openapi-sync`

## Status
Accepted

## Date
2026-05-16

## Context

ADR-0001 picked `swift-openapi-generator` as KinoKit's transport, with the
generator running from a vendored `openapi.json` at
`Packages/KinoKit/Sources/KinoKitGenerated/openapi.json`. That left two
mechanics unsettled: how the file gets into the repo, and how it stays honest
relative to the live server contract that lives at
`crates/kino-server/openapi.json` in the `kino` repo.

ADR-0001's consequences bullet floated an "openapi-binding-drift" CI job that
would fetch the file from a tagged `kino` release on every PR and fail the
build if the diff was unintended. That job was a hedge against the file going
stale silently, but it forces every kino-side endpoint addition to land as a
synchronized two-repo PR — kino bumps the file *and* kino-apple bumps the
vendored copy at the same time. It also paves over the more interesting
question of *when* the Apple clients should pick up new server endpoints,
making "we drifted" feel like a test failure rather than a deliberate
schedule.

The Phase 4 design (Phase 4 spec §11 and the M2 spec §1) treats the vendored
file as the authoritative contract this version of KinoKit binds to. Bumping
it is a deliberate engineering act, not an automatic resync.

## Decision

- The vendored `Packages/KinoKit/Sources/KinoKitGenerated/openapi.json` is the
  contract this version of KinoKit binds to. The file is committed to the
  repo; the generator reads it as-is on every build.
- A `just openapi-sync [ref]` recipe fetches the file from
  `github.com/fdatoo/kino` at the named ref (tag, branch, or commit SHA),
  defaulting to `main`. The engineer reviews the diff and commits as a
  deliberate PR. Recipe usage: `just openapi-sync v0.x.y` or
  `just openapi-sync 676c9be1`.
- No `openapi-binding-drift` CI job. The `kino-apple` CI does not check the
  vendored file against any external source. The file's presence in the repo
  is authoritative.

## Consequences

- **Server endpoint additions don't show up in clients until someone runs
  `just openapi-sync`.** That is the intended schedule: Apple clients pick up
  new server surface deliberately, on a cadence the Apple-side milestone
  drives, not opportunistically on every server PR.
- **Drift is visible at use time, not on a separate gate.** If KinoKit
  consumes an endpoint the vendored spec doesn't describe, the build fails
  loudly during generation. If the spec gains an endpoint KinoKit hasn't
  wired yet, nothing fails — that's the correct outcome.
- **The refresh tool is local-only.** The recipe shells out to `curl` against
  `raw.githubusercontent.com`. No GitHub API token, no GitHub CLI dependency.
  Engineers can also run `just openapi-sync $(git -C ~/Developer/kino
  rev-parse HEAD)` to vendor from a local checkout's exact SHA.
- **A known generator quirk is documented here so it doesn't surprise future
  readers.** `swift-openapi-generator` emits `warning: Schema "null" is not
  supported, reason: "schema type", skipping …` for every nullable field in
  `kino`'s spec. The generator does not lose information for these fields —
  it falls back to making the property optional, which is what the spec
  intends. The warning is verbose and harmless. If it ever becomes blocking,
  the path forward is to rewrite kino's spec to use `nullable: true` plus a
  concrete type rather than the `oneOf: [null, …]` style.
- **Reversal is cheap.** If a drift gate becomes desirable later (for
  example, once a public stable API contract exists), adding it is a small
  CI workflow change — the file path is stable and the source of truth
  (`crates/kino-server/openapi.json` in the `kino` repo) is documented here.

## Supersedes

This ADR replaces ADR-0001's "Contract bumps are explicit" bullet's claim
that bumps land through a CI drift job. The mechanics are an engineer-run
`just openapi-sync` recipe, not a CI check. The rest of ADR-0001 stands.
