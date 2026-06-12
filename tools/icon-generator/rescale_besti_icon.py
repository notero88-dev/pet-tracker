"""
Re-scale the Besti dog-pin artwork to fill more of the icon canvas.

The hand-made besti_icon.png / _foreground.png had the dog-pin occupying
only ~45% of the 1024 canvas, leaving a large cream margin. On the iOS
home screen the launcher applies its own rounded-corner mask, so the
artwork should extend much closer to the edges. This script:

  1. Detects the artwork bounding box (non-cream for the full icon;
     non-transparent for the adaptive foreground).
  2. Scales the cropped artwork so its larger dimension hits a target
     fraction of the canvas.
  3. Re-composites it centered — on cream for the full icon, on
     transparent for the foreground.

Targets differ by purpose:
  - besti_icon.png        → 0.86 (fills the iOS / legacy-square icon)
  - besti_icon_foreground → 0.72 (Android adaptive crops to a central
    circle/squircle; staying ~72% keeps the pin inside the safe zone)

Re-run: python3 tools/icon-generator/rescale_besti_icon.py
then: dart run flutter_launcher_icons
"""

import os
from PIL import Image

CREAM = (250, 247, 242)
CANVAS = 1024
HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(HERE, "..", "..", "assets", "icons")


def _artwork_bbox_nontransparent(img: Image.Image):
    """BBox of pixels with alpha above a small threshold."""
    alpha = img.getchannel("A")
    # point() → 255 where alpha>16 else 0, then getbbox on that mask.
    mask = alpha.point(lambda a: 255 if a > 16 else 0)
    return mask.getbbox()


def _artwork_bbox_noncream(img: Image.Image):
    """BBox of pixels that differ from the cream background."""
    rgb = img.convert("RGB")
    px = rgb.load()
    w, h = rgb.size
    minx, miny, maxx, maxy = w, h, 0, 0
    found = False
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            if abs(r - CREAM[0]) + abs(g - CREAM[1]) + abs(b - CREAM[2]) > 24:
                found = True
                if x < minx:
                    minx = x
                if y < miny:
                    miny = y
                if x > maxx:
                    maxx = x
                if y > maxy:
                    maxy = y
    if not found:
        return None
    return (minx, miny, maxx + 1, maxy + 1)


def rescale(src_name: str, target_frac: float, on_cream: bool):
    src = os.path.join(ASSETS, src_name)
    img = Image.open(src).convert("RGBA")

    bbox = (
        _artwork_bbox_noncream(img) if on_cream
        else _artwork_bbox_nontransparent(img)
    )
    if bbox is None:
        print(f"  {src_name}: no artwork detected, skipping")
        return

    art = img.crop(bbox)
    aw, ah = art.size
    target_px = int(CANVAS * target_frac)
    scale = target_px / max(aw, ah)
    new_w = max(1, int(round(aw * scale)))
    new_h = max(1, int(round(ah * scale)))
    art = art.resize((new_w, new_h), Image.LANCZOS)

    if on_cream:
        canvas = Image.new("RGBA", (CANVAS, CANVAS), (*CREAM, 255))
    else:
        canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))

    ox = (CANVAS - new_w) // 2
    oy = (CANVAS - new_h) // 2
    canvas.alpha_composite(art, (ox, oy))
    canvas.save(src)
    print(f"  {src_name}: artwork {aw}x{ah} → {new_w}x{new_h} "
          f"(fill {target_frac:.0%}), centered")


if __name__ == "__main__":
    rescale("besti_icon.png", target_frac=0.86, on_cream=True)
    rescale("besti_icon_foreground.png", target_frac=0.72, on_cream=False)
    print("Done. Now run: dart run flutter_launcher_icons")
