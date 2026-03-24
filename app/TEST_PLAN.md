# TEST_PLAN

## P0 Flows
1. Add a new book with valid required fields.
2. Validate required field errors for empty title/author.
3. Search by title and author with case-insensitive partial matches.
4. Change status from list row and from detail panel.
5. Delete a book and confirm it is removed.
6. Relaunch app and verify persisted state.
7. Export CSV and open in Numbers/Excel.

## Unit Tests
- `LibrarySearchTests`
- `CSVExporterTests`
- `PersistenceTests`

## Commands
```bash
xcodebuild -scheme LibraryApp -destination 'platform=macOS' build
xcodebuild -scheme LibraryApp -destination 'platform=macOS' test
```
