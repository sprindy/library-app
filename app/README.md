# LibraryApp (MVP)

Local-first macOS SwiftUI app for managing a personal book library.

## Features
- Add books with title, author, status, and optional notes
- List books sorted by `updatedAt` descending
- Search by title or author (case-insensitive contains)
- Update status from list and detail views
- Delete books with confirmation
- Persist data locally using SwiftData
- Export library to CSV

## Project Layout
- `LibraryApp/` app source
- `LibraryAppTests/` unit tests
- `Package.swift` package manifest

## Build (Spec Gate)
```bash
xcodebuild -scheme LibraryApp -destination 'platform=macOS' build
```

## Test (Spec Gate)
```bash
xcodebuild -scheme LibraryApp -destination 'platform=macOS' test
```

## Run
1. Open the `app/` package in Xcode.
2. Select macOS run destination.
3. Run the `LibraryApp` scheme.

## Keyboard Shortcuts
- `Command-N`: New book
- `Command-F`: Focus search field

## Notes
This workspace environment does not currently provide a working Xcode toolchain (`xcodebuild` unavailable) and has a Swift/SDK mismatch for CLI compilation, so local build/test verification must be run on a machine with a valid Xcode setup.
