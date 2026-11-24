#!/usr/bin/env bash
# Thin forwarding wrapper. The implementation lives in the installed
# cross-language-crystal-parity skill; see scripts/parity_skill_dir.sh.
set -euo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/parity_skill_dir.sh"

exec "$(resolve_parity_skill_dir)/scripts/generate_test_parity_manifest.sh" "$@"
