# kino-apple

Native Apple clients (iOS, tvOS, macOS) for [Kino](https://github.com/fdatoo/Kino),
plus the shared `KinoKit` Swift package they consume.

The server lives in the [`Kino`](https://github.com/fdatoo/Kino) repo. Both
repos share one Linear project (FynnLabs / Kino) and one continuous `F-XXX`
issue numbering.

## Layout

```
kino-apple/
├── AGENTS.md           # canonical onboarding doc (CLAUDE.md → AGENTS.md)
├── Justfile            # setup, build, test, fmt, fmt-check, lint
├── .githooks/          # pre-commit: swift-format lint on staged .swift files
├── docs/
│   ├── kino-apple-vision.md
│   ├── adrs/           # architecture decisions
│   └── agents/
│       ├── specs/      # design specs
│       └── plans/      # implementation + acceptance plans
├── Packages/
│   └── KinoKit/        # shared Swift package consumed by all three apps
├── Apps/
│   ├── Kino-iOS/
│   ├── Kino-tvOS/
│   └── Kino-macOS/
├── Kino.xcworkspace    # workspace referencing KinoKit + all three apps
└── .github/workflows/ci.yml
```

## Getting started

```
git clone git@github.com:fdatoo/kino-apple.git
cd kino-apple
just setup    # activates the git hooks and verifies Xcode + Swift 6.x
just build    # builds KinoKit and all three apps
just test     # runs KinoKit tests and UI smoke tests
```

Open `Kino.xcworkspace` in Xcode for IDE work.

## Where to look

- [AGENTS.md](AGENTS.md) — onboarding doc (conventions, commands, commit
  rules). `CLAUDE.md` is a symlink to it.
- [docs/kino-apple-vision.md](docs/kino-apple-vision.md) — how the Apple
  side relates to the server-side vision.
- [docs/agents/specs/2026-05-13-phase-4-design.md](docs/agents/specs/2026-05-13-phase-4-design.md) —
  the Phase 4 design spec.
- [docs/adrs/](docs/adrs/) — architecture decision records.
- [Linear F-499](https://linear.app/fdatoo/issue/F-499) — the M0
  foundations epic.

## Phase 4 status

| Milestone                        | State    |
|----------------------------------|----------|
| M0 — kino-apple foundations      | landed   |
| M1 — server pre-work (`Kino`)    | upcoming |
| M2 — KinoKit core                | upcoming |
| M3 — iOS to shippable            | upcoming |
| M4 — tvOS                        | upcoming |
| M5 — macOS                       | upcoming |

See [docs/agents/specs/2026-05-13-phase-4-design.md](docs/agents/specs/2026-05-13-phase-4-design.md)
§10 for the per-milestone exit bars.
