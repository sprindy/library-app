# BUG_REPORT

## Open Defects

### LIB-S2-001
- Severity: **S2 High**
- Title: Add-book sheet dismisses even when persistence save fails, risking data loss
- Environment: macOS sandbox code review (2026-03-24), source-level validation
- Preconditions: `BookFormView` add sheet is open, persistence layer returns an error on save
- Repro Steps:
1. Open Add Book sheet.
2. Enter valid title/author and optional notes.
3. Trigger a save-path failure (for example via fault injection/stubbed `ModelContext.save()` failure condition).
4. Click `Save`.
- Expected: Save failure is shown and add form remains open with entered values intact so user can retry.
- Actual: Form calls `dismiss()` immediately after `onSave`, regardless of save result; save failure alert occurs in parent view after form closure.
- Evidence:
  - `BookFormView.save()` always dismisses after `onSave`: `LibraryApp/Views/BookFormView.swift:82-87`
  - Save errors are surfaced later in `ContentView.persistChanges(...)`: `LibraryApp/Views/ContentView.swift:203-208`
- User Impact: User can lose unsaved input if persistence fails.
- Status: **OPEN**
- Owner: Development

## Non-Defect Test Blockers (Environment)

### TB-ENV-001
- Type: Environment/tooling blocker
- Description: Mandatory build/test gates cannot be executed in this sandbox.
- Evidence:
1. `cd app && xcodebuild -scheme LibraryApp -destination 'platform=macOS' build` -> failed (package/project resolution + simulator/log access issues in sandbox).
2. `cd app && xcodebuild -scheme LibraryApp -destination 'platform=macOS' test` -> failed for same reasons.
3. `cd app && swift test` -> failed (module cache write denied under sandbox, manifest compile blocked).
- Impact: End-to-end release confidence is limited; P0 execution is blocked.

## Open Severity Totals
- S1: **0**
- S2: **1**
