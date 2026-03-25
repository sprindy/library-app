# CONTRIBUTING.md

## Team Workflow (Linus, Leon, Helen)

This repo uses a **real-author workflow** so PRs and commits show the correct contributor identity on GitHub.

Contributors:
- Linus
- Leon
- Helen

---

## 1) One-time Git setup per teammate

Each teammate should set their own git identity (global or per-repo).

### Option A: Global (all repos)
```bash
git config --global user.name "Linus"
git config --global user.email "LINUS_GITHUB_NOREPLY_EMAIL"
```

### Option B: Per-repo (recommended if sharing one machine)
```bash
cd /path/to/library-app
git config user.name "Linus"
git config user.email "LINUS_GITHUB_NOREPLY_EMAIL"
```

Repeat for each person:

```bash
# Leon
git config user.name "Leon"
git config user.email "LEON_GITHUB_NOREPLY_EMAIL"

# Helen
git config user.name "Helen"
git config user.email "HELEN_GITHUB_NOREPLY_EMAIL"
```

Verify:
```bash
git config --get user.name
git config --get user.email
```

---

## 2) GitHub noreply email format

Use an email linked to the contributor’s GitHub account.

Preferred private format (from GitHub Email settings):
- `12345678+username@users.noreply.github.com`

Legacy format (some accounts):
- `username@users.noreply.github.com`

To find it:
- GitHub → **Settings** → **Emails** → copy your noreply email
- Keep **“Keep my email addresses private”** enabled if preferred.

> If email is not linked to the GitHub account, commit attribution will fail.

---

## 3) Authentication (CLI)

Each person should authenticate as themselves:
```bash
gh auth login
gh auth status
```

If sharing one machine, confirm active account before pushing:
```bash
gh auth status
```

---

## 4) Branch + PR flow (recommended)

### Step 1: sync main
```bash
git checkout main
git pull origin main
```

### Step 2: create feature branch
Branch naming convention:
- `feat/<name>-<topic>`
- `fix/<name>-<topic>`
- `docs/<name>-<topic>`

Examples:
```bash
git checkout -b feat/linus-search-improvements
git checkout -b fix/leon-save-error-handling
git checkout -b docs/helen-test-rerun-report
```

### Step 3: commit with clear message
```bash
git add .
git commit -m "feat(search): improve partial match ranking"
```

### Step 4: push branch
```bash
git push -u origin <your-branch-name>
```

### Step 5: open PR
```bash
gh pr create \
  --base main \
  --head <your-branch-name> \
  --title "feat: short summary" \
  --body "## What\n- ...\n\n## Why\n- ...\n\n## Test\n- ..."
```

---

## 5) Co-authors (when pairing)

If one person commits code authored by multiple teammates, add co-author trailers:

```text
Co-authored-by: Linus <LINUS_GITHUB_NOREPLY_EMAIL>
Co-authored-by: Leon <LEON_GITHUB_NOREPLY_EMAIL>
Co-authored-by: Helen <HELEN_GITHUB_NOREPLY_EMAIL>
```

Example:
```bash
git commit -m "feat: implement save retry UX

Co-authored-by: Linus <LINUS_GITHUB_NOREPLY_EMAIL>
Co-authored-by: Helen <HELEN_GITHUB_NOREPLY_EMAIL>"
```

This preserves visible contribution credit even if committer differs.

---

## 6) Shared-machine quick switch script

If multiple teammates use one machine, run one of these before committing:

```bash
# Linus
git config user.name "Linus"
git config user.email "LINUS_GITHUB_NOREPLY_EMAIL"
gh auth status

# Leon
git config user.name "Leon"
git config user.email "LEON_GITHUB_NOREPLY_EMAIL"
gh auth status

# Helen
git config user.name "Helen"
git config user.email "HELEN_GITHUB_NOREPLY_EMAIL"
gh auth status
```

Optional check before each commit:
```bash
echo "git user: $(git config --get user.name) <$(git config --get user.email)>"
```

---

## 7) Avoid attribution mistakes

- Do not commit with placeholder emails.
- Do not use another teammate’s authenticated `gh` session.
- Always verify `git config user.*` before commit.
- Prefer separate branches per contributor.
- Use co-author trailers for pair/mob contributions.

---

## 8) Repo maintainers: merge strategy notes

- **Squash merge** is fine; co-author trailers still appear in the squashed commit if included.
- If preserving individual commit history matters, use **rebase merge** or **merge commit**.

---

## 9) Team checklist (copy/paste)

Before opening PR:
- [ ] `git config --get user.name` is correct
- [ ] `git config --get user.email` is linked to your GitHub account
- [ ] `gh auth status` shows your own account
- [ ] Branch name follows convention
- [ ] Tests/docs updated as needed
- [ ] Co-author trailers added if needed
