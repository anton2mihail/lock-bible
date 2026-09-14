# Frames raw simulator captures into App Store slides for iPhone + iPad.
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

RAW = "marketing/screenshots/raw"
OUTROOT = "marketing/screenshots/framed"
GOLD = (255, 194, 90); DIM = (181, 172, 166)

DEVICES = {
  "iphone": {
    "sizes": [(1284,2778,"iphone-6.7_1284x2778"),(1242,2688,"iphone-6.5_1242x2688"),(1320,2868,"iphone-6.9_1320x2868")],
    "slides": [
      ("04-lockscreen","Scripture on your Lock Screen","A fresh verse every day — and all day long."),
      ("01-today","Your verse of the moment","Open the app for today's verse. Share it, or read it in context."),
      ("03-settings","Make it your own","Old Testament, New, or the whole Bible — rotating every 10 minutes to once a day."),
      ("02-read","The complete Catholic Bible","Every book, chapter, and verse. Free, and fully offline."),
    ],
  },
  "ipad": {
    "sizes": [(2048,2732,"ipad-13_2048x2732"),(2064,2752,"ipad-13_2064x2752")],
    "slides": [
      ("ipad-01-today","Your verse of the moment","A fresh verse every day — and all day long."),
      ("ipad-02-read","The complete Catholic Bible","Every book, chapter, and verse. Free, and fully offline."),
      ("ipad-03-settings","Make it your own","Old Testament, New, or the whole Bible — every 10 minutes to once a day."),
    ],
  },
}

def load(size, bold=False):
    try:
        f = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", size)
        try: f.set_variation_by_name("Bold" if bold else "Regular")
        except Exception: pass
        return f
    except Exception:
        p = "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf"
        return ImageFont.truetype(p, size)

def gradient(W,H,top,bot):
    base=Image.new("RGB",(1,H))
    for y in range(H):
        t=y/(H-1); base.putpixel((0,y),tuple(int(top[i]+(bot[i]-top[i])*t) for i in range(3)))
    return base.resize((W,H))

def wrap(draw,text,font,maxw):
    words,lines,cur=text.split(),[],""
    for w in words:
        t=(cur+" "+w).strip()
        if draw.textlength(t,font=font)<=maxw: cur=t
        else:
            if cur: lines.append(cur)
            cur=w
    if cur: lines.append(cur)
    return lines

def rounded(img,r):
    m=Image.new("L",img.size,0)
    ImageDraw.Draw(m).rounded_rectangle([0,0,img.size[0]-1,img.size[1]-1],radius=r,fill=255)
    o=img.convert("RGBA"); o.putalpha(m); return o

def render(W,H,label,slides):
    out=os.path.join(OUTROOT,label); os.makedirs(out,exist_ok=True)
    # font sizes scale with HEIGHT for visual consistency across devices
    hfont=load(int(H*0.030),bold=True); sfont=load(int(H*0.0155))
    hlh=int(H*0.036); slh=int(H*0.021); radius=int(min(W,H)*0.03)
    for i,(name,head,sub) in enumerate(slides,1):
        canvas=gradient(W,H,(42,27,44),(19,14,17)).convert("RGBA")
        d=ImageDraw.Draw(canvas); y=int(H*0.055)
        for ln in wrap(d,head,hfont,W-int(W*0.14)):
            w=d.textlength(ln,font=hfont); d.text(((W-w)/2,y),ln,font=hfont,fill=GOLD); y+=hlh
        y+=int(H*0.006)
        for ln in wrap(d,sub,sfont,W-int(W*0.16)):
            w=d.textlength(ln,font=sfont); d.text(((W-w)/2,y),ln,font=sfont,fill=DIM); y+=slh
        shot=Image.open(f"{RAW}/{name}.png").convert("RGB")
        sw=int(W*0.78); sh=int(shot.height*sw/shot.width); shot=shot.resize((sw,sh))
        card=rounded(shot,radius); top=H-sh-int(H*0.024); x=(W-sw)//2
        shimg=Image.new("RGBA",canvas.size,(0,0,0,0))
        ImageDraw.Draw(shimg).rounded_rectangle([x,top+18,x+sw,top+sh+18],radius=radius,fill=(0,0,0,150))
        canvas=Image.alpha_composite(canvas,shimg.filter(ImageFilter.GaussianBlur(34)))
        canvas.alpha_composite(card,(x,top))
        canvas.convert("RGB").save(f"{out}/{i:02d}-{name.replace('ipad-','').split('-',1)[-1]}.png")
    print(f"  {label}: {len(slides)} slides")

if os.path.isdir(OUTROOT):
    for f in os.listdir(OUTROOT):
        if f.endswith(".png"): os.remove(os.path.join(OUTROOT,f))
for dev in DEVICES.values():
    for W,H,label in dev["sizes"]: render(W,H,label,dev["slides"])
print("done")
