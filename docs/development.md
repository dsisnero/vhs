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

## Upstream Pin

`vendor/vhs` is pinned at `v0.10.0` + 19 commits
(`04e743a9fac3f9e0f0beb42de2363a2fe6137f44`). Updating the pin is its own
change: re-base the parity ledger afterwards and record the new revision in
[`plans/parity.md`](../plans/parity.md).

## Parity Tooling

Canonical parity manifests live under [`plans/inventory/`](../plans/inventory).
The scripts under [`scripts/`](../scripts) are thin forwarding wrappers around
the installed `cross-language-crystal-parity` skill
(`${HOME}/.agents/skills/crystal_forge/skills/cross-language-crystal-parity`,
overridable with `PARITY_SKILL_DIR`); `scripts/parity_skill_dir.sh` performs the
lookup. Validate everything with:

```bash
make inventory       # verify skill + all three manifests
```

The generated `go_source_parity.tsv` / `go_test_parity.tsv` files carry curated
statuses and notes, so regenerating them is a deliberate, reviewed action, not a
routine gate. Bootstrap or rebuild them with
`scripts/ensure_parity_plan.sh <root> <source> <language> <parser> <refresh>`
where `refresh=1` overwrites; review the diff before committing.

The curated ledger uses `regex` discovery. Native tree-sitter discovery is
available in this environment but reports a different kind vocabulary, so a
switch is a reviewed ID migration.

## Checkout Quirks

- This checkout is on an exFAT volume, so macOS writes AppleDouble `._*`
  sidecars. They break spec discovery and git; `make sidecars` removes them and
  every gate depends on it.
- `shard.override.yml` is committed: the pinned `ultraviolet` still depends on
  the deleted `docelic/terminfo`, so the override redirects it to
  `dsisnero/terminfo`.
- `make install` fails while building the `ameba` dev dependency on Crystal
  ≥ 1.19. Use the standalone `ameba` binary on `PATH`; the shard install
  itself still completes.
