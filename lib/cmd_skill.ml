let skill_content = {|# Roz - Development Workflow Skill

You have access to the `roz` CLI tool for managing issues and PRs across Gitea and GitHub.

## Commands

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
- `roz week create` - create milestone for current week (interactive TUI)

### Info
- `roz info` - show detected forge and repo info

## Workflow

### Labels lifecycle
`idea` → `planned` → `in-progress` → `review` → `done`

### Branch naming
`issue-{number}-{slug}`, e.g. `issue-45-add-login-page`

### PR conventions
- PR title: `#{issue_number} {description}`
- PR body should contain `Closes #{issue_number}`

## Task: "Sprawdź co jest do zrobienia" / "What needs to be done?"

When asked to check what needs to be done, follow this priority order:

### 1. PRs needing fixes (highest priority)
```bash
roz pr list
```
For each open PR, check for review comments:
```bash
roz pr comments <number>
```
If there are unaddressed review comments — these need fixing first. See "Fix PR review comments" below.

### 2. PRs ready to merge
Check if any open PRs have no pending review comments and are approved. Report them to the developer — they decide when to merge.

### 3. Bugs (critical — before any new features)
```bash
roz issue list --label bug
```
If there are ANY open issues labeled `bug`, they must be fixed before working on new features or planned issues. Bugs have priority regardless of milestone — even if a bug is not assigned to the current week, fix it first.

### 4. Issues ready for implementation
```bash
roz week plan
```
Look for issues labeled `planned` — these are fleshed out and ready to implement. Pick the first one that isn't `in-progress` yet.

### 5. Issues needing planning
Look for issues labeled `idea` in the current milestone — these need technical details, checklists, and acceptance criteria before implementation.

## Task: "Popraw PR #N" / "Fix PR #N"

1. Read the review comments:
   ```bash
   roz pr comments <N>
   ```
2. Read the PR details to understand context:
   ```bash
   roz pr show <N>
   ```
3. Checkout the PR branch:
   ```bash
   git checkout <branch-name>
   ```
4. Read each review comment carefully
5. Make the requested changes
6. Commit and push:
   ```bash
   git add <changed-files>
   git commit -m "Address review comments on PR #<N>"
   git push
   ```

## Task: "Zaimplementuj issue #N" / "Implement issue #N"

1. Read the issue:
   ```bash
   roz issue show <N>
   ```
2. Create a branch:
   ```bash
   git checkout -b issue-<N>-<slug>
   ```
3. Update issue label:
   ```bash
   roz issue update <N> --add-label in-progress --remove-label planned
   ```
4. Implement the changes described in the issue
5. Commit, push, and create PR:
   ```bash
   git push -u origin issue-<N>-<slug>
   roz pr create --issue <N>
   ```
6. Update issue label:
   ```bash
   roz issue update <N> --add-label review --remove-label in-progress
   ```

## Task: "Zaplanuj issue #N" / "Plan issue #N"

1. Read the current issue:
   ```bash
   roz issue show <N>
   ```
2. Discuss with the developer what needs to be done
3. Update the issue with technical details, implementation plan, and checklist:
   ```bash
   roz issue update <N> --body-file plan.md --add-label planned --remove-label idea
   ```
|}

let install ~global () =
  let target_dir =
    if global then
      let home = Sys.getenv "HOME" in
      Filename.concat home ".claude/skills"
    else
      ".claude/skills"
  in
  (try Unix.mkdir target_dir 0o755 with Unix.Unix_error (Unix.EEXIST, _, _) -> ());
  let target = Filename.concat target_dir "roz.md" in
  let oc = open_out target in
  output_string oc skill_content;
  close_out oc;
  Printf.printf "Installed skill to %s\n" target
