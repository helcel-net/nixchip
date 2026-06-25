#!/usr/bin/env bash
set -euo pipefail

system="${1:-${NIX_SYSTEM:-x86_64-linux}}"
package="${2:?usage: ci-build.sh <system> <package>}"

repo_root="$(git rev-parse --show-toplevel)"
flake_ref="path:${repo_root}"

echo "::group::build packages.${system}.${package}"
nix build "${flake_ref}#packages.${system}.${package}" --print-build-logs
echo "::endgroup::"
