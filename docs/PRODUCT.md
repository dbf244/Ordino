# Ordino — product spec

Ordino watches folders on a Mac and tidies files automatically with simple
rules: "every PDF with 'invoice' in its name that lands in Downloads goes to
Documents/Invoices". Same idea as Hazel, but free, open source, native,
beautiful and built for everyone, not only power users.

Tagline: **Your folders, in order.**

## Principles
1. Safety before features: nothing ships that could lose a user's file.
2. Simple by default, powerful when you look for it.
3. Beautiful and minimal: fewer screens, fewer visible options.
4. Private: everything happens on the Mac. No accounts, no telemetry, no network.
5. MIT licensed, free forever, on the Mac App Store and GitHub.

## Rules
- A rule = *in this folder* → *if these conditions match* → *do these actions*.
- Each watched folder has an ordered list of rules. For each file, the first
  matching rule runs (advanced option: keep checking the following rules).
- Conditions combine with ALL or ANY and can be nested in groups.
- Rules can be enabled/disabled, duplicated, reordered by drag and drop.
- Rules export/import as JSON so people can share them.

## Conditions (v1.0)
| Condition | Examples |
| --- | --- |
| Name | contains, starts with, ends with, matches pattern (regex in advanced mode) |
| Extension | is pdf, is one of jpg/png/heic |
| Kind | image, video, audio, document, archive, installer (.dmg/.pkg), folder |
| Size | larger than 500 MB, smaller than 1 KB |
| Dates | date added / created / modified / last opened more or less than N days ago |
| Finder tags | has tag Red, has no tags |
| Download source | downloaded from a domain (`kMDItemWhereFroms`) |
| Is screenshot | `kMDItemIsScreenCapture` |

After v1.0: PDF text content, image dimensions, EXIF.

## Actions (v1.0)
| Action | Details |
| --- | --- |
| Move | to a folder, creating subfolders from patterns (`{year}/{month}`) |
| Copy | like move, keeps the original |
| Rename | patterns: `{name}`, `{date-added:yyyy-MM-dd}`, `{counter}`, `{extension}` |
| Tag | add or remove Finder tags |
| Move to Trash | never a permanent delete (`FileManager.trashItem`) |
| Compress | create a .zip |
| Open with | a chosen app |
| Notify | macOS notification describing what happened |
| Run script | advanced mode only, and only scripts in the app's Application Scripts folder (sandbox) |

## Safety (non-negotiable)
- **Simulation:** before enabling a rule, show the exact list of affected files
  and what would happen to each one. The Simulator reuses the same Evaluator,
  so simulation and reality can never drift apart.
- **History with undo:** every action is logged with what is needed to revert it.
- **Half-written files:** ignore in-progress downloads (`.crdownload`,
  `.download`, `.part`) and wait until the file size is stable.
- **Name conflicts:** add a suffix (` 2`, ` 3`…). Never overwrite silently.
- **Loop protection:** if rules keep moving a file between watched folders,
  stop after N times, pause those rules and tell the user.
- **Protected paths:** system folders, `~/Library` and `/` cannot be watched.
- **Global pause:** one click in the menu bar stops everything.
- **Sandbox:** access to every folder comes from the user choosing it; stored
  as security-scoped bookmarks; stale bookmarks pause the affected rules and
  ask the user to grant access again.

## Experience
- Menu bar app: discreet icon, a panel with recent activity and pause, and a
  main window to manage rules.
- 3-step onboarding: pick a folder, pick a template, simulate and enable.
- Templates: Sort Downloads by type, Clean old installers, Screenshots by
  month, Archive invoices, Tidy Desktop nightly.
- Open at login (optional), English + Spanish, VoiceOver, keyboard, light/dark.

## After v1.0 (ideas)
- Create rules in natural language with Apple's on-device Foundation Models.
- Shortcuts integration (App Intents), Finder extension, scheduled rules.

## Architecture
```
Ordino/
├── App/                 # SwiftUI app: menu bar, windows, onboarding
├── Packages/
│   └── Core/            # Swift package, no UI
│       ├── Model/       # Rule, Condition, Action, WatchedFolder
│       ├── Engine/      # Evaluator, ActionRunner, Simulator
│       ├── Watcher/     # FSEvents wrapper, stability checker
│       ├── Access/      # security-scoped bookmarks
│       ├── History/     # action log + undo
│       └── Storage/     # GRDB database, migrations
├── Tests/
├── docs/
├── .github/workflows/
├── project.yml          # XcodeGen
└── CLAUDE.md
```

### The journey of a file
1. **Watcher** gets an FSEvents notification for a watched folder.
2. **Stability checker** waits until the file stops changing and skips partial downloads.
3. **Evaluator** goes through that folder's rules and finds the first match.
4. **ActionRunner** runs its actions in order, resolving name conflicts.
5. **History** records each step with what is needed to undo it.
6. The UI shows the activity and, if the rule asks for it, sends a notification.

## Distribution
- Mac App Store (free) — main channel. Sandboxed. Updates via the App Store.
- GitHub Releases — notarized DMG built from the same code, plus Homebrew Cask.
- Requires an Apple Developer Program membership ($99/year).
