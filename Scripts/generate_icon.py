#!/usr/bin/env python3
"""Optional icon regeneration (Pillow); the generated assets are checked in."""
from pathlib import Path
import json
import math
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
assets = ROOT / "Moment/Assets.xcassets"
icon_dir = assets / "AppIcon.appiconset"
accent_dir = assets / "AccentColor.colorset"
icon_dir.mkdir(parents=True, exist_ok=True)
accent_dir.mkdir(parents=True, exist_ok=True)

size = 1024
image = Image.new("RGB", (size, size))
pixels = image.load()
for y in range(size):
    for x in range(size):
        light = max(0, 1 - math.hypot((x - 230) / 1100, (y - 140) / 1100))
        pixels[x, y] = (int(17 + 47 * light), int(159 + 53 * light), int(157 + 43 * light))

decoration = Image.new("RGBA", image.size)
draw = ImageDraw.Draw(decoration)
draw.ellipse((530, -300, 1330, 500), outline=(255, 255, 255, 22), width=60)
draw.ellipse((-400, 660, 300, 1360), outline=(255, 255, 255, 15), width=65)
image = Image.alpha_composite(image.convert("RGBA"), decoration)
mark = Image.new("RGBA", image.size)
draw = ImageDraw.Draw(mark)
points = [(275, 716), (275, 330), (512, 580), (749, 330), (749, 716)]
draw.line(points, fill=(248, 255, 252, 255), width=88, joint="curve")
for x, y in points:
    draw.ellipse((x - 44, y - 44, x + 44, y + 44), fill=(248, 255, 252, 255))
shadow = Image.new("RGBA", image.size)
shadow.paste((6, 83, 84, 85), (0, 12, size, size + 12), mark.getchannel("A"))
image = Image.alpha_composite(image, shadow.filter(ImageFilter.GaussianBlur(14)))
image = Image.alpha_composite(image, mark).convert("RGB")
image.save(icon_dir / "AppIcon.png", optimize=True)

def write(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")

write(assets / "Contents.json", {"info": {"author": "xcode", "version": 1}})
write(icon_dir / "Contents.json", {
    "images": [{"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
    "info": {"author": "xcode", "version": 1},
})
write(accent_dir / "Contents.json", {
    "colors": [{"idiom": "universal", "color": {"color-space": "srgb", "components": {
        "alpha": "1.000", "red": "0.360", "green": "0.890", "blue": "0.820"}}}],
    "info": {"author": "xcode", "version": 1},
})
print("Generated Moment app icon and accent color")
