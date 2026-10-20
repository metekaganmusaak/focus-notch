# Focus Notch — developer guide

A Pomodoro timer that lives in the MacBook notch (macOS) or a virtual notch (Windows), with animated pet companions, topics, statistics, themes and 23 languages.

## Layout

- `macos/` — native SwiftUI + AppKit app (Xcode project, macOS 14+). See `macos/README.md`.
  - `FocusNotch/App` — entry point, `AppModel` (wires engine events to the notch, sounds, notifications), menu bar menu.
  - `FocusNotch/Timer` — `PomodoroEngine` (phases, 5-min reminder, finish), `StatsStore` (per-day, per-topic), `TopicStore`.
  - `FocusNotch/Notch` — `NotchPanel` above the menu bar, hover via global mouse monitors, `NotchLayout` sizes per mode, views.
  - `FocusNotch/Pets` — `PetStore` (12 bundled animals in cute and pixel styles + custom GIFs), `AnimatedGIFView`.
  - `FocusNotch/Settings` — `SettingsStore` (UserDefaults), toolbar-tab settings window.
  - `FocusNotch/Support` — `Theme`, `PhaseStyle`, `TimeFormat`, notifications, language override.
  - `FocusNotch/Resources` — `Localizable.xcstrings` (single source of truth for all translations), pet GIFs, sounds, icon.
  - `Tools/PetForge` — Swift package: `pixel`, `cute`, `icon`, `sounds` commands that generate the resources. `Tools/Art` holds the Codex source art.
- `windows/` — Electron port with the same features. See `windows/README.md`.
  - `src/main` — `main.js` (windows, tray, IPC, alerts), `engine.js` (port of PomodoroEngine.swift), `store.js`, `i18n.js`, `pets.js`, `preload.js`.
  - `src/renderer/notch` — virtual notch: fixed 760×300 transparent window, spring-animated SVG shape, content clipped to it. On Windows it stands in the bottom taskbar and grows upward (`placement` from `positionNotch()` in main.js; position via `notchPosition` setting or dragging the status strip; collapsed width via `notchSize` small/medium/large; `--taskbar` previews it on other OSes).
  - `src/renderer/settings` — settings window. `src/renderer/shared/shared.js` — `FN` helpers (t, duration, themes, icons).
  - `scripts/sync-assets.mjs` copies pets/sounds/icon from `macos/` and converts the String Catalog to `assets/locales/*.json`.

## Commands

- macOS build: `cd macos && xcodebuild -project FocusNotch.xcodeproj -scheme FocusNotch -configuration Release -derivedDataPath <dir> build`
- PetForge (run from `macos/`): `swift run -c release --package-path Tools/PetForge petforge <pixel|cute Tools/Art|icon Tools/Art/icon.png|sounds> [--preview out.png]`
- Windows: `cd windows && npm install && npm start`; installer: `npm run dist`; visual check: `npm run snapshot` (PNGs in `windows/snapshots/`, uses a throwaway profile; `-- --lang=tr` for a language).
- If Electron starts as plain Node, unset `ELECTRON_RUN_AS_NODE` (VS Code terminals set it).

## Conventions

- Keep the two apps' behavior in sync: engine logic, alert texts, sizes (`NotchLayout.swift` ↔ `layout()` in `notch.js`), theme colors (`Theme.swift` ↔ `THEMES` in `shared.js`).
- All UI text goes through the String Catalog with English keys. After adding strings, translate all 22 languages (tr, zh-Hans, zh-Hant, hi, es, fr, ar, bn, pt-BR, ru, ur, id, de, ja, ko, vi, it, fa, pl, uk, th, nl) and run `npm run sync` in `windows/`. Windows reuses the macOS keys; avoid Windows-only strings.
- Swift: default MainActor isolation, `@Observable` stores, comments only where the why isn't obvious.
- Sounds must be original or CC0; record sources in `ASSETS.md`.
- All docs, comments, commit messages and release notes are in English; render README screenshots with the English UI.
