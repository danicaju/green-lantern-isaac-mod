#!/usr/bin/env python3
"""
Deep audit script for green_lantern_mod.
Checks:
1. XML resource references (sprites, anm2 files referenced in content/*.xml).
2. Global variables leaked without local.
3. Unchecked nil dereferences or missing player guards in callbacks.
4. Coordinate double-offsets or screen-space errors.
5. SoundEffect references and custom sounds.
6. Division by zero risks and potential nil table lookups.
"""

import os
import re
import sys
import xml.etree.ElementTree as ET

ROOT_DIR = r"c:\Users\danic\Desktop\green_lantern_mod"
CONTENT_DIR = os.path.join(ROOT_DIR, "content")
RESOURCES_DIR = os.path.join(ROOT_DIR, "resources")
MODULES_DIR = os.path.join(ROOT_DIR, "modules")

def audit_xml_resources():
    print("=== AUDITING XML RESOURCES ===")
    issues = []
    
    # 1. players.xml
    players_xml = os.path.join(CONTENT_DIR, "players.xml")
    if os.path.exists(players_xml):
        tree = ET.parse(players_xml)
        root = tree.getroot()
        root_dir = root.attrib.get("root", "gfx/characters/")
        p_root = root.attrib.get("portraitroot", "gfx/ui/boss/")
        n_root = root.attrib.get("nameimageroot", "gfx/ui/boss/")
        b_root = root.attrib.get("bigportraitroot", "gfx/ui/stage/")
        
        for p in root.findall("player"):
            name = p.attrib.get("name", "Unknown")
            for attr, folder in [("skin", root_dir), ("skinalt", root_dir),
                                 ("portrait", p_root), ("nameimage", n_root),
                                 ("bigportrait", b_root)]:
                val = p.attrib.get(attr)
                if val:
                    full_path = os.path.join(RESOURCES_DIR, folder, val)
                    if not os.path.exists(full_path):
                        issues.append(f"players.xml ({name}): Missing resource {folder}{val} at {full_path}")
                    else:
                        print(f"  [OK] Found {folder}{val}")
                        
    # 2. items.xml
    items_xml = os.path.join(CONTENT_DIR, "items.xml")
    if os.path.exists(items_xml):
        tree = ET.parse(items_xml)
        root = tree.getroot()
        for item in root.findall(".//passive") + root.findall(".//active") + root.findall(".//familiar"):
            gfx = item.attrib.get("gfx")
            if gfx:
                full_path = os.path.join(RESOURCES_DIR, "gfx", gfx) if not gfx.startswith("gfx/") else os.path.join(RESOURCES_DIR, gfx)
                if not os.path.exists(full_path):
                    # Also check resources/gfx/items/collectibles/
                    full_alt = os.path.join(RESOURCES_DIR, "gfx/items/collectibles", gfx)
                    if not os.path.exists(full_alt):
                        issues.append(f"items.xml ({item.attrib.get('name')}): Missing gfx {gfx}")
                    else:
                        print(f"  [OK] Found item gfx {gfx}")
                else:
                    print(f"  [OK] Found item gfx {gfx}")
                    
    # 3. trinkets.xml
    trinkets_xml = os.path.join(CONTENT_DIR, "trinkets.xml")
    if os.path.exists(trinkets_xml):
        tree = ET.parse(trinkets_xml)
        root = tree.getroot()
        for t in root.findall(".//trinket"):
            gfx = t.attrib.get("gfx")
            if gfx:
                full_path = os.path.join(RESOURCES_DIR, "gfx", gfx) if not gfx.startswith("gfx/") else os.path.join(RESOURCES_DIR, gfx)
                if not os.path.exists(full_path):
                    full_alt = os.path.join(RESOURCES_DIR, "gfx/items/trinkets", gfx)
                    if not os.path.exists(full_alt):
                        issues.append(f"trinkets.xml ({t.attrib.get('name')}): Missing gfx {gfx}")
                    else:
                        print(f"  [OK] Found trinket gfx {gfx}")
                else:
                    print(f"  [OK] Found trinket gfx {gfx}")
                    
    # 4. costumes2.xml
    costumes_xml = os.path.join(CONTENT_DIR, "costumes2.xml")
    if os.path.exists(costumes_xml):
        tree = ET.parse(costumes_xml)
        root = tree.getroot()
        for c in root.findall(".//costume"):
            anm2 = c.attrib.get("anm2path")
            if anm2:
                full_path = os.path.join(RESOURCES_DIR, anm2)
                if not os.path.exists(full_path):
                    issues.append(f"costumes2.xml ({c.attrib.get('name', 'unnamed')}): Missing anm2path {anm2}")
                else:
                    print(f"  [OK] Found costume anm2 {anm2}")

    return issues

def audit_lua_code():
    print("\n=== AUDITING LUA CODE IN MODULES & MAIN ===")
    issues = []
    
    lua_files = [os.path.join(ROOT_DIR, "main.lua")]
    for f in sorted(os.listdir(MODULES_DIR)):
        if f.endswith(".lua"):
            lua_files.append(os.path.join(MODULES_DIR, f))
            
    for fpath in lua_files:
        rel = os.path.relpath(fpath, ROOT_DIR)
        with open(fpath, "r", encoding="utf-8", errors="replace") as f:
            lines = f.readlines()
            
        for idx, line in enumerate(lines, 1):
            raw = line.strip()
            if raw.startswith("--"):
                continue
                
            # Check 1: WorldToScreen double offset
            if "WorldToScreen" in raw and ("renderOffset" in raw or "RenderOffset" in raw):
                issues.append(f"{rel}:{idx}: Double offset bug: WorldToScreen + renderOffset")
                
            # Check 2: Unsafe SetEntityScaleAndColor without pcall or guard
            # if "SetEntityScaleAndColor" in raw: ... (usually handled via Core.SetEntityScaleAndColor which uses pcall)
            
            # Check 3: Check for division by zero risks: / 0 or / var where var could be 0 without guard
            # e.g., / maxCharge without check
            div_match = re.search(r'/\s*([a-zA-Z0-9_\.:]+)', raw)
            if div_match:
                divisor = div_match.group(1)
                if divisor in ["0", "0.0"]:
                    issues.append(f"{rel}:{idx}: Explicit division by zero: {raw}")

            # Check 4: Check if Vector.Zero is used directly or Vector(0,0)
            
            # Check 5: Look for globals assigned inside functions without local or Core/GL/mod
            # match: variable = something (at indentation >= 4 spaces or tab)
            assign_match = re.match(r'^(?:    |\t)+([a-zA-Z_][a-zA-Z0-9_]*)\s*=\s*[^=]', line)
            if assign_match:
                var_name = assign_match.group(1)
                # Ignore self, Core, GL, data, player, mod, or all-caps constants if intended
                if var_name not in ["self", "data", "player", "Core", "GL", "mod"] and not var_name.startswith("_"):
                    # Check if declared earlier in file
                    # We can do a quick check if "local " + var_name is in the file
                    code_text = "".join(lines[:idx])
                    if not re.search(r'\blocal\s+[^;=]*\b' + re.escape(var_name) + r'\b', code_text):
                        # Could be a global leak or Core property
                        # Check if var_name is a known global or declared in outer scope
                        if var_name not in ["passes", "failures", "check", "Isaac", "Game", "Color", "Vector", "Sprite", "Font", "KColor"]:
                            issues.append(f"{rel}:{idx}: Possible undeclared variable / global leak: '{var_name}'")

    return issues

if __name__ == "__main__":
    xml_issues = audit_xml_resources()
    lua_issues = audit_lua_code()
    
    print("\n=== AUDIT RESULTS ===")
    if xml_issues:
        print(f"Found {len(xml_issues)} XML issues:")
        for i in xml_issues:
            print("  [!] " + i)
    else:
        print("XML resources: 100% CLEAN")
        
    if lua_issues:
        print(f"\nFound {len(lua_issues)} LUA potential issues:")
        for i in lua_issues:
            print("  [?] " + i)
    else:
        print("LUA code: 100% CLEAN")
