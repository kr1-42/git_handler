# git-handler

A Bash utility to streamline Git workflows with feature branch management, repository initialization, and convenient commit/push operations.

## Features

- **Feature branch workflow** — Automatically creates `feature/` prefixed branches
- **Repository initialization** — Set up a new repo and push to remote in one command
- **Move changes to branch** — Rescue uncommitted or committed work from `main`/`master` to a new branch
- **Interactive branch selection** — Switch between existing branches easily

## Requirements

- Bash 4.0+
- Git

## Installation

### User Installation (no root required)

```bash
./install.sh
```

This installs the script to `~/git_handler/git-handler.sh` and adds an alias to your `~/.bashrc`:

```bash
alias git-handler="bash ~/git_handler/git-handler.sh"
```

Reload your shell or run `source ~/.bashrc` to use the alias.

### System-wide Installation (requires root)

```bash
sudo ./install.sh
```

Installs to `/usr/bin/git-handler`.

## Usage

### Default Workflow (Feature Branch)

```bash
git-handler
```

When run without arguments inside a Git repository:

1. If on `main`/`master`/`trunk`, prompts you to:
   - Switch to an existing branch, or
   - Create a new `feature/<name>` branch
2. If already on a `feature/*` branch, prompts for a commit message, commits all changes, and pushes to origin.

**Example:**

```
$ git-handler
Switch to an existing branch? [y/N]: n
Enter branch name (without 'feature/'): add-login
# Creates feature/add-login, switches to it
# If not on main/master, prompts for commit and pushes
```

### Initialize Repository

```bash
git-handler --init <repo_url>
```

Sets up a new or existing directory as a Git repository and pushes to the specified remote.

**What it does:**

1. Runs `git init` if not already a repository
2. Adds or updates the `origin` remote
3. Prompts for an initial commit message (if no commits exist)
4. Pushes to origin

**Example:**

```bash
git-handler --init git@github.com:user/my-repo.git
```

### Move Changes to a New Branch

```bash
git-handler --move-to-branch
```

Moves uncommitted changes and/or local commits from your current branch to a new branch. Useful when you accidentally made changes on `main`/`master`.

**What it does:**

1. Detects uncommitted changes and commits ahead of upstream
2. Prompts for a new branch name
3. Creates and switches to the new branch (preserving uncommitted changes)
4. Optionally resets the original branch to match upstream (removing the commits from it)

**Example:**

```
$ git-handler --move-to-branch
Enter new branch name: feature/my-work
Reset 'main' to 'origin/main' (drops 2 commit(s) from main)? [y/N]: y
Moved commits to 'feature/my-work' and reset 'main' to 'origin/main'.
```

## Workflow Summary

| Scenario | Command |
|----------|---------|
| Start a new feature branch | `git-handler` |
| Commit and push on a feature branch | `git-handler` |
| Initialize a new repo | `git-handler --init <url>` |
| Move accidental work off main | `git-handler --move-to-branch` |

## Branch Naming Convention

The script enforces a `feature/` prefix for new branches. When prompted for a branch name, enter only the suffix:

```
Enter branch name (without 'feature/'): user-authentication
# Creates: feature/user-authentication
```

## Protected Branches

The script treats `main`, `master`, and `trunk` as protected branches:
- Won't commit directly to these branches
- Prompts to create/switch to a feature branch instead

## License

MIT
