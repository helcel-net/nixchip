#!/usr/bin/env bash
# Refresh pkgs/{claude-code,codex,opencode}/sources.json to upstream's latest
# prebuilt release. These ship one binary per platform, so nix-update (which
# rewrites a single hash) cannot bump them; hashes come from the checksums
# upstream publishes (claude-code's manifest, GitHub release asset digests)
# instead of downloading every binary.
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

curl_gh() {
  curl -fsSL ${GH_TOKEN:+-H "Authorization: Bearer $GH_TOKEN"} "$@"
}

sri() {
  nix hash convert --hash-algo sha256 --to sri "$1"
}

# write_sources FILE VERSION SYSTEM=HEXSHA256...
write_sources() {
  local file="$1" version="$2" hashes='{}' pair
  shift 2
  for pair in "$@"; do
    hashes=$(jq --arg s "${pair%%=*}" --arg h "$(sri "${pair#*=}")" '. + {($s): $h}' <<< "$hashes")
  done
  jq -n --arg v "$version" --argjson h "$hashes" '{version: $v, hashes: $h}' > "$file"
  echo "${file%/sources.json}: $version"
}

# github_digest RELEASE_JSON ASSET_NAME -> hex sha256
github_digest() {
  jq -er --arg n "$2" '.assets[] | select(.name == $n) | .digest | ltrimstr("sha256:")' <<< "$1"
}

base=https://downloads.claude.ai/claude-code-releases
version=$(curl -fsSL "$base/latest")
manifest=$(curl -fsSL "$base/$version/manifest.json")
claude() { jq -er --arg p "$1" '.platforms[$p].checksum' <<< "$manifest"; }
write_sources pkgs/claude-code/sources.json "$version" \
  "x86_64-linux=$(claude linux-x64)" \
  "aarch64-linux=$(claude linux-arm64)" \
  "x86_64-darwin=$(claude darwin-x64)" \
  "aarch64-darwin=$(claude darwin-arm64)"

release=$(curl_gh https://api.github.com/repos/openai/codex/releases/latest)
version=$(jq -er '.tag_name | ltrimstr("rust-v")' <<< "$release")
codex() { github_digest "$release" "codex-$1.tar.gz"; }
write_sources pkgs/codex/sources.json "$version" \
  "x86_64-linux=$(codex x86_64-unknown-linux-musl)" \
  "aarch64-linux=$(codex aarch64-unknown-linux-musl)" \
  "x86_64-darwin=$(codex x86_64-apple-darwin)" \
  "aarch64-darwin=$(codex aarch64-apple-darwin)"

release=$(curl_gh https://api.github.com/repos/anomalyco/opencode/releases/latest)
version=$(jq -er '.tag_name | ltrimstr("v")' <<< "$release")
opencode() { github_digest "$release" "opencode-$1"; }
write_sources pkgs/opencode/sources.json "$version" \
  "x86_64-linux=$(opencode linux-x64.tar.gz)" \
  "aarch64-linux=$(opencode linux-arm64.tar.gz)" \
  "x86_64-darwin=$(opencode darwin-x64.zip)" \
  "aarch64-darwin=$(opencode darwin-arm64.zip)"
