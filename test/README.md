# Test Notes

This project is mostly a macOS integration patcher. Use these checks before running it:

```bash
bash -n patch.sh
node --check rtl-payload.js
test/injection-targets.test.sh
./patch.sh --status
```

The install path creates a copied app at `~/Applications/Codex-RTL.app` and leaves `/Applications/Codex.app` unchanged.
