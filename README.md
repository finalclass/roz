# roz

CLI tool for managing development workflow across Gitea and GitHub. Bridges issue tracking and Claude Code for automated implementation cycles.

## Install

Requires OCaml 5.4+ and dune 3.17+.

```bash
git clone git@github.com:finalclass/roz.git
cd roz
dune pkg lock
dune build
ln -sf "$(pwd)/_build/default/bin/main.exe" ~/.local/bin/roz
```

## Configuration

Create `~/.config/roz/config.toml`:

```toml
[default]
poll_interval = 30

[forge.github."github.com"]
token = "github_pat_..."

[forge.gitea."gitea.7willows.com"]
token = "your-gitea-token"
```

### Getting tokens

**GitHub**: Settings → Developer settings → Fine-grained tokens → permissions: Issues (RW), Pull requests (RW), Metadata (R)

**Gitea**: Settings → Applications → Manage Access Tokens → permissions: issue (RW), repository (R)

## Usage

### Info

```bash
roz info                    # show detected forge, owner, repo, token status
```

### Issues

```bash
roz issue list                                    # list open issues
roz issue list --label planned --milestone W07-2026
roz issue show 123                                # show issue details
roz issue create "Add login page"                 # create issue
roz issue create "Fix bug" --label idea --milestone W07-2026
roz issue update 123 --body "new description"
roz issue update 123 --body-file plan.md          # body from file
roz issue update 123 --add-label planned --remove-label idea
roz issue update 123 --milestone W07-2026
roz issue close 123
```

### Pull requests

```bash
roz pr list                       # list open PRs
roz pr show 123                   # show PR details
roz pr comments 123               # show review comments
roz pr create --issue 45          # create PR linked to issue
roz pr create --issue 45 --branch feature --base main --draft
```

### Weekly milestones

```bash
roz week plan                     # show current week's issues
roz week plan --week W07-2026     # specific week
roz week report                   # status report for management
roz week create                   # interactive TUI to select issues from backlog
roz week create --empty           # create empty milestone
roz week create --issues 34,37,41 # assign specific issues
```

### Watch daemon

Polls for new PR review comments and spawns Claude Code to address them.

```bash
roz watch                         # start daemon (default 30s interval)
roz watch --interval 60           # custom poll interval
roz watch --once                  # single check, then exit
roz watch --dry-run               # show what would happen
```

Stop with `Ctrl+C`.

### Claude Code skill

Install a skill file that teaches Claude Code how to use roz:

```bash
roz skill install                 # to .claude/skills/ in current repo
roz skill install --global        # to ~/.claude/skills/
```

## Workflow

1. **Ideas** — `roz issue create "one-liner idea"`
2. **Planning** — flesh out with Claude Code, `roz issue update 123 --add-label planned`
3. **Implementation** — Claude Code creates branch, implements, `roz pr create --issue 123`
4. **Review** — developer reviews PR, leaves comments
5. **Fixes** — `roz watch` detects comments, spawns Claude Code to fix
6. **Merge** — developer merges approved PRs
7. **Deploy** — Monday morning

## Labels convention

`idea` → `planned` → `in-progress` → `review` → `done`

## Milestone convention

`W{ISO_WEEK}-{YEAR}`, e.g. `W07-2026`

## Branch naming

`issue-{number}-{slug}`, e.g. `issue-45-add-login-page`
