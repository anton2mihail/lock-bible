# Frames raw simulator captures into App Store slides for iPhone + iPad.
# Raw captures: iPhone 17 Pro Max (1320x2868) and iPad Pro 13" (2064x2752)
# simulators; 04-lockscreen is a real Lock Screen with both widgets added.
# Slide background matches the icon plum (#371026).
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

# Override with RAW_DIR / OUT_DIR, e.g. RAW_DIR=marketing/screenshots/raw-2.0.2 OUT_DIR=marketing/screenshots/framed-2.0.2
# 2.0.2 order: the paged Reader (John 1, Pages mode) is slide 1.
RAW = os.environ.get("RAW_DIR", "marketing/screenshots/raw")
OUTROOT = os.environ.get("OUT_DIR", "marketing/screenshots/framed")
GOLD = (255, 194, 90); DIM = (181, 172, 166)

# Slide sets by release. RELEASE=2.0.2 rebuilds the old set; the default is the current one.
# A slide whose raw name is None is a text-only slide (no screenshot).
RELEASE = os.environ.get("RELEASE", "2.1.0")
SETS = {
  "2.0.2": {
    "iphone": [
      ("02-read","Turn the page, like a book","The complete Catholic Bible, page by page. Three editions. Free, and fully offline."),
      ("04-lockscreen","Scripture on your Lock Screen","A fresh verse every day — and all day long."),
      ("01-today","Your Catholic day at a glance","Today's readings, the Rosary, and a verse to carry with you."),
      ("05-readings","Walk with the Church year","Daily Mass readings and feast days, opened right in the Bible."),
      ("06-pray","Make room for prayer","The Rosary, novenas, everyday prayers, and Lectio Divina."),
      ("03-settings","Make it your own","Pages or scroll, text size, typeface and dark mode."),
    ],
    "ipad": [
      ("ipad-02-read","Turn the page, like a book","The complete Catholic Bible, page by page. Three editions. Free, and fully offline."),
      ("ipad-01-today","Your Catholic day at a glance","Today's readings, the Rosary, and a verse to carry with you."),
      ("ipad-04-pray","Make room for prayer","The Rosary, novenas, everyday prayers, and Lectio Divina."),
      ("ipad-03-settings","Make it your own","Pages or scroll, text size, typeface and dark mode."),
    ],
  },
  # 2.1.0 (store-conversion plan, Part A2): each caption is a plain statement of what the app is.
  "2.1.0": {
    "iphone": [
      ("02-read","The Catholic Bible. Three editions. Offline.","Douay-Rheims, the Clementine Vulgate and the WEB Catholic Edition, page by page."),
      ("01-today","Today's Mass readings and the saint of the day","The Church year on the United States Roman calendar."),
      ("06-pray","The Rosary, the Seven Sorrows, the chaplets","Novenas, everyday prayers and Lectio Divina."),
      ("04-lockscreen","A verse on your Lock Screen","A fresh verse as often as you like, from every 10 minutes to once a day."),
      ("07-works","26 Fathers and Doctors. 15 million words. Offline.","Augustine, Aquinas, Chrysostom and more. Read the first part of every work free."),
      (None,"No account. No ads. No subscription.","Everything works offline."),
    ],
    "ipad": [
      ("ipad-02-read","The Catholic Bible. Three editions. Offline.","Douay-Rheims, the Clementine Vulgate and the WEB Catholic Edition, page by page."),
      ("ipad-01-today","Today's Mass readings and the saint of the day","The Church year on the United States Roman calendar."),
      ("ipad-04-pray","The Rosary, the Seven Sorrows, the chaplets","Novenas, everyday prayers and Lectio Divina."),
      ("ipad-07-works","26 Fathers and Doctors. 15 million words. Offline.","Augustine, Aquinas, Chrysostom and more. Read the first part of every work free."),
    ],
  },
}

DEVICES = {
  "iphone": {
    "sizes": [(1284,2778,"iphone-6.7_1284x2778"),(1242,2688,"iphone-6.5_1242x2688"),(1320,2868,"iphone-6.9_1320x2868")],
    "slides": SETS[RELEASE]["iphone"],
  },
  "ipad": {
    "sizes": [(2048,2732,"ipad-13_2048x2732"),(2064,2752,"ipad-13_2064x2752")],
    "slides": SETS[RELEASE]["ipad"],
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
        canvas=gradient(W,H,(55,16,38),(24,8,18)).convert("RGBA")
        d=ImageDraw.Draw(canvas); y=int(H*0.055)
        for ln in wrap(d,head,hfont,W-int(W*0.14)):
            w=d.textlength(ln,font=hfont); d.text(((W-w)/2,y),ln,font=hfont,fill=GOLD); y+=hlh
        y+=int(H*0.006)
        for ln in wrap(d,sub,sfont,W-int(W*0.16)):
            w=d.textlength(ln,font=sfont); d.text(((W-w)/2,y),ln,font=sfont,fill=DIM); y+=slh
        if name is None:
            # Text-only slide: the heading above, then three plain lines in a card.
            lines=["Bible, Rosary, readings and saints, all offline","No sign-in, nothing to set up","Your notes stay private, synced only to your own iCloud if you choose"]
            lf=load(int(H*0.021)); lh=int(H*0.03); gap=int(H*0.022); pad=int(H*0.035)
            cw=int(W*0.78); cx=(W-cw)//2
            blocks=[wrap(d,ln,lf,cw-int(W*0.10)) for ln in lines]
            ch=pad*2+sum(len(b) for b in blocks)*lh+gap*(len(blocks)-1)
            cy=(H-ch)//2
            d.rounded_rectangle([cx,cy,cx+cw,cy+ch],radius=radius,fill=(74,28,52))
            ty=cy+pad
            for b in blocks:
                for part in b:
                    w=d.textlength(part,font=lf); d.text(((W-w)/2,ty),part,font=lf,fill=(240,232,226)); ty+=lh
                ty+=gap
            canvas.convert("RGB").save(f"{out}/{i:02d}-no-account.png")
            continue
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
    for root,_,files in os.walk(OUTROOT):
        for f in files:
            if f.endswith(".png"): os.remove(os.path.join(root,f))
for dev in DEVICES.values():
    for W,H,label in dev["sizes"]: render(W,H,label,dev["slides"])
print("done")
