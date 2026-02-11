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

## Development

This project follows the Go vhs implementation closely. The Go source lives
in the `vendor/vhs` git submodule and serves as the reference.

### Setup

1.  Clone with submodules:

```bash
git clone --recurse-submodules https://github.com/dsisnero/vhs
```

2.  Install dependencies:

*   Crystal (>= 1.19.1)
*   `ttyd` and `ffmpeg` (required by VHS, see [vendor README](vendor/vhs/README.md#installation))

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

## Contributing

1.  Fork it (<https://github.com/dsisnero/vhs/fork>)
2.  Create your feature branch (`git checkout -b my-new-feature`)
3.  Commit your changes (`git commit -am 'Add some feature'`)
4.  Push to the branch (`git push origin my-new-feature`)
5.  Create a new Pull Request

## Contributors

*   [Dominic Sisneros](https://github.com/dsisnero) — creator and maintainer
