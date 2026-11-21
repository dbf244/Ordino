# Contributing to Ordino

Thank you for helping. Ordino handles people's files, so the bar for safety
and quality is high. This guide explains how the project works.

## Before you start

1. Read [docs/PRODUCT.md](docs/PRODUCT.md), [docs/ACHIEVEMENTS.md](docs/ACHIEVEMENTS.md)
   and [docs/design/DESIGN.md](docs/design/DESIGN.md).
2. For anything bigger than a small fix, open an issue first so we can agree
   on the approach before you write code.
3. Be kind. Everyone here follows the [Code of Conduct](CODE_OF_CONDUCT.md).

## How the project is built

Ordino is built **one achievement at a time** (see docs/ACHIEVEMENTS.md).
Each achievement has a clear list of acceptance criteria and leaves the app
in a working state. Pull requests should fit the current achievement, or be
bug fixes, docs or tests.

## Setup

```bash
brew install xcodegen
xcodegen generate
open Ordino.xcodeproj
```

Never commit `Ordino.xcodeproj`. Change `project.yml` instead and regenerate.

## Rules for code

- **Language:** everything in the repo is in English: code, comments, commits,
  docs and UI strings. Translations live in `Localizable.xcstrings`.
- **Stack:** Swift 6 with strict concurrency, SwiftUI, macOS 14+.
- **Core first:** logic goes in `Packages/Core` (no UI imports). The app
  target only contains UI and glue.
- **Tests first** for anything in Core, using Swift Testing.
- **Zero warnings.** Warnings are treated as errors.
- No force-unwraps outside tests. No TODOs, stubs or commented-out code.
- Prefer Apple APIs. Open an issue before adding a dependency.

## Safety rules (non-negotiable)

- Never delete permanently: only `FileManager.trashItem`.
- Never overwrite an existing file without an explicit user choice.
- Every action is recorded in History with enough data to undo it.
- Never act on files that are still being written or downloaded.
- Protected paths (`/`, `/System`, `/Library`, `~/Library`) are never watched or touched.
- **Test only inside `~/Ordino-Playground`**, never on your real folders.

## Sandbox and App Store

The app is sandboxed and ships on the Mac App Store. Folder access only comes
from the user choosing a folder, stored as a security-scoped bookmark. Any new
entitlement must be strictly necessary and documented in
[docs/ENTITLEMENTS.md](docs/ENTITLEMENTS.md). No private APIs, no network
access, no data collection.

## Before you open a pull request

```bash
swift test --package-path Packages/Core
xcodegen generate
xcodebuild test -project Ordino.xcodeproj -scheme Ordino -destination 'platform=macOS'
```

Both must pass with no warnings. CI runs the same checks.

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org/):
`feat:`, `fix:`, `test:`, `docs:`, `refactor:`, `chore:`. Keep commits small
and focused.

## Design

Follow [docs/design/DESIGN.md](docs/design/DESIGN.md): colors, spacing,
typography and SF Symbols. Every screen must work in light and dark mode,
with VoiceOver and with the keyboard alone.
