# Codex Desktop RTL macOS Design

## Goal

Build a small public-ready macOS patcher that adds automatic Hebrew/Arabic RTL handling to a copied Codex Desktop app without modifying the original installation.

## Architecture

The repository ships a Bash patcher and a browser-side JavaScript payload. The patcher creates `~/Applications/Codex-RTL.app` from `/Applications/Codex.app`, extracts its Electron `app.asar`, prepends the payload to likely renderer JavaScript bundles, repacks the archive, disables Electron ASAR integrity validation, ad-hoc signs the copied app, and optionally launches it.

The payload runs in the renderer, detects RTL text in editable fields and rendered message content, applies `dir`, `direction`, and alignment styles, and keeps code, terminal, diff, and preformatted regions LTR.

## Safety

- The original `/Applications/Codex.app` is never modified.
- `--uninstall` removes only `~/Applications/Codex-RTL.app`.
- The script refuses to patch unless the source app exists and the destination either does not exist or looks like a previous Codex RTL copy.
- Temporary files are created with `mktemp -d` and cleaned on exit.
- The payload is idempotent and avoids double injection via a marker string.

## Commands

- `./patch.sh --install`
- `./patch.sh --uninstall`
- `./patch.sh --status`
- `./patch.sh --help`

## Verification

Static checks cover shell syntax and payload syntax. Runtime verification is installing the copied app and confirming that it launches.
