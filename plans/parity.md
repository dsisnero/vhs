# Parity Plan — VHS Crystal

Curated feature roadmap for the Go → Crystal port. The generated manifests live
in `plans/inventory/`; per-symbol state belongs in
`plans/inventory/go_port_inventory.tsv`. Repo rules (gates, definition of done,
commit format) live in [`AGENTS.md`](../AGENTS.md) — this file tracks *where we
are*, not *how the repo works*.

## Where we are

- **Current focus:** finish reconciling the curated ledger with the code already
  in `src/`. `command.go` is done (39 of its 41 symbols map 1:1 to
  `Vhs::Evaluator.execute_*`). Start with `style.go`, where all 21 rows already
  have a home in `src/`, then take the two small blocks (`error.go`,
  `evaluator.go`) that are genuine implementation gaps rather than ledger debt.
- **Next up:**
  1. Reconcile `style.go` (21 rows) — ledger-only, everything exists: the 19
     color constants map to `src/vhs/evaluator.cr:9-27`
     (`BACKGROUND`…`INDIGO`, same hex/lipgloss values), `StyleOptions` →
     `Vhs::StyleOptions` (`evaluator.cr:1259`), `DefaultStyleOptions` →
     `Vhs.default_style_options` (`evaluator.cr:1520`).
  2. Reconcile `error.go` (5 rows) — partially implemented, so this is porting,
     not just bookkeeping: `InvalidSyntaxError` exists (`evaluator.cr:183`) but
     `ErrorColumnOffset`, `Underline`, `LineNumber`, and upstream's
     `printError`/`printErrors` layout (line number gutter, caret underline,
     `ErrorStyle`) have no Crystal counterpart yet. Check what
     `Vhs#evaluate` currently prints for parser errors before promoting rows.
  3. Reconcile `evaluator.go` (2 rows): `Evaluate` → `Vhs#evaluate(tape,
     output)` (`evaluator.cr:1993`), but the signature drops upstream's
     `context.Context` and `...EvaluatorOption`; `EvaluatorOption` itself is
     absent. Record the divergence or port the option type.
  4. Reconcile the remaining source rows: `token/token.go` (85),
     `parser/parser.go` (12), `lexer/lexer.go` (3), `vhs.go` (13), `draw.go`
     (11), `themes.go` (4), `screenshot.go` (3), `record.go` (1),
     `shell.go` (1).
  5. Map the existing lexer/parser/token specs onto the nine `missing` test IDs
     in `go_test_parity.tsv` (`lexer/lexer_test.go` ×2, `parser/parser_test.go`
     ×6, `token/token_test.go` ×1).
  6. Port `ffmpeg.go`'s filter/stream builders (16 rows) — today
     `src/vhs/ffmpeg_renderer.cr` builds ffmpeg arguments ad hoc and has no
     spec coverage.
  7. Port the remaining CLI surfaces: `publish.go`, `serve.go`, `tty.go`,
     `syntax.go`, `testing.go`, `man.go`.
- **Status by area:**
  - Lexer / token / parser: implemented in `src/vhs/{lexer,token,parser}.cr`
    with specs; ledger rows still `missing` (100 source rows + 9 test IDs).
  - Errors / evaluate entrypoint: `InvalidSyntaxError` ported; the
    `error.go` display helpers and `EvaluatorOption` are not.
  - Command dispatch / evaluator: all 41 `command.go` rows reconciled — 3
    `ported`, 14 `partial`, 23 `in_progress`, 1 `intentional_divergence`. Only
    Set Theme has upstream-asserted behavior; the rest record implementation
    presence and name the missing assertions.
  - Renderers: `png_renderer.cr` has spec coverage; `ffmpeg_renderer.cr` is
    unverified and does not mirror upstream's builders.
  - Record / screenshot / themes: upstream tests ported (8 `ported` test rows).
  - CLI, publish, serve, tty, man: not ported.
- **Scoping notes / gotchas:**
  - The ledger is a **regex** ledger. `PARITY_PARSER=tree-sitter` works here
    (toolchain `v0.3.4` is installed) but discovers 378 Go items instead of 248
    because it reports native kinds (`function`, `class`, `interface`). Treat a
    parser switch as a reviewed ID migration, not a config change.
  - The generated layer (`go_source_parity.tsv`, `go_test_parity.tsv`) was
    rebuilt with the canonical scripts: it now carries the `# kinds=` header and
    a `.metadata.json` sibling, and its statuses are always `missing`/`baseline`.
    Curated state lives **only** in `go_port_inventory.tsv`.
  - This checkout is on an exFAT volume: macOS writes AppleDouble `._*`
    sidecars next to every file. They break spec discovery and make git print
    `non-monotonic index .../._pack-*.idx`. Run `make sidecars` (every gate
    already depends on it).
  - `shard.override.yml` is required: `ultraviolet` (pinned) still depends on
    `docelic/terminfo`, which was deleted upstream; the override points at the
    maintained `dsisnero/terminfo` fork.
  - `Metrics/CyclomaticComplexity` is excluded for `src/vhs/evaluator.cr` only,
    because the dispatch mirrors upstream's Go switches case for case.
  - Reconciliation follows evidence, not hopeful naming: `ported` requires a
    spec that asserts upstream behavior, `partial` means some assertions exist
    with known gaps, `in_progress` means the implementation exists but nothing
    asserts it yet, and `intentional_divergence` is a deliberate surface
    difference listed below.
  - Specs write into `./temp`, so two suites running at once collide on the same
    files (the `Source` command spec fails intermittently). Run gates serially;
    the adversarial signoff runs a nested `make test`.
- **Last commit:** `dc4a050` port: reconcile command.go ledger rows against
  evaluator.cr (working tree clean at that commit).
- **Ledger `missing` rows left (199), by file:** `token/token.go` 85,
  `style.go` 21, `ffmpeg.go` 16, `vhs.go` 13, `parser/parser.go` 12,
  `draw.go` 11, `video.go` 6, `error.go` 5, `testing.go` 5, `themes.go` 4,
  `lexer/lexer.go` 3, `screenshot.go` 3, `evaluator.go` 2, `record.go` 1,
  `shell.go` 1, `publish.go` 1, `syntax.go` 1, plus the 9 test IDs.
- **Gates:** `make lint` pass (21 files); `make test` `90 examples, 0 failures`;
  `make inventory` pass (strict refs; 231 items tracked, 248 ledger rows: 11
  `ported`, 14 `partial`, 23 `in_progress`, 199 `missing`, 1
  `intentional_divergence`); `verify_parity_adversarial.sh . vendor/vhs go
  'make test' 'go test ./...'` pass; `check_kind_vocabulary.py --scan
  go=vendor/vhs` no drops.

Keep this block accurate after every feature: the next session reads it first
(see `AGENTS.md` → **How to resume**).

## Phase 1 — Ledger truth

- [x] Reconcile `command.go` rows (41) against `src/vhs/evaluator.cr`
- [ ] Reconcile `style.go` constants (21) against `src/vhs/evaluator.cr`
- [ ] Reconcile `error.go` (5) — port `LineNumber`, `Underline`,
      `ErrorColumnOffset`, error printing
- [ ] Reconcile `evaluator.go` (2) — `Evaluate` signature, `EvaluatorOption`
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

- `WaitTick` (upstream `10 * time.Millisecond`): the port inlines
  `10.milliseconds` in `Vhs::Evaluator.execute_wait` instead of exporting a
  constant, so the row is `intentional_divergence` rather than `partial`.
- `ScreenshotOptions#frame_capture?`: Crystal predicate naming for the upstream
  `FrameCapture` field; behavior is identical.
- `src/vhs/evaluator.cr` keeps upstream's flat command dispatch (high cyclomatic
  complexity) instead of splitting into helpers, so divergence from
  `vendor/vhs/command.go` stays visible. Ameba excludes that file for the rule.
- `shard.override.yml` redirects the `terminfo` dependency to a fork; the pinned
  upstream repository no longer exists.
