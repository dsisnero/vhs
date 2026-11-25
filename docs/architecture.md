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
- `src/vhs/evaluator.cr` coordinates command execution, the ttyd + browser
  session, frame recording, and rendering.
- `src/vhs/tty.cr` spawns ttyd, `src/vhs/keys.cr` maps runes to browser input
  keys, and `src/vhs/evaluator.cr`'s `VHS` class drives Rod (page, canvases,
  keyboard) exactly like upstream's `vhs.go`.
- `src/vhs/draw.cr` draws the window bar and border-radius mask, and
  `src/vhs/ffmpeg_builder.cr` + `src/vhs/ffmpeg_renderer.cr` assemble and run the
  ffmpeg commands (upstream's `draw.go`, `ffmpeg.go`, `video.go`).
- `src/vhs/styles.cr` holds the lipgloss styles that colour the command echo and
  error output (upstream's `style.go`).
- `src/vhs/record.cr` + `src/vhs/pty.cr` implement `vhs record`: the POSIX
  pseudo-terminal (`posix_openpt`, `termios` raw mode) and the keystroke-to-tape
  conversion of upstream's `record.go` + creack/pty.
- `src/vhs_record_shell.cr` is the separate `vhs-record-shell` launcher a recorded
  shell is started through: it does `setsid`/`TIOCSCTTY`/window size and then
  `exec`s the shell, which is the work Crystal's `Process` cannot do in the child.
- `src/vhs/publish.cr` implements `vhs publish` (upstream's `publish.go`) and
  `src/vhs.cr` is the CLI: the root command plus the `record` and `publish`
  subcommands that upstream main.go registers with cobra.
- `vendor/vhs` remains the source of truth for API behavior, edge cases,
  fixtures, and tests.

## Boundaries

- Treat `vendor/vhs` as read-only source material for parity work.
- Keep Crystal-only support code minimal and driven by upstream behavior.
- Generated or temporary artifacts belong in [`temp/`](../temp), not committed
  source paths.
