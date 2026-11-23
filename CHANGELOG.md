# Changelog

All notable changes to Ordino are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-11-23

Achievement 2: The First Rule.

### Added
- `Rule`, `Condition`, `RuleAction` and `WatchedFolder` models with a stable,
  documented JSON format. Unknown condition or action types are rejected.
- `Evaluator` with name conditions (is, is not, contains, does not contain,
  starts with, ends with, matches pattern) and extension conditions (is,
  is not, is one of). Case-insensitive by default and Unicode-aware. Empty
  values, empty groups and invalid patterns never match.
- Move action: name conflicts become `test 2.pdf`, `test 3.pdf`… using an
  exclusive rename, so nothing is ever overwritten. Moves to another volume
  copy, verify, then send the original to the Trash.
- A test rule defined in code (PDFs → a destination folder the user picks,
  saved as a bookmark), and moves shown in the Activity Log with where each
  file went.
- Watched folders and their rules are saved; v0.1.0 installs are migrated.

## [0.1.0] - 2026-11-23

Achievement 1: The Watcher.

### Added
- Choose a folder to watch from the menu bar. Access is saved as a
  security-scoped bookmark and restored on every launch without asking again;
  a moved folder is found again, and a folder that can't be reached is kept
  and the menu asks to choose it again.
- `FolderWatcher` on FSEvents, reporting new, changed, renamed and removed
  items directly inside the watched folder.
- `StabilityChecker`: an item is only reported once it has stopped changing,
  so files still being copied or downloaded are reported once, when finished.
  Partial downloads (`.crdownload`, `.download`, `.part`) and hidden files are ignored.
- Activity Log window (⌘L) listing what happened, newest first.
- Protected locations (`/`, system folders, `~/Library`) can never be chosen.
- Entitlements for user-selected folders and app-scoped bookmarks
  (see docs/ENTITLEMENTS.md).

## [0.0.1] - 2026-11-21

Achievement 0: Foundations.

### Added
- Menu bar app with a Quit item and no Dock icon.
- App Sandbox enabled from day one (see docs/ENTITLEMENTS.md).
- `OrdinoCore` Swift package for all non-UI logic, with Swift Testing.
- XcodeGen project definition (`project.yml`), with warnings treated as errors.
- App tests (version, bundle ID, no Dock icon, sandbox, menu bar icon) and a UI test that opens the menu bar item and quits through it.
- GitHub Actions CI that builds the app and runs all tests on macOS, failing on any warning or a missing sandbox.
- README, MIT license, contributing guide, code of conduct and this changelog.

[Unreleased]: https://github.com/dbf244/Ordino/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/dbf244/Ordino/releases/tag/v0.2.0
[0.1.0]: https://github.com/dbf244/Ordino/releases/tag/v0.1.0
[0.0.1]: https://github.com/dbf244/Ordino/releases/tag/v0.0.1
