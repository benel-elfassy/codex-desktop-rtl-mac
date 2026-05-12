#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PAYLOAD_FILE="$SCRIPT_DIR/rtl-payload.js"

SOURCE_APP="${CODEX_RTL_SOURCE_APP:-/Applications/Codex.app}"
PATCHED_APP="${CODEX_RTL_PATCHED_APP:-$HOME/Applications/Codex-RTL.app}"
PATCHED_ASAR="$PATCHED_APP/Contents/Resources/app.asar"
MARKER_FILE="$PATCHED_APP/Contents/Resources/.codex-rtl-patched"
CODEX_RTL_TARGET_DIRS="${CODEX_RTL_TARGET_DIRS:-.vite/build webview/assets}"
CODEX_RTL_WEBVIEW_ENTRY_PATTERN="${CODEX_RTL_WEBVIEW_ENTRY_PATTERN:-^(index|app-main)-.*\\.js$}"
TMP_DIR=""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log() { echo -e " ${CYAN}[*]${NC} $1"; }
success() { echo -e " ${GREEN}[+]${NC} $1"; }
warn() { echo -e " ${YELLOW}[!]${NC} $1"; }
err() { echo -e " ${RED}[X]${NC} $1"; }
step() { echo -e "\n${BOLD}${CYAN}► $1${NC}"; }
die() { err "$1"; exit 1; }

cleanup() {
  if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
    rm -rf "$TMP_DIR" 2>/dev/null || true
  fi
}
trap cleanup EXIT

asar_cmd() {
  if command -v asar >/dev/null 2>&1; then
    asar "$@"
  elif command -v npx >/dev/null 2>&1; then
    npx --yes @electron/asar "$@"
  else
    die "Neither asar nor npx found. Install Node.js or npm install -g @electron/asar."
  fi
}

fuses_cmd() {
  if command -v npx >/dev/null 2>&1; then
    npx --yes @electron/fuses "$@"
  else
    die "npx not found. Install Node.js to use @electron/fuses."
  fi
}

bundle_value() {
  local plist="$1"
  local key="$2"
  /usr/libexec/PlistBuddy -c "Print :$key" "$plist" 2>/dev/null || true
}

check_source_app() {
  [ -d "$SOURCE_APP" ] || die "Codex.app not found at $SOURCE_APP."
  [ -f "$SOURCE_APP/Contents/Info.plist" ] || die "Missing Info.plist in $SOURCE_APP."
  [ -f "$SOURCE_APP/Contents/Resources/app.asar" ] || die "Missing app.asar in $SOURCE_APP."

  local bundle_id
  bundle_id="$(bundle_value "$SOURCE_APP/Contents/Info.plist" CFBundleIdentifier)"
  [ "$bundle_id" = "com.openai.codex" ] || die "Refusing to patch unexpected bundle id: ${bundle_id:-unknown}."
}

check_dependencies() {
  local missing=()
  if ! command -v npx >/dev/null 2>&1 && ! command -v asar >/dev/null 2>&1; then
    missing+=("Node.js/npx or @electron/asar")
  fi
  if ! command -v npx >/dev/null 2>&1; then
    missing+=("Node.js/npx for @electron/fuses")
  fi
  if ! command -v codesign >/dev/null 2>&1; then
    missing+=("Xcode Command Line Tools for codesign")
  fi
  if [ ${#missing[@]} -gt 0 ]; then
    err "Missing required dependencies:"
    for dep in "${missing[@]}"; do echo " - $dep"; done
    exit 1
  fi
}

validate_destination_for_replace() {
  if [ ! -d "$PATCHED_APP" ]; then
    return
  fi

  local name bundle_id
  name="$(bundle_value "$PATCHED_APP/Contents/Info.plist" CFBundleDisplayName)"
  bundle_id="$(bundle_value "$PATCHED_APP/Contents/Info.plist" CFBundleIdentifier)"

  if [ -f "$MARKER_FILE" ] || { [ "$name" = "Codex-RTL" ] && [ "$bundle_id" = "com.openai.codex.rtl" ]; }; then
    return
  fi

  die "Refusing to replace $PATCHED_APP because it does not look like a Codex RTL copy."
}

quit_codex_rtl() {
  if pgrep -f "Codex-RTL.app" >/dev/null 2>&1; then
    step "Quitting Codex-RTL..."
    osascript -e 'tell application "Codex-RTL" to quit' 2>/dev/null || true
    sleep 2
    pkill -f "Codex-RTL.app/Contents/MacOS" 2>/dev/null || true
    success "Codex-RTL stopped."
  fi
}

prepare_copy() {
  step "Creating patched copy..."
  mkdir -p "$HOME/Applications"
  validate_destination_for_replace

  if [ -d "$PATCHED_APP" ]; then
    log "Removing previous Codex-RTL copy..."
    rm -rf "$PATCHED_APP"
  fi

  log "Copying $SOURCE_APP to $PATCHED_APP..."
  cp -R "$SOURCE_APP" "$PATCHED_APP"

  /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Codex-RTL" "$PATCHED_APP/Contents/Info.plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string Codex-RTL" "$PATCHED_APP/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.openai.codex.rtl" "$PATCHED_APP/Contents/Info.plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.openai.codex.rtl" "$PATCHED_APP/Contents/Info.plist"

  echo "patched-by=codex-desktop-rtl-mac" > "$MARKER_FILE"
  success "Created copied app."
}

inject_payload() {
  step "Extracting app.asar..."
  TMP_DIR="$(mktemp -d)"
  asar_cmd extract "$PATCHED_ASAR" "$TMP_DIR/app"
  success "Extracted ASAR."

  step "Injecting RTL payload..."
  [ -f "$PAYLOAD_FILE" ] || die "Missing rtl-payload.js next to patch.sh."

  local injected=0
  local skipped=0
  local found_targets=0
  local target_dir

  for target_dir in $CODEX_RTL_TARGET_DIRS; do
    local absolute_target="$TMP_DIR/app/$target_dir"
    if [ ! -d "$absolute_target" ]; then
      warn "Target directory not found in ASAR: $target_dir"
      continue
    fi

    found_targets=$((found_targets + 1))

    while IFS= read -r -d '' js_file; do
      case "$js_file" in
        *worker*.js|*preload*.js|*bootstrap*.js|*sentry*.js) continue ;;
      esac
      if [ "$target_dir" = "webview/assets" ] && ! basename "$js_file" | grep -Eq "$CODEX_RTL_WEBVIEW_ENTRY_PATTERN"; then
        continue
      fi

      if grep -q "CODEX RTL PATCH START" "$js_file" 2>/dev/null; then
        skipped=$((skipped + 1))
        continue
      fi

      cat "$PAYLOAD_FILE" "$js_file" > "$TMP_DIR/merged.js"
      mv "$TMP_DIR/merged.js" "$js_file"
      injected=$((injected + 1))
      log "Injected into ${js_file#$TMP_DIR/app/}"
    done < <(find "$absolute_target" -type f -name '*.js' -print0)
  done

  [ "$found_targets" -gt 0 ] || die "No target JavaScript directories found. Checked: $CODEX_RTL_TARGET_DIRS"

  if [ "$injected" -eq 0 ] && [ "$skipped" -eq 0 ]; then
    die "No suitable renderer JavaScript files found."
  fi

  success "Injected payload into $injected file(s); skipped $skipped already patched file(s)."

  step "Repacking app.asar..."
  asar_cmd pack "$TMP_DIR/app" "$TMP_DIR/app.asar.new"
  cp "$TMP_DIR/app.asar.new" "$PATCHED_ASAR"
  success "Repacked ASAR."
}

disable_integrity_and_sign() {
  step "Disabling Electron ASAR integrity validation..."
  fuses_cmd write --app "$PATCHED_APP" EnableEmbeddedAsarIntegrityValidation=off 2>&1 | while IFS= read -r line; do
    log "$line"
  done
  success "ASAR integrity validation disabled."

  step "Ad-hoc signing copied app..."
  codesign --force --deep --sign - "$PATCHED_APP" 2>&1 | while IFS= read -r line; do
    log "$line"
  done
  success "Copied app signed."
}

install_patch() {
  echo -e "\n${BOLD}${CYAN}Codex Desktop RTL Patcher - Install${NC}\n"
  check_source_app
  check_dependencies
  quit_codex_rtl
  prepare_copy
  inject_payload
  disable_integrity_and_sign

  rm -rf "$TMP_DIR" 2>/dev/null || true
  TMP_DIR=""

  step "Launching Codex-RTL..."
  open "$PATCHED_APP"
  success "Installed. Original app remains unchanged at $SOURCE_APP."
}

uninstall_patch() {
  echo -e "\n${BOLD}${CYAN}Codex Desktop RTL Patcher - Uninstall${NC}\n"
  if [ ! -d "$PATCHED_APP" ]; then
    warn "No patched app found at $PATCHED_APP."
    exit 0
  fi
  validate_destination_for_replace
  quit_codex_rtl
  step "Removing patched copy..."
  rm -rf "$PATCHED_APP"
  success "Removed $PATCHED_APP. Original Codex.app was not modified."
}

show_status() {
  echo ""
  echo -e "${BOLD}Codex Desktop RTL Patch - Status${NC}"
  echo ""
  if [ -d "$SOURCE_APP" ]; then
    local version
    version="$(bundle_value "$SOURCE_APP/Contents/Info.plist" CFBundleShortVersionString)"
    success "Original Codex.app: installed (${version:-unknown version})"
  else
    warn "Original Codex.app: not found at $SOURCE_APP"
  fi

  if [ -d "$PATCHED_APP" ]; then
    local name bundle_id version
    name="$(bundle_value "$PATCHED_APP/Contents/Info.plist" CFBundleDisplayName)"
    bundle_id="$(bundle_value "$PATCHED_APP/Contents/Info.plist" CFBundleIdentifier)"
    version="$(bundle_value "$PATCHED_APP/Contents/Info.plist" CFBundleShortVersionString)"
    success "Patched app: found at $PATCHED_APP (${version:-unknown version}, ${name:-unknown name}, ${bundle_id:-unknown id})"
    if [ -f "$MARKER_FILE" ]; then
      success "Safety marker: present"
    else
      warn "Safety marker: missing"
    fi
  else
    log "Patched app: not installed"
  fi
  echo ""
}

usage() {
  cat <<'EOF'

Codex Desktop RTL Patcher for macOS

Usage:
  ./patch.sh --install     Create or update ~/Applications/Codex-RTL.app
  ./patch.sh --uninstall   Remove ~/Applications/Codex-RTL.app
  ./patch.sh --status      Show install status
  ./patch.sh --help        Show this help

Environment overrides:
  CODEX_RTL_SOURCE_APP=/path/to/Codex.app
  CODEX_RTL_PATCHED_APP=/path/to/Codex-RTL.app
  CODEX_RTL_TARGET_DIRS=".vite/build webview/assets"
  CODEX_RTL_WEBVIEW_ENTRY_PATTERN='^(index|app-main)-.*\.js$'

EOF
}

case "${1:-}" in
  --install) install_patch ;;
  --uninstall) uninstall_patch ;;
  --status) show_status ;;
  --help|-h) usage ;;
  "") usage ;;
  *) err "Unknown option: $1"; usage; exit 1 ;;
esac
