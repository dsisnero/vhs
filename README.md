# VHS Crystal

Crystal port of the [charmbracelet/vhs](https://github.com/charmbracelet/vhs) Go library
for writing terminal GIFs as code.

VHS creates terminal GIFs and videos for integration testing, demos,
and documentation via simple tape files.

> **Note**: This is a work-in-progress port. The Go implementation in the
> `vendor/vhs` submodule is the authoritative source. This Crystal library
> aims to provide API parity and produce identical output.

## Installation

Add this shard to your `shard.yml`:

```yaml
dependencies:
  vhs:
    github: dsisnero/vhs
```

Then run `shards install`.

For command-line usage, build the binary:

```bash
make build
```

The `vhs` executable will be placed in `bin/`.

## Usage

Create a `.tape` file:

```elixir
Output demo.gif
Set FontSize 16
Set Width 800
Set Height 600

Type "echo 'Hello from Crystal VHS!'"
Sleep 500ms
Enter
Sleep 2s
```

Run it:

```bash
vhs demo.tape
```

This generates `demo.gif` with the terminal session.

See the [VHS Command Reference](vendor/vhs/README.md#vhs-command-reference)
for all available commands.

### Differences from Go VHS

The runtime is the same as upstream's: `ttyd` serves xterm.js, the
[Rod](https://github.com/dsisnero/rod) Crystal port drives a headless Chromium
browser, and each frame is the xterm.js text and cursor canvas captured as PNG.
ffmpeg then applies the same filter chain Go VHS uses (window bar, border
radius, margin fill, palette for GIF). Echoed commands and error output go
through the same lipgloss styles as upstream (`src/vhs/styles.cr`), so the
colours follow the terminal's detected colour profile (`NO_COLOR`, `COLORTERM`,
`TERM`).

Runtime requirements therefore match upstream: a Chromium-family browser and
`ttyd` on `PATH`. Browser-backed specs are opt-in with `VHS_SPEC_BROWSER=1` so
the default `make test` stays dependency-free.

Two CLI surfaces are intentionally not implemented:

* `vhs record` needs a PTY and raw-terminal handling that Crystal's standard
  library does not provide. The tape-conversion core (`Vhs::Record.input_to_tape`)
  is ported and tested.
* `vhs publish` uploads the GIF over SSH to `ghost.charm.sh`, which would require
  an SSH client dependency. The CLI reports publishing as unavailable.

## Development

This project follows the Go vhs implementation closely. The Go source lives
in the `vendor/vhs` git submodule and serves as the reference.

### Setup

1. Clone with submodules:

```bash
git clone --recurse-submodules https://github.com/dsisnero/vhs
```

2. Install dependencies:

* Crystal (>= 1.19.1)
* `ttyd` and `ffmpeg` (required by VHS, see [vendor README](vendor/vhs/README.md#installation))

### Building

```bash
make build
```

### Testing

```bash
make test
```

### Code Quality

```bash
make lint
```

Run `make help` for all available targets.

## Documentation

| File | Purpose |
| --- | --- |
| [Resuming work](docs/resuming.md) | Start here in a new session: plan, gates, and checkout quirks |
| [Architecture](docs/architecture.md) | Runtime layout, upstream boundaries, and rendering pipeline |
| [Development](docs/development.md) | Local setup, upstream pin, parity tooling, and checkout quirks |
| [Coding Guidelines](docs/coding-guidelines.md) | Crystal style, parity expectations, and file rules |
| [Testing](docs/testing.md) | Spec organization, gates, and parity validation |
| [PR Workflow](docs/pr-workflow.md) | Beads workflow, branch hygiene, and landing requirements |

Current port status and the ordered backlog live in
[`plans/parity.md`](plans/parity.md).

## Contributing

1. Fork it (<https://github.com/dsisnero/vhs/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

* [Dominic Sisneros](https://github.com/dsisnero) — creator and maintainer
