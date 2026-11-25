"""Bake original pixel masonry, field folios and the ten-room cross-section with Pillow."""
import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/upgrade/props"
INK = "#1a1822"
GRANITE = ["#292632", "#39343d", "#514b51", "#686263", "#82776f", "#a99b88", "#c7b698"]
BRASS = ["#312a32", "#493933", "#775540", "#a8784e", "#c69a69", "#e7c694", "#f4ddb3"]
NEAREST = Image.Resampling.NEAREST


def native(size):
    return Image.new("RGBA", size), random.Random(2317)


def shift(color, amount):
    if isinstance(color, str):
        color = bytes.fromhex(color.lstrip("#"))
    return tuple(max(0, min(255, a + amount)) for a in color[:3])


def chipped(draw, x, y, w, h, palette, rng, detail=True):
    """A single hewn block with a left-lit bevel and a chipped southeast edge."""
    if w < 3 or h < 3:
        return
    cut = min(2, (w - 1) // 3, (h - 1) // 2)
    edges = [(x+cut,y), (x+w-2,y), (x+w,y+1), (x+w,y+h-cut),
             (x+w-cut,y+h), (x+1,y+h), (x,y+h-2), (x,y+cut)]
    draw.polygon(edges, fill=palette[1])
    draw.polygon([(x+cut,y),(x+w-2,y),(x+w-1,y+1),(x+w-2,y+h-2),
                  (x+2,y+h-1),(x+1,y+h-3),(x+1,y+1)], fill=palette[2])
    draw.line([(x+1,y+h-3),(x+1,y+2),(x+cut+1,y+1),(x+w-3,y+1)], fill=palette[3])
    if not detail or h < 5:
        return
    a = rng.randint(2, max(2, w//3))
    draw.line((x+a,y+1,x+min(w-3,a+3),y+1),fill=palette[4])
    if w > 8 and rng.random() < .67:
        cx = x+rng.randint(3,w-4)
        draw.line([(cx,y+1),(cx-1,y+2),(cx,y+3)], fill=palette[1])
    for _ in range((w*h)//95):
        u,v = x+rng.randint(2,w-3), y+rng.randint(2,max(2,h-2))
        draw.line((u,v,u+rng.randrange(2),v),fill=palette[rng.choice([1,3])])


def write(name, im, scale=1):
    if scale != 1:
        im = im.resize((im.width*scale, im.height*scale), NEAREST)
    im.save(OUT / (name+".png"), optimize=True)


def furniture():
    # The tall brazier is a fluted bronze basket on a course of the altar's masonry.
    im,rng=native((24,36)); d=ImageDraw.Draw(im)
    d.ellipse((2,29,23,35),fill=(12,13,20,105))
    for x,y,w,h in [(4,28,16,4),(6,25,12,3),(8,17,8,8),(7,15,10,3)]:
        chipped(d,x,y,w,h,GRANITE,rng)
    d.polygon([(4,12),(19,12),(18,17),(15,20),(9,20),(6,17)],fill=BRASS[1],outline=INK)
    d.line([(6,14),(8,17),(10,18),(15,18),(18,15)],fill=BRASS[3])
    d.ellipse((4,10,20,14),fill="#3c2c2e",outline=BRASS[4]); d.line((7,14,16,14), fill=BRASS[4])
    d.polygon([(7,12),(6,9),(8,7),(9,4),(10,6),(13,3),(14,0),(16,4),(15,7),(18,6),(17,10),(15,12)],fill="#c46b3e")
    d.polygon([(9,11),(9,8),(11,9),(13,5),(14,6),(15,9),(14,12)],fill="#f4ae59")
    d.line([(11,11),(12,9),(13,10)],fill="#ffe6a2")
    write("lamp",im,2)
    im,rng=native((26,27));d=ImageDraw.Draw(im)
    d.ellipse((2,21,25,26),fill=(14,14,20,100))
    d.polygon([(7,6),(18,6),(18,10),(22,13),(23,18),(21,22),(16,25),(9,25),(4,21),(3,16),(5,12),(8,10)],fill="#37292e",outline=INK)
    d.polygon([(8,10),(17,10),(21,14),(21,18),(18,22),(14,24),(9,23),(6,20),(5,16)],fill="#7b4b3d")
    d.polygon([(8,11),(12,10),(15,11),(14,13),(9,15),(8,19),(6,18),(6,14)],fill="#b07450")
    d.line([(5,16),(9,18),(13,18),(17,16),(20,16)],fill="#d2a771")
    d.line([(7,18),(10,21),(13,19),(16,20),(19,17)],fill="#b3875d")
    d.ellipse((6,3,19,10),fill="#bb8b62",outline="#3d2e30")
    d.ellipse((8,4,17,8),fill="#413034");d.line((9,4,15,4),fill="#e0b382")
    write("pot",im,2)
    im,rng=native((32,22));d=ImageDraw.Draw(im)
    d.ellipse((2,14,31,21),fill=(14,14,20,95))
    for x,y,w,h in [(5,7,10,5),(16,6,8,5),(3,12,9,5),(12,12,11,5),(24,14,5,3),(8,4,8,4),(17,4,5,3)]:
        chipped(d,x,y,w,h,GRANITE,rng)
    d.line([(11,6),(13,7),(11,9)],fill=GRANITE[0]); d.point((4,19),fill=GRANITE[3])
    write("rubble",im,2)
    for armed in [False,True]:
        im,rng=native((30,22));d=ImageDraw.Draw(im)
        poly=[(4,3),(24,3),(28,15),(25,19),(3,19),(1,15)]
        d.polygon(poly,fill=GRANITE[1],outline=INK)
        d.line([(2,15),(5,4),(23,4)],fill=GRANITE[4])
        d.line([(4,16),(25,16),(27,14)],fill=GRANITE[3])
        e=-2 if armed else 0
        d.polygon([(6,6+e),(22,6+e),(24,14+e),(5,14+e)], fill="#5d4a43",outline="#292630")
        d.line([(6,13+e),(7,7+e),(21,7+e)],fill=BRASS[3 if armed else 2])
        for x in [4,24]:
            d.point((x,14),fill=BRASS[4])
        for x in [10,14]:
            d.line([(x,8+e),(x+3,10+e),(x,12+e)],fill="#f3c27e" if armed else "#9e8164")
        write("plate_armed" if armed else "plate",im,2)
        im,rng=native((24,19));d=ImageDraw.Draw(im)
        d.polygon([(1,9),(4,5),(16,4),(22,6),(23,13),(19,16),(4,17),(1,14)],fill=GRANITE[1],outline=INK)
        chipped(d,3,9,15,5,GRANITE,rng)
        d.polygon([(4,8),(8,4),(16,3),(20,5),(17,9)],fill=GRANITE[4])
        d.polygon([(17,7),(20,5),(22,7),(22,12),(18,15),(16,13)],fill=BRASS[3],outline=BRASS[0])
        d.line([(18,10),(20,8),(20,11),(18,12)], fill=INK,width=2)
        d.line([(6,8),(12,6),(16,6)], fill=BRASS[5] if armed else BRASS[2])
        if armed:
            d.line((17,11,23,10),fill="#f7c077")
        write("launcher_armed" if armed else "launcher",im,2)
    im,rng=native((64,48)); d=ImageDraw.Draw(im)
    d.rectangle((0,0,63,47),fill=GRANITE[0])
    for row in range(6):
        for col in range(-1,5):
            chipped(d,col*19+(row%2)*9,row*8,18,7,GRANITE,rng)
    write("wall",im,2)


def folio(name, manuscript):
    im,_=native((640,360)); d=ImageDraw.Draw(im); rng=random.Random(110+manuscript)
    # Binding, stitched pigskin corners and a narrow sheen beneath each section of paper.
    hull=[(12,12),(202,8),(318,15),(438,7),(626,12),(635,22),(634,343),
          (626,352),(440,347),(320,354),(200,348),(12,352),(4,344),(4,22)]
    d.polygon(hull,fill="#241e23",outline="#17161e",width=3)
    for off,color in [(5,"#4a3835"),(8,"#58463c")]:
        d.line([(11,18+off),(11,340-off),(201,338-off),(317,345-off)],fill=color)
        d.line([(628,20+off),(628,340-off),(441,337-off),(323,345-off)],fill=color)
    for side in (0,1):
        def mirror(point):
            return (639-point[0] if side else point[0],point[1])
        def line(points,color,width=1):
            d.line([mirror(p) for p in points],fill=color,width=width)
        for inset in range(5):
            pts=[(18,19+inset),(168,16+inset),(264,19+inset),(316,24+inset),
                 (316,336+inset),(224,331+inset),(17,338+inset)]
            d.polygon([mirror(p) for p in pts],fill=("#514640" if inset%2 else "#322e30"))
        base = (42,40,40) if manuscript else (32,37,40)
        pts=[(17,17),(166,14),(247,16),(303,20),(317,23),(317,335),(275,329),(210,327),(17,333)]
        d.polygon([mirror(p) for p in pts],fill=base)
        for j in range(13):
            x=304+j
            line([(x,22),(x,333)],shift(base,-j//2))
        for _ in range(2000):
            x,y=rng.randrange(24,296),rng.randrange(28,323)
            line([(x,y),(x+rng.choice((0,0,1,2)),y)],shift(base,rng.choice([-2,2,3])))
        edge = "#585049" if manuscript else "#53534e"
        line([(24,42),(24,28),(40,27)],edge)
        line([(25,315),(25,324),(40,324)],edge)
        for x,y in [(21,20),(21,327)]:
            line([(x,y),(x+12,y),(x,y+5),(x,y)],"#86715a")
            line([(x+2,y+1),(x+5,y+1)],"#b39772")
        # Hatch the corner like a used surveyor's folio, keeping the typesetting area clear.
        if manuscript:
            for k in range(6):
                line([(28+3*k,316),(47+3*k,310)],"#3d3836")
    d.polygon([(602,8),(611,8),(610,40),(606,37),(601,42)],fill="#854e45",outline="#493738")
    for x in [312,319,325]:
        d.line((x,29,x,327),fill="#28262a")
    for y in [36,87,267,315]:
        d.arc((311,y-3,328,y+3),0,180,fill="#766751",width=2)
    write(name,im)


def arch():
    source=Image.open(Path(__file__).with_name("sources")/"arch.png").convert("RGBA")
    source=source.resize((184,108),Image.Resampling.LANCZOS)
    # Only retain a one-pixel straight-alpha edge from the generated cutout.
    alpha=source.getchannel("A").point(lambda a:0 if a<44 else min(255,round(a*1.1)))
    source.putalpha(alpha)
    left,top=4,2
    front_mask=Image.new("L",source.size)
    m=ImageDraw.Draw(front_mask)
    # Exact stone soffit and pier contours; the aperture and all tread faces remain traversable.
    m.polygon([(18,0),(166,0),(164,31),(149,39),(148,76),(145,83),(128,85),
               (125,81),(125,50),(122,36),(115,29),(108,23),(99,20),(91,19),
               (79,20),(71,23),(63,29),(59,34),(59,48),(57,61),(56,81),
               (51,86),(34,84),(32,77),(34,37),(22,32)],fill=255)
    foreground=source.copy()
    foreground.putalpha(ImageChops.multiply(alpha,front_mask))
    for stage in ["open","closed","front"]:
        sprite=Image.new("RGBA",(192,128))
        art=foreground.copy() if stage=="front" else source.copy()
        if stage=="closed":
            # A forged portcullis sits behind the stone lip. Mask it to the opening.
            bars=Image.new("RGBA",source.size); d=ImageDraw.Draw(bars)
            for x in range(61,124,6):
                d.rectangle((x,14,x+2,55),fill="#28262c")
                d.line((x,17,x,54),fill="#615753")
                d.polygon([(x,55),(x+2,55),(x+1,58)],fill="#524944")
            for y in [34,46]:
                d.rectangle((57,y,126,y+2),fill="#393638")
                d.line((58,y,124,y),fill="#655a53")
                for x in range(61,124,12):
                    d.point((x+1,y+1),fill="#a18b71")
            aperture=Image.new("L",source.size); d=ImageDraw.Draw(aperture)
            d.polygon([(60,55),(60,35),(63,30),(70,24),(80,20),(90,19),(100,21),
                       (110,24),(117,30),(121,35),(122,56)],fill=255)
            bars.putalpha(ImageChops.multiply(aperture,bars.getchannel("A")))
            art.alpha_composite(bars)
        elif stage=="open":
            # Warm spill reaches the top steps only and leaves the jambs untouched.
            d=ImageDraw.Draw(art,"RGBA")
            for y,x0,x1,c in [(45,76,107,(119,100,76,255)),(48,72,108,(121,100,80,255)),(54,67,116,(116,97,84,255))]:
                d.line((x0,y,x1,y),fill=c)
        sprite.alpha_composite(art,(left,top))
        write("stairs_"+stage,sprite)


def tower():
    im=Image.open(Path(__file__).with_name("sources")/"valley.png").convert("RGBA")
    tower_src=Image.open(Path(__file__).with_name("sources")/"tower.png").convert("RGBA")
    # Retain the artist's furniture in all ten distinct rooms. Compress roof and foundation
    # independently so the route enters the actual room drawn at each gameplay marker.
    source_y=[0,203,288,370,450,515,590,655,720,785,875,992]
    target_y=[7,71,96,121,146,171,196,221,246,271,296,365]
    width=176; x=320-width//2
    for src_top,src_bottom,dst_top,dst_bottom in zip(source_y,source_y[1:],target_y,target_y[1:]):
        strip=tower_src.crop((0,src_top,tower_src.width,src_bottom))
        strip=strip.resize((width,dst_bottom-dst_top),Image.Resampling.LANCZOS)
        # Bring warm room paint into the same night air as the landscape around it.
        alpha=strip.getchannel("A")
        strip=ImageEnhance.Color(strip).enhance(.85)
        strip.putalpha(alpha)
        im.alpha_composite(strip,(x,dst_top))
    d=ImageDraw.Draw(im)
    for floor in range(10):
        y=296-floor*25
        d.line([(343,y+1),(345,y+2),(347,y+1)],fill="#62483e")
        d.line([(344,y),(346,y)],fill="#b39870")
    write("tower_cutaway",im)


def ground(floor):
    # One repeat spans the width of roughly eight flags. Treat the same source stone
    # differently in each storey while retaining the altar's ash-gray and mauve values.
    rng=random.Random(6141+floor)
    size=(192,144)
    bases=["3a3c47","3e4048","383d48","3d3942","463d3d","443f3e","443c43","3b3748","3d3746","463d42"]
    base=bases[floor-1]
    stone=Image.new("RGB",size,shift(base,-12)); d=ImageDraw.Draw(stone)
    for row in range(10):
        y=round(row*size[1]/10); bottom=round((row+1)*size[1]/10)-1
        widths=rng.sample(range(15,31),6)
        widths += [(192-sum(widths))//2]
        widths += [192-sum(widths)]
        offset=rng.randrange(7,18); x=-offset
        for w in widths:
            v=rng.randrange(-4,6); crack=rng.random(); seed=rng.randrange(100000)
            for dx in (-192,0,192):
                xx=x+dx
                palette=[shift(base,z+v) for z in (-14,-6,1,6,10)]
                chipped(d,xx,y,w-1,bottom-y,palette,random.Random(seed),detail=False)
                if crack<.32:
                    d.line([(xx+3,y+2),(xx+5,y+3),(xx+6,y+5),(xx+8,y+5)],fill=shift(base,v-4))
                    d.point((xx+5,y+2),fill=shift(base,v+7))
            x+=w
    # Add fine mineral and aggregate texture from the edition's own painted stone sheet.
    ref=Image.open(ROOT/"assets/edition/environment.png").convert("L")
    family=1 if floor<=4 else 2 if floor<=7 else 3 if floor<=9 else 4
    u,v=family%3*512,family//3*512
    grain=ref.crop((u,v,u+512,v+512)).resize(size,Image.Resampling.BILINEAR)
    details=grain.filter(ImageFilter.GaussianBlur(2))
    g=grain.load(); smooth=details.load(); pix=stone.load()
    for yy in range(size[1]):
        for xx in range(size[0]):
            delta=round((g[xx,yy]-smooth[xx,yy])*.53)
            pix[xx,yy]=shift(pix[xx,yy],delta)
    if floor in (8,9):
        for x,y in [(30,47),(124,121)]:
            d.line([(x-7,y-3),(x-4,y-2),(x-3,y),(x,y),(x+2,y+3),(x+8,y+5)],fill="#503742")
            d.line([(x-2,y),(x,y+1),(x+1,y+3)],fill="#684353")
    if floor==10:
        for x,y in [(41,36),(132,105)]:
            d.line([(x-4,y),(x,y-2),(x+4,y),(x,y+2),(x-4,y)],fill="#615054")
    return stone
if __name__ == "__main__":
    OUT.mkdir(parents=True,exist_ok=True)
    for i in range(1,11):
        write(f"floor_{i:02d}",ground(i),2)
    arch()
    furniture()
    folio("book_spread",False)
    folio("codex_spread",True)
    tower()
