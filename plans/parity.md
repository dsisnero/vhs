# Parity Plan — VHS Crystal

Curated feature roadmap for the Go → Crystal port. The generated manifests live
in `plans/inventory/`; per-symbol state belongs in
`plans/inventory/go_port_inventory.tsv`. Repo rules (gates, definition of done,
commit format) live in [`AGENTS.md`](../AGENTS.md) — this file tracks *where we
are*, not *how the repo works*.

## Where we are

- **Current focus:** the `VHS` lifecycle and the testing helpers are now
  asserted rather than inferred: `Buffer`, `CurrentLine` (reads the cursor's row
  instead of the last line), `SaveOutput` (create-once + append + 80-column
  separator), `Record` (frames appear, pause stops them, resume continues), and
  `Start`. `VHS` and `Setup` are recorded as intentional divergences because
  their upstream surface is browser/rod-specific.
- **Next up:**
  1. The single remaining `partial` row is `Evaluate`: upstream starts recording
     after the settings/output header and fast-forwards an initial `Hide` before
     the first captured frame, while the port starts capture inside `Start`.
     Closing it means splitting `Start` (terminal only) from a recording start
     after the header.
  2. Port `serve.go`/`tty.go`/`man.go` (not in the regex ledger; add them as a
     reviewed discovery change).
  3. Consider the tree-sitter ID migration (378 items) as its own reviewed
     branch once the curated ledger is fully green.
- **Status by area:**
  - Token: all 85 `token/token.go` rows `ported` and `token_test.go::TestToCamel`
    ported — the spec carries the full 77-constant table, the 58-entry keyword
    table, and exact IsSetting/IsCommand/IsModifier membership sets.
  - Lexer: all 3 `lexer/lexer.go` rows `ported` and both upstream lexer tests
    ported — `spec/vhs/lexer_spec.cr` now replays the 81-expectation
    `TestNextToken` tape and the 199-expectation `all.tape` fixture table
    (checked in as `spec/fixtures/all.tape`).
  - Command execution: `Vhs.execute` wraps failures like upstream (keeping the
    original as the exception cause), flushes the test output after each
    successful command while recording, and falls back to a temp file when the
    test output directory cannot be created. Copy/Paste use a process-local
    clipboard instead of the OS one.
  - Input synthesis: `src/vhs/input.cr` owns the key→sequence mapping for
    `Type`, plain keys, Alt, Ctrl, and Shift; the tape-level divergence is that
    upstream types through the browser's keyboard while the headless port writes
    the equivalent bytes to the emulator (asserted in `spec/vhs/input_spec.cr`).
  - Command echo: `src/vhs/highlight.cr` ports `syntax.go::Highlight` (per-token
    option/argument styles, ENV `=`, faint hidden commands, elided source
    prefix) with ANSI codes standing in for lipgloss, and the evaluator prints
    through it like upstream (header in colour, hidden/ignored commands faint).
  - Parser: all 12 `parser/parser.go` rows reconciled (`CommandType` is an
    `intentional_divergence` because upstream's type is deadcode) and all six
    upstream parser tests ported — `spec/vhs/parser_spec.cr` replays the
    23-command `TestParser` table, the four `TestParserErrors` strings with
    upstream line numbers, the six `TestParseCtrl` cases, the five
    `TestParseSource` and two `TestParseScreenshot` cases, and the full
    75-command `TestParseTapeFile` table (the old spot-check is gone).
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
  - Renderers: complete for the port's architecture. `draw.go` lives in
    `src/vhs/draw.cr` (pixel-level specs), the ffmpeg builders and command
    assembly in `src/vhs/ffmpeg_builder.cr` (argument-level specs for every
    stage and format), and `ffmpeg_renderer.cr` only spawns the commands.
    `png_renderer.cr` renders both frame layers (text + cursor) and has spec
    coverage. An end-to-end tape renders a correct 400x200 GIF.
  - Durations: `Vhs.parse_duration` implements Go's `time.ParseDuration` grammar
    (ns/us/µs/ms/s/m/h, fractions, multi-component, signs) and is the single path
    for `Sleep`, `Wait`, `Set TypingSpeed`, and `Set WaitTimeout`; the three
    hand-rolled parsers it replaced rejected `1m` and treated unitless numbers as
    milliseconds.
  - Frame capture: a tape's capture fiber is now always stopped (an `ensure`
    covers every early return). Before this, a tape with an invalid setting left
    its fiber rendering forever, which starved later tapes into "no frames" and
    tripled suite time. PNG rendering is still the capture bottleneck: a busy
    24x80 screen takes ~450ms per frame, so real tapes capture well below the
    configured framerate (font resolution and font loading are cached now).
  - Style plumbing: upstream shares one `*StyleOptions` between `Options`,
    `Video`, and `Screenshot`; Crystal structs copy, so every `SET` that touches
    the style goes through `Vhs.update_style`, which writes all three copies
    (asserted in `spec/vhs/evaluator_spec.cr`).
  - VHS lifecycle: `Start`, `Record`, `ApplyLoopOffset`, and `Cleanup` are
    `ported` with specs (frames appear after start, pause/resume is honoured,
    loop offsets rename frames, cleanup removes the directories). `Setup` and
    the `VHS` struct are `intentional_divergence` (browser/rod surface), and
    `Render` is `partial` because no spec runs ffmpeg itself.
  - Testing helpers: all four `testing.go` rows are `ported` — `Buffer` and
    `CurrentLine` read the emulator's cursor row, and `SaveOutput` creates the
    file once, appends later calls, and writes the 80-character separator.
  - Record / screenshot / themes: upstream tests ported (8 `ported` test rows);
    screenshots are now deferred like upstream — `Screenshot` arms the next
    frame and `FFmpegRenderer.screenshot_commands` renders it.
  - CLI: file + flags (`-o`, `-q`, `-p`, `-v`, `-h`, stdin) are ported;
    `vhs record` and `vhs publish` are documented intentional divergences
    (README "Differences from Go VHS"). `serve`/`tty`/`man` are not ported and
    not yet in the ledger.
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
  - `crystal tool format` re-escapes heredoc contents: generating the upstream
    lexer tape with `<<-TAPE` (escape-processing) turned `/foo\/bar/` into
    `/foo/bar/` and silently changed the test input. Use `<<-'TAPE'` for input
    that must stay byte-identical, and re-check the content after formatting.
  - Specs write into `./temp`, so two suites running at once collide on the same
    files (the `Source` command spec fails intermittently). Run gates serially;
    the adversarial signoff runs a nested `make test`.
- **Last commit:** `c63caf5` port: assert sleep/wait/render and reclassify the
  StyleOptions divergence (working tree clean at that commit).
- **Ledger `missing` rows left: none, and no `in_progress` rows either.** 248
  rows: 237 `ported`, 1 `partial` (`Evaluate`'s recording order), 10
  `intentional_divergence`. No test IDs are `missing`.
- **Gates:** `make lint` pass (37 files); `make test` `222 examples, 0
  failures`; `make inventory` pass (strict refs; 231 items tracked, 248 ledger
  rows: 237 `ported`, 1 `partial`, 0 `in_progress`, 0 `missing`, 10
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
- [x] Reconcile `lexer/lexer.go` (3) and port both upstream lexer tests
- [x] Reconcile `parser/parser.go` (12) and port its six upstream tests
- [x] Reconcile `vhs.go` (13), `themes.go` (4), `screenshot.go` (3),
      `testing.go` (5), `record.go`, `shell.go` rows against the port's actual
      surface (the three `VHS` lifecycle methods stay `missing`)
- [x] Reconcile `draw.go` (11) by porting it to `src/vhs/draw.cr` (8 ported, 3
      intentional divergences for Go's image.Image interface artifacts)
- [x] Reconcile `ffmpeg.go` (16), `video.go` (6), `screenshot.go::MakeScreenshots`
      and wire the renderer end to end (two-stream capture, render in
      `Vhs.evaluate`, style propagation to the renderers)
- [ ] Regenerate `go_source_parity.tsv` and confirm `make inventory`

## Phase 2 — Upstream tests still unmapped

- [x] `lexer/lexer_test.go::TestNextToken`, `TestLexTapeFile`
- [x] `parser/parser_test.go` (`TestParser`, `TestParserErrors`,
      `TestParseCtrl`, `TestParseScreeenshot`, `TestParseSource`,
      `TestParseTapeFile`)
- [x] `token/token_test.go::TestToCamel`

## Phase 3 — Renderer parity

- [x] Port `draw.go` — border-radius mask, window bar (Colorful/Rings, mirrored),
      hex color parsing
- [x] Port `ffmpeg.go` `FilterComplexBuilder` (window bar, border radius,
      margin fill, GIF)
- [x] Port `ffmpeg.go` `StreamBuilder` (margin, bar, corner, mp4, webm)
- [x] Port `ffmpeg.go::calcTermDimensions` (asserted, no image fixture needed)
- [x] Reconcile `video.go` (6 rows) with `src/vhs/ffmpeg_builder.cr`
- [x] Wire the builders into `ffmpeg_renderer.cr` and switch the frame capture
      to text + cursor streams
- [x] Port `VHS#ApplyLoopOffset` and `VHS#Cleanup`; `VHS#Setup` is `partial`
      (frame-directory reset only)

## Phase 4 — CLI surfaces

- [x] `syntax.go` (`Highlight` + the evaluator's echo/warn/dimension checks)
- [x] `testing.go::DefaultTestOptions` (no `vhs test` command exists upstream)
- [x] `record.go` / `publish.go` recorded as intentional divergences and
      documented in the README
- [ ] `serve.go` / `tty.go` (server + tty handling, `serve_unix.go` first)
- [ ] `man.go`
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
- `vhs record` is not ported: upstream drives raw stdin through a PTY, and
  Crystal's standard library has no PTY allocator. `Vhs::Record.input_to_tape`
  (the recorder's pure core) is ported and covered by the three upstream tests.
- `vhs publish` is not ported: upstream uploads over SSH to `ghost.charm.sh`
  using keygen, go-app-paths, and known_hosts, all of which would be a new native
  dependency; the CLI reports publishing as unavailable.
- `Highlight` has no lipgloss: each upstream style becomes the 16-color ANSI code
  it resolves to, and `NoneStyle`/`KeywordStyle` (which have no attributes)
  become empty strings. `number?`/`time?` keep upstream's regexes, including
  `^[0-9]+m?s$` not matching a bare `1m`, and the source path is measured in
  characters instead of go-runewidth's display cells.
- `Output frames/`: upstream renames the temp frame directory to the raw
  argument (trailing slash), which fails silently, and the rename also fails
  across filesystems because the frame input lives in the system temp dir. The
  port trims the trailing slash so a same-filesystem output works; a
  cross-filesystem move still fails like upstream, since both ignore the error.
- `VHS#Cleanup`/`#Setup` retry directory removal: this checkout's exFAT volume
  creates and removes AppleDouble `._*` sidecars asynchronously, so a single
  `FileUtils.rm_rf` leaves entries behind.
- `Vhs.make_gif`/`make_mp4`/`make_webm` return the ffmpeg argument list (or nil)
  where upstream returns an `*exec.Cmd`; `FFmpegRenderer` spawns the process, and
  a failing invocation is logged rather than returned, matching upstream
  `Render`.
- `VHS#render` now runs inside `Vhs.evaluate` like upstream, so specs evaluate
  through `evaluate_without_render` (an `EvaluatorOption` that clears the outputs)
  to stay hermetic; the CLI path renders for real.
- `Draw::Circle`/`Rectangle`/`RoundedRectangle` expose `alpha_at`/`bounds`
  instead of Go's `image.Image` interface (`At`/`Bounds`/`ColorModel`), so the
  three `ColorModel` rows are `intentional_divergence`. The port composites the
  same masks directly rather than through `image/draw`, which is equivalent for
  these opaque sources and is asserted pixel-by-pixel.
- `Parser::Command#to_s` prints the args when `options` is empty, where
  upstream's `Command.String` formats two type/options fields and drops them
  (its empty-options branch is `fmt.Sprintf("%s %s", c.Type, c.Options)`).
  Everything else about the rendering matches, including the unconditional
  ToCamel of the token name.
- `Parser::CommandType` has no Crystal counterpart: upstream's `CommandTypes`
  list is deadcode and `Command.Type` is just `token.Type`, so the port keeps
  `Token::Type` and renders through `Token.to_camel`.
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
- `Vhs::Options.new` defaults `wait_pattern` to `/^$/` where Go's zero value is
  a nil regexp; only bare struct defaults are affected, and
  `Vhs.default_vhs_options` uses the upstream `/>$/` pattern.
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
