import urllib.request, cairosvg, io, os
from PIL import Image
UA={"User-Agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/124 Safari/537.36"}
def fetch(prefix,name,color,px):
    url=f"https://api.iconify.design/{prefix}/{name}.svg?color={color.replace('#','%23')}&height={px}"
    return urllib.request.urlopen(urllib.request.Request(url,headers=UA),timeout=30).read().decode()

GOLD="#FFC25A"   # slightly brighter warm gold for presence
PREFIX,NAME="mdi","bible"
GRAD='<defs><linearGradient id="bg" x1="0" y1="0" x2="0.35" y2="1"><stop offset="0" stop-color="#2A1B2C"/><stop offset="1" stop-color="#130E11"/></linearGradient></defs>'
FLAT="#191015"

def mark_svg(px): 
    s=fetch(PREFIX,NAME,GOLD,px); return s[s.index("<svg"):]

def render(size, mark_frac, bg, transparent=False):
    mark=int(size*mark_frac); off=(size-mark)//2
    bgrect="" if transparent else (f'<rect width="{size}" height="{size}" fill="url(#bg)"/>' if bg=="grad" else f'<rect width="{size}" height="{size}" fill="{bg}"/>')
    defs=GRAD if bg=="grad" and not transparent else ""
    svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}">{defs}{bgrect}<g transform="translate({off},{off})">{mark_svg(mark)}</g></svg>'
    png=cairosvg.svg2png(bytestring=svg.encode(),output_width=size,output_height=size)
    return Image.open(io.BytesIO(png)).convert("RGBA")

def bg_only(size):
    svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}">{GRAD}<rect width="{size}" height="{size}" fill="url(#bg)"/></svg>'
    png=cairosvg.svg2png(bytestring=svg.encode(),output_width=size,output_height=size)
    return Image.open(io.BytesIO(png)).convert("RGBA")

os.makedirs("out",exist_ok=True)
def save_rgb(im,path): im.convert("RGB").save(path)
def save_rgba(im,path): im.save(path)

# Full icons: mark ~58% on gradient, opaque (no alpha for iOS)
full=render(1024,0.58,"grad")
save_rgb(full,"out/app-icon-all.png")
save_rgb(full,"out/app-icon-ios.png")
save_rgb(full,"out/app-icon-android-legacy.png")
# Web favicon
save_rgb(render(196,0.58,"grad"),"out/app-icon-web-favicon.png")
# Android adaptive: foreground = mark in safe zone (transparent), background = gradient
save_rgba(render(1024,0.44,"grad",transparent=True),"out/app-icon-android-adaptive-foreground.png")
save_rgb(bg_only(1024),"out/app-icon-android-adaptive-background.png")
# Splash preview = foreground on flat #191015 (how Expo composes it)
splash_preview=Image.new("RGBA",(1024,1024),FLAT); fg=render(1024,0.30,"grad",transparent=True)
splash_preview.alpha_composite(fg); save_rgb(splash_preview,"out/_splash_preview.png")
print("done", os.listdir("out"))
