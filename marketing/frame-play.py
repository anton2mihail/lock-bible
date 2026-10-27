# Frames raw Android emulator captures into Google Play phone screenshots (1.2.x, 27 Oct 2026).
# Raw captures: Pixel_8 emulator (1080x2400), debug build of release/2.2.1 (Android 1.2.1), System UI demo mode
# (09:41, full battery, Wi-Fi), feature date 5 December 2026 (first week of Advent), library purchased.
#   python3 marketing/frame-play.py
# Same look as the App Store slides (marketing/frame-screenshots.py): the icon's plum, gold for the label, and the
# app's own fonts (Lora headline, Space Grotesk text). Slides are 1080x1920: Play asks for 16:9 or 9:16. The
# screen runs off the bottom edge, so it stays large; the tab bar is cut.
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

RAW = os.environ.get("RAW_DIR", "marketing/screenshots/raw-play-1.2")
OUT = os.environ.get("OUT_DIR", "assets/play-store/screenshots")
FONTS = "node_modules/@expo-google-fonts"
W, H = 1080, 1920
PLUM_TOP, PLUM_BOTTOM = (61, 19, 42), (26, 9, 20)
GOLD, IVORY, DIM = (232, 190, 120), (247, 240, 230), (196, 182, 176)

# (raw capture, label, headline, subline). A slide without a capture is a text slide.
SLIDES = [
    ("today-fathers", "ADVENT WITH THE FATHERS", "The Fathers on today’s Gospel",
     "A comment for each day’s Gospel from the Catena Aurea of St Thomas Aquinas."),
    ("reader", "THE BIBLE", "The Catholic Bible, page by page",
     "The Douay-Rheims, the Latin Vulgate and the WEB Catholic Edition. All 73 books, offline."),
    ("library", "THE FATHERS & DOCTORS", "275 works of the Fathers and Doctors",
     "St Augustine, St John Chrysostom, St Leo the Great, St Thomas Aquinas and more. Offline."),
    ("rosary-3", "THE ROSARY", "Pray the Rosary, step by step",
     "Every set of mysteries, with a painting for each. Seven novenas, with their sources."),
    ("advent-wreath", "ADVENT", "The Advent wreath and the O Antiphons",
     "The Collect of each Sunday from the Roman Missal, and Rorate caeli."),
    ("today", "EVERY DAY", "The day’s readings and the saints",
     "The Church’s year on the Roman calendar of the United States."),
    (None, "JOHN 1:1", "No account. No ads.",
     "Everything works offline."),
]
TEXT_SLIDE_LINES = [
    "The Bible, the Rosary, the readings and the saints: free",
    "No sign-in, nothing to set up",
    "One optional purchase for the full Fathers library",
]


def font(path, size):
    return ImageFont.truetype(os.path.join(FONTS, path), size)


LABEL = font("space-grotesk/500Medium/SpaceGrotesk_500Medium.ttf", 30)
HEAD = font("lora/500Medium/Lora_500Medium.ttf", 74)
SUB = font("space-grotesk/400Regular/SpaceGrotesk_400Regular.ttf", 36)
CARD = font("space-grotesk/400Regular/SpaceGrotesk_400Regular.ttf", 40)


def gradient():
    column = Image.new("RGB", (1, H))
    for y in range(H):
        t = y / (H - 1)
        column.putpixel((0, y), tuple(int(PLUM_TOP[i] + (PLUM_BOTTOM[i] - PLUM_TOP[i]) * t) for i in range(3)))
    return column.resize((W, H)).convert("RGBA")


def wrap(draw, text, face, width):
    words, lines, line = text.split(), [], ""
    for word in words:
        test = (line + " " + word).strip()
        if draw.textlength(test, font=face) <= width:
            line = test
        else:
            lines.append(line)
            line = word
    lines.append(line)
    return lines


def balanced(draw, text, face, width):
    """Two lines of near-equal length rather than a long line and an orphan ("step by / step")."""
    if draw.textlength(text, font=face) <= width:
        return [text]
    words = text.split()
    best = None
    for k in range(1, len(words)):
        a, b = " ".join(words[:k]), " ".join(words[k:])
        wa, wb = draw.textlength(a, font=face), draw.textlength(b, font=face)
        if wa <= width and wb <= width and (best is None or max(wa, wb) < best[0]):
            best = (max(wa, wb), [a, b])
    return best[1] if best else wrap(draw, text, face, width)


def centered(draw, y, lines, face, fill, step):
    for line in lines:
        draw.text(((W - draw.textlength(line, font=face)) / 2, y), line, font=face, fill=fill)
        y += step
    return y


def header(draw, label, head, sub):
    # The label: gold capitals with tracking, then a short gold rule.
    x = W / 2 - sum(draw.textlength(c, font=LABEL) + 5 for c in label) / 2
    for c in label:
        draw.text((x, 92), c, font=LABEL, fill=GOLD)
        x += draw.textlength(c, font=LABEL) + 5
    draw.line([(W / 2 - 36, 146), (W / 2 + 36, 146)], fill=GOLD, width=3)
    y = centered(draw, 172, balanced(draw, head, HEAD, W - 150), HEAD, IVORY, 88)
    return centered(draw, y + 14, wrap(draw, sub, SUB, W - 170), SUB, DIM, 48)


def rounded(image, radius):
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, image.size[0] - 1, image.size[1] - 1], radius=radius, fill=255)
    out = image.convert("RGBA")
    out.putalpha(mask)
    return out


def slide(index, name, label, head, sub):
    canvas = gradient()
    draw = ImageDraw.Draw(canvas)
    bottom = header(draw, label, head, sub)
    if name is None:
        card_w, pad, gap, step = 860, 70, 46, 56
        blocks = [wrap(draw, line, CARD, card_w - 120) for line in TEXT_SLIDE_LINES]
        card_h = pad * 2 + sum(len(b) for b in blocks) * step + gap * (len(blocks) - 1)
        top = max(bottom + 120, (H - card_h) // 2)
        x = (W - card_w) // 2
        draw.rounded_rectangle([x, top, x + card_w, top + card_h], radius=44, fill=(78, 31, 56),
                               outline=(122, 72, 82), width=2)
        y = top + pad
        for block in blocks:
            y = centered(draw, y, block, CARD, IVORY, step) + gap
        canvas.convert("RGB").save(f"{OUT}/{index:02d}-no-account.png")
        return
    shot = Image.open(f"{RAW}/{name}.png").convert("RGB")
    width = 800
    height = int(shot.height * width / shot.width)
    shot = shot.resize((width, height), Image.LANCZOS)
    top = bottom + 50
    x = (W - width) // 2
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([x, top + 24, x + width, top + height + 24], radius=52, fill=(0, 0, 0, 170))
    canvas = Image.alpha_composite(canvas, shadow.filter(ImageFilter.GaussianBlur(40)))
    canvas.alpha_composite(rounded(shot, 52), (x, top))
    # A thin warm edge so the light screen sits cleanly on the plum.
    ImageDraw.Draw(canvas).rounded_rectangle([x - 1, top - 1, x + width, top + height], radius=53, outline=(140, 96, 98), width=2)
    canvas.convert("RGB").save(f"{OUT}/{index:02d}-{name}.png")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for old in os.listdir(OUT):
        if old.endswith(".png"):
            os.remove(os.path.join(OUT, old))
    for i, (name, label, head, sub) in enumerate(SLIDES, 1):
        slide(i, name, label, head, sub)
    print(f"{len(SLIDES)} slides in {OUT}")
