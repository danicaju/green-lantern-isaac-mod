import os

base = r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources"
costume_files = []
for root, dirs, files in os.walk(base):
    for f in files:
        if "costume" in f.lower():
            costume_files.append(os.path.join(root, f))

print("Found costume files:", len(costume_files))
for cf in costume_files[:15]:
    print(cf)
