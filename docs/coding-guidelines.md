# Coding Guidelines

## Parity First

- Preserve upstream behavior before pursuing Crystal-specific refactors.
- Keep parameter semantics, invalid-input handling, and output formatting aligned with Go.
- Document intentional naming or structural deviations in parity manifests when they occur.

## File Rules

- Add or update specs for every meaningful change under [`src/`](../src).
- Keep temporary helpers and scratch artifacts out of committed source files.
- Avoid edits in `vendor/` unless a task explicitly requires source-of-truth updates.

## Crystal Conventions

- Prefer explicit, readable code over clever compression.
- Use project-scoped quality gates that exclude `vendor`, `lib`, and `temp`.
- Add comments only where control flow or parity intent would otherwise be hard to infer.
