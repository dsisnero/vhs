require "baked_file_system"

module Vhs
  # Assets is the port's embedded data: the files upstream bakes into the binary
  # with `//go:embed` — `themes.json` (themes.go) and `examples/demo.tape`
  # (embed.go).
  #
  # They live under `src/vhs/assets/` and are baked at compile time, so a shard
  # dependency or a distributed binary carries them. Before this, themes were
  # read from `vendor/vhs/themes.json` at runtime, which only worked inside this
  # checkout: an installed shard silently had no themes at all, so `Set Theme`
  # reported every theme as missing and `vhs themes` printed nothing.
  class Assets
    extend BakedFileSystem

    bake_folder "./assets"
  end
end
