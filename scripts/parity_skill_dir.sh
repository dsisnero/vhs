#!/usr/bin/env bash
# Resolve the installed cross-language-crystal-parity skill directory.
#
# The repository never vendors the parity implementation. Every wrapper under
# scripts/ forwards to the installed skill so a skill update takes effect
# immediately. Set PARITY_SKILL_DIR to override the search order.
set -euo pipefail

parity_skill_candidates() {
  if [[ -n "${PARITY_SKILL_DIR:-}" ]]; then
    printf '%s\n' "${PARITY_SKILL_DIR}"
  fi
  printf '%s\n' "${HOME}/.agents/skills/crystal_forge/skills/cross-language-crystal-parity"
  printf '%s\n' "${HOME}/.agents/skills/cross-language-crystal-parity"
  printf '%s\n' "${HOME}/.config/opencode/skills/cross-language-crystal-parity"
}

# Print the first candidate that carries the canonical inventory library.
resolve_parity_skill_dir() {
  local dir
  while IFS= read -r dir; do
    if [[ -n "${dir}" && -f "${dir}/scripts/parity_inventory_lib.rb" ]]; then
      printf '%s\n' "${dir}"
      return 0
    fi
  done < <(parity_skill_candidates)

  echo "cross-language-crystal-parity skill not found." >&2
  echo "Install it or set PARITY_SKILL_DIR to its directory." >&2
  return 1
}
