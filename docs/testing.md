# Testing

## Expectations

- Specs live under [`spec/`](../spec).
- Upstream Go tests and fixtures are the behavioral contract.
- Output-sensitive changes should be validated against fixtures or generated
  images, not only type-level assertions.

## Core Gates

```bash
make format
make lint
make test
```

`make format` and `make lint` include `bin/` only when a build exists, because
`bin/` is gitignored. The underlying commands are:

```bash
CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal tool format --check src spec
CRYSTAL_CACHE_DIR=$PWD/.crystal-cache ameba src spec
CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal spec
```

Every gate depends on `make sidecars` so macOS AppleDouble `._*` files cannot
break spec discovery on this exFAT volume.

## Parity Validation

- Use `make inventory` ([`scripts/check_parity.sh`](../scripts/check_parity.sh))
  to verify the installed parity skill and all three manifests against
  `vendor/vhs`.
- Regenerating the generated manifests
  ([`scripts/ensure_parity_plan.sh`](../scripts/ensure_parity_plan.sh)) overwrites
  curated statuses and notes; do it deliberately and review the diff, then run
  `make inventory`.
- Use
  [`scripts/verify_parity_adversarial.sh`](../scripts/verify_parity_adversarial.sh)
  for an independent parity signoff pass.
- Resolve `pending`, `xit`, and similar placeholder specs before claiming parity
  completion.
