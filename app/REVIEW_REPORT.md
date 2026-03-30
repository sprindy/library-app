# REVIEW_REPORT

## 1) Verdict
BLOCKED (`REQUEST_CHANGES` for PR #9)

## 2) Blockers (if any)
1. PR branch does not compile due invalid command group placement.
   - File: `app/LibraryApp/LibraryAppApp.swift:22`
   - Code: `CommandGroup(replacing: .find)`
   - Error from build/test gate: `type 'CommandGroupPlacement' has no member 'find'`
   - Impact: app cannot build or test; issue fix cannot be validated.

## 3) High/Medium/Low findings

### High
1. No regression coverage for command-based search focus behavior.
   - This PR changes command routing/focus behavior but adds no tests or UI smoke evidence for `Cmd+F` and menu action behavior.

### Medium
1. `focusSearchField()` uses async re-focus (`Task { @MainActor ... }`) but there is no behavioral coverage for repeated command taps or sheet-open states.
   - Risk is moderate because behavior is timing-sensitive and this code path was changed specifically for reliability.

### Low
1. None.

## 4) Spec coverage matrix (feature -> status)
- Add a book -> UNCHANGED by this PR
- List books -> UNCHANGED by this PR
- Search books by title/author -> BLOCKED (build failure prevents validation)
- Update status -> UNCHANGED by this PR
- Delete a book with confirmation -> UNCHANGED by this PR
- Persist data locally -> UNCHANGED by this PR
- Export current library to CSV -> UNCHANGED by this PR
- Keyboard shortcuts (`Cmd+N`, `Cmd+F`) -> BLOCKED (`Cmd+F` command implementation fails to compile)

## 5) Required fixes before tester sign-off
1. Replace `CommandGroup(replacing: .find)` with a valid SwiftUI command placement/menu strategy that compiles on target toolchain.
2. Re-run and post passing gate results:
   - `xcodebuild -scheme LibraryApp -destination 'platform=macOS' build`
   - `xcodebuild -scheme LibraryApp -destination 'platform=macOS' test`
3. Add verification for the changed search-focus behavior (automated or documented manual smoke steps) to reduce regression risk.

## 6) Checks run (this review)
1. `xcodebuild -scheme LibraryApp -destination 'platform=macOS' build` (from `app/`) -> FAIL  
   - `LibraryAppApp.swift:22:38: error: type 'CommandGroupPlacement' has no member 'find'`
2. `xcodebuild -scheme LibraryApp -destination 'platform=macOS' test` (from `app/`) -> FAIL  
   - Same compile error; tests not executed due build failure.

## 7) Submission status
1. Intended PR action: `REQUEST_CHANGES` on PR #9 as `LeonReviewer`.
2. Intended issue marker comment:
   - `[leon-review-submitted:v1] verdict: REQUEST_CHANGES next_action: replace invalid CommandGroup placement, rerun build/test, and re-request review.`
3. Actual result in this environment:
   - `gh pr review 9 --request-changes ...` -> `GraphQL: Resource not accessible by personal access token (addPullRequestReview)`
   - `gh api -X POST repos/sprindy/library-app/issues/8/comments ...` -> `HTTP 403 Resource not accessible by personal access token`
