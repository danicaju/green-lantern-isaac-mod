import xml.etree.ElementTree as ET
import os

base = r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\characters"

def inspect_anm2(filename):
    print(f"\n================ {filename} ================")
    path = os.path.join(base, filename)
    tree = ET.parse(path)
    root = tree.getroot()
    for sheet in root.findall(".//Spritesheets/Spritesheet"):
        print("  Sheet:", sheet.attrib)
    for layer in root.findall(".//Layers/Layer"):
        print("  Layer:", layer.attrib)
    for anim in root.findall(".//Animations/Animation"):
        name = anim.attrib.get("Name")
        if name in ["WalkRight", "WalkLeft", "HeadRight", "HeadLeft", "WalkDown", "HeadDown"]:
            for la in anim.findall("LayerAnimations/LayerAnimation"):
                lid = la.attrib.get("LayerId")
                frames = la.findall("Frame")
                if frames:
                    f0 = frames[0].attrib
                    print(f"  Anim {name} - Layer {lid}: XCrop={f0.get('XCrop')} YCrop={f0.get('YCrop')} W={f0.get('Width')} H={f0.get('Height')} XPos={f0.get('XPosition')} YPos={f0.get('YPosition')} XPiv={f0.get('XPivot')} YPiv={f0.get('YPivot')} XScale={f0.get('XScale', '100')}")

inspect_anm2("169_Polyphemus.anm2")
inspect_anm2("070_Growth Hormones.anm2")
inspect_anm2("118_Brimstone.anm2")
inspect_anm2("028_The Belt.anm2")
