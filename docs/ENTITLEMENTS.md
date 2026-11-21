# Entitlements

Ordino is sandboxed and ships on the Mac App Store. It asks for as little as
possible. Every entitlement in `App/Ordino.entitlements` is listed here with
the reason it's needed. A pull request that adds an entitlement must add it to
this table too.

| Entitlement | Value | Since | Why |
| --- | --- | --- | --- |
| `com.apple.security.app-sandbox` | `true` | v0.0.1 | Required for the Mac App Store. The app only reaches files the user explicitly gives it. |

## Deliberately not requested

- **Network** (`com.apple.security.network.client` / `.server`): Ordino never
  talks to the network. Updates come from the Mac App Store.
- **Temporary exceptions** (`com.apple.security.temporary-exception.*`): not
  allowed. Folder access always comes from the user choosing a folder.
- **Camera, microphone, contacts, location, calendars**: not needed.

## Planned

Each one is added only in the achievement that needs it, with its row above:

- `com.apple.security.files.user-selected.read-write` and
  `com.apple.security.files.bookmarks.app-scope` (Achievement 1): let the user
  pick folders with `NSOpenPanel` and keep access across launches with
  security-scoped bookmarks.

## Added by Xcode, not by us

Local builds are signed ad hoc ("Sign to Run Locally"). Xcode adds
`com.apple.security.get-task-allow` to them so a debugger can attach, and
test builds also get `com.apple.security.temporary-exception.*` entries so
the test runner can talk to the app. None of these are in
`App/Ordino.entitlements`, and none are in a build exported for the Mac App
Store or notarization.

## How to check

```bash
codesign -d --entitlements - /path/to/Ordino.app
```
