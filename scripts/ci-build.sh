#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "usage: ci-build.sh <system> <package> [<package> ...]" >&2
  exit 2
fi

system="$1"
shift

repo_root="$(git rev-parse --show-toplevel)"
flake_ref="path:${repo_root}"
results_file="$(mktemp)"
results_tmp="$(mktemp)"
log_dir="${CI_LOG_DIR:-ci-logs}"
failed=0

mkdir -p "$log_dir"
printf '[]' > "$results_file"

for package in "$@"; do
  log_file="${log_dir}/${package}.log"
  echo "build packages.${system}.${package} -> ${log_file}"

  if nix build "${flake_ref}#packages.${system}.${package}" --print-build-logs > "$log_file" 2>&1; then
    status="success"
    echo "ok ${package}"
  else
    status="failure"
    failed=1
    echo "failed ${package}; last log lines:"
    tail -n 80 "$log_file" || true
  fi

  jq \
    --arg package "$package" \
    --arg status "$status" \
    --arg log "$log_file" \
    '. + [{ package: $package, status: $status, log: $log }]' \
    "$results_file" > "$results_tmp"
  mv "$results_tmp" "$results_file"
done

results="$(jq -c . "$results_file")"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "results<<EOF"
    echo "$results"
    echo "EOF"
    if [ "$failed" -eq 0 ]; then
      echo "has-failures=false"
    else
      echo "has-failures=true"
    fi
  } >> "$GITHUB_OUTPUT"
fi

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "## Package build results"
    echo
    echo "Full per-package logs are available in the \`ci-build-logs\` artifact."
    echo
    echo "| Package | Status | Log file |"
    echo "| --- | --- | --- |"
    jq -r '.[] | "| `\(.package)` | \(.status) | `\(.log)` |"' "$results_file"
  } >> "$GITHUB_STEP_SUMMARY"
fi

# In GitHub Actions, the report matrix turns individual package failures red.
# Outside Actions, preserve the usual command-line convention.
if [ "$failed" -ne 0 ] && [ -z "${GITHUB_ACTIONS:-}" ]; then
  exit 1
fi
