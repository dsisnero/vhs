# PR Workflow

## Before Coding

- Confirm the upstream behavior in `vendor/vhs`.
- Check the parity manifests in [`plans/inventory/`](../plans/inventory) when the change maps to upstream API or tests.

## During Work

- Track follow-up work in `bd`; do not use assistant-internal task tracking.
- Keep branches and commits focused on one parity unit or bug fix at a time.
- Run targeted specs while iterating, then run the repo gates that apply to your change.

## Landing

Session completion requires:

```bash
git pull --rebase
bd sync
git push
git status
```

Do not stop at a local-only state. Work is only handed off after the branch is synchronized with origin and any remaining follow-up is captured in `bd`.
