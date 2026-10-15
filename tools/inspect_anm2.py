import xml.etree.ElementTree as ET

tree = ET.parse(r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\001.000_player.anm2")
root = tree.getroot()

for anim in root.findall(".//Animations/Animation"):
    name = anim.attrib.get("Name")
    if name in ["WalkRight", "WalkLeft", "HeadRight", "HeadLeft", "WalkDown", "HeadDown", "WalkUp", "HeadUp"]:
        print(f"\n================ Animation: {name} ================")
        for la in anim.findall("LayerAnimations/LayerAnimation"):
            lid = la.attrib.get("LayerId")
            vis = la.attrib.get("Visible", "true")
            print(f"--- LayerId: {lid} (Visible={vis}) ---")
            for i, f in enumerate(la.findall("Frame")):
                print(f"  Frame {i}: XCrop={f.attrib.get('XCrop')} YCrop={f.attrib.get('YCrop')} W={f.attrib.get('Width')} H={f.attrib.get('Height')} XPos={f.attrib.get('XPosition')} YPos={f.attrib.get('YPosition')} XPiv={f.attrib.get('XPivot')} YPiv={f.attrib.get('YPivot')} XScale={f.attrib.get('XScale', '100')} YScale={f.attrib.get('YScale', '100')}")
