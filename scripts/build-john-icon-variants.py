# Derives every platform icon/splash variant from the single generated
# production icon (assets/artwork/john-icon.png): the Chi Rho mark is lifted
# off its plum field so iOS 18 dark/tinted icons, the splash mark, and the
# Android adaptive layers all share one source of truth.
#
#   python3 scripts/build-john-icon-variants.py
#
# Requires Pillow and numpy.
import os
import numpy as np
from PIL import Image, ImageFilter

SRC = "assets/artwork/john-icon.png"
OUT = "assets/artwork"
SIZE = 1024

icon = Image.open(SRC).convert("RGB")
rgb = np.asarray(icon).astype(np.float32)
lum = 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]

# The plum field never exceeds ~55 luminance and the ivory/gold mark never
# drops below ~85, so a soft ramp between them gives an anti-aliased mask.
LO, HI = 55.0, 90.0
alpha = np.clip((lum - LO) / (HI - LO), 0.0, 1.0)

# Colour of the field directly around the mark, used to un-mix edge pixels
# so the extracted mark carries no plum fringe on transparent backgrounds.
bg_samples = rgb[alpha == 0]
field = np.median(bg_samples, axis=0)
FIELD_HEX = "#%02X%02X%02X" % tuple(int(round(c)) for c in field)

a3 = alpha[..., None]
unmixed = np.where(a3 > 0.02, (rgb - (1 - a3) * field) / np.maximum(a3, 0.02), rgb)
unmixed = np.clip(unmixed, 0, 255)


def rgba(colour, a):
    out = np.dstack([colour, a * 255.0]).round().astype(np.uint8)
    return Image.fromarray(out, "RGBA")


mark = rgba(unmixed, alpha)
ys, xs = np.where(alpha > 0.5)
bbox = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
print("field colour", FIELD_HEX, "mark bbox", bbox)


def save(img, name, **kw):
    path = os.path.join(OUT, name)
    img.save(path, optimize=True, **kw)
    print("wrote", path, img.mode, img.size)


# --- iOS 18 appearance variants -------------------------------------------
# Dark: transparent field, the system paints its own dark gradient behind it.
save(mark, "john-icon-dark.png")

# Tinted: opaque greyscale on black; the system tints the whole image, so the
# mark is pushed toward white for a bright, legible glyph.
mark_l = 0.299 * unmixed[..., 0] + 0.587 * unmixed[..., 1] + 0.114 * unmixed[..., 2]
mark_l = np.clip((mark_l - 60) / (235 - 60), 0, 1) ** 0.8 * 255
tinted = (mark_l * alpha)[..., None].repeat(3, axis=2)
save(Image.fromarray(tinted.round().astype(np.uint8), "RGB"), "john-icon-tinted.png")

# --- Splash mark -----------------------------------------------------------
# Tight crop of the mark with a little breathing room; expo-splash-screen
# scales it to `imageWidth` points, so the crop's width IS the mark's width.
PAD = 24
crop = mark.crop((bbox[0] - PAD, bbox[1] - PAD, bbox[2] + PAD, bbox[3] + PAD))
save(crop, "john-splash.png")

# --- Android adaptive icon ---------------------------------------------------
# Foreground: the mark scaled so every pixel sits inside the 66% safe circle
# (with margin), because launchers mask the layer into circles/squircles.
SAFE_R = 0.5 * 0.66 * SIZE * 0.94
cx, cy = (bbox[0] + bbox[2]) / 2, (bbox[1] + bbox[3]) / 2
r = np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2).max()
scale = SAFE_R / r
mw, mh = bbox[2] - bbox[0], bbox[3] - bbox[1]
small = mark.crop(bbox).resize((round(mw * scale), round(mh * scale)), Image.LANCZOS)
fg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
fg.alpha_composite(small, ((SIZE - small.width) // 2, (SIZE - small.height) // 2))
save(fg, "john-adaptive-foreground.png")
print("adaptive scale %.3f, mark %dx%d px" % (scale, small.width, small.height))

# Monochrome (Android 13 themed icons): the same silhouette in solid white.
mono = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
mono.putalpha(fg.getchannel("A"))
save(mono, "john-adaptive-monochrome.png")

# Background: the plum field re-synthesised without the mark. A quadratic
# surface fitted to the untouched field reproduces the vignette, and the
# paper grain is sampled from the mark-free left strip and tiled with mirrored
# seams, so nothing of the Chi Rho (or its shadow) ghosts through the launcher
# mask.
hole = Image.fromarray((alpha * 255).round().astype(np.uint8), "L").filter(ImageFilter.MaxFilter(61))
free = np.asarray(hole) == 0
yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32) / SIZE
basis = np.stack([np.ones_like(xx), xx, yy, xx * xx, yy * yy, xx * yy], axis=-1)
smooth = np.zeros_like(rgb)
for c in range(3):
    coef, *_ = np.linalg.lstsq(basis[free], rgb[..., c][free], rcond=None)
    smooth[..., c] = basis @ coef
grain = rgb - np.asarray(icon.filter(ImageFilter.GaussianBlur(2.5))).astype(np.float32)
strip = grain[:, :200]
tiles = [strip if i % 2 == 0 else strip[:, ::-1] for i in range(6)]
grain_tiled = np.concatenate(tiles, axis=1)[:, :SIZE]
background = np.clip(smooth + grain_tiled, 0, 255)
save(Image.fromarray(background.round().astype(np.uint8), "RGB"), "john-adaptive-background.png")

# --- Web favicon --------------------------------------------------------------
save(icon.resize((256, 256), Image.LANCZOS), "../images/john-favicon.png")

print("splash/adaptive background colour:", FIELD_HEX)
