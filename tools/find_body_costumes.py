import xml.etree.ElementTree as ET
import glob
import os

base = r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\characters"
body_anms = []
for f in glob.glob(os.path.join(base, "*.anm2")):
    try:
        tree = ET.parse(f)
        root = tree.getroot()
        for layer in root.findall(".//Layers/Layer"):
            if "body" in layer.attrib.get("Name", "").lower():
                body_anms.append(f)
                break
    except:
        pass

print("Costumes with body layer:", len(body_anms))
for b in body_anms[:10]:
    print(os.path.basename(b))
