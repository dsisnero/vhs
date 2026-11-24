# Architecture

## Overview

`vhs` is a Crystal port of the upstream Go project in
[`vendor/vhs`](../vendor/vhs). The Crystal code under [`src/`](../src) mirrors
upstream behavior while adapting implementation details to Crystal libraries and
types.

Current port status, area-by-area progress, and the ordered backlog live in
[`plans/parity.md`](../plans/parity.md); per-symbol state lives in
[`plans/inventory/`](../plans/inventory).

## Main Areas

- `src/vhs/parser.cr`, `src/vhs/lexer.cr`, and related specs implement tape
  parsing.
- `src/vhs/evaluator.cr` coordinates command execution, terminal interaction,
  screenshot capture, and recording.
- `src/vhs/png_renderer.cr` and `src/vhs/ffmpeg_renderer.cr` handle rendered
  image and video output.
- `vendor/vhs` remains the source of truth for API behavior, edge cases,
  fixtures, and tests.

## Boundaries

- Treat `vendor/vhs` as read-only source material for parity work.
- Keep Crystal-only support code minimal and driven by upstream behavior.
- Generated or temporary artifacts belong in [`temp/`](../temp), not committed
  source paths.
