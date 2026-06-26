#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

system="${NIX_SYSTEM:-x86_64-linux}"

# Auto-discover packages to update from the flake.
# Enrollment: add `passthru.nixchipUpdate = true;` to a package's own derivation file.
# The nix expression also emits a "branch" hint for packages whose version string
# contains "unstable" (e.g. "0-unstable-2026-06-23"), so that get_version_flags
# does not incorrectly assign a version-series regex to branch-tracking packages.
raw_lines=()
readarray -t raw_lines < <(
  nix eval --raw ".#packages.${system}" --apply '
    pkgs:
    let
      allNames = builtins.attrNames pkgs;
      names = builtins.filter (n:
        let p = pkgs.${n}; in
        p ? passthru && p.passthru ? nixchipUpdate && p.passthru.nixchipUpdate
      ) allNames;
      byFamily = builtins.groupBy (n: pkgs.${n}.pname or n) names;
      slotRev = n: builtins.match ".*-[0-9]+$"  n != null;
      hasVer  = n: builtins.match ".*[0-9]$"    n != null;
      isUnstable = n: builtins.match ".*unstable.*" (pkgs.${n}.version or "") != null;
      pickBest = ns:
        let branch = builtins.filter isUnstable ns;
            slot = builtins.filter slotRev ns;
            vers = builtins.filter hasVer  ns;
        in if branch != [] then builtins.head branch
           else if slot != [] then builtins.head slot
           else if vers != [] then builtins.head vers
           else builtins.head ns;
      unique = builtins.map pickBest (builtins.attrValues byFamily);
      versionHint = n: if isUnstable n then "branch" else "";
      nixchipFlags = n: builtins.concatStringsSep " " (pkgs.${n}.passthru.nixchipUpdateFlags or []);
      line = n: "${n}\t${versionHint n}\t${nixchipFlags n}";
    in
    builtins.concatStringsSep "\n" (builtins.sort builtins.lessThan (builtins.map line unique))
  '
)

[[ ${#raw_lines[@]} -gt 0 ]] || { echo "error: package discovery returned 0 packages — check the flake for evaluation errors" >&2; exit 1; }

packages=()
declare -A version_hints
declare -A nixchip_flags
for entry in "${raw_lines[@]}"; do
  IFS=$'\t' read -r pkg hint flags <<< "$entry"
  packages+=("$pkg")
  [[ -n "$hint" ]] && version_hints["$pkg"]="$hint"
  [[ -n "$flags" ]] && nixchip_flags["$pkg"]="$flags"
done

# Extract the version series from a package name:
#   "dramsim3-1"           → "1"   (trailing -N is the version major)
#   "ghdl6"                → "6"   (trailing digits in the name)
#   "openroad-flow-scripts"→ ""    (no trailing digits → branch tracking)
pkg_major() {
  local pkg="$1"
  if [[ "$pkg" =~ -([0-9]+)$ ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo "${pkg##*[^0-9]}"
  fi
}

# Emit nix-update version flags for a package.
#
# Packages with a trailing version number N get:
#   --version-regex=^v?(N[Q._][0-9.]+[a-z]?)$
# Covers semver (6.1.2), quarterly (26Q1), underscore (13_0), letter suffix (2.3.4a).
#
# Packages without a version number fall back to --version=branch.
get_version_flags() {
  local pkg="$1"
  local major
  major="$(pkg_major "$pkg")"
  if [[ -z "$major" ]]; then
    echo "--version=branch"
  else
    echo "--version-regex=^v?(${major}[Q._][0-9.]+[a-z]?)$"
  fi
}


verify_branch_head() {
  local package="$1"
  local info owner repo rev version remote

  info="$(nix eval --raw ".#packages.${system}.${package}" --apply '
    p: "${p.src.owner or ""}\t${p.src.repo or ""}\t${p.src.rev or ""}\t${p.version or ""}"
  ')"
  IFS=$'\t' read -r owner repo rev version <<< "$info"

  if [[ -z "$owner" || -z "$repo" || -z "$rev" ]]; then
    echo "warning: cannot verify branch HEAD for $package; src owner/repo/rev unavailable" >&2
    return 0
  fi

  if [[ ! "$version" =~ ^([0-9]+-)?unstable-[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "error: $package branch version '$version' should look like unstable-YYYY-MM-DD or N-unstable-YYYY-MM-DD" >&2
    return 1
  fi

  remote="$(git ls-remote "https://github.com/${owner}/${repo}.git" HEAD | awk '{print $1}')"
  if [[ -z "$remote" ]]; then
    echo "error: failed to resolve upstream HEAD for $package (${owner}/${repo})" >&2
    return 1
  fi

  if [[ "$rev" != "$remote" ]]; then
    echo "error: $package is not at upstream HEAD after update" >&2
    echo "  current: $rev" >&2
    echo "  upstream: $remote" >&2
    return 1
  fi
}

build_flag=()
if [ "${NIXCHIP_UPDATE_BUILD:-0}" = "1" ]; then
  build_flag=(--build --system "${system}")
fi

failed=()

for package in "${packages[@]}"; do
  echo "::group::nix-update $package"
  extra_flags="${nixchip_flags[$package]:-}"
  if [[ " $extra_flags " != *" --version"* ]]; then
    if [[ -v "version_hints[$package]" ]] && [[ "${version_hints[$package]}" == "branch" ]]; then
      extra_flags+=" --version=branch"
    else
      extra_flags+=" $(get_version_flags "$package")"
    fi
  fi
  branch_update=false
  if [[ " $extra_flags " == *" --version=branch "* ]]; then
    branch_update=true
  fi
  # shellcheck disable=SC2086
  if nix run nixpkgs#nix-update -- -F "$package" $extra_flags "${build_flag[@]}"; then
    if [[ "$branch_update" == true ]]; then
      verify_branch_head "$package"
    fi
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
