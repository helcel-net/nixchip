#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

packages=(
  chisel7
  chipyard1
  dramsim3-1
  hotspot7
  mcpat1
  openroad-flow-scripts26
  yosys-slang0
  systemc2
  systemc3
  vtr9
  eqy0
)

if [ "${NIXCHIP_UPDATE_HISTORICAL:-0}" = "1" ]; then
  packages+=(
    cacti6
    cacti7
    verilator3
    verilator4
  )
fi

# Per-package extra flags for nix-update.
# Most important use: --version-regex to keep a package on a major version series.
declare -A package_extra_flags=(
  ["systemc2"]="--version-regex=^(2\\.[0-9.]+[a-z]?)$"
  ["systemc3"]="--version-regex=^(3\\.[0-9.]+)$"
  ["vtr9"]="--version-regex=^v?(9\\.[0-9.]+)$"
  ["yosys-slang0"]="--version=unstable"
)

failed=()

for package in "${packages[@]}"; do
  echo "::group::nix-update $package"
  extra_flags="${package_extra_flags[$package]:-}"
  # shellcheck disable=SC2086
  if nix run nixpkgs#nix-update -- -F "$package" $extra_flags --build --system "${NIX_SYSTEM:-x86_64-linux}"; then
    echo "updated $package"
  else
    failed+=("$package")
    echo "failed to update $package" >&2
  fi
  echo "::endgroup::"
done

if [ "${#failed[@]}" -ne 0 ]; then
  printf 'package update failures:' >&2
  printf ' %s' "${failed[@]}" >&2
  printf '\n' >&2
  exit 1
fi
