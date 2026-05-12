#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PATCHER="$ROOT_DIR/patch.sh"

if ! grep -q 'webview/assets' "$PATCHER"; then
  echo "patch.sh must inject into Codex webview/assets renderer bundles" >&2
  exit 1
fi

if ! grep -q 'CODEX_RTL_TARGET_DIRS' "$PATCHER"; then
  echo "patch.sh must expose target dirs via CODEX_RTL_TARGET_DIRS" >&2
  exit 1
fi

if ! grep -q 'CODEX_RTL_WEBVIEW_ENTRY_PATTERN' "$PATCHER"; then
  echo "patch.sh must limit webview/assets injection to entry bundles" >&2
  exit 1
fi

echo "injection target checks passed"
