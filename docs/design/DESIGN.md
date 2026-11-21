# Ordino design

Original canvas (Claude Design, private to the maintainer):
https://claude.ai/artifact/Byaic5zqPq2d4tVmGkhKCy

`source/` holds every artboard as HTML. Read them for exact layout, copy,
sizes and colors; they are mockups, not code to ship. `assets/` holds the
icon artwork as SVG.

## Look
Minimal, calm, very native macOS. One accent color over system grays.
SF Pro, SF Symbols, system materials, lots of air. No gradients except the
very subtle one on the app icon. A new user must understand any screen in
3 seconds.

## Colors
| Token | Light | Dark |
| --- | --- | --- |
| accent | #167A6C | #4FC2AE |
| accentText (text on accent) | #FFFFFF | #0E2F2A |
| accentTint (selected rows, chips) | #E3F1EE | #1F3A35 |
| accentTintText | #0F5E53 | #7FD8C7 |
| background | #FFFFFF | #1E1F21 |
| sidebar | #F4F5F4 | #252628 |
| text | #1C1D1F | #F2F3F4 |
| secondaryText | #5F6368 | #A9ADB2 |
| separator | #E3E5E4 | #36383B |
| controlBorder | #D5D8D7 | #45484C |
| toggleOff | #C9CDCC | #4A4D51 |
| placedPiece (logo highlight) | #A8EBDD | #A8EBDD |
| success | #1E7F4F on #E6F4EC | — |
| warning | #8A4E00 on #FBF0DF | — |
| error | #B03325 on #FBEAE8 | — |

Prefer system semantic colors (labelColor, separatorColor, windowBackground…)
where they match; use the accent above as the app's AccentColor asset.

## Type (SF Pro)
| Role | Size / weight |
| --- | --- |
| Window title | 28 / bold |
| Section header | 17 / semibold |
| Body | 14 / regular |
| Secondary | 13 / regular |
| Caption label | 11 / semibold, uppercase, tracking 0.06em |

Spacing in multiples of 4: 4, 8, 12, 16, 24, 32.
Radii: controls 6, rows 8, cards and windows 12, pills 999.

## App icon
The grid: 3×3 rounded squares, white on teal (#1C8E7E → #11685C, very subtle
vertical gradient). The last square is mint (#A8EBDD), slightly offset, about
to click into its dashed slot: "every file in its place".
- `assets/app-icon.svg` (1024 px master)
- `assets/menubar-active.svg` and `assets/menubar-paused.svg`: template images
  (monochrome, 18 pt). Filled grid = active, outline only = paused.

## Screens (see source/)
| File | Screen |
| --- | --- |
| Window.dc.html / WindowDark.dc.html | Main window: folder sidebar, rule list with toggles, recent activity |
| RuleEditor.dc.html | Rule editor that reads like a sentence + live preview panel |
| Simulation.dc.html | "This rule would affect 12 files" before enabling |
| History.dc.html | History by day with Undo/Redo, search and filters |
| Templates.dc.html | Template gallery (5 templates + start from scratch) |
| MenuBar.dc.html / MenuBarDark.dc.html | Menu bar panel: status, stats, recent with Undo, pause |
| Onboarding.dc.html | 3-step onboarding (folder → template → simulate) |
| Settings.dc.html | Settings: General, Folder access, History, About |
| EmptyStates.dc.html | No folders, folder access needed, loop detected |
| Logo.dc.html, System.dc.html | Icon exploration and visual system |
| SocialGitHub / SocialX / Avatar | Marketing images (1280×640, 1500×500, 400×400) |
