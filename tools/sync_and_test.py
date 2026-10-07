"""
tools/sync_and_test.py
Automated runner for The Binding of Isaac mod development:
1. Runs all unit tests (tools/test_*.lua) using lua.exe
2. Syncs modified mod files to the Steam mod directory via robocopy / shutil
"""

import os
import sys
import subprocess
import shutil

STEAM_MOD_DIR = r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\mods\green_lantern_mod"
PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def run_tests():
    print("=" * 60)
    print("RUNNING ISAAC MOD UNIT TESTS")
    print("=" * 60)
    tools_dir = os.path.join(PROJECT_DIR, "tools")
    test_files = [f for f in sorted(os.listdir(tools_dir)) if f.startswith("test_") and f.endswith(".lua")]
    
    passed = 0
    failed = 0
    for tf in test_files:
        full_path = os.path.join(tools_dir, tf)
        res = subprocess.run(["lua.exe", full_path], capture_output=True, text=True)
        if res.returncode == 0:
            print(f"  [PASS] {tf}")
            passed += 1
        else:
            print(f"  [FAIL] {tf}")
            print("        " + res.stderr.strip()[:200])
            failed += 1

    print("-" * 60)
    print(f"Results: {passed} passed, {failed} failed (Total: {len(test_files)})")
    return failed == 0

def sync_to_steam():
    print("\n" + "=" * 60)
    print("SYNCING MOD TO STEAM REBIRTH DIRECTORY")
    print("=" * 60)
    if not os.path.exists(STEAM_MOD_DIR):
        print(f"Error: Steam mod directory not found: {STEAM_MOD_DIR}")
        return False

    folders_to_sync = ["content", "modules", "resources"]
    files_to_sync = ["main.lua", "metadata.xml"]

    for folder in folders_to_sync:
        src = os.path.join(PROJECT_DIR, folder)
        dst = os.path.join(STEAM_MOD_DIR, folder)
        if os.path.exists(src):
            cmd = ["robocopy", src, dst, "/E", "/NFL", "/NDL", "/NJH", "/NJS"]
            subprocess.run(cmd, capture_output=True)
            print(f"  [SYNCED] {folder}/ -> Steam")

    for file_name in files_to_sync:
        src = os.path.join(PROJECT_DIR, file_name)
        dst = os.path.join(STEAM_MOD_DIR, file_name)
        if os.path.exists(src):
            shutil.copy2(src, dst)
            print(f"  [COPIED] {file_name} -> Steam")

    print("Sync complete!")
    return True

if __name__ == "__main__":
    tests_ok = run_tests()
    if tests_ok:
        sync_to_steam()
    else:
        print("\nSkipping sync due to test failures.")
        sys.exit(1)
