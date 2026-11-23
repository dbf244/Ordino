# Achievements

Ordino is built one achievement at a time. Each one leaves the app in a working
state that can be shown publicly. An achievement is done only when **every**
acceptance criterion passes AND the maintainer confirms the manual checks.

Status: **Current achievement → 2**

---

## 🏗️ Achievement 0 — Foundations (v0.0.1) ✅
An empty app runs in the menu bar and the repo is ready for the world.

**Deliverables:** README, LICENSE (MIT), CONTRIBUTING.md, CODE_OF_CONDUCT.md,
.gitignore, CHANGELOG.md, docs/ENTITLEMENTS.md, `project.yml` (XcodeGen),
empty `Packages/Core` Swift package, App Sandbox enabled from day one,
GitHub Actions CI (build + tests on macOS).

- [x] `xcodegen generate` creates the project and it builds with zero warnings.
- [x] Running the app shows a menu bar icon with a "Quit" item and no Dock icon.
- [x] The app is sandboxed (check with `codesign -d --entitlements - <app>`).
- [x] `swift test` in Core passes (one sample test).
- [x] CI is green on GitHub.

## 👀 Achievement 1 — The Watcher (v0.1.0) ✅
The app sees what happens in a folder the user picked.

**Deliverables:** `FolderAccess` (NSOpenPanel + security-scoped bookmarks,
saved and restored), `FolderWatcher` on FSEvents, `StabilityChecker` (waits
until a file stops changing; ignores `.crdownload`, `.download`, `.part`).

- [x] Pick ~/Ordino-Playground once; after relaunching the app, access still works without asking again.
- [x] Adding, renaming or deleting a file there shows up in the log in under 2 seconds.
- [x] A large file being copied is reported once, only when it's finished.
- [x] Automated tests for the watcher and stability checker using temp folders.
- [x] Idle CPU usage is ~0%.

## 🧠 Achievement 2 — The First Rule (v0.2.0)
A real rule moves a real file.

**Deliverables:** `Rule`, `Condition`, `Action`, `WatchedFolder` models
(Codable); `Evaluator` with name and extension conditions; Move action
(destination folder also picked by the user, stored as a bookmark);
one test rule defined in code.

- [ ] Dropping `test.pdf` into the folder moves it to the destination.
- [ ] If the destination already has that name, the file becomes `test 2.pdf`; nothing is overwritten.
- [ ] Evaluator tests cover every name and extension case.

## 🔍 Achievement 3 — All Conditions (v0.3.0)
The engine understands everything v1.0 needs.

**Deliverables:** kind, size, dates, Finder tags, download source and
screenshot conditions; nested ALL/ANY groups.

- [ ] Each condition has tests with real files (including Spotlight metadata).
- [ ] Nested groups (AND inside OR) evaluate correctly in tests.
- [ ] Evaluating 10,000 simulated files takes under 1 second.

## ⚡ Achievement 4 — All Actions (v0.4.0)
The app can do everything with a file.

**Deliverables:** Copy, Rename with patterns, Tag, Move to Trash, Compress,
Open with, Notify, Run script (advanced, Application Scripts folder only);
ordered execution; subfolders from patterns.

- [ ] Every action has integration tests in a temp folder.
- [ ] Name patterns (`{date-added:yyyy-MM-dd}`, `{counter}`…) have edge-case tests.
- [ ] If one action in a chain fails, the rest stop and the error is logged.
- [ ] No action ever deletes permanently (a test enforces it).

## 🛡️ Achievement 5 — Safety Net (v0.5.0)
From here on the app is safe to use on real folders.

**Deliverables:** GRDB database (rules, folders, history, migrations), History
with **undo**, **Simulator**, loop protection, protected paths, global pause,
stale-bookmark handling.

- [ ] Any action in History can be undone: the file returns to its place with its name.
- [ ] Simulation matches exactly what is then executed (a test compares them).
- [ ] Two rules passing a file back and forth are stopped and the user is told.
- [ ] `~/Library` and system folders cannot be watched.
- [ ] Rules, history and folder permissions survive quitting and restarting the Mac.

## 🎨 Achievement 6 — The Beautiful Face (v0.6.0)
The UI from docs/design, working for real.

**Deliverables:** main window (folder sidebar, rule list), rule editor that
reads like a sentence, simulation sheet, history window, menu bar panel.

- [ ] Rules can be created, edited, reordered, duplicated and deleted only through the UI.
- [ ] The app matches the design (compare screenshots with docs/design).
- [ ] Light and dark mode both look right.
- [ ] Everything works with the keyboard alone.

## ✨ Achievement 7 — First 60 Seconds (v0.7.0)
Someone who has never seen the app understands and uses it in one minute.

**Deliverables:** 3-step onboarding, template gallery, clear permission explanations.

- [ ] A person new to the app creates their first rule without help in under 60 seconds.
- [ ] All 5 templates work and go through simulation before being enabled.
- [ ] If folder access is denied or lost, the app explains what happens and how to fix it.

## 🔧 Achievement 8 — Everyday Life (v0.8.0)
The app survives real use, week after week.

**Deliverables:** open at login (`SMAppService`), "apply rules to existing
files", JSON import/export of rules, settings, automatic cleanup of old history.

- [ ] After restarting the Mac, the app starts on its own and keeps watching.
- [ ] A rule exported on one Mac imports on another and works the same.
- [ ] One week on the maintainer's real Downloads with no errors and no lost files.

## 🌍 Achievement 9 — For Everyone (v0.9.0 beta)
**Deliverables:** full Spanish localization (`Localizable.xcstrings`),
VoiceOver review, polished copy, public beta (TestFlight for Mac + GitHub).

- [ ] With the Mac in Spanish, no English text is left.
- [ ] A rule can be created start to finish with VoiceOver.
- [ ] Public beta is out to collect feedback.

## 📦 Achievement 10 — Ready to Install (v1.0.0)
**Deliverables:** App Store Connect listing (name reserved, screenshots,
English + Spanish description, "Data Not Collected" privacy label), App Review
submission, notarized DMG on GitHub Releases, Homebrew Cask pointing to it,
GitHub Pages site, final README with screenshots and a GIF.

- [ ] Apple approves the app and it is live, free, on the Mac App Store.
- [ ] On a clean Mac, the App Store build asks for folder access and works like in development.
- [ ] The GitHub DMG opens with no security warnings; `brew install --cask ordino` works.
- [ ] CI builds the release automatically when a tag is pushed.

## 🚀 Achievement 11 — Launch (v1.0.0 public)
**Deliverables:** Show HN, Reddit, Product Hunt, AlternativeTo (as a Hazel
alternative), PRs to awesome-macOS lists, `good first issue` labels.

- [ ] All launch posts published the same day.
- [ ] Every issue from the first week answered.

## After 1.0
Natural-language rules with on-device AI, Shortcuts, Finder extension,
scheduled rules, content-based conditions. Each becomes a new achievement
in this same format.
