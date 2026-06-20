#!/usr/bin/env bash
set -euo pipefail

system="${1:-${NIX_SYSTEM:-x86_64-linux}}"
package_set="${NIXCHIP_CI_PACKAGE_SET:-fast}"
repo_root="$(git rev-parse --show-toplevel)"
flake_ref="path:${repo_root}"

case "$package_set" in
  fast)
    packages=(
      chisel
      yosys-slang
      cacti6
      cacti7
      chipyard
      openroad-flow-scripts
      simulation-tools
      fpga-tools
    )
    ;;
  full)
    packages=(
      default
      hardware-tools
      simulation-tools
      fpga-tools
      asic-tools
    )
    ;;
  *)
    echo "unknown NIXCHIP_CI_PACKAGE_SET: $package_set" >&2
    exit 2
    ;;
esac

for package in "${packages[@]}"; do
  echo "::group::build packages.${system}.${package}"
  nix build "${flake_ref}#packages.${system}.${package}" --print-build-logs
  echo "::endgroup::"
done
