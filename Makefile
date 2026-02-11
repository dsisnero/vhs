.PHONY: install update format lint test markdown markdown-check clean build help

install:
	BEADS_DIR=$$(pwd)/.beads shards install

update:
	BEADS_DIR=$$(pwd)/.beads shards update

format:
	CRYSTAL_CACHE_DIR=$(PWD)/.crystal-cache crystal tool format --check

lint:
	CRYSTAL_CACHE_DIR=$(PWD)/.crystal-cache ameba --fix
	CRYSTAL_CACHE_DIR=$(PWD)/.crystal-cache ameba

test:
	CRYSTAL_CACHE_DIR=$(PWD)/.crystal-cache crystal spec

markdown:
	rumdl fmt .

markdown-check:
	rumdl check . --check

clean:
	rm -rf temp/*

build:
	mkdir -p bin
	CRYSTAL_CACHE_DIR=$(PWD)/.crystal-cache crystal build src/vhs.cr -o bin/vhs

help:
	@echo "Available targets:"
	@echo "  install        - Install shard dependencies"
	@echo "  update         - Update shard dependencies"
	@echo "  build          - Build vhs binary to bin/"
	@echo "  test           - Run specs"
	@echo "  format         - Check code formatting"
	@echo "  lint           - Run linter (ameba)"
	@echo "  markdown       - Format markdown files"
	@echo "  markdown-check - Check markdown formatting"
	@echo "  clean          - Remove temp directory"
	@echo "  help           - Show this help"