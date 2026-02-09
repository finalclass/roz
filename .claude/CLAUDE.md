# Roz (rozpiska)

A CLI tool for managing development workflow across Gitea and GitHub repositories. It bridges the gap between issue tracking and Claude Code, enabling automated implementation cycles.

## What we're building

Roz manages a weekly development cycle:

1. **Ideas** - developer creates issues (one-liner ideas)
2. **Planning** - developer talks with Claude Code to flesh out the issue, Claude updates the issue description with technical details, checklists, labels
3. **Implementation** - Claude Code picks up planned issues, creates branches, implements, opens PRs
4. **Review** - developer reviews PRs on Gitea/GitHub, leaves comments
5. **Fixes** - roz detects new review comments, spawns Claude Code to address them
6. **Merge** - developer merges approved PRs throughout the week
7. **Deploy** - Monday morning, developer runs deploy

## Core features

### 1. Git forge auto-detection
Read the git remote URL and detect whether it's Gitea or GitHub. Use a unified interface so the rest of the code doesn't care which forge is behind it.

Supported forges:
- **Gitea** (e.g. `https://gitea.7willows.com/owner/repo`)
- **GitHub** (e.g. `https://github.com/owner/repo`)

### 2. Issue management (`roz issue`)
```bash
roz issue list                    # list open issues
roz issue list --milestone W07    # list issues in milestone
roz issue show 123                # show issue details
roz issue create "title"          # create new issue (idea)
roz issue update 123              # update issue body/labels/milestone
roz issue close 123               # close issue
```

### 3. PR management (`roz pr`)
```bash
roz pr list                       # list open PRs
roz pr show 123                   # show PR details + review comments
roz pr comments 123               # show only review comments
roz pr create --issue 45          # create PR linked to issue
```

### 4. Milestone/sprint management (`roz week`)
```bash
roz week plan                     # show current week's milestone
roz week report                   # generate status report for management
roz week create                   # create milestone for current week
```

### 5. Polling daemon (`roz watch`)
Runs as a background process. Polls the forge API periodically (configurable, default 30s) and reacts to events:

- **New review comments on open PRs** - spawns Claude Code to address them
- **New issues assigned to current milestone** - notifies or queues for planning

The daemon should:
- Be lightweight (single process, no heavy dependencies)
- Log what it does
- Be stoppable gracefully (SIGTERM/SIGINT)
- Not spawn multiple Claude Code instances for the same PR simultaneously
- Track what it has already processed (last seen comment ID, etc.)

### 6. Claude Code integration
When spawning Claude Code for PR fixes:
- Clone/checkout the correct branch
- Pass context: PR number, review comments, issue description
- Claude Code implements fixes, commits, pushes
- Roz detects the push happened and moves on

## Architecture

```
roz/
  cmd/           # CLI entrypoints
  forge/         # Forge abstraction layer
    forge.go     # Interface definition
    gitea.go     # Gitea API implementation
    github.go    # GitHub API implementation
    detect.go    # Auto-detection from git remote
  issue/         # Issue operations
  pr/            # PR operations
  week/          # Milestone/sprint operations
  watch/         # Polling daemon
  config/        # Configuration (tokens, defaults)
```

## Configuration

Config file: `~/.config/roz/config.toml`

```toml
[default]
poll_interval = 30  # seconds

[forge.gitea.gitea.7willows.com]
token = "..."

[forge.github.github.com]
token = "..."
```

Tokens are per-forge-instance so you can work with multiple Gitea/GitHub servers.

## Tech stack

- **Go** - single binary, no runtime dependencies, good for CLI + daemon
- No heavy frameworks - stdlib net/http for API calls, cobra or similar for CLI

## Labels convention

Issues use labels to track lifecycle:
- `idea` - raw idea, one-liner
- `planned` - fleshed out, has technical details and checklist
- `in-progress` - being implemented
- `review` - PR open, awaiting review
- `done` - merged and closed

## Milestone convention

Milestones represent weeks: `W07-2026`, `W08-2026`, etc.
Format: `W{ISO_WEEK}-{YEAR}`

### 7. Claude Code skill (`roz skill`)

Roz provides a Claude Code skill file that can be installed into any project. The skill gives Claude Code access to issue/PR operations without the developer having to explain the workflow each time.

```bash
roz skill install            # copies skill file to .claude/skills/ in current repo
roz skill install --global   # copies to ~/.claude/skills/
```

The skill file teaches Claude Code how to:
- Read and update issues (`roz issue show/update`)
- Read PR review comments (`roz pr comments`)
- Create branches and PRs following naming conventions
- Follow the issue lifecycle (labels, milestones)
- Run `roz` commands to interact with the forge

The skill is a markdown file that gets loaded by Claude Code when invoked. It should be self-contained - Claude Code doesn't need to know about roz internals, just the CLI interface.

Skill location: `skill/roz.md` in this repo (source of truth).

## Development rules

- Code and comments in English
- Keep it simple - this is a workflow tool, not a platform
- No over-abstraction - two implementations (Gitea, GitHub) don't need a plugin system
- Tests: integration tests against real API (with test repos) preferred over mocks
- Do not add Co-Authored-By attribution to commits
