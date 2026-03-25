# Reviewer Checklist (Leon)

Use this checklist for bug-fix PR reviews (especially tester-reported defects).

## 1) Traceability
- [ ] PR links to exactly one primary defect issue (`Closes #...`)
- [ ] Severity and scope in issue match the PR intent
- [ ] Repro steps from tester are clear and complete

## 2) Correctness
- [ ] Change fixes the documented root cause
- [ ] Behavior now matches expected result in issue
- [ ] Error handling is explicit and user-safe
- [ ] No silent failures or swallowed errors without user feedback

## 3) Regression Risk
- [ ] Adjacent flows reviewed (create/update/delete/search/export as relevant)
- [ ] State management is consistent after failure/retry/cancel
- [ ] UI does not dismiss/lose data unexpectedly on failed operations

## 4) Test Quality
- [ ] Existing tests still pass
- [ ] New or updated tests cover the fix path where practical
- [ ] Manual tester validation is requested/completed for UX flows
- [ ] Build/test commands are included in PR evidence

## 5) Code Quality
- [ ] Naming and structure are clear
- [ ] Logic is minimal and focused (no unrelated refactor)
- [ ] No dead code / debug leftovers
- [ ] Error messages are actionable

## 6) Merge Gate
Approve only when all are true:
- [ ] CI/build/tests green
- [ ] Tester (Helen) signoff is PASS
- [ ] Defect acceptance criteria met

## Review Outcome
- [ ] APPROVE
- [ ] REQUEST CHANGES

Notes:
