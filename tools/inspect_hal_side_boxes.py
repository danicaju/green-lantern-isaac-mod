import os
from PIL import Image

costume_dir = r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\characters\costumes"
isaac_img = Image.open(os.path.join(costume_dir, "character_001_isaac.png")).convert("RGBA")
hal_img = Image.open("resources/gfx/characters/hal_jordan.png").convert("RGBA")
thal_img = Image.open("resources/gfx/characters/tainted_hal.png").convert("RGBA")

# Let's inspect the entire sprite sheet row 0 and row 2 for Hal and THal vs Isaac:
# Isaac:
# Row 0:
# (0, 0): HeadDown 0
# (32, 0): HeadDown 1
# (64, 0): HeadSide 0
# (96, 0): HeadSide 1
# (128, 0): HeadUp 0
# (160, 0): HeadUp 1

# Let's write a script to inspect every pixel of Isaac's HeadSide (64, 0) and compare to Hal's (64, 0)
# What are the exact colors in Hal Jordan?
# Hal Jordan has:
# Hair: dark brown / black #281a14 / #181008
# Skin: peach #ffd8b0, shade #d89870, outline #281810
# Mask: green #00e050, shadow #008028, outline #003010
# Eyes: glowing white #ffffff, inner #d0ffd8
# Mouth: dark outline / smirk

# In Isaac's HeadSide:
# Notice:
# 1. Isaac's head shape in HeadSide:
#    It's an ellipse elongated slightly horizontally, facing right.
#    Back of head is at X=2..10
#    Top of head is at Y=2..6
#    Front of forehead is at X=24..26, Y=6..11
#    Nose / cheek curve sticks out at X=26..28, Y=14..18
#    Chin curves back at X=20..24, Y=22..25
#    Cheek blush / tear track: X=20..24, Y=17..19
#    Eye: positioned at X=14..19, Y=12..17
#    Ear: small ear at X=4..7, Y=15..18

# Now, what did Hal Jordan's artist do for (64, 0)?
# Let's inspect Hal Jordan's (64, 0) and (96, 0)!
print("Hal (64, 0) non-empty box:", hal_img.crop((64, 0, 96, 32)).getbbox())
print("Hal (96, 0) non-empty box:", hal_img.crop((96, 0, 128, 32)).getbbox())
