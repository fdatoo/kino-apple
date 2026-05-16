# M2 acceptance results — 2026-05-16

Verification of the M2 exit bar on a fresh clone, per
[F-523](https://linear.app/fdatoo/issue/F-523).

## Runbook

```
git clone git@github.com:fdatoo/kino-apple.git
cd kino-apple
just setup
just build
just test
just fmt-check
just lint
KINO_PROBE_BASE_URL=http://127.0.0.1:7000 just probe
```

All commands must exit 0.

## Probe run

TODO: paste stdout of `just probe` against a real local kino-server.

## Notes

- `kit-coverage` must report at least 80% package line coverage and 100%
  region coverage for `KinoKitPlayback/VariantChooser.swift`.
- `kit-coverage` must be added manually to `main` branch protection after the
  CI job lands.
