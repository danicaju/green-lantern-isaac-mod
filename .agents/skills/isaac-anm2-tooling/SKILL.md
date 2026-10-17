---
name: isaac-anm2-tooling
description: Guide and XML schema parser for The Binding of Isaac .anm2 animation files. Use when inspecting, debugging, or authoring character animations, custom costumes, item pedestal animations, or boss transitions.
---

# Isaac ANM2 Tooling & Animation Skill

This skill explains the structure, coordinate systems, and debugging methodologies for The Binding of Isaac `.anm2` XML animation files.

---

## 1. Anatomy of an ANM2 File

An `.anm2` file is an XML document describing 2D skeletal sprite animations:

```xml
<AnimatedActor>
  <Info CreatedBy="Isaac" Fps="30"/>
  <Content>
    <Spritesheets>
      <Spritesheet Id="0" Path="characters/hal_jordan.png"/>
      <Spritesheet Id="1" Path="characters/hal_jordan_extra.png"/>
    </Spritesheets>
    <Layers>
      <Layer Id="0" Name="body" SpritesheetId="0"/>
      <Layer Id="4" Name="head" SpritesheetId="0"/>
      <Layer Id="12" Name="extra" SpritesheetId="1"/>
    </Layers>
    <NullAnimations/>
    <Events/>
  </Content>
  <Animations DefaultAnimation="IdleDown">
    <Animation Name="IdleDown" FrameNum="1" Loop="false">
      <RootAnimation>
        <Frame XPosition="0" YPosition="0" Delay="1" Visible="true"/>
      </RootAnimation>
      <LayerAnimations>
        <LayerAnimation LayerId="4" Visible="true">
          <Frame XPosition="0" YPosition="-5" XPivot="16" YPivot="16" XCrop="0" YCrop="0" Width="32" Height="32" Delay="1" Visible="true"/>
        </LayerAnimation>
      </LayerAnimations>
    </Animation>
  </Animations>
</AnimatedActor>
```

---

## 2. Key Frame Attributes Explained

| Attribute | Type | Meaning |
| :--- | :--- | :--- |
| `XCrop`, `YCrop` | Integer | Top-left pixel coordinate on the referenced spritesheet (`Path`). |
| `Width`, `Height` | Integer | Size of the sprite rectangle sampled from the sheet. |
| `XPivot`, `YPivot` | Integer | Pixel offset within the crop rectangle where the anchor point sits. E.g., for a 32×32 head centered at (16, 16), `XPivot="16" YPivot="16"`. |
| `XPosition`, `YPosition`| Float | Offset of the layer relative to the entity center / root socket. |
| `XScale`, `YScale` | Float | Percentage scaling (default `100`). `-100` mirrors the frame horizontally (e.g. flipping Right into Left). |
| `Delay` | Integer | Duration in engine frames (at 30 FPS). `1` = 1 frame. |
| `Visible` | Boolean | Whether the layer is drawn in this frame. |

---

## 3. Layer Ordering in `001.000_player.anm2`

When Isaac renders a player:
1. **Layer 0 (`body`)**: Lower torso and walking legs.
2. **Layer 4 (`head`)**: The character's head sprite.
3. **Layer 12 (`extra`)**: Overlays and celebratory raised-arms body frames (`\o/`).
> [!IMPORTANT]
> Layer 12 renders **ON TOP OF** Layer 4 (`head`). When designing celebratory pickup sprites on Layer 12, the collar and neck must align cleanly over the chin of Layer 4.

---

## 4. Automated Inspection Pattern

Use Python scripts in `tools/` (e.g., `inspect_anm2.py`, `inspect_costume_layouts.py`) to parse XML nodes, calculate composite bounding boxes, and verify that all `(XCrop + Width, YCrop + Height)` stay within the sheet's canvas boundaries.
