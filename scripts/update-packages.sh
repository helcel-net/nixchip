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
_nix_unique='builtins.map pickBest (builtins.attrValues byFamily)'
[ "${NIXCHIP_UPDATE_HISTORICAL:-0}" = "1" ] && _nix_unique='names'

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
      matchingPname = n: pkgs.${n}.pname or n == n;
      preferred = ns:
        let direct = builtins.filter matchingPname ns;
        in if direct != [] then direct else ns;
      pickBest = ns:
        let branch = preferred (builtins.filter isUnstable ns);
            slot = preferred (builtins.filter slotRev ns);
            vers = preferred (builtins.filter hasVer  ns);
        in if branch != [] then builtins.head branch
           else if slot != [] then builtins.head slot
           else if vers != [] then builtins.head vers
           else builtins.head (preferred ns);
      unique = '"${_nix_unique}"';
      versionHint = n: if isUnstable n then "branch" else "";
      nixchipFlags = n: builtins.concatStringsSep " " (pkgs.${n}.passthru.nixchipUpdateFlags or []);
      packageVersion = n: pkgs.${n}.version or "";
      line = n: "${n}|${versionHint n}|${nixchipFlags n}|${packageVersion n}";
    in
    builtins.concatStringsSep "\n" (builtins.sort builtins.lessThan (builtins.map line unique))
  '
)

[[ ${#raw_lines[@]} -gt 0 ]] || { echo "error: package discovery returned 0 packages — check the flake for evaluation errors" >&2; exit 1; }

packages=()
declare -A version_hints
declare -A nixchip_flags
declare -A package_versions
for entry in "${raw_lines[@]}"; do
  IFS="|" read -r pkg hint flags version <<< "$entry"
  packages+=("$pkg")
  [[ -n "$hint" ]] && version_hints["$pkg"]="$hint"
  [[ -n "$flags" ]] && nixchip_flags["$pkg"]="$flags"
  package_versions["$pkg"]="$version"
done

if [ -n "${NIXCHIP_UPDATE_PACKAGES:-}" ]; then
  declare -A discovered=()
  for package in "${packages[@]}"; do
    discovered["$package"]=1
  done

  selected=()
  read -r -a requested <<< "${NIXCHIP_UPDATE_PACKAGES//,/ }"
  for package in "${requested[@]}"; do
    if [[ -z "$package" ]]; then
      continue
    fi
    if [[ ! -v "discovered[$package]" ]]; then
      echo "error: requested package '$package' is not enrolled for updates" >&2
      exit 1
    fi
    selected+=("$package")
  done
  packages=("${selected[@]}")
fi

if [ "${NIXCHIP_UPDATE_LIST:-0}" = "1" ]; then
  printf '%s
' "${packages[@]}"
  exit 0
fi

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
# Packages with a trailing version number N get a release-series regex.
# Accept bare versions, v/r-prefixed tags, and tool-prefixed tags such as
# firtool-1.147.0, rel-3.0.0, z3-4.16.0, cvc5-1.3.4, and ngspice-45.
#
# Packages without a version number fall back to --version=branch.
get_version_flags() {
  local pkg="$1"
  local major
  major="$(pkg_major "$pkg")"
  if [[ -z "$major" ]]; then
    echo "--version=branch"
  else
    echo "--version-regex=^(?:[vr]|.*[-_])?(${major}(?:[Q._-][0-9.]+[a-z]?)?)$"
  fi
}


validate_package_selection() {
  local package extra_flags version
  local invalid=()

  for package in "${packages[@]}"; do
    extra_flags="${nixchip_flags[$package]:-}"
    if [[ " $extra_flags " == *" --version"* ]]; then
      continue
    fi
    if [[ -v "version_hints[$package]" ]] && [[ "${version_hints[$package]}" == "branch" ]]; then
      continue
    fi
    if [[ -z "$(pkg_major "$package")" ]]; then
      version="${package_versions[$package]:-}"
      if [[ ! "$version" =~ ^unstable-[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        invalid+=("$package ($version)")
      fi
    fi
  done

  if [ "${#invalid[@]}" -ne 0 ]; then
    echo "error: update discovery selected unsuffixed release packages for branch updates:" >&2
    printf "  %s\n" "${invalid[@]}" >&2
    echo "       make the unsuffixed attr branch-tracking, use a versioned slot, or set passthru.nixchipUpdateFlags." >&2
    return 1
  fi
}

validate_package_selection

verify_branch_head() {
  local package="$1"
  local info repo_url rev version remote

  # Use src.gitRepoUrl rather than reconstructing a github.com URL from
  # owner/repo: fetchFromGitLab sources (e.g. surfer) also expose owner/repo,
  # but their actual host is gitlab.com, not github.com.
  info="$(nix eval --raw ".#packages.${system}.${package}" --apply '
    p: "${p.src.gitRepoUrl or ""}\t${p.src.rev or ""}\t${p.version or ""}"
  ')"
  IFS=$'\t' read -r repo_url rev version <<< "$info"

  if [[ -z "$repo_url" || -z "$rev" ]]; then
    echo "warning: cannot verify branch HEAD for $package; src repo URL/rev unavailable" >&2
    return 0
  fi

  if [[ ! "$version" =~ ^unstable-[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "error: $package branch version '$version' should look like unstable-YYYY-MM-DD" >&2
    return 1
  fi

  remote="$(git ls-remote "$repo_url" HEAD | awk 'NR == 1 { print $1; exit }')"
  if [[ -z "$remote" ]]; then
    echo "error: failed to resolve upstream HEAD for $package (${repo_url})" >&2
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
  if [[ " $extra_flags " == *" --version=branch"* ]]; then
    branch_update=true
  fi

  if [[ "$branch_update" == true ]]; then
    # nix-update --version=branch resolves to the nearest tag commit rather than
    # actual HEAD. Bypass it entirely: fetch HEAD directly and patch the nix file.
    # Use src.gitRepoUrl / src.url rather than reconstructing a github.com URL:
    # fetchFromGitLab sources (e.g. surfer) also expose owner/repo, but their
    # actual host is gitlab.com, and their archive URL format differs from
    # GitHub's. Derive the new archive URL by substituting the new rev into
    # the current archive URL, so this works for either host.
    pkg_src_info="$(nix eval --raw ".#packages.${system}.${package}" --apply '
      p: "${p.src.gitRepoUrl or ""}\t${p.src.rev or ""}\t${p.src.outputHash or ""}\t${p.src.url or ""}\t${if p.src.fetchSubmodules or false then "1" else "0"}"
    ' 2>/dev/null)" || pkg_src_info=""
    IFS=$'\t' read -r src_repo_url current_rev current_hash current_src_url fetch_submodules <<< "$pkg_src_info"

    if [[ -z "$src_repo_url" || -z "$current_rev" ]]; then
      echo "error: cannot determine repo URL/rev for $package" >&2
      failed+=("$package"); echo "::endgroup::"; continue
    fi

    head_rev="$(git ls-remote "$src_repo_url" HEAD | awk 'NR == 1 { print $1; exit }')"
    if [[ -z "$head_rev" ]]; then
      echo "error: cannot resolve HEAD for ${src_repo_url}" >&2
      failed+=("$package"); echo "::endgroup::"; continue
    fi

    today="$(date -u +%Y-%m-%d)"

    if [[ "$head_rev" == "$current_rev" ]]; then
      # No upstream movement — skip hash computation entirely rather than
      # re-deriving it (submodule-fetching sources in particular can't be
      # hashed via a simple archive-URL fetch; see below).
      echo "unchanged $package"
      echo "::endgroup::"; continue
    fi

    if [[ "$fetch_submodules" == "1" ]]; then
      # fetchFromGitHub/GitLab fall back to the git-clone fetcher (fetchgit)
      # when fetchSubmodules is set, so there is no tarball archive URL to
      # substitute the rev into — use nix-prefetch-git instead.
      new_hash="$(nix run nixpkgs#nix-prefetch-git -- --url "$src_repo_url" --rev "$head_rev" --fetch-submodules --quiet 2>/dev/null | jq -r '.hash // empty')" || new_hash=""
    else
      archive_url="${current_src_url//$current_rev/$head_rev}"
      raw_hash="$(nix-prefetch-url --type sha256 --unpack "$archive_url" 2>/dev/null)" || raw_hash=""
      new_hash="$(nix hash to-sri --type sha256 "$raw_hash" 2>/dev/null)" || new_hash=""
    fi
    if [[ -z "$new_hash" ]]; then
      echo "error: cannot compute hash for ${package}@${head_rev}" >&2
      failed+=("$package"); echo "::endgroup::"; continue
    fi

    # Locate the nix file: convention is pkgs/<attribute>/default.nix.
    # Fall back to meta.position for any package that doesn't follow the convention.
    nix_file="${repo_root}/pkgs/${package}/default.nix"
    default_nix="${repo_root}/pkgs/default.nix"
    block_start=""
    block_end=""
    if [[ ! -f "$nix_file" ]]; then
      # Try stripping a trailing underscore (e.g. dramsim3_ → dramsim3).
      pkg_base="${package%_}"
      if [[ "$pkg_base" != "$package" && -f "${repo_root}/pkgs/${pkg_base}/default.nix" ]]; then
        nix_file="${repo_root}/pkgs/${pkg_base}/default.nix"
      else
        # Attr-block overrides (e.g. `cvc5_ = branchOverride basePkgs.cvc5 "unstable-..." (...);`)
        # live inline in pkgs/default.nix. meta.position for these points into the
        # nixpkgs store (inherited from the base derivation), which previously caused
        # a fallback to `nix-update -F`; that tool then edited pkgs/default.nix
        # unscoped and could clobber sibling `unstable-*` entries. Detect this shape
        # directly and restrict edits to just this attribute's block.
        block_start="$(grep -n -m1 -E "^[[:space:]]*${package}[[:space:]]*=[[:space:]]*branchOverride" "$default_nix" | cut -d: -f1)"
        if [[ -n "$block_start" ]]; then
          block_end="$(awk -v s="$block_start" 'NR>=s && /^[[:space:]]*\}\);[[:space:]]*$/ { print NR; exit }' "$default_nix")"
        fi
        if [[ -n "$block_start" && -n "$block_end" ]]; then
          nix_file="$default_nix"
        else
          pos="$(nix eval --raw ".#packages.${system}.${package}" \
            --apply 'p: p.meta.position or ""' 2>/dev/null | sed 's/:[0-9]*$//')"
          [[ -f "$pos" ]] && nix_file="$pos"
        fi
      fi
    fi
    if [[ ! -f "$nix_file" ]]; then
      echo "error: cannot find nix file for $package" >&2
      failed+=("$package"); echo "::endgroup::"; continue
    fi
    if [[ "$nix_file" == /nix/store/* ]]; then
      # Versioned slot — version/rev/hash live as callPackage args in pkgs/default.nix,
      # so the branch sed approach can't be used. Fall back to nix-update with a
      # major-version constraint so the slot tracks its own version series.
      ver_flags="$(get_version_flags "$package")"
      # shellcheck disable=SC2086
      if nix run nixpkgs#nix-update -- -F "$package" $ver_flags "${build_flag[@]}"; then
        echo "updated $package"
      else
        failed+=("$package")
        echo "failed to update $package" >&2
      fi
      echo "::endgroup::"; continue
    fi

    if [[ -n "$block_start" && -n "$block_end" ]]; then
      sed -Ei "${block_start},${block_end}s/\"unstable-[0-9]{4}-[0-9]{2}-[0-9]{2}\"/\"unstable-${today}\"/" "$nix_file"
      sed -Ei "${block_start},${block_end}s/\"[a-f0-9]{40}\"/\"${head_rev}\"/" "$nix_file"
      sed -Ei "${block_start},${block_end}s|hash = \"[^\"]*\"|hash = \"${new_hash}\"|" "$nix_file"
    else
      sed -Ei "0,/version ([?=]) \"[^\"]*\"/s//version \1 \"unstable-${today}\"/" "$nix_file"
      sed -Ei "0,/\"[a-f0-9]{40}\"/s//\"${head_rev}\"/" "$nix_file"
      sed -Ei "0,/hash ([?=]) \"[^\"]*\"/s|hash ([?=]) \"[^\"]*\"|hash \1 \"${new_hash}\"|" "$nix_file"
    fi

    if ! verify_branch_head "$package"; then
      failed+=("$package"); echo "::endgroup::"; continue
    fi
    echo "updated $package"
  else
    # shellcheck disable=SC2086
    if nix run nixpkgs#nix-update -- -F "$package" $extra_flags "${build_flag[@]}"; then
      echo "updated $package"
    else
      failed+=("$package")
      echo "failed to update $package" >&2
    fi
  fi
  echo "::endgroup::"
done

if [ "${#failed[@]}" -ne 0 ]; then
  printf 'package update failures:' >&2
  printf ' %s' "${failed[@]}" >&2
  printf '\n' >&2
  exit 1
fi
