.PHONY: install update format lint test markdown markdown-check inventory sidecars clean build help

# The parser mode is the one the curated ledger was generated with. Changing it
# changes manifest IDs, so it is a migration (see AGENTS.md -> Parity tooling).
PARITY_LANGUAGE ?= go
PARITY_PARSER ?= regex
PARITY_SOURCE ?= vendor/vhs

GATE_PATHS := src spec $(wildcard bin)

install:
	BEADS_DIR=$$(pwd)/.beads shards install

update:
	BEADS_DIR=$$(pwd)/.beads shards update

# This checkout lives on an exFAT volume, so macOS drops AppleDouble `._*`
# sidecars next to every file. They break `crystal spec` discovery and make git
# report "non-monotonic index" errors, so strip them before every gate.
sidecars:
	@find . -name '._*' -delete 2>/dev/null || true

format: sidecars
	CRYSTAL_CACHE_DIR=$(PWD)/.crystal-cache crystal tool format --check $(GATE_PATHS)

lint: sidecars
	CRYSTAL_CACHE_DIR=$(PWD)/.crystal-cache ameba --fix src spec
	CRYSTAL_CACHE_DIR=$(PWD)/.crystal-cache ameba src spec

test: sidecars
	CRYSTAL_CACHE_DIR=$(PWD)/.crystal-cache crystal spec

inventory: sidecars
	scripts/check_parity.sh . $(PARITY_SOURCE) $(PARITY_LANGUAGE) $(PARITY_PARSER)

markdown:
	rumdl fmt README.md docs plans

markdown-check:
	rumdl check README.md docs plans

clean:
	rm -rf ./temp/*
	mkdir -p ./temp

build:
	mkdir -p bin
	CRYSTAL_CACHE_DIR=$(PWD)/.crystal-cache crystal build src/vhs.cr -o bin/vhs
	CRYSTAL_CACHE_DIR=$(PWD)/.crystal-cache crystal build src/vhs_record_shell.cr -o bin/vhs-record-shell

help:
	@echo "Available targets:"
	@echo "  install        - Install shard dependencies"
	@echo "  update         - Update shard dependencies"
	@echo "  build          - Build vhs and vhs-record-shell binaries to bin/"
	@echo "  test           - Run specs"
	@echo "  format         - Check code formatting"
	@echo "  lint           - Run linter (ameba)"
	@echo "  inventory      - Validate parity manifests against $(PARITY_SOURCE)"
	@echo "  markdown       - Format markdown files"
	@echo "  markdown-check - Check markdown formatting"
	@echo "  clean          - Remove temp artifacts"
	@echo "  sidecars       - Strip macOS AppleDouble ._* files"
	@echo "  help           - Show this help"
