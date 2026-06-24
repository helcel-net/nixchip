#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

packages=(
  chisel7
  chipyard1
  dramsim3-1
  ghdl6
  hotspot7
  iverilog13
  klayout0
  magic-vlsi8
  mcpat1
  openroad26
  openroad-flow-scripts26
  systemc2
  systemc3
  vtr9
  eqy0
  yosys0
  yosys-slang0
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
  ["ghdl6"]="--version-regex=^(6\\.[0-9.]+)$"
  ["iverilog13"]="--version-regex=^(13\\.[0-9.]+)$"
  ["klayout0"]="--version-regex=^(0\\.[0-9.]+)$"
  ["magic-vlsi8"]="--version-regex=^(8\\.[0-9.]+)$"
  ["openroad26"]="--version-regex=^(26Q[0-9]+)$"
  ["openroad-flow-scripts26"]="--version-regex=^(26Q[0-9]+)$"
  ["systemc2"]="--version-regex=^(2\\.[0-9.]+[a-z]?)$"
  ["systemc3"]="--version-regex=^(3\\.[0-9.]+)$"
  ["vtr9"]="--version-regex=^v?(9\\.[0-9.]+)$"
  ["yosys0"]="--version-regex=^(0\\.[0-9.]+)$"
)

build_flag=()
if [ "${NIXCHIP_UPDATE_BUILD:-0}" = "1" ]; then
  build_flag=(--build --system "${NIX_SYSTEM:-x86_64-linux}")
fi

failed=()

for package in "${packages[@]}"; do
  echo "::group::nix-update $package"
  extra_flags="${package_extra_flags[$package]:-}"
  # shellcheck disable=SC2086
  if nix run nixpkgs#nix-update -- -F "$package" $extra_flags "${build_flag[@]}"; then
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
