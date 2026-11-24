# Parity Plan — VHS Crystal

Curated feature roadmap for the Go → Crystal port. The generated manifests live
in `plans/inventory/`; per-symbol state belongs in
`plans/inventory/go_port_inventory.tsv`. Repo rules (gates, definition of done,
commit format) live in [`AGENTS.md`](../AGENTS.md) — this file tracks *where we
are*, not *how the repo works*.

## Where we are

- **Current focus:** finish reconciling the curated ledger with the code already
  in `src/`. `command.go`, `style.go`, `error.go`, `evaluator.go` and
  `token/token.go` (85 rows + `TestToCamel`) are reconciled. Next is
  `parser/parser.go` (12) and `lexer/lexer.go` (3), where the code exists and
  only ledger work plus the six `parser_test.go`/two `lexer_test.go` IDs remain.
- **Next up:**
  1. Reconcile `parser/parser.go` (12) and `lexer/lexer.go` (3) rows, then map
     their upstream tests: `parser_test.go` (`TestParser`, `TestParserErrors`,
     `TestParseCtrl`, `TestParseScreeenshot`, `TestParseSource`,
     `TestParseTapeFile`) and `lexer_test.go` (`TestNextToken`,
     `TestLexTapeFile`).
  2. Reconcile the remaining source rows: `vhs.go` (13), `draw.go` (11),
     `video.go` (6), `testing.go` (5), `themes.go` (4), `screenshot.go` (3),
     `record.go` (1), `shell.go` (1).
  3. Port `ffmpeg.go`'s filter/stream builders (16 rows) — today
     `src/vhs/ffmpeg_renderer.cr` builds ffmpeg arguments ad hoc and has no
     spec coverage.
  4. Port the remaining CLI surfaces: `publish.go`, `serve.go`, `tty.go`,
     `syntax.go`, `testing.go`, `man.go`.
- **Status by area:**
  - Token: all 85 `token/token.go` rows `ported` and `token_test.go::TestToCamel`
    ported — the spec carries the full 77-constant table, the 58-entry keyword
    table, and exact IsSetting/IsCommand/IsModifier membership sets.
  - Lexer / parser: implemented in `src/vhs/{lexer,parser}.cr` with specs;
    ledger rows still `missing` (15 source rows + 8 test IDs).
  - Evaluate entrypoint: `EvaluatorOption` is `ported` (alias applied after
    stop, asserted by three specs); `Evaluate` itself is `partial` because the
    SET/OUTPUT/REQUIRE highlight print, dimension validation, and the render
    call are still missing. The unreachable duplicate `VHS#evaluate` (it
    re-implemented the same flow with different error handling and was the only
    caller of `VHS#render`) was deleted.
  - Errors / evaluate entrypoint: all 5 `error.go` rows `ported` in
    `src/vhs/error.cr` (moved out of `evaluator.cr` to mirror upstream's file
    layout): `InvalidSyntaxError`, `ERROR_COLUMN_OFFSET`, `underline`,
    `line_number`, and the `print_error`/`print_errors` gutter + caret renderer,
    all pinned by `spec/vhs/error_spec.cr`. `EvaluatorOption` is still absent.
  - Command dispatch / evaluator: all 41 `command.go` rows reconciled — 3
    `ported`, 14 `partial`, 23 `in_progress`, 1 `intentional_divergence`. Only
    Set Theme has upstream-asserted behavior; the rest record implementation
    presence and name the missing assertions.
  - Style / theme colors: all 21 `style.go` rows reconciled — 20 `ported`
    (19 hex constants + `DefaultStyleOptions`, pinned by
    `spec/vhs/style_spec.cr`), 1 `partial` (`StyleOptions`: fields match
    upstream, but a bare `StyleOptions.new` defaults to the
    `DefaultStyleOptions` numbers where a Go zero value is `0`/`""`). The
    file's lipgloss style vars (`CommandStyle`, `ErrorStyle`, `ErrorFileStyle`,
    `LineNumberStyle`, …) are not in the ledger's kind vocabulary and are not
    ported as styles: `ErrorStyle`/`LineNumberStyle` became the ANSI constants in
    `src/vhs/error.cr`, and the rest still land with `syntax.go`/`highlight`.
  - Renderers: `png_renderer.cr` has spec coverage; `ffmpeg_renderer.cr` is
    unverified and does not mirror upstream's builders.
  - Record / screenshot / themes: upstream tests ported (8 `ported` test rows).
  - CLI, publish, serve, tty, man: not ported.
- **Scoping notes / gotchas:**
  - The ledger is a **regex** ledger. `PARITY_PARSER=tree-sitter` works here
    (toolchain `v0.3.4` is installed) but discovers 378 Go items instead of 248
    because it reports native kinds (`function`, `class`, `interface`). Treat a
    parser switch as a reviewed ID migration, not a config change.
  - Run the adversarial signoff as `PORT_PARSER=regex
    verify_parity_adversarial.sh . vendor/vhs go 'make test' 'go test ./...'`.
    Without `PORT_PARSER=regex` the script's `auto` mode probes tree-sitter and
    fails with ~130 "source items missing from inventory" lines, which is the
    parser mismatch above, not ledger debt.
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
- **Last commit:** `c8341a2` port: reconcile token/token.go and drop the
  non-upstream Home keyword (working tree clean at that commit).
- **Ledger `missing` rows left (85), by file:** `ffmpeg.go` 16, `vhs.go` 13,
  `parser/parser.go` 12, `draw.go` 11, `video.go` 6, `testing.go` 5,
  `themes.go` 4, `screenshot.go` 3, `lexer/lexer.go` 3, `record.go` 1,
  `shell.go` 1, `publish.go` 1, `syntax.go` 1, plus the 8 remaining test IDs.
- **Gates:** `make lint` pass (24 files); `make test` `113 examples, 0
  failures`; `make inventory` pass (strict refs; 231 items tracked, 248 ledger
  rows: 123 `ported`, 16 `partial`, 23 `in_progress`, 85 `missing`, 1
  `intentional_divergence`); `PORT_PARSER=regex verify_parity_adversarial.sh .
  vendor/vhs go 'make test' 'go test ./...'` pass; `check_kind_vocabulary.py
  --scan go=vendor/vhs` no drops.

Keep this block accurate after every feature: the next session reads it first
(see `AGENTS.md` → **How to resume**).

## Phase 1 — Ledger truth

- [x] Reconcile `command.go` rows (41) against `src/vhs/evaluator.cr`
- [x] Reconcile `style.go` constants (21) against `src/vhs/evaluator.cr` and pin
      them with `spec/vhs/style_spec.cr`
- [x] Reconcile `error.go` (5) — port `LineNumber`, `Underline`,
      `ErrorColumnOffset`, `print_error`/`print_errors`, and wire the CLI to it
- [x] Reconcile `evaluator.go` (2) — port `EvaluatorOption`, accept options in
      `Vhs.evaluate`, drop the dead duplicate `VHS#evaluate`
- [x] Reconcile `token/token.go` (85) — full constant/keyword/classification
      tables in `spec/vhs/token_spec.cr`; dropped the non-upstream `Home`
      keyword
- [ ] Reconcile `parser/parser.go` (12), `lexer/lexer.go` (3) rows
- [ ] Reconcile `vhs.go` (13), `draw.go` (11), `themes.go` (4),
      `screenshot.go` (3), `record.go`, `shell.go` rows
- [ ] Regenerate `go_source_parity.tsv` and confirm `make inventory`

## Phase 2 — Upstream tests still unmapped

- [ ] `lexer/lexer_test.go::TestNextToken`, `TestLexTapeFile`
- [ ] `parser/parser_test.go` (`TestParser`, `TestParserErrors`,
      `TestParseCtrl`, `TestParseScreeenshot`, `TestParseSource`,
      `TestParseTapeFile`)
- [x] `token/token_test.go::TestToCamel`

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
- `InvalidSyntaxError#message`: Crystal spells Go's `Error()` method `message`,
  returning the same `parser: N error(s)` string.
- Error printing has no lipgloss: `ErrorStyle`/`LineNumberStyle` are emitted as
  the 16-color ANSI codes they resolve to (`31` / `90`) instead of negotiating a
  color profile with the terminal, so the bytes differ only in escape sequence.
- `Vhs::Token::Type` is a `Symbol` alias where upstream's `Type` is a string
  type. Values match one-for-one, so this shows up only in string construction
  and in `Type.String`, which becomes `Token.to_human_readable` because a Symbol
  cannot override `to_s`.
- The port's keyword table has no `Home` entry: upstream defines a `HOME` token
  (used by `record.go` and `IsCommand`) but never maps the bare word, so `Home`
  in a tape is a `STRING` identifier that the parser rejects — the Crystal table
  had added the mapping and now matches upstream.
- `Vhs.evaluate` needs two overloads (`evaluate(tape, output)` and
  `evaluate(tape, output, *opts : EvaluatorOption)`) because a Crystal typed
  splat parameter requires at least one argument; upstream's variadic call shape
  is otherwise preserved. `context.Context` has no Crystal counterpart and is
  omitted.
- `Vhs.print_error` guards the tape line lookup (`lines[line - 1]?`) where
  upstream panics on an out-of-range line number; the printed gutter is
  identical for valid lines.
- `Vhs::StyleOptions.new` initializes every field to the `DefaultStyleOptions`
  numbers (1200/600/60/30) with empty color strings, whereas Go's zero value is
  `0`/`""` for all fields. Only bare struct defaults are affected;
  `Vhs.default_vhs_options` / `default_video_options` /
  `default_style_options` set the upstream values explicitly, which is what
  `spec/vhs/style_spec.cr` asserts.
- `src/vhs/evaluator.cr` keeps upstream's flat command dispatch (high cyclomatic
  complexity) instead of splitting into helpers, so divergence from
  `vendor/vhs/command.go` stays visible. Ameba excludes that file for the rule.
- `shard.override.yml` redirects the `terminfo` dependency to a fork; the pinned
  upstream repository no longer exists.
