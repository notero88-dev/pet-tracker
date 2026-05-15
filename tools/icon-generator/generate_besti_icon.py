"""
Generate the Besti app launcher icon programmatically from the
besti-G-paw-pin.svg geometry.

SVG source (in 512x512 viewBox):
  - rounded-square cream background (rx=112)
  - orange ring outline (cx=256 cy=256 r=200, stroke=18)
  - three orange toe circles at (208,220), (256,195), (304,220), r=20
  - orange paw-pad path: arc top + two cubic beziers down to a point

This script renders the same geometry at 1024x1024 using PIL so
flutter_launcher_icons can downscale to all platform densities.
Re-run with `python3 assets/icons/generate_besti_icon.py` after any
geometry tweak.
"""

import math
import os

from PIL import Image, ImageDraw

# Brand colors per the SVG.
CREAM = (250, 247, 242, 255)   # #FAF7F2 — background
ORANGE = (232, 163, 61, 255)   # #E8A33D — ring + paw

CANVAS = 1024
SVG_VIEWBOX = 512
SCALE = CANVAS / SVG_VIEWBOX


def s(v: float) -> int:
    """Convert SVG-space coord to canvas-space pixel."""
    return int(round(v * SCALE))


def cubic_bezier(p0, p1, p2, p3, n: int = 40):
    """Sample n+1 points along a cubic Bezier curve from p0 to p3."""
    pts = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        x = u**3 * p0[0] + 3 * u**2 * t * p1[0] + 3 * u * t**2 * p2[0] + t**3 * p3[0]
        y = u**3 * p0[1] + 3 * u**2 * t * p1[1] + 3 * u * t**2 * p2[1] + t**3 * p3[1]
        pts.append((x, y))
    return pts


def elliptical_arc_top(cx, cy, rx, ry, n: int = 30):
    """Top half of a horizontal-axis ellipse, traversed left -> right.
    Matches SVG: M (cx-rx, cy) A rx ry 0 0 1 (cx+rx, cy)."""
    pts = []
    for i in range(n + 1):
        # theta sweeps from pi -> 0 (left to right along the top)
        theta = math.pi * (1 - i / n)
        x = cx + rx * math.cos(theta)
        y = cy - ry * math.sin(theta)
        pts.append((x, y))
    return pts


def paw_pad_polygon():
    """The SVG path: arc(192,295)->(320,295) then bezier->(256,395) then bezier back."""
    arc = elliptical_arc_top(256, 295, 64, 50, n=30)
    bez1 = cubic_bezier((320, 295), (320, 344), (290, 385), (256, 395), n=30)
    bez2 = cubic_bezier((256, 395), (222, 385), (192, 344), (192, 295), n=30)
    pts = arc + bez1[1:] + bez2[1:]
    return [(s(x), s(y)) for x, y in pts]


def _draw_paw_marks(draw: ImageDraw.ImageDraw):
    """Ring + three toes + pad. Used by both the full icon and the foreground."""
    # Orange ring. SVG: r=200, stroke-width=18 → ring sits between r=191 and r=209.
    ring_outer = 200 + 18 / 2  # 209
    draw.ellipse(
        (s(256 - ring_outer), s(256 - ring_outer),
         s(256 + ring_outer), s(256 + ring_outer)),
        fill=None,
        outline=ORANGE,
        width=s(18),
    )

    # Three toe circles.
    for cx, cy in [(208, 220), (256, 195), (304, 220)]:
        r = 20
        draw.ellipse(
            (s(cx - r), s(cy - r), s(cx + r), s(cy + r)),
            fill=ORANGE,
        )

    # Paw pad — bezier-sampled polygon.
    draw.polygon(paw_pad_polygon(), fill=ORANGE)


def build_icon() -> Image.Image:
    """Full square icon — cream bg + orange paw marks."""
    img = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle(
        (0, 0, CANVAS - 1, CANVAS - 1),
        radius=s(112),
        fill=CREAM,
    )
    _draw_paw_marks(draw)
    return img


def build_foreground() -> Image.Image:
    """
    Adaptive-icon foreground — orange paw marks on transparent canvas.

    Android adaptive icons crop the foreground in different shapes (circle,
    squircle, rounded square) depending on launcher. Our paw marks already
    sit inside the central circle (r=200 in 512-space, ~64% of the 1024
    canvas), well inside the ~66% safe-zone Android allows after crop.
    """
    img = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    _draw_paw_marks(draw)
    return img


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))

    full = build_icon()
    out_full = os.path.join(here, "besti_icon.png")
    full.save(out_full)
    print(f"  wrote besti_icon.png             {full.size}  ({os.path.getsize(out_full)} bytes)")

    fg = build_foreground()
    out_fg = os.path.join(here, "besti_icon_foreground.png")
    fg.save(out_fg)
    print(f"  wrote besti_icon_foreground.png  {fg.size}  ({os.path.getsize(out_fg)} bytes)")
