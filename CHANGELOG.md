# Changelog

All notable changes to Ordino are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/dbf244/Ordino/compare/v0.0.1...HEAD
[0.0.1]: https://github.com/dbf244/Ordino/releases/tag/v0.0.1
