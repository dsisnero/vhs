# AGENTS.md - AI Coding Assistant Guide

This is a library that ports the golang <https://github.com/charmbracelet/vhs> library to Crystal.. The original golang libraries exist as submodules in ./vendor.

## Source of Truth

* **Go libraries and tests are the authoritative source** - The `vhs`submodule contain the reference implementation
* **Golden files must match Go output** - Test fixtures in submodule `testdata/` directories are canonical; our implementation must produce identical output
* **API parity is required** - Public APIs should match Go equivalents in behavior and semantics
* **When in doubt, consult Go source** - Check the Go implementation for edge cases, default values, and behavioral details

## Agent Behavior

### Core Workflow Principles

* **Use the shared cache**: export `CRYSTAL_CACHE_DIR=$PWD/.crystal-cache` for every `crystal` invocation
* **Clean artifacts** with `make clean` before recording logs or re-running flaky specs

### File Safety Protocol

* **NEVER INVENT FILE PATHS** - Always verify file existence before reading
* **ALWAYS USE DISCOVERY TOOLS FIRST** - Use `dir.list` to explore directories before file access
* **Use `grep` for file discovery** - Search for files by name or content before reading
* **Handle missing files gracefully** - Report missing files clearly rather than causing errors

* All tests must live under the `spec/` directory
* Every new or modified source file under `src/` must have corresponding specs
* Temporary files must be in ./temp directory. Dont use system temp or working directory

## Issue Tracking

This project uses **bd (beads)** for issue tracking.
Run `bd prime` for workflow context, or install hooks (`bd hooks install`) for auto-injection.

**Quick reference:**

* `bd ready` - Find unblocked work
* `bd create "Title" --type task --priority 2` - Create issue
* `bd close <id>` - Complete work
* `bd sync` - Sync with git (run at session end)
* `bd types` - Show available issue types

**Do not use internal tools to track progress** - We use beads (bd) for all issues, tasks, and todos.
Never use AI assistant's internal todo tracking tools. Do not use internal todo tool

For full workflow details: `bd prime`

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below.
Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
   * Safe commands on our code only (no git submodules, no `lib/`):
     * `crystal tool format src spec bin`
     * `ameba --fix src spec bin`
     * `ameba src spec bin` (gating)
     * `rumdl fmt src spec bin`
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:

   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```

5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**

* Work is NOT complete until `git push` succeeds
* NEVER stop before pushing - that leaves work stranded locally
* NEVER say "ready to push when you are" - YOU must push
* If push fails, resolve and retry until it succeeds
