#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

system="${NIX_SYSTEM:-x86_64-linux}"
default_nix="${repo_root}/pkgs/default.nix"

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
# Accept bare versions, v/r-prefixed tags, tool-prefixed tags such as
# firtool-1.147.0, rel-3.0.0, z3-4.16.0, cvc5-1.3.4, ngspice-45, and
# release/v-prefixed tags such as release/v5.14.7.
#
# Packages without a version number fall back to --version=branch.
get_version_flags() {
  local pkg="$1"
  local major
  major="$(pkg_major "$pkg")"
  if [[ -z "$major" ]]; then
    echo "--version=branch"
  else
    echo "--version-regex=^(?:[vr]|.*[-_/]v?)?(${major}(?:[Q._-][0-9.]+[a-z]?)?)$"
  fi
}

nix_update_changed=false
run_nix_update() {
  local package="$1"
  shift
  local output

  nix_update_changed=false
  if output="$(nix run nixpkgs#nix-update -- -F "$package" "$@" 2>&1)"; then
    printf '%s\n' "$output"
    # nix-update exits 0 both when it actually rewrote the file and when it
    # found nothing new ("Not updating version, already X"). Only the former
    # should trigger downstream work (attr-scope restore, version-clobber
    # repair, a full source-fetch rebuild) — treating every successful call
    # as "changed" wastes a rebuild on every no-op run, and made the
    # clobber-repair pass rewrite already-committed, unrelated version
    # mismatches it had no business touching.
    if ! grep -q "Not updating version, already" <<< "$output"; then
      nix_update_changed=true
    fi
    return 0
  fi

  if grep -q "No version matched the regex" <<< "$output"; then
    echo "unchanged $package; no upstream version matched its update constraint"
    return 0
  fi

  printf '%s\n' "$output"
  return 1
}

# Repairs a package's `version` field when nix-update clobbers it with the
# raw new tag/rev instead of the value its own --version-regex captured.
# nix-update's replace_version() (nix_update/update.py) does two whole-line
# text substitutions in sequence: first swap the old rev/tag substring for
# the new one, then swap the quoted old version substring for the new one.
# When a package's version and rev were textually identical (e.g.
# cryptominisat5 at "5.11.21"/"5.11.21"), the first substitution already
# matches on the version-declaration line and clobbers it before the second,
# correctly-scoped substitution gets a chance — so the field ends up holding
# the untrimmed tag ("release/v5.14.7") instead of the regex-captured
# version ("5.14.7"). Re-derive the intended version from the regex nix-update
# was given and patch it back in if it doesn't match what got written.
repair_clobbered_version() {
  local package="$1" ver_regex="$2"
  local new_rev version_now fixed

  new_rev="$(nix eval --raw ".#packages.${system}.${package}" --apply 'p: p.src.rev or ""' 2>/dev/null)" || return 0
  version_now="$(nix eval --raw ".#packages.${system}.${package}" --apply 'p: p.version or ""' 2>/dev/null)" || return 0
  [[ -n "$new_rev" && -n "$version_now" ]] || return 0

  fixed="$(python3 -c '
import re, sys
m = re.match(sys.argv[1], sys.argv[2])
print(".".join(g for g in m.groups() if g) if m else "")
' "$ver_regex" "$new_rev" 2>/dev/null)"

  [[ -n "$fixed" && "$fixed" != "$version_now" ]] || return 0

  echo "repairing clobbered version for $package: '$version_now' -> '$fixed'" >&2
  local block_info block_s block_e escaped_old
  block_info="$(find_default_nix_attr_block "$package")"
  if [[ -z "$block_info" ]]; then
    echo "error: cannot locate block to repair version for $package" >&2
    return 1
  fi
  IFS=$'\t' read -r block_s block_e <<< "$block_info"
  # Scope to the block's first line only: `pkg = pinnedOverride basePkgs.x
  # "VERSION" (...` always puts the version argument there, while `rev =
  # "..."` (which legitimately keeps the full tag) lives on a later line
  # inside the same block and must not be touched.
  escaped_old="$(printf '%s' "$version_now" | sed -e 's/[.[\*^$/]/\\&/g')"
  sed -Ei "${block_s}s/\"${escaped_old}\"/\"${fixed}\"/" "$default_nix"
}

find_default_nix_override_block() {
  local package="$1"
  local file="${2:-$default_nix}"
  local start end

  # cargoVendorOverride wraps a branchOverride/pinnedOverride to re-point a Rust
  # package's vendored-crates hash, so accept it as a block opener too --
  # otherwise the wrapped package falls through to the meta.position path, which
  # points into the nixpkgs store and lands on the unscoped `nix-update -F`
  # fallback that can clobber sibling entries.
  # Entries also appear parenthesised so a trailing .overrideAttrs can be chained
  # (e.g. `z3_ = (branchOverride ...)).overrideAttrs { ... };`). Those were
  # previously invisible here, which sent them to the meta.position fallback too.
  # nixfmt breaks long entries as `pkg =` / newline / `(branchOverride ...`, so
  # the opener is accepted on the attr line or the one after it. Without the
  # second case a reformat would silently send these to the meta.position path.
  start="$(awk -v pkg="$package" '
    function is_opener(tok) {
      sub(/^\(/, "", tok)
      return (tok == "branchOverride" || tok == "pinnedOverride" || tok == "cargoVendorOverride")
    }
    {
      if (pending) {
        if (is_opener($1)) { print pending; exit }
        pending = 0
      }
      if ($1 == pkg && $2 == "=") {
        if (is_opener($3)) { print NR; exit }
        if (NF == 2) { pending = NR }
      }
    }
  ' "$file")"
  if [[ -n "$start" ]]; then
    # Closers, by shape: `});` plain, `);` wrapper-call, `};` chained overrideAttrs.
    end="$(awk -v s="$start" 'NR>=s && /^[[:space:]]*(\}?\);|\};)[[:space:]]*$/ { print NR; exit }' "$file")"
  fi
  if [[ -n "$start" && -n "$end" ]]; then
    printf '%s\t%s\n' "$start" "$end"
  fi
}

find_default_nix_attr_block() {
  local package="$1"
  local file="${2:-$default_nix}"

  awk -v pkg="$package" '
    $1 == pkg && $2 == "=" {
      start = NR
      indent = match($0, /[^[:space:]]/) - 1
      if ($0 ~ /;[[:space:]]*$/ && $0 !~ /\{[[:space:]]*$/) {
        print start "\t" start
        exit
      }
    }
    start && NR > start {
      currentIndent = match($0, /[^[:space:]]/) - 1
      if (currentIndent == indent && $0 ~ /^[[:space:]]*(\}\);|\};|.*;)[[:space:]]*$/) {
        print start "\t" NR
        exit
      }
    }
  ' "$file"
}

restore_default_nix_attr_scope() {
  local package="$1"
  local before_file="$2"
  local old_start="$3"
  local old_end="$4"
  local block_info new_start new_end block_file merged_file

  block_info="$(find_default_nix_attr_block "$package")"
  if [[ -z "$block_info" ]]; then
    echo "error: cannot find updated pkgs/default.nix attr block for $package" >&2
    return 1
  fi
  IFS=$'\t' read -r new_start new_end <<< "$block_info"

  block_file="$(mktemp)"
  merged_file="$(mktemp)"
  sed -n "${new_start},${new_end}p" "$default_nix" > "$block_file"
  awk -v s="$old_start" -v e="$old_end" -v block="$block_file" '
    NR == s {
      while ((getline line < block) > 0) {
        print line
      }
    }
    NR < s || NR > e {
      print
    }
  ' "$before_file" > "$merged_file"
  mv "$merged_file" "$default_nix"
  rm -f "$block_file"
}

verify_source_fetch() {
  local package="$1"
  local has_src

  has_src="$(nix eval --raw ".#packages.${system}.${package}" \
    --apply 'p: if p ? src then "1" else ""' 2>/dev/null || true)"
  if [[ "$has_src" != "1" ]]; then
    echo "warning: cannot verify source fetch for $package; package has no src" >&2
    return 0
  fi

  if ! nix build --impure --no-link --print-build-logs --expr '
    let
      flake = builtins.getFlake "'"${repo_root}"'";
    in flake.packages."'"${system}"'"."'"${package}"'".src
  '; then
    echo "error: source fetch failed for $package after update" >&2
    return 1
  fi
}

# Refreshes a package's vendored Cargo.lock to match its new pinned rev.
# Rust packages built via `cargoLock.lockFile` (e.g. bender) vendor a
# snapshot of the upstream Cargo.lock instead of regenerating one, since
# there's no network access in the build sandbox to resolve dependencies.
# Bumping the source rev without also refreshing this file breaks the build
# the moment upstream's own Cargo.lock changes ("cargoHash is out of date" /
# "Cargo.lock is not the same in $cargo-vendor-dir"). No-ops when the
# package has no such vendored lockfile.
refresh_cargo_lock() {
  local package="$1" repo_url="$2" rev="$3" nix_file="$4"
  local lock_file
  lock_file="$(dirname "$nix_file")/Cargo.lock"
  [[ -f "$lock_file" ]] || return 0

  local clean_url="${repo_url%/}"
  clean_url="${clean_url%.git}"
  local raw_url="${clean_url}/raw/${rev}/Cargo.lock"
  local new_lock
  new_lock="$(mktemp)"
  if ! curl -fsSL "$raw_url" -o "$new_lock"; then
    echo "error: failed to fetch Cargo.lock for $package from $raw_url" >&2
    rm -f "$new_lock"
    return 1
  fi
  if ! head -n1 "$new_lock" | grep -q "generated by Cargo"; then
    echo "error: fetched Cargo.lock for $package does not look like a Cargo lockfile" >&2
    rm -f "$new_lock"
    return 1
  fi

  if cmp -s "$new_lock" "$lock_file"; then
    rm -f "$new_lock"
  else
    chmod u+w "$lock_file" 2>/dev/null || true
    mv "$new_lock" "$lock_file"
    echo "refreshed Cargo.lock for $package"
  fi
}

# Refreshes the vendored-crates hash for Rust packages built through
# rustPlatform.buildRustPackage's `cargoHash`. Unlike refresh_cargo_lock above,
# these vendor from crates.io at build time rather than from an in-repo
# Cargo.lock, so there is no file to copy -- only a hash to recompute.
#
# buildRustPackage reads cargoHash from its *original* args, so overrideAttrs
# cannot reach it; the effective value lives on the vendor FOD's outputHash
# (see cargoVendorOverride in pkgs/default.nix). The vendor derivation does take
# `src` from finalAttrs, so bumping a rev re-vendors against the new source
# while still checking it against the stale hash -- a guaranteed mismatch until
# this runs. Must be called *after* the rev/hash edits land, since the hash it
# computes is the one for the new source.
#
# Only needed on the branch-tracking path, which bypasses nix-update entirely;
# nix-update refreshes cargoHash itself on the paths where it does run. No-ops
# for packages that don't vendor this way.
refresh_cargo_hash() {
  local package="$1" nix_file="$2" block_start="$3" block_end="$4"
  local has_vendor
  has_vendor="$(nix eval --raw ".#packages.${system}.${package}" \
    --apply 'p: if (p.cargoDeps.vendorStaging or null) != null then "1" else ""' 2>/dev/null || true)"
  [[ "$has_vendor" == "1" ]] || return 0

  # Same deliberately-wrong-hash trick used for the source hash above: let the
  # real fetcher run and read the correct hash back out of the mismatch error.
  local fake_hash="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
  local build_output new_hash
  build_output="$(nix build --impure --no-link --print-out-paths --expr '
    let
      flake = builtins.getFlake "'"${repo_root}"'";
      p = flake.packages."'"${system}"'"."'"${package}"'";
    in p.cargoDeps.vendorStaging.overrideAttrs { outputHash = "'"${fake_hash}"'"; }
  ' 2>&1)" || true
  new_hash="$(grep -oP 'got:\s+\K\S+' <<< "$build_output" | tail -1)"
  if [[ -z "$new_hash" ]]; then
    echo "error: cannot compute cargoHash for $package" >&2
    echo "$build_output" >&2
    return 1
  fi

  # `hash = "` never matches `cargoHash = "` (capital H), so the source-hash sed
  # above and this one stay disjoint.
  if [[ -n "$block_start" && -n "$block_end" ]]; then
    sed -Ei "${block_start},${block_end}s|cargoHash = \"[^\"]*\"|cargoHash = \"${new_hash}\"|" "$nix_file"
  else
    sed -Ei "0,/cargoHash[[:space:]]+([?=]) \"[^\"]*\"/s|cargoHash[[:space:]]+([?=]) \"[^\"]*\"|cargoHash \1 \"${new_hash}\"|" "$nix_file"
  fi
  echo "refreshed cargoHash for $package"
}

# nix-update has no SourceForge backend at all (see nix_update/version/__init__.py:
# it only knows codeberg/crates.io/gitea/github/gitlab/pypi/savannah/sourcehut/
# rubygems/npm), so it can never auto-detect a new version for a
# `mirror://sourceforge/...` fetchurl package — it fails with "Please specify
# the version" every single time, regardless of whether a newer release
# exists upstream. Bypass nix-update entirely for these: list the project's
# recent files via SourceForge's own RSS feed, apply the package's existing
# major-version regex (the same one get_version_flags() already computes for
# every numbered slot) to find the newest matching sibling filename, then
# fetch the real hash the same way the branch-tracking bypass does (build
# with a deliberately wrong hash and read the real one back out of the error).
is_sourceforge_package() {
  local package="$1"
  local block_info block_s block_e
  block_info="$(find_default_nix_override_block "$package")"
  [[ -n "$block_info" ]] || return 1
  IFS=$'\t' read -r block_s block_e <<< "$block_info"
  sed -n "${block_s},${block_e}p" "$default_nix" | grep -q 'mirror://sourceforge/'
}

update_sourceforge_package() {
  local package="$1"
  local block_info block_s block_e block_text
  block_info="$(find_default_nix_override_block "$package")"
  if [[ -z "$block_info" ]]; then
    echo "error: cannot locate pkgs/default.nix block for $package" >&2
    return 1
  fi
  IFS=$'\t' read -r block_s block_e <<< "$block_info"
  block_text="$(sed -n "${block_s},${block_e}p" "$default_nix")"

  local old_version old_url old_hash
  old_version="$(nix eval --raw ".#packages.${system}.${package}" --apply 'p: p.version' 2>/dev/null)" || old_version=""
  old_url="$(grep -oP 'url = "\K[^"]+' <<< "$block_text" | head -1)"
  old_hash="$(grep -oP 'hash = "\K[^"]+' <<< "$block_text" | head -1)"
  if [[ -z "$old_version" || -z "$old_url" || -z "$old_hash" ]]; then
    echo "error: cannot find version/url/hash for sourceforge package $package" >&2
    return 1
  fi

  # mirror://sourceforge/<project>/<...>/<filename>, with a legacy
  # `mirror://sourceforge/project/<project>/...` form some packages use.
  local sf_path project filename
  sf_path="${old_url#mirror://sourceforge/}"
  [[ "$sf_path" == project/* ]] && sf_path="${sf_path#project/}"
  project="${sf_path%%/*}"
  filename="${sf_path##*/}"

  local ver_regex
  ver_regex="$(get_version_flags "$package")"
  ver_regex="${ver_regex#--version-regex=}"

  local rss_file
  rss_file="$(mktemp)"
  if ! curl -fsSL "https://sourceforge.net/projects/${project}/rss" -o "$rss_file"; then
    echo "error: failed to fetch SourceForge RSS feed for project $project" >&2
    rm -f "$rss_file"
    return 1
  fi

  local best
  best="$(python3 -c '
import re, sys

filename, old_version, ver_regex, rss_path = sys.argv[1:5]
if old_version not in filename:
    sys.exit(0)
prefix, suffix = filename.split(old_version, 1)
name_re = re.compile("^" + re.escape(prefix) + "(.+?)" + re.escape(suffix) + "$")
ver_re = re.compile(ver_regex)

def version_key(v):
    return tuple(int(x) if x.isdigit() else x for x in re.split(r"(\d+)", v) if x != "")

with open(rss_path, encoding="utf-8", errors="replace") as f:
    rss = f.read()

best = None
for title in re.findall(r"<title><!\[CDATA\[([^\]]*)\]\]></title>", rss):
    base = title.rsplit("/", 1)[-1]
    m = name_re.match(base)
    if not m:
        continue
    vm = ver_re.match(m.group(1))
    if not vm:
        continue
    groups = [g for g in vm.groups() if g]
    v = ".".join(groups) if groups else m.group(1)
    if best is None or version_key(v) > version_key(best):
        best = v
print(best or "")
' "$filename" "$old_version" "$ver_regex" "$rss_file")"
  rm -f "$rss_file"

  if [[ -z "$best" || "$best" == "$old_version" ]]; then
    echo "unchanged $package"
    return 0
  fi

  local new_url new_filename
  new_filename="${filename/$old_version/$best}"
  new_url="${old_url/$filename/$new_filename}"

  local fake_hash new_hash build_output
  fake_hash="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
  build_output="$(nix build --impure --no-link --print-out-paths --expr '
    let
      flake = builtins.getFlake "'"${repo_root}"'";
    in (import flake.inputs.nixpkgs { system = "'"${system}"'"; }).fetchurl {
      url = "'"${new_url}"'";
      hash = "'"${fake_hash}"'";
    }
  ' 2>&1)" || true
  new_hash="$(grep -oP 'got:\s+\K\S+' <<< "$build_output" | tail -1)"
  if [[ -z "$new_hash" ]]; then
    echo "error: cannot compute hash for ${package}@${best} (${new_url})" >&2
    echo "$build_output" >&2
    return 1
  fi

  local escaped_old_version
  escaped_old_version="$(printf '%s' "$old_version" | sed -e 's/[.[\*^$/]/\\&/g')"
  sed -Ei "${block_s}s/\"${escaped_old_version}\"/\"${best}\"/" "$default_nix"
  sed -Ei "${block_s},${block_e}s|url = \"[^\"]*\"|url = \"${new_url}\"|" "$default_nix"
  sed -Ei "${block_s},${block_e}s|hash = \"[^\"]*\"|hash = \"${new_hash}\"|" "$default_nix"

  if ! verify_source_fetch "$package"; then
    return 1
  fi
  echo "updated $package"
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

  if is_sourceforge_package "$package"; then
    if update_sourceforge_package "$package"; then
      :
    else
      failed+=("$package")
      echo "failed to update $package" >&2
    fi
    echo "::endgroup::"; continue
  fi

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
    # Use src.gitRepoUrl rather than reconstructing a github.com URL:
    # fetchFromGitLab sources (e.g. surfer) also expose owner/repo, but their
    # actual host is gitlab.com.
    pkg_src_info="$(nix eval --raw ".#packages.${system}.${package}" --apply '
      p: "${p.src.gitRepoUrl or ""}\t${p.src.rev or ""}\t${p.src.outputHash or ""}"
    ' 2>/dev/null)" || pkg_src_info=""
    IFS=$'\t' read -r src_repo_url current_rev current_hash <<< "$pkg_src_info"

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
      echo "unchanged $package"
      echo "::endgroup::"; continue
    fi

    # Compute the hash for the new rev by asking Nix to actually build the
    # source with a deliberately wrong hash and reading the correct one back
    # out of the resulting error. This goes through the exact same fetcher
    # nixpkgs will use later (fetchFromGitHub/fetchFromGitLab, with or without
    # submodules), so it can't diverge from what a real build will fetch —
    # unlike reconstructing an archive URL and hashing it with nix-prefetch-url,
    # which silently produced a wrong hash for at least one package (sv-lang).
    fake_hash="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    build_output="$(nix build --impure --no-link --print-out-paths --expr '
      let
        flake = builtins.getFlake "'"${repo_root}"'";
        p = flake.packages."'"${system}"'"."'"${package}"'";
      in p.src.override { rev = "'"${head_rev}"'"; hash = "'"${fake_hash}"'"; }
    ' 2>&1)" || true
    new_hash="$(grep -oP 'got:\s+\K\S+' <<< "$build_output" | tail -1)"
    if [[ -z "$new_hash" ]]; then
      echo "error: cannot compute hash for ${package}@${head_rev}" >&2
      echo "$build_output" >&2
      failed+=("$package"); echo "::endgroup::"; continue
    fi

    # Locate the nix file: convention is pkgs/<attribute>/default.nix.
    # Fall back to meta.position for any package that doesn't follow the convention.
    nix_file="${repo_root}/pkgs/${package}/default.nix"
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
        # unscoped and could clobber sibling entries. Detect this shape
        # directly and restrict edits to just this attribute's block.
        block_info="$(find_default_nix_override_block "$package")"
        if [[ -n "$block_info" ]]; then
          IFS=$'\t' read -r block_start block_end <<< "$block_info"
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
      if run_nix_update "$package" $ver_flags "${build_flag[@]}"; then
        if [[ "$nix_update_changed" == true ]] && ! verify_source_fetch "$package"; then
          failed+=("$package")
          echo "::endgroup::"; continue
        fi
        if [[ "$nix_update_changed" == true ]]; then
          echo "updated $package"
        fi
      else
        failed+=("$package")
        echo "failed to update $package" >&2
      fi
      echo "::endgroup::"; continue
    fi

    if [[ -n "$block_start" && -n "$block_end" ]]; then
      # The optional prefix in the match strips upstream-derived prefixes
      # (e.g. Nightly-unstable-..., once written by nix-update for repos whose
      # latest release is a rolling "Nightly") down to plain unstable-YYYY-MM-DD.
      sed -Ei "${block_start},${block_end}s/\"([A-Za-z][A-Za-z0-9]*-)?unstable-[0-9]{4}-[0-9]{2}-[0-9]{2}\"/\"unstable-${today}\"/" "$nix_file"
      sed -Ei "${block_start},${block_end}s/\"[a-f0-9]{40}\"/\"${head_rev}\"/" "$nix_file"
      sed -Ei "${block_start},${block_end}s|hash = \"[^\"]*\"|hash = \"${new_hash}\"|" "$nix_file"
    else
      sed -Ei "0,/version[[:space:]]+([?=]) \"[^\"]*\"/s//version \1 \"unstable-${today}\"/" "$nix_file"
      sed -Ei "0,/\"[a-f0-9]{40}\"/s//\"${head_rev}\"/" "$nix_file"
      sed -Ei "0,/hash[[:space:]]+([?=]) \"[^\"]*\"/s|hash[[:space:]]+([?=]) \"[^\"]*\"|hash \1 \"${new_hash}\"|" "$nix_file"
    fi

    if ! refresh_cargo_lock "$package" "$src_repo_url" "$head_rev" "$nix_file"; then
      failed+=("$package"); echo "::endgroup::"; continue
    fi
    if ! refresh_cargo_hash "$package" "$nix_file" "$block_start" "$block_end"; then
      failed+=("$package"); echo "::endgroup::"; continue
    fi
    if ! verify_branch_head "$package"; then
      failed+=("$package"); echo "::endgroup::"; continue
    fi
    if ! verify_source_fetch "$package"; then
      failed+=("$package"); echo "::endgroup::"; continue
    fi
    echo "updated $package"
  else
    inline_block_info="$(find_default_nix_attr_block "$package")"
    before_default_nix=""
    inline_block_start=""
    inline_block_end=""
    if [[ -n "$inline_block_info" ]]; then
      IFS=$'\t' read -r inline_block_start inline_block_end <<< "$inline_block_info"
      before_default_nix="$(mktemp)"
      cp "$default_nix" "$before_default_nix"
    fi

    # shellcheck disable=SC2086
    if run_nix_update "$package" $extra_flags "${build_flag[@]}"; then
      if [[ "$nix_update_changed" == true && -n "$before_default_nix" ]]; then
        if ! restore_default_nix_attr_scope "$package" "$before_default_nix" "$inline_block_start" "$inline_block_end"; then
          failed+=("$package")
          echo "failed to scope update for $package" >&2
          rm -f "$before_default_nix"
          echo "::endgroup::"; continue
        fi
      fi
      if [[ "$nix_update_changed" == true && -n "$inline_block_info" && "$extra_flags" == *"--version-regex="* ]]; then
        ver_regex="${extra_flags#*--version-regex=}"
        ver_regex="${ver_regex%% *}"
        if ! repair_clobbered_version "$package" "$ver_regex"; then
          failed+=("$package")
          rm -f "$before_default_nix"
          echo "::endgroup::"; continue
        fi
      fi
      if [[ "$nix_update_changed" == true ]] && ! verify_source_fetch "$package"; then
        failed+=("$package")
        rm -f "$before_default_nix"
        echo "::endgroup::"; continue
      fi
      if [[ "$nix_update_changed" == true ]]; then
        echo "updated $package"
      fi
    else
      if [[ -n "$before_default_nix" ]]; then
        cp "$before_default_nix" "$default_nix"
      fi
      failed+=("$package")
      echo "failed to update $package" >&2
    fi
    rm -f "$before_default_nix"
  fi
  echo "::endgroup::"
done

if [ "${#failed[@]}" -ne 0 ]; then
  printf 'package update failures:' >&2
  printf ' %s' "${failed[@]}" >&2
  printf '\n' >&2
  exit 1
fi
