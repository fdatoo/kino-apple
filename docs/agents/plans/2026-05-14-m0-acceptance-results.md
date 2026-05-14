# M0 acceptance results — 2026-05-14

Verification of the M0 exit bar on a fresh clone, per
[F-507](https://linear.app/fdatoo/issue/F-507).

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

All five commands must exit 0.

## Environment

| Tool           | Version                                                  |
|----------------|----------------------------------------------------------|
| macOS          | Darwin 25.4.0 (arm64)                                    |
| Xcode          | 16+ (default selection via `xcode-select -p`)            |
| Swift          | Apple Swift 6.2.4 (swiftlang-6.2.4.1.4 clang-1700.6.4.2) |
| just           | 1.50.0                                                   |
| swift-format   | 6.2.3 (bundled in toolchain via `swift format`)          |
| xcodegen       | 2.45.4 (only needed to regenerate `.xcodeproj` files)    |
| iOS simulator  | iPhone 17, OS=latest                                     |
| tvOS simulator | Apple TV, OS=latest                                      |

Fresh clone path: `/tmp/kino-apple-fresh-clone`. No Xcode DerivedData carried
over from the development worktree.

## Results

| Step             | Exit | Wall-clock | Notes                                                                                              |
|------------------|------|------------|----------------------------------------------------------------------------------------------------|
| `just setup`     | 0    | <1s        | Activates `core.hooksPath`. Confirms `xcode-select -p` and Swift 6.x.                              |
| `just build`     | 0    | 16s        | KinoKit (5 targets) + `xcodebuild build` per app on generic simulator destinations, no signing.    |
| `just test`      | 0    | 66s        | KinoKit `swift test` (2 tests pass), iOS UI smoke, tvOS UI smoke, macOS UI `build-for-testing`.    |
| `just fmt-check` | 0    | <1s        | `swift format lint --strict --recursive Packages Apps`.                                            |
| `just lint`      | 0    | 1s         | Same gate as `fmt-check` for now (per ticket "lint == `swift-format lint --strict`").              |

CI on `main` enforces the same gates in parallel on `macos-14`; every PR in
M0 (PRs #1–#7) landed green.

## Notes

- The macOS UI test uses `xcodebuild build-for-testing` rather than `test`
  because unsigned macOS UI test runners are Gatekeeper-blocked on launch.
  The build-for-testing path still proves the UI test target compiles and
  links against KinoKit, which is the only signal M0 cares about. When code
  signing arrives in a later milestone, this flips to `test`.
- The `--- xcodebuild: WARNING: Using the first of multiple matching
  destinations` line on macOS is benign: xcodebuild reports both arm64 and
  x86_64 device entries for "My Mac" and silently picks the first. No effect
  on the exit code.

## Conclusion

M0 exit bar met. The repository is ready for M1 (server pre-work) and M2
(KinoKit core).
