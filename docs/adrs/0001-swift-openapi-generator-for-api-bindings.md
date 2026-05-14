# ADR-0001 — swift-openapi-generator for API bindings

## Status
Accepted

## Date
2026-05-14

## Context

KinoKit needs an HTTP client that matches `kino-server`'s OpenAPI surface. The
server already publishes `openapi.json` and runs an OpenAPI drift check in its
own CI, so that file is the authoritative contract for Apple clients.

Two clients realistically fit. A hand-written `URLSession` client gives maximum
control over the public API and avoids a generator dependency, but every server
endpoint addition, rename, or schema change becomes a manual sync across
iOS, tvOS, and macOS release cycles. Apple's `swift-openapi-generator` can
instead shadow the spec deterministically as a SwiftPM build plugin, with the
human-facing surface kept in hand-written code. Phase 4 design spec §5 already
sets that shape for KinoKit.

## Decision

Adopt Apple's `swift-openapi-generator`
(https://github.com/apple/swift-openapi-generator) as a SwiftPM build plugin.
Generated code lives in the `KinoKitGenerated` target, added in M2 alongside the
vendored `openapi.json`. Generation runs on every build from
`Packages/KinoKit/Sources/KinoKitGenerated/openapi.json`; generated output is
never committed and never hand-edited. The public `KinoClient` facade described
in Phase 4 design spec §5 wraps the generated transport and owns error mapping
into `KinoError`, retry and refresh behavior, and app-facing types.

## Consequences

- **Contract bumps are explicit.** Updating the server contract is one PR that
  updates `openapi.json`. CI's `openapi-binding-drift` job, added in M2,
  refreshes the file from a tagged `kino` server release and fails if the diff
  is not intentional.
- **Clean builds do a little more work.** SwiftPM runs the generator as a build
  plugin step. Incremental builds should mostly use cached output.
- **The generator version is pinned.** `Package.swift` pins a specific
  generator release. Bumping it is an ADR-grade change because generated code
  shape can change even when the `KinoClient` facade hides most of the churn.
- **Generated code is transport only.** The generator emits a literal mirror of
  OpenAPI, which is useful for transport and poor as an app API. The
  hand-written facade absorbs that awkwardness; generated code stays entirely
  machine-owned.
- **Reversal has a contained cost.** If the generator becomes a problem because
  of size, build time, or codegen bugs, the facade already isolates apps from
  the generated surface. Switching to a hand-written transport would replace
  the inner layer without changing app call sites.
