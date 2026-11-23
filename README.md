<p align="center">
  <img src="docs/design/assets/app-icon.svg" width="128" height="128" alt="Ordino app icon">
</p>

<h1 align="center">Ordino</h1>

<p align="center"><strong>Your folders, in order.</strong></p>

<p align="center">
  <a href="https://github.com/dbf244/Ordino/actions/workflows/ci.yml"><img src="https://github.com/dbf244/Ordino/actions/workflows/ci.yml/badge.svg" alt="CI status"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-167A6C" alt="MIT license"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-167A6C" alt="macOS 14 or later">
</p>

Ordino is a free, open-source, native macOS app that watches folders and
organizes files automatically with simple rules. For example: *every PDF with
"invoice" in its name that lands in Downloads goes to Documents/Invoices.*

It's a safe, beginner-friendly alternative to Hazel. It's simple by default,
and there's more power when you go looking for it.

## Status

Ordino is being built in public, one achievement at a time.
**Right now Ordino watches one folder you choose and logs what arrives,
changes, is renamed or removed there. It does not move or change any file yet.**
See [docs/ACHIEVEMENTS.md](docs/ACHIEVEMENTS.md) for the roadmap and progress.

## Principles

- **Safety first.** Ordino never deletes permanently (only Move to Trash),
  never silently overwrites a file, and lets you undo every action. You'll be
  able to simulate a rule before you enable it.
- **Private.** Everything happens on your Mac. No accounts, no telemetry,
  no network access.
- **Native.** Swift, SwiftUI, SF Symbols, light and dark mode, VoiceOver and
  full keyboard navigation.
- **Sandboxed.** Ordino only touches the folders you choose.
- **Free forever.** MIT licensed. It will ship on the Mac App Store and as a
  notarized DMG here on GitHub.

## Building from source

Requirements: Xcode 26 or later (Swift 6.2) on a Mac, and
[XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
git clone https://github.com/dbf244/Ordino.git
cd Ordino
xcodegen generate
open Ordino.xcodeproj
```

The Xcode project is generated from `project.yml` and is not checked in.

Run the tests:

```bash
swift test --package-path Packages/Core
xcodebuild test -project Ordino.xcodeproj -scheme Ordino -destination 'platform=macOS'
```

## Project layout

```
App/              SwiftUI app (menu bar, windows)
AppTests/         App-level tests
AppUITests/       UI tests that drive the real app
Packages/Core/    OrdinoCore: all the logic, no UI
docs/             Product spec, roadmap, design, entitlements
project.yml       XcodeGen project definition
```

The product spec is in [docs/PRODUCT.md](docs/PRODUCT.md), the design system
is in [docs/design/DESIGN.md](docs/design/DESIGN.md), and every sandbox
entitlement is explained in [docs/ENTITLEMENTS.md](docs/ENTITLEMENTS.md).

## Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) and
the [Code of Conduct](CODE_OF_CONDUCT.md) first.

## License

[MIT](LICENSE) © 2026 Daniel Boghi
