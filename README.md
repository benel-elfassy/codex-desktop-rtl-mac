# Codex Desktop RTL Patch for macOS

Adds automatic right-to-left (RTL) text support for Hebrew and Arabic in Codex Desktop on macOS.

The patcher creates a separate copied app at `~/Applications/Codex-RTL.app`. It does not modify `/Applications/Codex.app`.

## What it does

- Detects Hebrew and Arabic text in editable fields and rendered messages.
- Applies RTL direction and right/start alignment automatically.
- Keeps code blocks, diffs, terminals, and shell output left-to-right.
- Re-processes streamed or dynamically inserted content with a `MutationObserver`.
- Creates a separate ad-hoc signed app copy so the original Codex installation remains intact.

## Requirements

- macOS
- Codex Desktop installed at `/Applications/Codex.app`
- Node.js with `npx`
- Xcode Command Line Tools for `codesign`

Install common dependencies:

```bash
brew install node
xcode-select --install
```

## Install

```bash
git clone https://github.com/benel-elfassy/codex-desktop-rtl-mac.git
cd codex-desktop-rtl-mac
chmod +x patch.sh
./patch.sh --install
```

The patched app is created at:

```text
~/Applications/Codex-RTL.app
```

Launch `Codex-RTL.app`, not the original `Codex.app`, when you want RTL support.

## Commands

```bash
./patch.sh --install
./patch.sh --uninstall
./patch.sh --status
./patch.sh --help
```

## How it works

1. Copies `/Applications/Codex.app` to `~/Applications/Codex-RTL.app`.
2. Extracts the Electron `app.asar` archive.
3. Prepends `rtl-payload.js` into likely renderer JavaScript bundles under `.vite/build` and `webview/assets`.
4. Repacks `app.asar`.
5. Disables Electron's embedded ASAR integrity validation fuse so the modified archive can load.
6. Re-signs the copied app with an ad-hoc signature.
7. Launches `Codex-RTL.app`.

Advanced targeting can be adjusted with environment variables:

```bash
CODEX_RTL_SOURCE_APP=/path/to/Codex.app
CODEX_RTL_PATCHED_APP=/path/to/Codex-RTL.app
CODEX_RTL_TARGET_DIRS=".vite/build webview/assets"
CODEX_RTL_WEBVIEW_ENTRY_PATTERN='^(index|app-main)-.*\.js$'
CODEX_RTL_ASAR_PACKAGE='@electron/asar@4.0.1'
CODEX_RTL_FUSES_PACKAGE='@electron/fuses@2.0.0'
```

## Safety

The script is intentionally conservative:

- It refuses to patch anything except an app with bundle id `com.openai.codex`.
- It validates that source and destination are absolute `.app` paths and refuses to patch the source path in place.
- It never modifies `/Applications/Codex.app`.
- It only removes `~/Applications/Codex-RTL.app` if it looks like a previous Codex RTL copy.
- It writes a marker file inside the copied app and checks that marker before replacing/removing.
- It pins the npm tools used by `npx` (`@electron/asar` and `@electron/fuses`) instead of using a floating latest version.

## After Codex Updates

Codex updates apply to the original app at `/Applications/Codex.app`. After an update, rerun:

```bash
./patch.sh --install
```

This rebuilds `Codex-RTL.app` from the current original app.

## Troubleshooting

### `Codex quit unexpectedly`

The ASAR integrity fuse may not have been disabled correctly, or macOS may be blocking the ad-hoc signed copy. Rerun:

```bash
./patch.sh --install
```

Then right-click `~/Applications/Codex-RTL.app` and choose Open if Gatekeeper blocks the first launch.

### `Neither asar nor npx found`

Install Node.js:

```bash
brew install node
```

### The patch does not affect Hebrew

Make sure you launched `~/Applications/Codex-RTL.app`. The original `/Applications/Codex.app` is intentionally unchanged.

## Development Checks

```bash
bash -n patch.sh
node --check rtl-payload.js
test/injection-targets.test.sh
./patch.sh --status
```

## License

MIT
