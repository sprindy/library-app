# SPEC.md — macOS Library App (MVP)

## 1) Goal
Build a local-first macOS app to manage a personal book library with fast add/search/status tracking.

## 2) In Scope (Must Have)
1. Add a book with:
   - Title (required)
   - Author (required)
   - Status (`To Read`, `Reading`, `Finished`)
   - Optional notes
2. List all books (default sort by updated date desc)
3. Search books by title/author (case-insensitive contains)
4. Update status from list/detail
5. Delete a book (with confirmation)
6. Persist data locally (SwiftData preferred; Core Data acceptable)
7. Export current library to CSV

## 3) Out of Scope (Round 1)
- Cloud sync / iCloud
- User accounts / auth
- External ISBN APIs
- Tags, ratings, cover image scraping
- iOS version

## 4) Tech Constraints
- Language: Swift 5.9+
- UI: SwiftUI
- Platform: macOS 14+
- Storage: SwiftData (preferred) or Core Data
- Testing: XCTest (unit) + lightweight UI smoke checks if feasible

## 5) UX Requirements
- Native macOS look and feel
- Primary navigation: Sidebar/List + Detail OR simple split view
- Keyboard-friendly:
  - Cmd+N: New book
  - Cmd+F: Focus search
- Empty state for no books
- Validation errors should be explicit and non-crashing

## 6) Data Model (minimum)
Book
- id: UUID
- title: String
- author: String
- status: enum {toRead, reading, finished}
- notes: String?
- createdAt: Date
- updatedAt: Date

## 7) Acceptance Criteria (Definition of Done)
- App builds and launches via xcodebuild
- Can add/edit/delete/search books reliably
- Status changes persist after relaunch
- CSV export works and file opens in Numbers/Excel
- Unit tests cover model + basic persistence + search logic
- README includes build/run/test instructions

## 8) Quality Gates (must pass)
1. Build gate:
   - `xcodebuild -scheme LibraryApp -destination 'platform=macOS' build`
2. Test gate:
   - `xcodebuild -scheme LibraryApp -destination 'platform=macOS' test`
3. Review gate:
   - No unresolved blocker issues from reviewer
4. Tester gate:
   - All P0 flows pass (add/search/update/delete/export)

## 9) Deliverables
- Working Xcode project
- Source code
- Tests
- `README.md`
- `TEST_PLAN.md`
- `BUG_REPORT.md` (if defects found)

## 10) Stretch (only if all must-have done)
- Import from CSV
- Filter by status
- Basic reading progress field
