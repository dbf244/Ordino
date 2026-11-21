# CLAUDE.md — rules for working on Ordino

## What this project is
Ordino is a free, open-source (MIT), native macOS app that watches folders and
organizes files automatically with user-defined rules. A beautiful, safe,
beginner-friendly alternative to Hazel. It ships free on the Mac App Store and
as a notarized DMG on GitHub.

Read these first, in this order:
1. docs/PRODUCT.md — what the app does and how it works inside.
2. docs/ACHIEVEMENTS.md — the roadmap and the source of truth for progress.
3. docs/design/DESIGN.md — the visual system and the screens to build.

## Language
- Everything committed to the repo is in English: code, comments, commit
  messages, docs, issues, UI strings (Spanish lives in Localizable.xcstrings).
- Talk to the maintainer in Spanish in chat.

## Stack
Swift 6 strict concurrency, SwiftUI, macOS 14+, FSEvents, GRDB.swift,
Swift Testing, XcodeGen (project.yml). Core logic lives in Packages/Core with
no UI dependencies. No Sparkle: updates come from the Mac App Store.

## App Store and sandbox (from Achievement 0)
- The app is sandboxed. Only add entitlements that are strictly needed, and
  explain each one in docs/ENTITLEMENTS.md.
- Access to folders comes only from the user choosing them (NSOpenPanel),
  stored as security-scoped bookmarks. This applies to watched folders AND
  destination folders. Handle stale bookmarks gracefully.
- Scripts can only run from the app's Application Scripts folder
  (NSUserScriptTask). Trash only via FileManager.trashItem.
- No private APIs, no network access, no data collection.

## How we work: one achievement at a time
1. Read docs/ACHIEVEMENTS.md and find the current achievement.
2. Write a short plan (files to touch, tests to add, risks). Wait for approval.
3. Write tests first for anything in Core.
4. After every meaningful change: build (`xcodebuild ... build`) and run tests
   (`swift test` in Packages/Core, plus app tests). Never continue on red.
5. When all acceptance criteria pass, give the maintainer a numbered manual
   test checklist. Do NOT mark the achievement done until they confirm.
6. Then: tick it in docs/ACHIEVEMENTS.md, update CHANGELOG.md, commit, tag,
   and draft the X post for that achievement (see docs/SOCIAL.md).
7. Never start the next achievement in the same step. Never skip criteria.

## Quality bar
- Do it properly, not quickly. No TODOs, stubs or commented-out code left in
  a finished achievement. No force-unwraps outside tests.
- If a criterion cannot be met, stop and explain why. Do not fake it, do not
  weaken a test to make it pass.
- Prefer Apple APIs over dependencies. Ask before adding any new dependency.
- Ask before any architecture change or anything that is hard to undo.

## Safety rules (non-negotiable)
- The app never deletes permanently: only move to Trash.
- Never overwrite an existing file without an explicit user choice.
- Every action is recorded in History with enough data to undo it.
- Never act on files that are still being written or downloaded.
- Protected paths (/System, /Library, ~/Library, /) are never watched or touched.
- During development, test only inside ~/Ordino-Playground, never real folders.

## Design
Follow docs/design/DESIGN.md exactly: colors, spacing, typography, icons.
The files in docs/design/source/ are the original mockups (HTML): read them for
exact layout, copy and values. Accent #167A6C (dark mode #4FC2AE).
Use SF Pro, SF Symbols and system materials. Support light and dark mode,
VoiceOver and full keyboard navigation.

## Git
Conventional commits (feat:, fix:, test:, docs:, refactor:, chore:).
Small commits. Tag each finished achievement (v0.1.0, v0.2.0, ...).
Never push without the maintainer's OK.
