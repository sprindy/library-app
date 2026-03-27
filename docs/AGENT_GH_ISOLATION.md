# Per-Agent GitHub Auth Isolation (single machine)

Use separate `GH_CONFIG_DIR` per role so Linus/Leon/Helen can each stay logged into different GitHub accounts.

## Launch a role shell

```bash
cd /Users/sprindy/.openclaw/workspace/library-app
./scripts/agent-shell.sh linus
# or: leon / helen
```

This opens a shell with:
- role workspace as cwd
- isolated `GH_CONFIG_DIR`
- repo-local git identity already configured

## First-time login in each role shell

```bash
gh auth login
gh auth status
```

## Verify separation

In each role shell:

```bash
echo $GH_CONFIG_DIR
gh auth status
git config user.name
git config user.email
```

You should see different `GH_CONFIG_DIR` and account identity per role.

## Suggested usage

- Linus shell: implement + open PR
- Leon shell: review + approve PR
- Helen shell: QA comments/validation

This enables real multi-account behavior without account switching conflicts.
