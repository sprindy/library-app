# Team Agent Automation Secrets

To enable true account-level automation (Linus/Leon/Helen acting as their GitHub identities), add these repository secrets:

- `CODERLINUS_PAT`
- `LEONREVIEWER_PAT` (reserved for next phase)
- `TESTERHELEN_PAT` (reserved for next phase)

## Required scopes
For each PAT:
- `repo`
- `workflow`

## Current behavior implemented
With `CODERLINUS_PAT` configured:
1. Helen-reported issue gets triaged/routed to Linus.
2. On triage/assignment trigger, automation moves to `status:in-dev`.
3. Automation creates Linus branch scaffold, opens draft PR, and requests Leon + Helen reviewers.

Without `CODERLINUS_PAT`:
- Workflow posts warning comment and only updates labels/status.

## How to set secrets
GitHub repo → Settings → Secrets and variables → Actions → New repository secret.
