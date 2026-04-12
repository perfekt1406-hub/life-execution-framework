# Life Execution Framework

A brutally honest, single-page workbook that walks you through 7 phases of goal execution — from raw discipline to annual review. Packaged as a cross-platform Electron desktop app with local storage and daily auto-open.

## Features

- **7-phase workbook** — Discipline → Clarity → Constraints → Leverage → System → Measure → Iterate
- **Persistent local storage** — all inputs and checklist progress saved automatically via `localStorage`
- **Progress tracking** — overall completion percentage across all phase checklists
- **Daily auto-open** — launches once per logical day (day boundary: 3:30 AM) on login, then stays out of your way
- **Cross-platform** — Linux, macOS, Windows

## Quick start (development)

```bash
npm install
npm start
```

## Build distributable packages

```bash
# All platforms (from the matching OS)
npm run dist

# Platform-specific
npm run dist:linux   # .AppImage + .deb
npm run dist:mac     # .dmg
npm run dist:win     # .exe (NSIS installer)
```

## Auto-open behavior

On first launch the app registers itself to start at login. On each subsequent login:

1. The app checks if it has already been shown during the current *logical day* (which starts at 3:30 AM, not midnight).
2. If already shown today → the app exits silently.
3. If not → the window opens and the date is stamped.

Manually launching the app always opens the window regardless of the stamp.

### Reset the daily stamp

Delete the stamp file inside Electron's `userData` directory:

- **Linux:** `~/.config/life-execution-framework/state/last-open`
- **macOS:** `~/Library/Application Support/life-execution-framework/state/last-open`
- **Windows:** `%APPDATA%\life-execution-framework\state\last-open`

## License

MIT
