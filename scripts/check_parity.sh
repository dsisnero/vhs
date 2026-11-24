#!/usr/bin/env bash
# Parity gate: verify the installed skill, then check all three manifests.
#
# Usage:
#   scripts/check_parity.sh [ROOT_DIR] [SOURCE_PATH] [LANGUAGE] [PARSER]
#
# Defaults: root=<cwd>, source=vendor/vhs, language=go, parser=$PORT_PARSER or
# regex. The parser mode must match the mode recorded in AGENTS.md; switching it
# changes the curated IDs and is a migration, not a configuration tweak.
set -euo pipefail

ROOT_DIR="${1:-$(pwd)}"
SOURCE_PATH="${2:-vendor/vhs}"
LANGUAGE="${3:-go}"
PARSER="${4:-${PORT_PARSER:-regex}}"

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/parity_skill_dir.sh"
SKILL_DIR="$(resolve_parity_skill_dir)"

INVENTORY_DIR="${ROOT_DIR}/plans/inventory"

"${SKILL_DIR}/scripts/verify_skill_install.sh" "${ROOT_DIR}" "${LANGUAGE}" "${PARSER}"

export PORT_PARSER="${PARSER}"

"${SCRIPT_DIR}/check_port_inventory.sh" \
  "${ROOT_DIR}" "${INVENTORY_DIR}/${LANGUAGE}_port_inventory.tsv" "${SOURCE_PATH}" "${LANGUAGE}"
"${SCRIPT_DIR}/check_source_parity.sh" \
  "${ROOT_DIR}" "${INVENTORY_DIR}/${LANGUAGE}_source_parity.tsv" "${SOURCE_PATH}" "${LANGUAGE}"
"${SCRIPT_DIR}/check_test_parity.sh" \
  "${ROOT_DIR}" "${INVENTORY_DIR}/${LANGUAGE}_test_parity.tsv" "${SOURCE_PATH}" "${LANGUAGE}"

echo "Parity gate passed (language=${LANGUAGE}, parser=${PARSER})."
