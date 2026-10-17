---
name: lua-static-analysis
description: Automated static code analysis and syntax linting for Isaac Repentance+ Lua modules. Use when writing, refactoring, or testing Lua code to detect undefined variables, coordinate double-offset violations, missing pcall guards, and syntax errors.
---

# Lua Static Analysis Skill

This skill provides automated static analysis routines to safeguard against silent runtime bugs in The Binding of Isaac Repentance modding.

## Why This Matters
In The Binding of Isaac, callbacks executed by the game engine (`MC_POST_UPDATE`, `MC_POST_PLAYER_RENDER`, `MC_EVALUATE_CACHE`, etc.) run in protected or wrapped environments where `nil` dereferences or missing local variables can fail silently without displaying an error window, breaking features without obvious diagnostic logs.

## Running the Linter
The linter is integrated directly into the test pipeline:
```powershell
python tools/sync_and_test.py
```
Or run the static analysis tool standalone:
```powershell
python tools/lint_modules.py
```

## Checks Performed
1. **Syntax Verification**: Validates all `modules/*.lua` and `main.lua` against the Lua compiler syntax parser.
2. **Coordinate Bug Guard**: Verifies that `Isaac.WorldToScreen()` is NEVER combined with `renderOffset` in `MC_POST_PLAYER_RENDER` (preventing the double-offset camera bug in scrolling rooms).
3. **Regression Guards**: Checks that local variables (like `local dir` in discrete firing buffers) are explicitly declared before use.
4. **API Safety**: Flags unprotected entity method calls.
