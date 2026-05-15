"""
Generate the PetTrack / Petti app launcher icon programmatically.

Produces three variants in this folder:
- petti_icon.png             (full square, marigold bg + midnight paw + halo)
                                used as the legacy iOS / fallback icon
- petti_icon_foreground.png  (transparent bg, paw only, sized for adaptive icons)
- petti_icon_round.png       (circular variant for older Android)

Why programmatic instead of a hand-illustrated PNG: the design is simple
(paw silhouette on solid marigold), so Python PIL keeps the source editable
in version control and easy to re-tune as the brand evolves. Re-run with
`python3 assets/icons/generate_petti_icon.py` after any tweak.

Brand tokens come straight from lib/utils/petti_theme.dart (Marigold / Midnight).
"""

from PIL import Image, ImageDraw, ImageFilter

# Brand colors (must stay in sync with lib/utils/petti_theme.dart)
MARIGOLD = (232, 163, 61, 255)        # #E8A33D
MARIGOLD_BRIGHT = (242, 180, 87, 255)  # #F2B457 — gradient accent
MIDNIGHT = (14, 27, 44, 255)          # #0E1B2C
CLOUD = (250, 247, 242, 255)          # #FAF7F2

SIZE = 1024  # canvas size; flutter_launcher_icons downscales to all densities


def draw_paw(draw: ImageDraw.ImageDraw, cx: int, cy: int, scale: float, color):
    """Draw a paw print centered at (cx, cy). Scale=1.0 → fills ~600px box."""
    # Main pad (bottom rounded triangle / oval)
    pad_w = int(380 * scale)
    pad_h = int(300 * scale)
    pad_top = cy - int(20 * scale)
    pad_left = cx - pad_w // 2
    draw.ellipse(
        (pad_left, pad_top, pad_left + pad_w, pad_top + pad_h),
        fill=color,
    )

    # Toe pads (4 ovals above main pad)
    toe_w = int(140 * scale)
    toe_h = int(180 * scale)
    toe_y = cy - int(290 * scale)

    # Outer toes are positioned slightly lower than inner toes for natural feel
    toe_offsets_x = [-260, -100, 100, 260]  # relative to cx
    toe_offsets_y = [40, -10, -10, 40]      # relative to toe_y

    for ox, oy in zip(toe_offsets_x, toe_offsets_y):
        tx = cx + int(ox * scale) - toe_w // 2
        ty = toe_y + int(oy * scale)
        draw.ellipse((tx, ty, tx + toe_w, ty + toe_h), fill=color)


def build_full_icon() -> Image.Image:
    """Square icon with marigold background and midnight paw — main variant."""
    img = Image.new("RGBA", (SIZE, SIZE), MARIGOLD)
    draw = ImageDraw.Draw(img)

    # Subtle radial gradient: brighter marigold in upper-left, deeper in lower-right.
    # Implemented as a few overlay ellipses with low alpha — cheap pseudo-gradient.
    overlay = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    odraw = ImageDraw.Draw(overlay)
    for r, alpha in [(900, 25), (700, 40), (500, 55)]:
        odraw.ellipse(
            (SIZE // 2 - r, SIZE // 2 - r,
             SIZE // 2 + r, SIZE // 2 + r),
            fill=(*MARIGOLD_BRIGHT[:3], alpha),
        )
    img = Image.alpha_composite(img, overlay)

    draw = ImageDraw.Draw(img)
    draw_paw(draw, cx=SIZE // 2, cy=SIZE // 2 + 60, scale=1.05, color=MIDNIGHT)
    return img


def build_foreground() -> Image.Image:
    """
    Adaptive-icon foreground — paw on transparent background.

    Android adaptive icons crop the foreground in different shapes (circle,
    squircle, rounded square) depending on launcher. We keep the paw in the
    center 60% of the canvas to avoid being cropped on aggressive masks.
    """
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Slightly smaller scale so the paw stays inside the safe zone after crop.
    draw_paw(draw, cx=SIZE // 2, cy=SIZE // 2 + 40, scale=0.85, color=MIDNIGHT)
    return img


def build_round_icon() -> Image.Image:
    """Pre-Android-8 circular variant (manually masked)."""
    base = build_full_icon()
    mask = Image.new("L", (SIZE, SIZE), 0)
    mdraw = ImageDraw.Draw(mask)
    mdraw.ellipse((0, 0, SIZE, SIZE), fill=255)
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    out.paste(base, (0, 0), mask)
    return out


if __name__ == "__main__":
    import os
    here = os.path.dirname(os.path.abspath(__file__))

    full = build_full_icon()
    full.save(os.path.join(here, "petti_icon.png"))
    print(f"  wrote petti_icon.png            {full.size}")

    fg = build_foreground()
    fg.save(os.path.join(here, "petti_icon_foreground.png"))
    print(f"  wrote petti_icon_foreground.png {fg.size}")

    rnd = build_round_icon()
    rnd.save(os.path.join(here, "petti_icon_round.png"))
    print(f"  wrote petti_icon_round.png      {rnd.size}")
