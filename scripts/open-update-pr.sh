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

if gh pr view "$branch" --json number >/dev/null 2>&1; then
  gh pr edit "$branch" --title "$title" --body "$body"
else
  gh pr create --base "$base" --head "$branch" --title "$title" --body "$body"
fi
