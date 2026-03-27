# Team Workflow (Linus / Leon / Helen)

This repo supports a 3-agent delivery chain with real code workspaces.

## Local Workspaces

- Linus: `/Users/sprindy/.openclaw/workspace/agent-workspaces/linus/library-app`
- Leon: `/Users/sprindy/.openclaw/workspace/agent-workspaces/leon/library-app`
- Helen: `/Users/sprindy/.openclaw/workspace/agent-workspaces/helen/library-app`

Each workspace has repo-local git identity configured:

- Linus → `Linus Coder <coder.linus@protonmail.com>`
- Leon → `LeonReviewer <leon.reviewer@protonmail.com>`
- Helen → `TesterHelen <tester.helen@protonmail.com>`

## Role Responsibilities

- **Helen (Tester)**: reports defects, validates fixes in QA, confirms close.
- **Linus (Coder)**: implements fix, opens PR, addresses review comments.
- **Leon (Reviewer)**: reviews code quality, approves or requests changes.

## Branch & PR Convention

- Branch naming:
  - Linus: `linus/issue-<id>-<short-slug>`
  - Leon: `leon/<topic>` (if needed for review tooling/docs)
  - Helen: `helen/<topic>` (if needed for test artifacts)
- PR title:
  - `fix: <summary> (#<issue>)`
- PR body must include closing keyword, e.g.:
  - `Fixes #6`

## Automation Expectations

Current workflows implement:

1. Tester-source issue opened/reopened:
   - normalize role labels
   - assign Linus
   - kickoff comment
   - move status to `status:in-dev`
2. PR opened for linked tester-flow issue:
   - request reviewers (Leon + Helen)
   - move issue to `status:in-review`
3. Leon approval:
   - move issue to `status:qa`
4. PR merged:
   - move issue to `status:done`

## GitHub Account Auth (Required)

Each role should authenticate `gh` with its own account before creating reviews/PRs:

```bash
# example in that role workspace
cd /Users/sprindy/.openclaw/workspace/agent-workspaces/linus/library-app
gh auth login
```

Verify current account:

```bash
gh auth status
```

## Daily Loop

1. Helen files/updates issue (`source:tester`).
2. Linus pulls latest main, creates feature branch, pushes fix PR with `Fixes #<issue>`.
3. Leon reviews and approves.
4. Helen validates QA.
5. Merge PR; automation finalizes status/close.
