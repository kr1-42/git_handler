#!/usr/bin/env bash
set -euo pipefail

if ! command -v git >/dev/null 2>&1; then
  echo "git is not installed or not in PATH." >&2
  exit 1
fi

if [[ "${1-}" == "--init" ]]; then
  repo_url="${2-}"
  if [[ -z "${repo_url}" ]]; then
    echo "Usage: $0 --init <repo_url>" >&2
    exit 1
  fi

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git init
  fi

  if git remote get-url origin >/dev/null 2>&1; then
    git remote set-url origin "${repo_url}"
  else
    git remote add origin "${repo_url}"
  fi

  if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
    read -r -p "Initial commit message [Initial commit]: " init_message
    init_message="${init_message:-Initial commit}"
    git add -A
    git commit -m "${init_message}"
  fi

  current_branch="$(git rev-parse --abbrev-ref HEAD)"
  git push -u origin "${current_branch}"
  echo "Initialized repo and pushed to ${repo_url} on ${current_branch}."
  exit 0
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not inside a git repository." >&2
  exit 1
fi

initial_branch="$(git rev-parse --abbrev-ref HEAD)"
current_branch="${initial_branch}"
use_existing_branch=false
on_feature_branch=false

if [[ "${initial_branch}" == feature/* ]]; then
  on_feature_branch=true
fi

mapfile -t existing_branches < <(
  git for-each-ref --format='%(refname:short)' refs/heads |
    grep -vE '^(main|master|trunk)$' |
    grep -vF "${current_branch}"
)

if [[ "${on_feature_branch}" == false ]] && (( ${#existing_branches[@]} > 0 )); then
  read -r -p "Switch to an existing branch? [y/N]: " switch_choice
  if [[ "${switch_choice}" =~ ^[Yy]$ ]]; then
    echo "Available branches:"
    for i in "${!existing_branches[@]}"; do
      printf "  %d) %s\n" "$((i + 1))" "${existing_branches[$i]}"
    done
    read -r -p "Enter number or branch name: " selection
    target_branch=""
    if [[ "${selection}" =~ ^[0-9]+$ ]] && (( selection >= 1 && selection <= ${#existing_branches[@]} )); then
      target_branch="${existing_branches[$((selection - 1))]}"
    else
      target_branch="${selection}"
    fi

    if [[ -z "${target_branch}" ]]; then
      echo "Branch selection cannot be empty." >&2
      exit 1
    fi

    if git show-ref --verify --quiet "refs/heads/${target_branch}"; then
      git checkout "${target_branch}"
      current_branch="${target_branch}"
      use_existing_branch=true
    else
      echo "Branch '${target_branch}' does not exist locally." >&2
      exit 1
    fi
  fi
fi

skip_commit=false
case "${initial_branch}" in
  main|master|trunk)
    skip_commit=true
    ;;
esac

branch_name="${current_branch}"
if [[ "${on_feature_branch}" == false ]] && [[ "${use_existing_branch}" == false ]]; then
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
fi

if [[ "${skip_commit}" == true ]]; then
  echo "Started from '${initial_branch}'. Switched to '${branch_name}'. No commit or push performed."
  exit 0
fi

if [[ "${branch_name}" != feature/* ]]; then
  echo "Current branch '${branch_name}' is not a feature/ branch. No commit or push performed."
  exit 0
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
