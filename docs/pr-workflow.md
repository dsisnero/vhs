# PR Workflow

## Before Coding

- Confirm the upstream behavior in `vendor/vhs`.
- Check the parity manifests in [`plans/inventory/`](../plans/inventory) when the
  change maps to upstream API or tests.

## During Work

- Track follow-up work in `bd`; do not use assistant-internal task tracking.
- Keep branches and commits focused on one parity unit or bug fix at a time.
- Run targeted specs while iterating, then run the repo gates that apply to your
  change: `make lint`, `make test`, and `make inventory`.
- Refresh the **Where we are** block in [`plans/parity.md`](../plans/parity.md)
  before committing.

## Committing

Use `port: <one-line feature>` followed by bullets for what changed and the
upstream revision (`charmbracelet/vhs v0.10.0+19 (04e743a9)`). Include
divergences and gate results. The full Definition of done lives in
[`AGENTS.md`](../AGENTS.md).

## Landing

Session completion requires:

```bash
git pull --rebase
bd sync
git push
git status
```

Do not stop at a local-only state. Work is only handed off after the branch is
synchronized with origin and any remaining follow-up is captured in `bd`.
