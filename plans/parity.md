# Parity Plan — VHS Crystal

Curated feature roadmap for the Go → Crystal port. The generated manifests live
in `plans/inventory/`; per-symbol state belongs in
`plans/inventory/go_port_inventory.tsv`. Repo rules (gates, definition of done,
commit format) live in [`AGENTS.md`](../AGENTS.md) — this file tracks *where we
are*, not *how the repo works*.

## Where we are

- **Current focus:** make the curated ledger tell the truth. Most
  `go_source_parity.tsv` rows still say `missing` for symbols the port already
  implements (`command.go::func::Execute` → `src/vhs/evaluator.cr:374`,
  `style.go` color constants → `src/vhs/evaluator.cr:9-27`). Until that is
  reconciled, "missing" counts overstate the remaining work.
- **Next up:**
  1. Reconcile `go_source_parity.tsv` status/`crystal_refs` for `command.go`
     (41 rows), `style.go` (21), `token/token.go` (85), `parser/parser.go` (12),
     `vhs.go` (13), and `draw.go` (11) against `src/`.
  2. Map the existing lexer/parser/token specs onto the nine `missing` test IDs
     in `go_test_parity.tsv` (`lexer/lexer_test.go`, `parser/parser_test.go`,
     `token/token_test.go`).
  3. Port `ffmpeg.go`'s filter/stream builders (16 rows) — today
     `src/vhs/ffmpeg_renderer.cr` builds ffmpeg arguments ad hoc and has no
     spec coverage.
  4. Port the remaining CLI surfaces: `publish.go`, `serve.go`, `tty.go`,
     `syntax.go`, `testing.go`, `man.go`.
- **Status by area:**
  - Lexer / token / parser: implemented in `src/vhs/{lexer,token,parser}.cr`
    with specs; ledger rows still `missing` (100 rows).
  - Command dispatch / evaluator: broad coverage in `src/vhs/evaluator.cr`;
    only `Set Theme`, `Wait`, and `Shift` rows are promoted.
  - Renderers: `png_renderer.cr` has spec coverage; `ffmpeg_renderer.cr` is
    unverified and does not mirror upstream's builders.
  - Record / screenshot / themes: upstream tests ported (8 `ported` test rows).
  - CLI, publish, serve, tty, man: not ported.
- **Scoping notes / gotchas:**
  - The ledger is a **regex** ledger. `PARITY_PARSER=tree-sitter` works here
    (toolchain `v0.3.4` is installed) but discovers 378 Go items instead of 248
    because it reports native kinds (`function`, `class`, `interface`). Treat a
    parser switch as a reviewed ID migration, not a config change.
  - This checkout is on an exFAT volume: macOS writes AppleDouble `._*`
    sidecars next to every file. They break spec discovery and make git print
    `non-monotonic index .../._pack-*.idx`. Run `make sidecars` (every gate
    already depends on it).
  - `shard.override.yml` is required: `ultraviolet` (pinned) still depends on
    `docelic/terminfo`, which was deleted upstream; the override points at the
    maintained `dsisnero/terminfo` fork.
  - `Metrics/CyclomaticComplexity` is excluded for `src/vhs/evaluator.cr` only,
    because the dispatch mirrors upstream's Go switches case for case.
- **Last commit:** `31cb4d2` Promote record and screenshot tests in parity
  manifests
- **Gates:** `make lint` pass; `make test` `90 examples, 0 failures`;
  `make inventory` pass (231 port items, 231 API items, 17 tests).

Keep this block accurate after every feature: the next session reads it first
(see `AGENTS.md` → **How to resume**).

## Phase 1 — Ledger truth

- [ ] Reconcile `command.go` rows (41) against `src/vhs/evaluator.cr`
- [ ] Reconcile `style.go` constants (21) against `src/vhs/evaluator.cr`
- [ ] Reconcile `token/token.go` (85), `parser/parser.go` (12),
      `lexer/lexer.go` (3) rows
- [ ] Reconcile `vhs.go` (13), `draw.go` (11), `themes.go` (4),
      `screenshot.go` (3), `record.go`, `shell.go` rows
- [ ] Regenerate `go_source_parity.tsv` and confirm `make inventory`

## Phase 2 — Upstream tests still unmapped

- [ ] `lexer/lexer_test.go::TestNextToken`, `TestLexTapeFile`
- [ ] `parser/parser_test.go` (`TestParser`, `TestParserErrors`,
      `TestParseCtrl`, `TestParseScreeenshot`, `TestParseSource`,
      `TestParseTapeFile`)
- [ ] `token/token_test.go::TestToCamel`

## Phase 3 — Renderer parity

- [ ] Port `ffmpeg.go` `FilterComplexBuilder` (window bar, border radius,
      margin fill, GIF)
- [ ] Port `ffmpeg.go` `StreamBuilder` (margin, bar, corner, mp4, webm)
- [ ] Port `ffmpeg.go::calcTermDimensions` and add output fixtures
- [ ] Reconcile `video.go` (6 rows) with `src/vhs/ffmpeg_renderer.cr`

## Phase 4 — CLI surfaces

- [ ] `publish.go` (Charm publish path)
- [ ] `serve.go` / `tty.go` (server + tty handling, `serve_unix.go` first)
- [ ] `syntax.go`, `testing.go`, `man.go`
- [ ] Evaluate `token/token.go` native tree-sitter migration as a separate
      reviewed branch

## Intentional divergences

- `ScreenshotOptions#frame_capture?`: Crystal predicate naming for the upstream
  `FrameCapture` field; behavior is identical.
- `src/vhs/evaluator.cr` keeps upstream's flat command dispatch (high cyclomatic
  complexity) instead of splitting into helpers, so divergence from
  `vendor/vhs/command.go` stays visible. Ameba excludes that file for the rule.
- `shard.override.yml` redirects the `terminfo` dependency to a fork; the pinned
  upstream repository no longer exists.
