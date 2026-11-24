# VHS Crystal

> **How to resume:** read [`plans/parity.md`](plans/parity.md) first and use its
> **Where we are** block (current focus + ordered "Next up"), then run
> `make lint` and `make test`. Details: [docs/resuming.md](docs/resuming.md). Do
> not re-derive state from git.

Crystal port of the vhs library (Go) from
[charmbracelet/vhs](https://github.com/charmbracelet/vhs), vendored at
`vendor/vhs` (release `v0.10.0` + 19 commits, commit
`04e743a9fac3f9e0f0beb42de2363a2fe6137f44`).

## Commands

```bash
make install         # shards install (needs shard.override.yml, see below)
make update          # shards update
make format          # crystal tool format --check src spec (bin when built)
make lint            # ameba src spec (with --fix pass first)
make test            # crystal spec
make inventory       # parity gate: verify skill + check all three manifests
make markdown        # rumdl fmt README.md docs plans
make markdown-check  # rumdl check README.md docs plans
make build           # build bin/vhs
make clean           # remove temp artifacts
make sidecars        # strip macOS AppleDouble ._* files
```

Direct gates, when a make target does not apply:

```bash
CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal tool format --check src spec
CRYSTAL_CACHE_DIR=$PWD/.crystal-cache ameba src spec
CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal spec
```

## Docs

- [Resuming work](docs/resuming.md)
- [Architecture](docs/architecture.md)
- [Development](docs/development.md)
- [Coding Guidelines](docs/coding-guidelines.md)
- [Testing](docs/testing.md)
- [PR Workflow](docs/pr-workflow.md)

## Principles

1. Upstream behavior is the source of truth; `vendor/vhs` wins over local
   preference.
2. Port behavior, not style.
3. Port upstream tests early and never weaken assertions.
4. Track parity in `plans/parity.md` and `plans/inventory/`.
5. Commit one completed feature at a time.

## Parity tooling

The active cross-language parity skill is
`${HOME}/.agents/skills/crystal_forge/skills/cross-language-crystal-parity`.
`make inventory` must invoke that skill's scripts or a thin forwarding wrapper,
never a copied parity implementation. The wrappers under `scripts/` are exactly
that: `scripts/check_parity.sh` resolves the skill through
`scripts/parity_skill_dir.sh` and forwards. Updating the installed skill takes
effect immediately; do not reintroduce `*.rb` copies of its internals.

The curated ledger uses `regex` discovery. Keep that mode for the regular gate
until a reviewed manifest and ID migration changes it. Before relying on
discovery, run:

```bash
PARITY_SKILL_DIR="${HOME}/.agents/skills/crystal_forge/skills/cross-language-crystal-parity"
"${PARITY_SKILL_DIR}/scripts/verify_skill_install.sh" . go regex
PORT_PARSER=regex make inventory
```

Check `PARITY_DISCOVERY_BACKEND` in the gate output and, when manifests are
regenerated, `backend` in their `.metadata.json` files. A requested parser mode
does not prove tree-sitter ran. This toolchain has tree-sitter available
(`chiasmus v0.3.4`), which discovers 378 Go items with native kind labels versus
248 with regex — switching is a migration, so the regex ledger stays
authoritative meanwhile.

## Session continuity (read this first)

`plans/parity.md` is the single source of truth for where we are. At the start
of every session:

1. Read `plans/parity.md` and use its **Where we are** block to find the current
   focus, the ordered "Next up" list, and per-area chunk status. Do not
   re-derive state from git history.
2. Skim `git log --oneline -10` and `git status` to confirm the working tree.
3. Confirm the **Parity tooling** command still forwards to the installed skill,
   then run `make lint`, `make test`, and `make inventory` before changes.

See [docs/resuming.md](docs/resuming.md) for the full resume checklist.

### Keeping `plans/parity.md` resumable

- `plans/parity.md` starts with a **Where we are** block (`Current focus`,
  `Next up`, chunk status by area). Keep it accurate after every feature.
- Work items are feature-sized (roughly one branch/commit). Per-symbol state
  lives in `plans/inventory/go_port_inventory.tsv`, not in the plan.
- The ledger is a **current-state** artifact of the pinned baseline. Re-base it
  when the `vendor/vhs` pin changes; never append across versions.
- If the plan grows too large, split it into `plans/parity/<area>.md`, link each
  from `plans/parity.md`, and mark each split file complete/in-progress plus the
  file being worked on next.

### Definition of done for every feature (required)

A feature is complete only when all of the following are true, and all of it
must be committed as **one** atomic commit before starting the next feature:

1. the API surface is implemented;
2. upstream tests (or equivalent characterization specs) exist and pass;
3. gates pass: `make lint`, `make test`, and `make inventory`;
4. parity inventory rows for the feature are updated
   (`plans/inventory/go_port_inventory.tsv`) and `make inventory` passes — it
   checks every row against the pinned tree *and* that each `crystal_refs` file
   still exists, which is the half that rots when repo files move;
5. `plans/parity.md` status is updated and the **Where we are** block refreshed
   (current focus + next up);
6. any intentional divergence is documented (in `plans/parity.md` and/or the
   commit message).

### Commit message

Start with `port:` and a one-line feature name, then bullets for what changed,
then the upstream revision (`charmbracelet/vhs v0.10.0+19
(04e743a9fac3f9e0f0beb42de2363a2fe6137f44)`). Include new/changed files,
divergences, and the gate results so a new session can resume from the commit
alone.

## Project Conventions

- Verify file existence before reading or editing paths inferred from upstream
  docs or tests.
- Keep tests under `spec/` and add or update specs for every change under
  `src/`.
- Prefer repo-scoped gate commands: `src`, `spec`, and `bin`; avoid scanning
  `vendor`, `lib`, and `temp`.
- Every `crystal` invocation uses `CRYSTAL_CACHE_DIR=$PWD/.crystal-cache`.
- Temporary artifacts belong in `./temp`, never the repo root or system temp.
- This checkout is on an exFAT volume: run `make sidecars` if `crystal spec` or
  git misbehaves (AppleDouble `._*` sidecars).
- `shard.override.yml` is committed on purpose: the pinned `ultraviolet` depends
  on the deleted `docelic/terminfo`, so the override points at
  `dsisnero/terminfo`.
- Use `bd` for issue tracking. `bd sync` is part of session closeout.
- Session completion is not done until changes are committed, rebased, synced,
  and pushed successfully.
