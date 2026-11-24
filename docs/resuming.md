# Resuming Work

This is the first thing to read in a new session. It takes a few minutes to get
back to a known-good state.

## 1. Read where we are

- [`plans/parity.md`](../plans/parity.md) — start at the **Where we are**
  block. It names the current focus, the ordered "Next up" list, per-area chunk
  status, and the scoping notes/gotchas, plus the last commit and current gate
  results. Do not re-derive state from git history.

- [`plans/inventory/go_port_inventory.tsv`](../plans/inventory/go_port_inventory.tsv)
  — the curated per-symbol ledger (status + `crystal_refs`). Run
  `make inventory` before trusting it: it fails on a stale row and on a
  `crystal_refs` file that no longer exists. Use it to see what is left inside
  the current chunk:

  ```bash
  awk -F '\t' '!/^#/ && NF {print $3}' \
    plans/inventory/go_port_inventory.tsv | sort | uniq -c
  ```

## 2. Confirm the working tree

```bash
git log --oneline -10
git status
```

The last commit should be the previous feature (`port: ...`), committed
atomically. If the tree is dirty, finish or stash before starting.

If git prints `non-monotonic index .../._pack-*.idx`, macOS left AppleDouble
sidecars in the object database; run `make sidecars` and retry.

## 3. Confirm a clean baseline

```bash
make lint
make test
make inventory
```

All three must pass before changing anything. `make inventory` runs
`scripts/check_parity.sh`, which verifies the installed
`cross-language-crystal-parity` skill and then checks all three manifests
against `vendor/vhs`.

The skill is resolved by
[`scripts/parity_skill_dir.sh`](../scripts/parity_skill_dir.sh); set
`PARITY_SKILL_DIR` to pin a specific install. The ledger is a **regex** ledger
(`PARITY_PARSER=regex`); tree-sitter discovery is available but produces a
different ID vocabulary, so switching modes is a reviewed migration.

Run the inventory gate and compare any drift with the **Where we are** block;
recorded upstream drift may be the next feature to fix.

## 4. Pick the next feature

Take the first unchecked item in the **Next up** list (or the next `[ ]` item in
the current phase). For each feature:

1. Read the upstream source under `vendor/vhs` and the nearest upstream tests.
2. Port the tests first (red → green); never weaken assertions.
3. Satisfy the **Definition of done** in `AGENTS.md` (API, tests, gates,
   inventory rows, `plans/parity.md` status + **Where we are** refresh,
   divergences).
4. Commit atomically with the `port: ...` message format from `AGENTS.md`.

## If the plan is split

When `plans/parity.md` grows too large it is split into `plans/parity/<area>.md`
files. In that case every split file is linked from `plans/parity.md`, and
`plans/parity.md` marks each file complete/in-progress and names the file being
worked on plus the next file/phase to start.

## Environment notes

This checkout lives on an exFAT volume, so macOS writes an AppleDouble `._*`
sidecar next to every file it touches:

- a `._foo_spec.cr` sidecar breaks `crystal spec` discovery;
- git reports `non-monotonic index .../._pack-*.idx` and can refuse to run.

`make sidecars` deletes them (`find . -name '._*' -delete`); `format`, `lint`,
`test`, and `inventory` depend on it. Delete by hand when a git operation fails
before make can run.

Other checkout-specific notes:

- `bin/` is gitignored, so a fresh clone has no binary. The gate targets only
  include `bin` when it exists; run `make build` to lint a built tree.
- `shard.override.yml` redirects the `terminfo` dependency to a maintained fork
  because the pinned `docelic/terminfo` repository was deleted. Keep it.
- `make install` builds the `ameba` dev dependency, which does not compile on
  Crystal ≥ 1.19; lint is meant to run the standalone `ameba` binary already on
  `PATH`. The install error is expected and not fatal for the gates.
