# Working in kino-apple

This is the canonical agent-onboarding doc for the Apple clients. `CLAUDE.md`
is a symlink to it, so tools that look for `AGENTS.md` (Codex, Copilot,
Cursor, ...) and tools that look for `CLAUDE.md` (Claude Code) read the same
content.

If you're a human, this doc still applies.

## Setup

First run `just setup`. Skipping this means your commits will likely be
rejected. This activates the mandatory Git hooks via `core.hooksPath`.

A clean clone also needs Xcode with Swift 6.x, the Swift toolchain tools, and
`just`. Standard commands:

| Action       | Command          |
|--------------|------------------|
| Setup        | `just setup`     |
| Build        | `just build`     |
| Test         | `just test`      |
| Format       | `just fmt`       |
| Format check | `just fmt-check` |
| Lint         | `just lint`      |

The `Justfile` lands in M0.2. Once present, run `just build`, `just test`,
`just fmt-check`, and `just lint` before claiming work is done; they are what
CI runs.

## Repo layout

```
kino-apple/
|-- AGENTS.md                    # this file (CLAUDE.md is a symlink to it)
|-- CLAUDE.md -> AGENTS.md
|-- README.md
|-- Justfile                     # setup, build, test, fmt, fmt-check, lint
|-- .githooks/                   # pre-commit: fmt-check + lint on staged Swift
|-- .gitignore
|-- .editorconfig
|-- docs/
|   |-- kino-apple-vision.md
|   |-- adrs/
|   `-- agents/
|       |-- README.md
|       |-- specs/
|       `-- plans/
|-- Packages/
|   `-- KinoKit/
|       |-- Package.swift
|       |-- Sources/KinoKit/
|       |-- Sources/KinoKitGenerated/
|       `-- Tests/KinoKitTests/
|-- Apps/
|   |-- Kino-iOS/
|   |-- Kino-tvOS/
|   `-- Kino-macOS/
|-- Kino.xcworkspace
`-- .github/workflows/ci.yml
```

Two rules:

- **Product/architecture docs go in `docs/`.** Agent-authored specs and plans
  go in `docs/agents/` so the product docs surface stays clean.
- **KinoKit owns the shared surface.** App targets should not duplicate
  networking, pairing, discovery, playback coordination, or session storage
  logic that belongs in the package.

## Tracking

- **Linear** is the source of truth for what to build and in what order.
  - Project: **Kino** in the **FynnLabs** team.
  - M0 epic: [F-499](https://linear.app/fdatoo/issue/F-499).
  - Issue identifiers look like `F-500`. Branch names follow Linear's
    `fdatoo/f-XXX-short-slug` format.
- **Phase 4 design:** `docs/agents/specs/2026-05-13-phase-4-design.md`.
- **ADRs:** `docs/adrs/` - cross-cutting architecture decisions (OpenAPI
  generation, mDNS library choice, formatting overrides, etc.). See
  `docs/adrs/README.md` for when to write one once that tree exists.

For non-trivial issues, write a design spec in `docs/agents/specs/` (named
`YYYY-MM-DD-short-slug.md`) before writing code. For multi-step execution,
write a plan in `docs/agents/plans/`.

## Code conventions

- **Swift 6.x.** Deployment targets are iOS 17, tvOS 17, and macOS 14. Keep
  KinoKit in strict concurrency shape as it is introduced.
- **Formatting and linting:** use `swift-format` from the active toolchain.
  `just fmt` writes; `just fmt-check` is the gate; `just lint` runs
  `swift-format lint --strict`. Do not add SwiftLint unless a needed rule is
  missing, and record that decision in an ADR.
- **Errors:** each KinoKit module defines typed `enum` errors conforming to
  `LocalizedError`. Do not erase errors into strings or silently discard thrown
  failures. App boundaries translate errors into user-facing state explicitly.
- **Logging:** use `os.Logger`. Do not use `print` outside app top-levels.
  Log at the lowest level that still reaches the right operator:
  - `info`: lifecycle events, durable state transitions, and rare operational
    milestones that should be visible at the default log level.
  - `debug`: per-operation detail, branch decisions, retry attempts, counts,
    ids, and timings useful while diagnosing one request or flow.
  - `warning`: recoverable degradation where Kino continues but behavior,
    latency, or correctness may be affected.
  - `error`: bugs, invariant violations, startup failures, and operation
    failures that the caller must handle. Log and return/propagate the error;
    logging is not a substitute for handling it.
- **Doc comments:** every public KinoKit symbol gets a `///` doc comment -
  purpose and any non-obvious invariant, not the type signature. Inline `//`
  comments stay rare and explain why, not what.
- **Tests:** KinoKit tests live under `Packages/KinoKit/Tests/`; app smoke tests
  live with their Xcode projects. A change is not done until the relevant tests
  pass.

## Commit messages

**Semantic prefix, one line maximum.** No body. No trailers. Ever.

```
feat(kit): add pairing client
fix(ios): preserve playback progress on background
chore(ci): add macos build job
docs(agents): document commit convention
```

- **Allowed prefixes:** `feat`, `fix`, `chore`, `refactor`, `test`, `docs`,
  `perf`, `build`.
- **Allowed scopes:** `kit`, `ios`, `tvos`, `macos`, `ci`, `repo`, `agents`,
  `docs`.
- **Subject** is imperative, lowercase, no trailing period.

**Never include:**

- Multi-line commit bodies. Explanation belongs in the PR description or a spec.
- `Co-Authored-By:` trailers.
- Agent attribution, generated-by footers, or tool watermarks of any kind.

If a change is too big for a one-line message, the change is too big - split it.

## Workflow expectations

1. **Read first:** the Linear issue, then any linked spec under
   `docs/agents/specs/`.
2. **Plan before coding** for non-trivial work - a short spec or plan under
   `docs/agents/`.
3. **Verify before claiming done:** run the commands in [Setup](#setup)
   locally; treat their failure the same way CI will.
4. **One commit per logical change.** Don't bundle unrelated work into a single
   commit.
5. **Match the convention.** If you find yourself wanting to add a trailer or a
   commit body, re-read the [Commit messages](#commit-messages) section - it is
   not a default to override.
