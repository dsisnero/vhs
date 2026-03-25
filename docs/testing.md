# Testing

## Expectations

- Specs live under [`spec/`](../spec).
- Upstream Go tests and fixtures are the behavioral contract.
- Output-sensitive changes should be validated against fixtures or generated images, not only type-level assertions.

## Core Gates

```bash
CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal tool format --check src spec bin
CRYSTAL_CACHE_DIR=$PWD/.crystal-cache ameba src spec bin
CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal spec
```

## Parity Validation

- Use [`scripts/ensure_parity_plan.sh`](../scripts/ensure_parity_plan.sh) to create or validate inventory manifests.
- Use [`scripts/verify_parity_adversarial.sh`](../scripts/verify_parity_adversarial.sh) for an independent parity signoff pass.
- Resolve `pending`, `xit`, and similar placeholder specs before claiming parity completion.
