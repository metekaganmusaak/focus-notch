# Focus Notch for Windows

The Windows version of Focus Notch, built with Electron. PCs have no hardware notch, so the virtual notch sits **inside the taskbar** and grows upward when you hover over it. It has the same features as the macOS app: the Pomodoro cycle, the 5-minute reminder, animated pets and their sounds, topics and statistics, themes and 23 languages.

See the [main README](../README.md) for screenshots and how to use the app.

## Requirements

- Windows 10 or 11 (development also works on macOS and Linux)
- Node.js 20 or later

## Running

```sh
cd windows
npm install
npm start
```

`npm start` runs `npm run sync` first. It copies the pet GIFs, sounds and icon from `../macos/FocusNotch/Resources` and converts `Localizable.xcstrings` into `assets/locales/*.json`, so both apps share the same content and translations.

The app doesn't show up in the taskbar's app list. Click its icon in the notification area to open settings, or right-click it for the control menu.

## Building the installer

```sh
npm run dist
```

This writes an NSIS installer (`Focus Notch Setup *.exe`) to `dist/`. It works on macOS too:

```sh
npx electron-builder --win nsis portable --x64
```

This builds both the installer and a portable exe.

## How the virtual notch works

- **Placement:** It stands in the taskbar and opens upward; if the taskbar is at the top of the screen it hangs down instead. When Windows 11 centers the taskbar icons, it starts on the left so it doesn't cover them; otherwise it starts in the center.
- **Position and size:** Change them in **Settings → General**:
  - **Notch position:** Left, Center or Right, plus a slider for fine-tuning.
  - **Notch size:** Small, Medium or Large.
  - **Design:** Standard or Compact (a narrower pill and smaller panels). A preview in Settings shows both states, and the notch opens for a moment when you switch.
  - You can also drag the open panel by its status strip. The position is remembered.
- **A window that never moves:** The notch lives in a transparent, always-on-top 760×300 window above the taskbar. The window itself never moves or resizes. The black shape is a spring-animated SVG inside it, and the content is clipped to the same path, so growing and shrinking never jitters or overflows.
- **Click-through:** Clicks on the transparent area go to whatever is underneath. The panel only captures the mouse while you're hovering over it. Because clicking the taskbar can raise it above other topmost windows, the notch puts itself back on top every 1.5 seconds.

## Development

- `npm run snapshot` saves every view to `snapshots/` as PNG files, using a throwaway profile. Add options after `--`:
  - `--lang=de` for a language.
  - `--taskbar` to preview the taskbar placement on macOS or Linux.
  - `--notch-size=small` for a notch size.
- If Electron starts as plain Node in a VS Code terminal, unset `ELECTRON_RUN_AS_NODE`.
- See `CLAUDE.md` at the repository root for the code structure.
