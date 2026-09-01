#!/usr/bin/env bash
set -euo pipefail

branch="${1:?branch is required}"
title="${2:?title is required}"
base="${3:?base branch is required}"
body="$(cat)"

if git diff --quiet && git diff --cached --quiet; then
  echo "No changes to publish."
  exit 0
fi

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

git switch -C "$branch"
git add -A
git commit -m "$title"
git push --force-with-lease origin "$branch"

# `gh pr view <branch>` falls back to the most recently created PR for the
# branch in ANY state, so after a merge/close it would edit that dead PR
# instead of opening a new one. Only an OPEN pr counts as reusable.
open_pr="$(gh pr list --head "$branch" --state open --json number --jq '.[0].number' 2>/dev/null || true)"
if [ -n "$open_pr" ]; then
  gh pr edit "$open_pr" --title "$title" --body "$body"
else
  gh pr create --base "$base" --head "$branch" --title "$title" --body "$body"
fi
