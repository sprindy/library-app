## Summary
- Fixes: Closes #<issue_number>
- Defect ID: `LIB-Sx-xxx`

## Root Cause
- 

## What Changed
- 
- 

## Risk & Rollback
- **Risk level:** `Low | Medium | High`
- **Potential side effects:**
- **Rollback plan:** revert this PR commit(s)

## Test Evidence
### Automated
- [ ] `xcodebuild -scheme LibraryApp -destination 'platform=macOS' build`
- [ ] `xcodebuild -scheme LibraryApp -destination 'platform=macOS' test`
- [ ] `swift test`

### Manual Repro Validation (by Tester)
- [ ] Original repro steps no longer fail
- [ ] Error handling UX is correct
- [ ] Regression checks completed

## Virtual Ownership (Label-based)
- **Coder:** Linus (`role:coder-linus`)
- **Reviewer:** Leon (`role:reviewer-leon`)
- **Tester:** Helen (`role:tester-helen`)
- **Status label:** `status:in-review` while PR is open

## Reviewer Checklist
- [ ] Linked issue is correct and complete
- [ ] Fix addresses root cause (not just symptom)
- [ ] Error path is safe and does not lose user data
- [ ] Tests are added/updated appropriately
- [ ] No obvious regressions in related flows
- [ ] Code readability/maintainability acceptable

## Tester Signoff (Helen)
- [ ] PASS
- [ ] FAIL (explain below)

Tester notes:


## Reviewer Signoff (Leon)
- [ ] APPROVE
- [ ] REQUEST CHANGES (explain below)

Reviewer notes:
