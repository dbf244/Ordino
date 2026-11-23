# Entitlements

Ordino is sandboxed and ships on the Mac App Store. It asks for as little as
possible. Every entitlement in `App/Ordino.entitlements` is listed here with
the reason it's needed. A pull request that adds an entitlement must add it to
this table too.

| Entitlement | Value | Since | Why |
| --- | --- | --- | --- |
| `com.apple.security.app-sandbox` | `true` | v0.0.1 | Required for the Mac App Store. The app only reaches files the user explicitly gives it. |
| `com.apple.security.files.user-selected.read-write` | `true` | v0.1.0 | Lets Ordino read and organize the folder the user picks in the Open panel. Without it, a chosen folder is not accessible. Read-write because later achievements move, rename and tag files there. |
| `com.apple.security.files.bookmarks.app-scope` | `true` | v0.1.0 | Lets Ordino save a security-scoped bookmark to each chosen folder, so access survives relaunches without asking again. |

## Deliberately not requested

- **Network** (`com.apple.security.network.client` / `.server`): Ordino never
  talks to the network. Updates come from the Mac App Store.
- **Temporary exceptions** (`com.apple.security.temporary-exception.*`): not
  allowed. Folder access always comes from the user choosing a folder.
- **Camera, microphone, contacts, location, calendars**: not needed.

## How folder access works

1. The user picks a folder in `NSOpenPanel` (`FolderPicker`). This is the only
   way Ordino gets access to anything outside its container.
2. `FolderAccess` (in OrdinoCore) refuses protected locations (`/`, system
   folders, `~/Library`), creates a security-scoped bookmark and saves it in
   `Application Support/Ordino/folders.json` inside the app's container.
3. On the next launch the bookmark is resolved and
   `startAccessingSecurityScopedResource()` is called. A stale bookmark (folder
   moved or renamed) is refreshed. If access fails, the folder is kept and the
   menu asks the user to choose it again; nothing is silently dropped.

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
