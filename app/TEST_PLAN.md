# TEST_PLAN

## Scope and Method
- Target: PR #20 for issue #19 (`Search still does not work after local test: cannot type keyword in search`)
- PR branch: `linus/issue-19-search-still-does-not-work-after-loc`
- Spec source: `../SPEC.md`
- Tester instructions: `../TASK_TESTER.md`
- Reviewer context: `./REVIEW_REPORT.md`
- Test date: 2026-04-02 (GMT+8)
- Environment: macOS terminal workspace with Xcode + SwiftPM; no GUI automation harness in this repo.

## Execution Evidence
```bash
# Build gate (from app/)
xcodebuild -scheme LibraryApp -destination 'platform=macOS' build
# Result: PASS

# Test gate (from app/)
xcodebuild -scheme LibraryApp -destination 'platform=macOS' test
# Result: PASS (11 passed, 0 failed)

# Focused regressions (from app/)
swift test --filter SearchFieldFocusTests
# Result: PASS (1 passed, 0 failed)

swift test --filter LibrarySearchTests
# Result: PASS (2 passed, 0 failed)

swift test --filter UICommandCenterTests
# Result: PASS (4 passed, 0 failed)
```

## Issue #19 Validation Matrix
| ID | Check | Expected Result | Actual Result | Status |
|---|---|---|---|---|
| I19-1 | Search action keeps typing focus | After triggering search action, user can immediately type more characters in search field | `Coordinator.performSearch(_:)` now calls `focusSearchFieldEditorForTyping(sender)` before syncing bound text | PASS |
| I19-2 | Caret placement after focus handoff | Caret lands at end of current search text to continue typing | `SearchFieldFocusTests.testFocusSearchFieldEditorForTypingMovesCaretToEnd` passes | PASS |
| I19-3 | Search filtering logic regression | Partial/case-insensitive title and author filtering remains correct | `LibrarySearchTests` pass | PASS |
| I19-4 | Command center regression | Search focus command path still posts/increments expected signals | `UICommandCenterTests` pass | PASS |

## P0 Scenario Coverage Snapshot
| P0 Scenario | Coverage Method in This Run | Status |
|---|---|---|
| 1. Add book with valid title/author | `PersistenceTests.testInsertAndFetchBookInMemoryContainer` | PASS |
| 2. Validation for missing title/author | Source inspection of `BookFormView.save()` required-field guards | PASS |
| 3. Search by partial title/author, case-insensitive | `SearchFieldFocusTests` + `LibrarySearchTests` + issue-specific event-path inspection | PASS |
| 4. Update status (To Read -> Reading -> Finished) | `PersistenceTests.testStatusUpdatePersistsInMemoryContainer` | PASS |
| 5. Delete with confirmation | Source inspection of confirmation dialog + delete path in `ContentView` | PASS |
| 6. Relaunch app and confirm data persistence | Unit-level persistence checks only (no full relaunch automation in terminal run) | PARTIAL |
| 7. CSV export success + file content check | `CSVExporterTests` verifies CSV output content/escaping | PASS |

## Summary
- PR #20 build/test gates pass, and the new focus handoff logic for search typing is covered by a dedicated test.
- No reproducible defect was found in issue #19 scope.
- Limitation: full GUI click choreography and relaunch behavior are not directly automated in this terminal-only run.
