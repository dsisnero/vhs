# Development

## Setup

Install dependencies with:

```bash
make install
```

Clone with submodules so `vendor/vhs` is present:

```bash
git clone --recurse-submodules <repo>
```

## Local Workflow

- Export `CRYSTAL_CACHE_DIR=$PWD/.crystal-cache` for every `crystal` command.
- Run `make clean` before re-recording outputs or retrying flaky renderer specs.
- Keep temporary files in [`temp/`](../temp).

## Common Commands

```bash
make format
make lint
make test
make build
make markdown
make markdown-check
```

## Parity Tooling

Canonical parity manifests live under [`plans/inventory/`](../plans/inventory). Use the checked-in scripts under [`scripts/`](../scripts) to bootstrap or validate parity against `vendor/vhs`.
