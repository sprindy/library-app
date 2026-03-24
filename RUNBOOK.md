# RUNBOOK.md — Multi-Agent Execution Plan (Coder → Reviewer → Tester)

This runbook is the exact sequence to run your 3-agent test with minimal drift.

## Paths
- Pack root: `/Users/sprindy/.openclaw/workspace/agent-packs/library-app`
- Spec: `/Users/sprindy/.openclaw/workspace/agent-packs/library-app/SPEC.md`
- Coder task: `/Users/sprindy/.openclaw/workspace/agent-packs/library-app/TASK_CODER.md`
- Reviewer task: `/Users/sprindy/.openclaw/workspace/agent-packs/library-app/TASK_REVIEWER.md`
- Tester task: `/Users/sprindy/.openclaw/workspace/agent-packs/library-app/TASK_TESTER.md`

---

## 0) Preflight (Orchestrator)
Before spawning anyone:
1. Confirm spec exists and is frozen for this run.
2. Confirm output folder is clean enough:
   - `./app/` can exist, but avoid stale artifacts from old tests.
3. Decide strict policy:
   - Reviewer can block
   - Tester can fail release

Recommended one-liner to track run ID in notes:
- `RUN_ID=library-macos-$(date +%Y%m%d-%H%M)`

---

## 1) Spawn Coder (Build Phase)

### Coder Prompt (copy/paste)
You are the coder agent for a multi-agent workflow.
Working directory: `/Users/sprindy/.openclaw/workspace/agent-packs/library-app`
Read and follow exactly:
1) `SPEC.md`
2) `TASK_CODER.md`
Do not expand scope. Implement MVP and produce required artifacts under `./app/`.
Return a concise completion summary with exact artifact paths.

### Coder Exit Criteria
Must produce:
- `./app/LibraryApp/` (project/source)
- `./app/LibraryAppTests/`
- `./app/README.md`
- `./app/HANDOFF_CODER.md`

If coder is blocked, do not continue to reviewer/tester.

---

## 2) Spawn Reviewer (Quality Gate)
Trigger only after coder completes.

### Reviewer Prompt (copy/paste)
You are the reviewer agent for a multi-agent workflow.
Working directory: `/Users/sprindy/.openclaw/workspace/agent-packs/library-app`
Read and follow exactly:
1) `SPEC.md`
2) `TASK_REVIEWER.md`
3) `./app/HANDOFF_CODER.md`
Review coder output under `./app/`. Do not rewrite the app unless explicitly required.
Produce `./app/REVIEW_REPORT.md` and return verdict summary.

### Reviewer Gate Logic
- If verdict is `BLOCKED`: route findings back to coder for fixes.
- If verdict is `PASS WITH NOTES`: proceed to tester, but keep notes as known risks.
- If verdict is `PASS`: proceed to tester.

---

## 3) Spawn Tester (Validation Gate)
Trigger after reviewer report is available.

### Tester Prompt (copy/paste)
You are the tester agent for a multi-agent workflow.
Working directory: `/Users/sprindy/.openclaw/workspace/agent-packs/library-app`
Read and follow exactly:
1) `SPEC.md`
2) `TASK_TESTER.md`
3) `./app/REVIEW_REPORT.md` (if present)
Validate app flows and produce:
- `./app/TEST_PLAN.md`
- `./app/BUG_REPORT.md`
- `./app/TEST_SIGNOFF.md`
Return verdict with P0 pass rate and open S1/S2 bug counts.

### Tester Gate Logic
- If any open S1/S2 bug: status = FAIL (route back to coder)
- If all P0 pass and no open S1/S2: status = PASS

---

## 4) Fix Loop (When Needed)
If reviewer/tester returns blockers:
1. Send coder only the delta fixes (not full re-implementation).
2. Require coder to update `HANDOFF_CODER.md` with "Fix Round N" section.
3. Re-run reviewer (focused) then tester regression.

Stop conditions:
- Max 3 fix rounds for this experiment, OR
- Quality gates pass.

---

## 5) Final Sign-off Template (Orchestrator)
Use this summary format after completion:

- Run ID: `<RUN_ID>`
- Build status: PASS/FAIL
- Review verdict: PASS / PASS WITH NOTES / BLOCKED
- Test verdict: PASS/FAIL
- P0 pass rate: `x/7`
- Open critical defects (S1/S2): `n`
- Artifacts:
  - Spec: `/Users/sprindy/.openclaw/workspace/agent-packs/library-app/SPEC.md`
  - Code: `/Users/sprindy/.openclaw/workspace/agent-packs/library-app/app/`
  - Review: `/Users/sprindy/.openclaw/workspace/agent-packs/library-app/app/REVIEW_REPORT.md`
  - Test plan: `/Users/sprindy/.openclaw/workspace/agent-packs/library-app/app/TEST_PLAN.md`
  - Bugs: `/Users/sprindy/.openclaw/workspace/agent-packs/library-app/app/BUG_REPORT.md`
  - Signoff: `/Users/sprindy/.openclaw/workspace/agent-packs/library-app/app/TEST_SIGNOFF.md`

---

## 6) Optional: Parallelization Variant (for stress tests)
If you want to stress orchestration quality:
- Keep coder first (mandatory).
- Then run reviewer + tester in parallel using same coder output.
- Compare mismatch rates in findings.

This is useful for evaluating agent consistency, not for fastest shipping.
