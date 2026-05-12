# Codex Desktop RTL macOS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a standalone macOS patcher repository for Codex Desktop RTL support.

**Architecture:** A Bash script safely copies and patches Codex Desktop's Electron ASAR, while a JavaScript payload applies RTL behavior in the renderer. Documentation explains risks, install, uninstall, and update flow.

**Tech Stack:** Bash, Electron ASAR tooling via `@electron/asar`, Electron fuses via `@electron/fuses`, JavaScript DOM MutationObserver, macOS `codesign`.

---

### Task 1: Repository Files

**Files:**
- Create: `README.md`
- Create: `LICENSE`
- Create: `.gitignore`

- [ ] Add concise public documentation, MIT license, and local artifact ignores.

### Task 2: RTL Payload

**Files:**
- Create: `rtl-payload.js`

- [ ] Implement idempotent RTL detection for Hebrew and Arabic.
- [ ] Process editable fields, message-like text, lists, tables, and compact containers.
- [ ] Force code, diff, preformatted, and terminal-like regions to LTR.

### Task 3: macOS Patcher

**Files:**
- Create: `patch.sh`

- [ ] Add install, uninstall, status, and help modes.
- [ ] Copy `/Applications/Codex.app` to `~/Applications/Codex-RTL.app`.
- [ ] Extract, inject, repack, disable ASAR integrity validation, sign, and launch.
- [ ] Add safety checks for source, destination, dependencies, and idempotence.

### Task 4: Verification

**Files:**
- Create: `test/README.md`

- [ ] Run `bash -n patch.sh`.
- [ ] Run `node --check rtl-payload.js`.
- [ ] Initialize git and commit the repository.
- [ ] Run `./patch.sh --install` after user-approved dependency/network escalation if needed.
