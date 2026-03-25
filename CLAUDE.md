# VHS Crystal

Crystal port of the Go [charmbracelet/vhs](https://github.com/charmbracelet/vhs) library for terminal recording, screenshots, and rendered video output.

## Verified Commands

```bash
make install
make update
make format
make lint
make test
make build
make markdown
make markdown-check
make clean
```

Direct Crystal gates used by this repo:

```bash
CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal tool format --check src spec bin
CRYSTAL_CACHE_DIR=$PWD/.crystal-cache ameba src spec bin
CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal spec
```

## Documentation

| File | Purpose |
| --- | --- |
| [docs/architecture.md](docs/architecture.md) | Runtime layout, upstream source-of-truth boundaries, and rendering pipeline |
| [docs/development.md](docs/development.md) | Local setup, cache usage, temp directory rules, and day-to-day commands |
| [docs/coding-guidelines.md](docs/coding-guidelines.md) | Crystal style, parity expectations, and file-level constraints |
| [docs/testing.md](docs/testing.md) | Spec organization, parity expectations, and quality gates |
| [docs/pr-workflow.md](docs/pr-workflow.md) | Beads workflow, branch hygiene, and landing requirements |

## Core Principles

- Go source and tests in `vendor/vhs` are the authoritative behavior spec.
- Golden outputs and fixtures must match upstream behavior before work is considered complete.
- Public APIs should preserve upstream semantics even when Crystal implementation details differ.
- Every `crystal` invocation should use `CRYSTAL_CACHE_DIR=$PWD/.crystal-cache`.
- Temporary artifacts belong in `./temp`, not the repo root or system temp.

## Commit Convention

Use short imperative commit subjects that describe the behavior change, for example `Align PNG font fallback resolution with upstream defaults`.

## Project Conventions

- Verify file existence before reading or editing paths inferred from upstream docs or tests.
- Keep tests under `spec/` and add or update specs for every change under `src/`.
- Prefer repo-scoped gate commands: `src`, `spec`, and `bin`; avoid scanning `vendor`, `lib`, and `temp`.
- Use `bd` for issue tracking. `bd sync` is part of session closeout.
- Session completion is not done until changes are committed, rebased, synced, and pushed successfully.
