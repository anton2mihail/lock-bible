# Derives every platform icon and splash file from the real painting.
#
# The source is assets/artwork/john-icon.png: a square crop of the 6th-century
# Christ Pantocrator icon at Saint Catherine's Monastery, Sinai. The wider
# Android layer, assets/artwork/john-adaptive-background.png, is a second crop
# of the same photograph. scripts/fetch-artwork.py makes both crops from
# Wikimedia Commons (see assets/artwork/sources.json).
#
#   python3 scripts/fetch-artwork.py --only john-icon john-adaptive-background
#   python3 scripts/build-john-icon-variants.py
#
# This script does not draw anything. It only resizes, copies, and applies one
# global colour adjustment to the whole image:
#   - john-icon-dark.png: the icon at 80% brightness (iOS dark appearance).
#   - john-icon-tinted.png: the icon in greyscale (iOS tinted appearance; the
#     system adds the tint colour).
#   - john-splash.png: the icon resized to 360x360 (120 pt at 3x).
#   - images/john-favicon.png: the icon resized to 256x256.
#   - Android drawable-nodpi/john_background.png: a byte copy of the adaptive
#     layer. The launcher icon has no separate foreground or monochrome layer.
#
# Requires Pillow.
import pathlib
import shutil

from PIL import Image, ImageEnhance, ImageOps

ROOT = pathlib.Path(__file__).resolve().parent.parent
ART = ROOT / "assets" / "artwork"
SRC = ART / "john-icon.png"
ADAPTIVE = ART / "john-adaptive-background.png"
ANDROID = ROOT / "native/Android/app/src/main/res/drawable-nodpi/john_background.png"
SIZE = 1024

icon = Image.open(SRC).convert("RGB")
if icon.size != (SIZE, SIZE):
    raise SystemExit(f"{SRC} must be {SIZE}x{SIZE}, not {icon.size}")


def save(img: Image.Image, path: pathlib.Path) -> None:
    img.save(path, optimize=True)
    print("wrote", path.relative_to(ROOT), img.mode, img.size)


# iOS 18 appearance variants. Both stay opaque, like the light icon.
save(ImageEnhance.Brightness(icon).enhance(0.8), ART / "john-icon-dark.png")
save(ImageOps.grayscale(icon).convert("RGB"), ART / "john-icon-tinted.png")

# Splash mark: expo-splash-screen shows it 120 pt wide on the plum colour.
save(icon.resize((360, 360), Image.LANCZOS), ART / "john-splash.png")

# Web favicon.
save(icon.resize((256, 256), Image.LANCZOS), ROOT / "assets/images/john-favicon.png")

# Native Android launcher layer.
shutil.copyfile(ADAPTIVE, ANDROID)
print("copied", ADAPTIVE.relative_to(ROOT), "->", ANDROID.relative_to(ROOT))
