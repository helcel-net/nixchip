#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

packages=(
  chisel7
  chipyard1
  openroad-flow-scripts26
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

failed=()

for package in "${packages[@]}"; do
  echo "::group::nix-update $package"
  if nix run nixpkgs#nix-update -- -F "$package" --build --system "${NIX_SYSTEM:-x86_64-linux}"; then
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
