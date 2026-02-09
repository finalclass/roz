# Roz - Development Workflow Skill

You have access to the `roz` CLI tool for managing issues and PRs.

## Available commands

### Issues
- `roz issue list` - list open issues
- `roz issue list --label planned --milestone W07-2026` - filter issues
- `roz issue show 123` - show issue details
- `roz issue create "title"` - create new issue
- `roz issue update 123 --body-file plan.md` - update issue body from file
- `roz issue update 123 --add-label planned --remove-label idea` - manage labels
- `roz issue update 123 --milestone W07-2026` - assign to milestone
- `roz issue close 123` - close issue

### Pull Requests
- `roz pr list` - list open PRs
- `roz pr show 123` - show PR details
- `roz pr comments 123` - show review comments
- `roz pr create --issue 45` - create PR linked to issue

### Week/Sprint
- `roz week plan` - show current week's milestone
- `roz week report` - generate status report
- `roz week create` - create milestone for current week

### Info
- `roz info` - show detected forge and repo info

## Workflow

1. Issues start with label `idea`
2. After planning, change label to `planned`
3. During implementation, change to `in-progress`
4. After opening PR, change to `review`
5. After merge, change to `done`

## Branch naming

Use: `issue-{number}-{slug}`, e.g. `issue-45-add-login-page`

## PR conventions

- PR title: `#{issue_number} {description}`
- PR body should contain `Closes #{issue_number}`
