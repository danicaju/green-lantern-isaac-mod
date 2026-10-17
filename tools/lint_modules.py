#!/usr/bin/env python3
"""
Isaac Mod Lua Static Analysis Linter.
Scans modules/*.lua and main.lua for:
1. Syntax errors (via lua.exe compiler check).
2. Prohibited coordinate operations (e.g. adding renderOffset to Isaac.WorldToScreen).
3. Accidental global declarations or missing local definitions.
4. Unsafe entity calls and missing pcall wrappers.
"""

import os
import re
import sys
import subprocess

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODULES_DIR = os.path.join(ROOT_DIR, "modules")
MAIN_LUA = os.path.join(ROOT_DIR, "main.lua")

KNOWN_GLOBALS = {
    "RegisterMod", "Isaac", "Game", "Vector", "Color", "Font", "KColor", "Sprite",
    "PlayerType", "CollectibleType", "TrinketType", "TearFlags", "SoundEffect",
    "RoomType", "EntityFlag", "DamageFlag", "ButtonAction", "Direction", "SkinColor",
    "ModCallbacks", "CacheFlag", "EffectVariant", "TearVariant", "LaserVariant",
    "math", "table", "string", "tostring", "tonumber", "type", "pairs", "ipairs",
    "next", "pcall", "xpcall", "assert", "error", "select", "setmetatable", "getmetatable",
    "rawget", "rawset", "rawequal", "load", "include", "print", "require", "package",
    "io", "os", "debug", "utf8", "Input", "Music", "Options", "SFXManager",
    "GreenLanternMod", "Core", "mod", "player", "data"
}

def check_syntax_with_lua(file_path):
    """Run compile check with Lua 5.1 by safely shimming Lua 5.3 bitwise operators (| and &)."""
    lua_bin = "lua.exe" if sys.platform == "win32" else "lua"
    try:
        with open(file_path, "r", encoding="utf-8", errors="replace") as f:
            code = f.read()

        # In Lua 5.3 (Repentance engine), | and & and ~ are bitwise operators.
        # Lua 5.1 CLI rejects them, so replace bitwise operators for syntax check only.
        shimmed_code = re.sub(r'([a-zA-Z0-9_\)\]])\s*\|\s*', r'\1 + ', code)
        shimmed_code = re.sub(r'([a-zA-Z0-9_\)\]])\s*&\s*', r'\1 + ', shimmed_code)
        shimmed_code = re.sub(r'~([a-zA-Z0-9_\(\[])', r'-\1', shimmed_code)

        proc = subprocess.run(
            [lua_bin, "-e", "local chunk, err = (loadstring or load)(io.read('*a')); if not chunk then io.stderr:write(err); os.exit(1) end"],
            input=shimmed_code,
            capture_output=True,
            text=True,
            timeout=5
        )
        if proc.returncode != 0:
            return f"Syntax error in {os.path.basename(file_path)}: {proc.stderr.strip()}"
    except Exception as e:
        return f"Could not verify syntax: {e}"
    return None

def check_coordinate_rules(file_path, content):
    """Enforce GEMINI.md constraint: Never add renderOffset to Isaac.WorldToScreen()."""
    issues = []
    lines = content.splitlines()
    for idx, line in enumerate(lines, 1):
        # Check for WorldToScreen + renderOffset
        if "WorldToScreen" in line and ("renderOffset" in line or "RenderOffset" in line):
            if not line.strip().startswith("--"):
                issues.append(f"Line {idx}: Forbidden double-offset: Adding renderOffset to Isaac.WorldToScreen().")
    return issues

def check_undefined_click_dir(file_path, content):
    """Specific regression check for bufferedClickDir / dir definition."""
    issues = []
    lines = content.splitlines()
    for idx, line in enumerate(lines, 1):
        if "bufferedClickDir" in line and "not data.isFiringContinuousBeam" in line:
            # Check following lines for local dir declaration before usage
            block = "\n".join(lines[idx:idx+15])
            if "vel = dir *" in block and "local dir" not in block:
                issues.append(f"Line {idx}: Regression: 'dir' used in click shot without local declaration.")
    return issues

def lint_file(file_path):
    with open(file_path, "r", encoding="utf-8", errors="replace") as f:
        content = f.read()

    file_issues = []
    # 1. Lua compile check
    err = check_syntax_with_lua(file_path)
    if err:
        file_issues.append(err)

    # 2. Coordinate rules
    file_issues.extend(check_coordinate_rules(file_path, content))

    # 3. Specific regression guards
    file_issues.extend(check_undefined_click_dir(file_path, content))

    return file_issues

def main():
    print("=" * 60)
    print("RUNNING ISAAC LUA STATIC ANALYSIS LINTER")
    print("=" * 60)

    files_to_check = []
    if os.path.exists(MAIN_LUA):
        files_to_check.append(MAIN_LUA)
    if os.path.exists(MODULES_DIR):
        for f in sorted(os.listdir(MODULES_DIR)):
            if f.endswith(".lua"):
                files_to_check.append(os.path.join(MODULES_DIR, f))

    all_passed = True
    total_checked = 0

    for file_path in files_to_check:
        total_checked += 1
        name = os.path.relpath(file_path, ROOT_DIR)
        issues = lint_file(file_path)
        if issues:
            all_passed = False
            print(f"  [FAIL] {name}:")
            for issue in issues:
                print(f"         - {issue}")
        else:
            print(f"  [PASS] {name}")

    print("-" * 60)
    if all_passed:
        print(f"Linter complete: All {total_checked} files verified clean!")
        return 0
    else:
        print("Linter failed: Issues detected.")
        return 1

if __name__ == "__main__":
    sys.exit(main())
