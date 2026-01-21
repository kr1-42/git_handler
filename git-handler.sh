#!/usr/bin/env bash
set -euo pipefail

if ! command -v git >/dev/null 2>&1; then
  echo "git is not installed or not in PATH." >&2
  exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not inside a git repository." >&2
  exit 1
fi

read -r -p "Enter branch name (without 'feature/'): " branch_suffix
branch_suffix="${branch_suffix## }"
branch_suffix="${branch_suffix%% }"

if [[ -z "$branch_suffix" ]]; then
  echo "Branch name cannot be empty." >&2
  exit 1
fi

branch_name="feature/${branch_suffix}"

if git show-ref --verify --quiet "refs/heads/${branch_name}"; then
  echo "Branch '${branch_name}' already exists locally. Checking it out..."
  git checkout "${branch_name}"
else
  git checkout -b "${branch_name}"
fi

read -r -p "Commit message: " commit_message
commit_message="${commit_message## }"
commit_message="${commit_message%% }"

if [[ -z "$commit_message" ]]; then
  echo "Commit message cannot be empty." >&2
  exit 1
fi

git add -A

git commit -m "${commit_message}"

git push -u origin "${branch_name}"

echo "Done: ${branch_name} pushed to origin."
