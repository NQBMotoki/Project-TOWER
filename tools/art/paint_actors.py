"""Author and bake articulated pixel cels. Positions are relative to the same 64-pixel stage."""
import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/upgrade/actors"
DIR8 = ["s","se","e","ne","n","nw","w","sw"]
DIR4 = ["s","e","n","w"]
BASE = ["idle","walk","windup","strike","recovery","hurt","dissolve"]
COUNTS = dict(idle=2,walk=6,windup=3,strike=3,recovery=3,hurt=2,dissolve=5,startled=4,
              appear=4,point_sword=4,point_staff=4,fade=4,
              assemble=4,phase=4,stance=2,final=2,gesture=4,defeated=5)
ACTIONS = {"archer":["melee"],"corrupted_archer":["melee","volley"],"corrupted_goblin":["rush"],
           "corrupted_skeleton":["zone"],"elite":["volley","sweep","rush"],"lord":["volley","zone","melee"]}
BOSS_POSES = {"elite":["assemble","phase","stance"],"lord":["phase","stance","final","gesture","defeated"]}
ALL = ["hero","hero_sword","hero_staff","knight","goblin","skeleton","archer","elite","lord",
       "corrupted_goblin","corrupted_skeleton","corrupted_archer","slime","corrupted_slime","ghost"]
KNIGHT = ["appear","point_sword","point_staff","fade"]
INK = "#211c27"
BONE = ["#66545a","#aa8e83","#dac3a4","#f4e2bc"]
STEEL = ["#3d3e4c","#747784","#a5a6aa","#d1cec0"]
HIDE = ["#372a31","#5d423a","#90634e","#be9173"]
GOLD = ["#554037","#835d43","#c39761","#ecd49b"]
SKIN = ["#795556","#b7826c","#e0b48a","#f4cfa0"]
BLUE = ["#293344","#405268","#657b89","#9cabb0"]
WINE = ["#382633","#633d49","#93585b","#c28879"]
VIOLET = ["#3d2945","#674261","#936685","#ba8fa0"]
OLIVE = ["#594637","#9c7547","#c49a5a","#e5c57b"]
KNIGHT_ARMOR = ["#2b4552","#496e79","#73959b","#acbec0"]
MINT = ["#26444c","#3e7677","#73ae9f","#c1e4c5"]
STRIDE = [1,.46,-.38,-1,-.46,.38]
RAISE = [0,0,2,0,0,2]


def pts(p):
    return [(round(x),round(y)) for x,y in p]


class Brush:
    def __init__(self):
        self.im=Image.new("RGBA",(64,64))
        self.d=ImageDraw.Draw(self.im)
    def shape(self,xy,fill,edge=None):
        self.d.polygon(pts(xy),fill=fill,outline=edge)
    def line(self,xy,color,w=1):
        self.d.line(pts(xy),fill=color,width=w,joint="curve")
    def dot(self,x,y,c):
        self.d.point((round(x),round(y)),fill=c)
    def oval(self,x,y,rx,ry,fill,edge=None):
        self.d.ellipse((round(x-rx),round(y-ry),round(x+rx),round(y+ry)),fill=fill,outline=edge)


def segment(b,a,c,width,palette):
    b.line([a,c],INK,width+2)
    b.line([a,c],palette[1],width)
    b.line([(a[0]-1,a[1]-1),(c[0]-1,c[1]-1)],palette[2],max(1,width//3))


def cloth(b,x,y,w,h,colors,yaw,phase,hanging=False):
    # Pointed overlapping cloth folds trail the weight-bearing leg.
    drag=round(phase*2)-(2 if yaw else 0)
    b.shape([(x-w*.77,y),(x+w*.55,y-1),(x+w*.78,y+4),(x+w+drag,y+h-1),
             (x+w*.48+drag,y+h-2),(x+w*.32+drag,y+h+1),(x+drag,y+h-1),
             (x-w*.40+drag,y+h+2),(x-w*.45+drag,y+h-1),(x-w-1+drag,y+h)],colors[0],INK)
    for spread in [-.63,-.2,.37]:
        b.shape([(x+w*spread,y+2),(x+w*(spread+.23),y+2),
                 (x+w*(spread+.36)+drag,y+h-3),(x+w*spread+drag-1,y+h-1)],
                colors[1 if spread!=-.63 else 2])
    if hanging:
        b.line([(x-w*.45,y+3),(x-w*.34+drag,y+h-2)],colors[3])


def hero_head(b,x,y,yaw,rear,look,blink=False):
    # Face planes turn independently of hair and the outer silhouette.
    hair=["#382c39","#58434b","#775965","#977481"]
    sx=round(yaw*2)
    if not rear:
        face=[(x-7+sx,y-3),(x+5+sx,y-4),(x+8,y-1),(x+8+sx,y+3),
              (x+6+sx,y+6),(x+2+sx,y+8),(x-3+sx,y+7),(x-7+sx,y+3)]
        b.shape(face,SKIN[1],INK)
        b.shape([(x-4+sx,y-2),(x+5+sx,y-3),(x+7+sx,y),
                 (x+7+sx,y+4),(x+2+sx,y+6),(x-2+sx,y+5)],SKIN[2])
        if yaw<.85:
            for dx in ([-3,4] if yaw<.2 else [-1,5]):
                b.line([(x+sx+dx,y+1),(x+sx+dx+1,y+1)],INK)
                if not blink:
                    b.dot(x+sx+dx+1,y+2,"#35343b")
        else:
            b.line([(x+6,y+1),(x+8,y+1)],INK)
            b.dot(x+8,y+3,SKIN[3])
        b.dot(x+sx+3,y+5,SKIN[3])
    hairline = [(x+7,y+1),(x+5,y-3),(x+2,y+1),(x+1,y-2),(x-3,y+3),
                (x-4,y),(x-7,y+4),(x-8,y+2)] if not rear else [
                (x+8,y+5),(x+5,y+7),(x+3,y+5),(x,y+8),(x-2,y+5),(x-5,y+6),(x-8,y+3)]
    b.shape([(x-9,y+2),(x-11,y),(x-8,y-3),(x-11,y-4),(x-7,y-6),
             (x-8,y-8),(x-3,y-7),(x-1,y-10),(x+2,y-8),(x+5,y-10),
             (x+5,y-7),(x+9,y-7),(x+7,y-5),(x+10,y-2)]+hairline,hair[1],INK)
    b.shape([(x-8,y-4),(x-5,y-6),(x-2,y-6),(x,y-8),(x+1,y-6),(x-2,y-3),(x-6,y-1)],hair[2])
    b.line([(x-5,y-5),(x-2,y-6),(x,y-7)],hair[3])
    b.shape([(x+2,y-5),(x+4,y-7),(x+6,y-7),(x+5,y-4),(x+2,y-1)],hair[2])
    if rear:
        b.line([(x-7,y),(x-4,y-2),(x-2,y-2)],hair[2])
        b.line([(x+1,y+4),(x+4,y+1),(x+5,y-1)],hair[0])
    elif yaw>.6:
        b.oval(x-1,y+2,1,2,SKIN[1]); b.dot(x-1,y+1,SKIN[2])


def hood_head(b,x,y,yaw,rear,kind,colors,corrupt):
    goblin=kind=="goblin"
    shades=OLIVE if goblin else BONE
    eye="#f5a8e6" if corrupt else "#29232c"
    for side in [-1,1] if yaw<.7 else [-1]:
        if goblin:
            b.shape([(x+side*5,y-3),(x+side*15,y-5),(x+side*10,y+1),(x+side*6,y+3)],shades[2],INK)
            b.line([(x+side*7,y-1),(x+side*11,y-3)],shades[0])
    b.shape([(x-9,y+1),(x-12,y+3),(x-10,y-2),(x-13,y-3),(x-9,y-4),
             (x-6,y-8),(x-2,y-10),(x+3,y-9),(x+7,y-7),(x+9,y-2),
             (x+8,y+4),(x+4,y+7),(x-3,y+7)],colors[1],INK)
    b.shape([(x-10,y-2),(x-6,y-6),(x-3,y-8),(x+2,y-8),(x+5,y-6),(x,y-5),(x-5,y-1),(x-7,y+3)],colors[2])
    b.line([(x-7,y-5),(x-4,y-7),(x-1,y-8)],colors[3])
    if rear:
        b.line([(x-4,y+2),(x-1,y-2),(x+3,y-4),(x+6,y-4)],colors[0])
        if corrupt:
            b.line([(x-5,y-7),(x-2,y-4),(x-3,y-2),(x,y)],"#ce73b2")
        return
    sx=round(yaw*3)
    b.shape([(x-5+sx,y-1),(x-2+sx,y-5),(x+3+sx,y-5),(x+7+sx,y-2),
             (x+7+sx,y+2),(x+3+sx,y+6),(x-2+sx,y+5),(x-4+sx,y+3)],shades[1],INK)
    b.shape([(x-3+sx,y-2),(x+sx,y-4),(x+4+sx,y-4),(x+6+sx,y-1),
             (x+4+sx,y+1),(x+1+sx,y),(x-2+sx,y+1)],shades[2])
    for dx in ([-2,3] if yaw<1 else [3]):
        b.line([(x+dx+sx,y),(x+dx+sx+2,y+1)],eye,2)
    b.dot(x+sx+1,y+3,shades[0])
    if not goblin:
        b.line([(x+sx,y+4),(x+sx+3,y+4)],shades[3])
        b.dot(x+sx+1,y+4,shades[0])
    if corrupt:
        b.line([(x-5,y-7),(x-1,y-5),(x-1,y-3)],"#d37bbe")


def lord_head(b,x,y,yaw,rear,kind,crowned=True):
    spectral=kind=="knight"
    p=KNIGHT_ARMOR if spectral else BONE
    sx=round(yaw*2)
    b.shape([(x-8,y-5),(x-5,y-9),(x+2,y-10),(x+7,y-7),(x+8,y),
             (x+6,y+5),(x+2,y+8),(x-4,y+6),(x-7,y+2)],p[1],INK)
    b.shape([(x-6,y-5),(x-4,y-8),(x+2,y-8),(x+6,y-5),(x+6,y-2),(x+1,y-3),(x-5,y)],p[2])
    b.line([(x-5,y-6),(x-2,y-8),(x+1,y-8)],p[3])
    if not rear:
        b.shape([(x-5+sx,y),(x-2+sx,y-1),(x+2+sx,y+1),(x+7,y-1),(x+6+sx,y+3),
                 (x+3+sx,y+4),(x+2+sx,y+6),(x-2+sx,y+4)],INK)
        if spectral:
            b.line([(x-4+sx,y),(x+sx,y+1),(x+6,y)],"#aae4df")
            b.line([(x+2+sx,y+2),(x+2+sx,y+5)],p[2])
        else:
            for i in [-2,4]:
                b.dot(x+i+sx,y+1,"#f193dc" if kind=="lord" else "#dba370")
            b.line([(x-2+sx,y+5),(x+1+sx,y+6),(x+4+sx,y+5)],p[3])
    if kind=="lord" and crowned:
        b.shape([(x-8,y-4),(x-11,y-13),(x-6,y-10),(x-4,y-5),(x-2,y-7),
                 (x,y-15),(x+2,y-7),(x+5,y-6),(x+10,y-14),(x+8,y-5),
                 (x+5,y-2),(x-1,y-3)],GOLD[2],INK)
        b.line([(x-9,y-11),(x-6,y-6),(x-3,y-5)],GOLD[3])
        b.shape([(x+1,y-9),(x+3,y-6),(x+1,y-4),(x-1,y-6)],"#e581d1")
    elif kind=="elite":
        for s in [-1,1]:
            b.shape([(x+5*s,y-6),(x+10*s,y-12),(x+8*s,y-4),
                     (x+5*s,y-2)],BONE[2],INK)
    elif kind!="lord":
        b.line([(x-1,y-8),(x-2,y-12),(x-6,y-14),(x-10,y-13)],MINT[2],2)
        b.line([(x-7,y-13),(x-12,y-10)],MINT[1],2)


def held_weapon(b,kind,hand,other,heading,reach,state,role,corrupt):
    x,y=hand; dx,dy=heading
    if kind=="archer" and role!="melee":
        # Recurve tips bow away from the archer; string and arrow follow the drawn hand.
        ax,ay=x+dx*2,y+dy*2
        t=(-dy,dx)
        tips=[(ax-dx*3+t[0]*10,ay-dy*3+t[1]*10),
              (ax-dx*3-t[0]*10,ay-dy*3-t[1]*10)]
        bow=[tips[0],(ax+t[0]*8,ay+t[1]*8),(ax+dx*3+t[0]*3,ay+dy*3+t[1]*3),
             (ax+dx*3-t[0]*3,ay+dy*3-t[1]*3),(ax-t[0]*8,ay-t[1]*8),tips[1]]
        b.line(bow,INK,4);b.line(bow,"#b78965",2)
        nock=(ax-dx*(5+reach*5),ay-dy*(5+reach*5))
        b.line([tips[0],nock,tips[1]],"#c7b79d")
        if state=="windup":
            tip=(ax+dx*7,ay+dy*7);b.line([nock,tip],"#c9a889")
            b.dot(*tip,"#efdfbd")
        if corrupt:
            for a,c in tips:
                b.dot(a,c,"#df8de2")
        return
    if kind=="skeleton":
        if role=="zone":
            end=(x+3,y-13)
        else:
            end=(x+4+dx*reach*4,y-12+dy*reach*4)
        end=(min(58,max(5,end[0])),min(60,max(8,end[1])))
        b.line([(x-3,y+9),hand,end],INK,4)
        b.line([(x-3,y+9),hand,end],"#a38164",2)
        ex,ey=end
        b.shape([(ex-3,ey),(ex-2,ey-4),(ex+1,ey-6),(ex+4,ey-2),(ex+2,ey+1)],"#a052a1",INK)
        b.line([(ex,ey-4),(ex+1,ey-3),(ex,ey-2)],"#f3afd9")
        return
    if role in ["volley","zone"] and kind in ["elite","lord"]:
        return
    if kind in ("hero","knight"):
        return
    angle=math.atan2(dy,dx)
    if state=="windup":
        angle-=1.8*reach
    elif state=="strike":
        angle+=.6*reach-.3
    else:
        angle-=.75
    vx,vy=math.cos(angle),math.sin(angle)
    length=14 if kind in ["lord","elite"] else 10
    perp=(-vy,vx)
    # Shorten perspective on a full side lunge before the blade reaches the cell edge.
    limits=[length]
    if abs(vx)>.01: limits.append(((61 if vx>0 else 2)-x)/vx)
    if abs(vy)>.01: limits.append(((61 if vy>0 else 2)-y)/vy)
    length=max(2,min(limits))
    ex,ey=x+vx*length,y+vy*length
    guard=(x+vx*2,y+vy*2)
    b.line([(x-vx*2,y-vy*2),guard],GOLD[2],3)
    if kind=="elite" and role in ["sweep", "rush"]:
        heel=(x-vx*7,y-vy*7)
        b.line([heel,(ex,ey)],INK,4)
        b.line([heel,(ex,ey)],HIDE[2],2)
        b.shape([(ex-vx*6+perp[0]*4,ey-vy*6+perp[1]*4),(ex,ey),
                 (ex-vx*7-perp[0]*4,ey-vy*7-perp[1]*4)],BONE[2],INK)
        b.line([(ex-vx*3,ey-vy*3),(ex-vx*6+perp[0]*3,ey-vy*6+perp[1]*3)],BONE[3])
        return
    b.shape([(guard[0]+perp[0]*2,guard[1]+perp[1]*2),
             (ex,ey),(guard[0]-perp[0]*2,guard[1]-perp[1]*2)],STEEL[2],INK)
    b.line([guard,(ex-vx,ey-vy)],STEEL[3])
    b.line([(guard[0]+perp[0]*3,guard[1]+perp[1]*3),
            (guard[0]-perp[0]*3,guard[1]-perp[1]*3)],GOLD[2])


def shards(image,index,palette,reverse=False):
    if reverse:
        index=4-index
    if index<=0:
        return image
    # Remove fragments in drifting bands. Each surviving cluster travels as a cluster.
    result=Image.new("RGBA",image.size)
    p=image.load(); q=result.load()
    for y in range(64):
        for x in range(64):
            c=p[x,y]
            if c[3]==0: continue
            u,v=x//3,y//3
            bit=((u*313+v*587+u*v*7)%103)/103
            edge=(52-y)/54*.25
            if bit+edge < index*.238:
                continue
            drift=max(0,(index-1))*(bit+.38)
            ox=x+round(math.sin(u*.8+v*.4)*drift*1.6)
            oy=y-round(drift*(2+.7*math.cos(u)))
            if 1<=ox<63 and 1<=oy<63:
                if bit+edge<index*.238+.07:
                    c=(*bytes.fromhex(palette.lstrip("#")),210)
                q[ox,oy]=c[:3]+(int(c[3]*(1-.10*index)),)
    return result


# Directional front and profile cels retain the edition's original painted facial features.
# Masks use percentages of each character's original art region; no weapon is baked into them.
HEADS = {
    "hero": ((1002,670,178,232), [(12,0),(85,0),(85,29),(77,38),(66,46),(47,44),(28,38),(13,31)],23,20),
    "goblin": ((378,78,191,187), [(4,0),(96,0),(96,21),(73,48),(64,55),(44,51),(35,48),(6,27)],27,20),
    "corrupted_goblin": ((988,381,214,206), [(5,0),(98,0),(98,29),(77,43),(68,56),(53,54),(43,48),(33,48),(7,28)],27,21),
    "skeleton": ((670,34,228,239), [(11,7),(72,7),(72,39),(65,52),(53,59),(38,57),(25,50),(12,44)],22,20),
    "corrupted_skeleton": ((28,647,254,269), [(12,8),(71,8),(71,38),(64,49),(53,56),(38,53),(29,48),(12,43)],22,20),
    "archer": ((988,70,227,195), [(18,0),(61,0),(72,24),(69,35),(61,44),(51,48),(38,46),(25,41),(16,35)],21,20),
    "corrupted_archer": ((351,649,238,257), [(18,9),(62,9),(69,26),(67,40),(59,50),(47,52),(36,48),(25,43),(16,36)],21,20),
    "elite": ((20,338,258,263), [(36,0),(79,0),(83,19),(74,29),(69,39),(56,44),(48,38),(41,29),(34,24)],20,21),
    "lord": ((646,632,264,284), [(31,0),(76,0),(76,15),(67,25),(62,35),(51,38),(43,33),(38,25)],23,24),
}
HEAD_CACHE = {}


def painted_head(b,identity,x,y,yaw):
    name="hero" if identity.startswith("hero") else identity
    key=(name,yaw)
    if key not in HEAD_CACHE:
        bounds,contour,w,h=HEADS[name]
        xx,yy,ww,hh=bounds
        original=Image.open(ROOT/"assets/edition/actors.png").convert("RGBA")
        raw=original.crop((xx,yy,xx+ww,yy+hh)).resize((100,100),Image.Resampling.LANCZOS)
        stencil=Image.new('L',(100,100))
        ImageDraw.Draw(stencil).polygon(contour,fill=255)
        raw.putalpha(ImageChops.multiply(raw.getchannel("A"),stencil))
        raw=raw.crop(raw.getbbox())
        tex=raw.resize((round(w*(1-.11*yaw)),h),Image.Resampling.LANCZOS)
        tex=tex.filter(ImageFilter.UnsharpMask(radius=.7,percent=105,threshold=3))
        tex.putalpha(tex.getchannel("A").point(lambda v:255 if v>110 else 0))
        HEAD_CACHE[key]=tex
    face=HEAD_CACHE[key]
    b.im.alpha_composite(face,(round(x-face.width*.50+yaw),round(y+7-face.height)))


def humanoid(identity,direction,full_state,index):
    mirrored="w" in direction
    canonical=direction.replace("w","e")
    yaw={"s":0,"se":.64,"e":1,"ne":.64,"n":0}[canonical]
    rear=canonical in ["n","ne"]
    vector={"s":(0,1),"se":(.707,.707),"e":(1,0),"ne":(.707,-.707),"n":(0,-1)}[canonical]
    state,_,role=full_state.partition("_")
    kind=identity.removeprefix("corrupted_")
    held=kind.removeprefix("hero_") if kind.startswith("hero_") else ""
    if kind.startswith("hero"):
        kind="hero"
    knight=kind=="knight"; corrupt=identity.startswith("corrupted_")
    if knight:
        state=full_state
        canonical="s"; yaw=.22; rear=False; vector=(1,0)
    walk=STRIDE[index] if state=="walk" else 0
    cycle=math.sin(index*math.pi/3)
    bend=0; reach=0; lean=0; rise=0
    if state=="walk":
        rise=[0,-1,-2,0,-1,-2][index]
        lean=1
    elif state=="idle":
        rise=-index
    elif state=="windup":
        reach=[.22,.66,1][index]
        bend=reach*3; lean=-reach*3
    elif state=="strike":
        reach=[1,.83,.55][index]
        lean=4*reach; rise=-1
    elif state=="recovery":
        reach=[.57,.29,.08][index];lean=reach*2;bend=reach*2
    elif state=="hurt":
        reach=[1,.36][index];lean=-3*reach;bend=2*reach
    elif state=="startled":
        reach=[.4,1,.72,.28][index];lean=-3*reach;bend=3*reach
    elif state=="assemble":
        bend=[11,8,4,0][index]
        reach=[.3,.7,.9,.45][index]
    elif state=="phase":
        reach=[.15,.8,1,.64][index]
        bend=[5,2,0,1][index]
    elif state in ["stance","final"]:
        reach=[.48,.60][index]
        bend=2 if state=="stance" else 0
        rise=-index
    elif state=="gesture":
        reach=[.12,.35,.70,.87][index]
        lean=reach*2.5
    elif state=="defeated":
        reach=[.12,.34,.53,.77,1][index]
        bend=[2,7,12,10,9][index]
        lean=reach*3
    elif state=="dissolve" and kind=="elite":
        bend=[1,5,9,11,12][index]
    if kind=="goblin": bend+=3
    if role=="rush":
        lean+=1+reach*2;bend+=2*reach
    if knight:
        rise=[0,-1,-1,0][index]
        if state in ["point_sword", "point_staff"]:
            yaw=[.16,.28,.51,.64][index]
            lean=(1 if state=="point_staff" else -1)*[0,.5,1,1.5][index]
    b=Brush()
    robe = {"hero":BLUE,"goblin":VIOLET if corrupt else WINE,"skeleton":VIOLET,
            "archer":VIOLET if corrupt else ["#3f3645","#695d70","#8f8290","#b1a0a6"],
            "lord":["#372335","#633342","#983e48","#c26660"],"elite":WINE,"knight":MINT}[kind]
    armor=KNIGHT_ARMOR if knight else (BONE if kind in ["elite","lord","skeleton"] else (GOLD if kind=="goblin" else STEEL))
    flesh=KNIGHT_ARMOR if knight else (SKIN if kind=="hero" else OLIVE if kind=="goblin" else BONE)
    front=-1 if rear else 1
    lateral=1-.48*yaw
    hipx=32+round(vector[0]*lean*.32); hipy=40+rise+bend
    shouldx=32+round(vector[0]*lean); shouldy=30+rise+bend
    headx=shouldx+round(vector[0]*lean*.36); heady=21+rise+bend
    if kind in ["elite","lord"]: heady-=1
    if kind=="goblin": heady+=1;shouldy+=1
    if state=="startled":
        shouldy-=reach*2
        heady+=reach
    width=10 if kind in ["elite","lord"] else 8
    legs=[]
    for side in [-1,1]:
        swing=walk*side
        footx=32+side*5.5*lateral+vector[0]*swing*5
        footy=54+vector[1]*swing*3
        if state=="walk" and swing<0:
            footy-=abs(swing)*1.5
        if state=="startled" and side==-1:
            footx-=vector[0]*reach*3
            footy-=vector[1]*reach*3
        if state in ["windup","strike"]:
            footx+=side*reach*2
            footy+=side*reach*vector[1]
        kneex=hipx+side*4*lateral+vector[0]*swing*3+yaw*1.5
        kneey=(hipy+footy)/2-1-(1-max(0,swing))*yaw
        legs.append(((hipx+side*3*lateral,hipy-1),(kneex,kneey),(footx,footy),side))
    for hip,knee,foot,side in sorted(legs,key=lambda l:l[2][1]):
        fx,fy=foot
        if kind=="lord" and state!="defeated":
            continue
        if state=="defeated":
            fy=min(57,fy)
            knee=(knee[0]+side*2, min(46,knee[1]))
        segment(b,hip,knee,4 if kind!="goblin" else 3,HIDE if kind=="hero" else armor)
        segment(b,knee,(fx,fy-1),3 if kind in ["skeleton","archer"] else 4,HIDE if kind in ["hero","goblin"] else armor)
        toe=1+round(yaw*3)
        b.shape([(fx-3,fy-3),(fx+2,fy-3),(fx+toe,fy-1),(fx+toe+1,fy),
                 (fx+toe,fy+1),(fx-3,fy+1)],HIDE[1] if kind in ["hero","goblin"] else armor[1],INK)
        b.line([(fx-2,fy-2),(fx,fy-2),(fx+toe,fy)],HIDE[2] if kind=="hero" else armor[2])
        if kind in ["elite","archer","skeleton"]:
            b.dot(knee[0]-1,knee[1]-1,BONE[3])
    if kind in ["lord","knight","elite","skeleton","archer","goblin"]:
        cape_height=28 if kind=="lord" else (23 if kind in ["knight","skeleton","archer","elite"] else 14)
        if state in ["defeated","dissolve"]:
            cape_height=min(cape_height,57-shouldy)
        cloth(b,shouldx-yaw*2,shouldy-3,round(width*(1.3 if kind=="lord" else 1)),
              cape_height,robe,yaw,walk,
              kind in ["lord","knight"])
    # The primary hand is on screen right looking south, on screen left when looking north.
    # For profiles it moves ahead of the other hand, with the far forearm painted first.
    arms=[]
    for side in [-1,1]:
        s=(shouldx+side*width*lateral,shouldy)
        primary=side==(1 if not rear else -1)
        phase=walk*(-side)*2.5
        hx=s[0]+side*(2.5-yaw)+vector[0]*(phase+1.8)
        hy=s[1]+8+vector[1]*phase
        if primary and (held or kind in ["goblin","skeleton","archer","elite","lord"]):
            hx+=vector[0]*3;hy-=2+(1 if held=="staff" else 0)
        if primary and (state in ["windup","strike","recovery"]):
            if state=="windup":
                hx-=vector[0]*reach*6;hy-=reach*6
            elif state=="strike":
                hx+=vector[0]*reach*8;hy+=vector[1]*reach*6-2
            else:
                hx+=vector[0]*reach*4;hy+=vector[1]*reach*3
        if role in ["zone","volley"] and (primary or kind=="lord"):
            hx=s[0]+side*(4+reach*5)
            hy=s[1]-2-reach*(9 if role=="zone" else 5)
        if kind=="archer" and role!="melee" and not primary:
            hx=shouldx+vector[0]*2;hy=shouldy+4
        if state in ["hurt","startled"]:
            hx=s[0]-side*reach*4; hy=s[1]+7-reach*6
        if state in ["phase","assemble","stance","final"]:
            hx=s[0]+side*(2+reach*(7 if state in ["phase","final"] else 4))
            hy=s[1]+7-reach*(12 if state in ["phase","final"] else 5)
        if primary and state in ["gesture","defeated"]:
            hx=s[0]+(vector[0] if abs(vector[0])>.1 else side*.7)*(2+reach*10)
            hy=s[1]+vector[1]*reach*6+3-reach*4
        if knight and state in ["point_sword","point_staff"]:
            target=-1 if state=="point_sword" else 1
            if side==target:
                amp=[.12,.52,.87,1][index]
                hx=s[0]+side*(2+14*amp);hy=s[1]+7-amp*8
        el=(s[0]+(hx-s[0])*.48+side*2,s[1]+(hy-s[1])*.6+2)
        arms.append((side,primary,s,el,(hx,hy)))
    def paint_arm(arm):
        side,primary,s,el,end=arm
        segment(b,s,el,5 if kind in ["elite","lord","hero","knight"] else 3,armor if kind in ["elite","knight","archer"] else robe)
        segment(b,el,end,3 if kind!="hero" else 4,HIDE if kind=="hero" else armor if kind in ["elite","knight"] else flesh)
        b.oval(s[0],s[1],4 if kind in ["hero","elite","lord","knight"] else 3,3,armor[1],INK)
        b.line([(s[0]-2,s[1]),(s[0]-1,s[1]-2),(s[0]+1,s[1]-2)],armor[3])
        b.oval(*end,2,2,HIDE[2] if kind=="hero" and held else flesh[2],INK)
        b.dot(end[0]-1,end[1]-1,flesh[3])
        if knight and state in ["point_sword","point_staff"] and index>0 and side==(-1 if state=="point_sword" else 1):
            b.line([end,(end[0]+side*4,end[1]-1)],"#b9e4cf",2)
    far_side=1 if yaw>.2 else -1
    paint_arm(next(a for a in arms if a[0]==far_side))
    # A single flared tunic binds the shoulders to the stride.
    x,y=shouldx,shouldy; ww=width*lateral
    bottom=hipy+5
    b.shape([(x-ww+1,y-3),(x+ww-1,y-3),(x+ww,y+1),(hipx+ww-1,hipy-2),
             (hipx+ww+2,bottom),(hipx+1,bottom+2),(hipx-ww-2,bottom)], robe[1],INK)
    b.shape([(x-ww+2,y-2),(x-1,y-1),(hipx-1,hipy-1),(hipx-ww+1,hipy+2)],robe[2])
    if kind=="hero":
        b.line([(hipx-ww,bottom-1),(hipx,bottom+1),(hipx+ww+1,bottom-1)],"#c1a98a")
        b.shape([(x-ww+1,y-3),(x+ww-1,y-4),(x+ww+1,y-1),(x+2,y+4),(x-4,y+2)],BLUE[0],INK)
        b.line([(x-ww+2,y-2),(x-2,y+1),(x+ww-1,y-2)],BLUE[3],2)
        b.line([(x-ww+2,y+4),(x-ww+2,y+6)],BLUE[3])
        b.line([(hipx-ww+2,hipy),(hipx-ww+1,bottom-2)],BLUE[2])
        b.line([(hipx-ww,hipy-1),(hipx+ww-1,hipy-1)],HIDE[0],3)
        b.line([(hipx-ww+1,hipy-2),(hipx+ww-1,hipy-2)],HIDE[2])
        if not rear:
            b.oval(hipx+round(yaw*2),hipy-1,2,2,GOLD[2],INK)
    elif kind in ["skeleton","archer","elite"] and not rear:
        for i in range(3):
            b.line([(x-ww+2,y+2+i*2),(x+1,y+4+i*2),(x+ww-1,y+2+i*2)],BONE[2])
        b.line([(x+1,y+3),(x+1,y+9)],BONE[3])
    elif kind=="lord":
        hem=min(14,56-hipy) if state=="defeated" else 14
        cloth(b,hipx,hipy-1,8,hem,robe,yaw,walk,True)
        b.shape([(x,y-1),(x+4,y+3),(x,y+7),(x-4,y+3)],GOLD[2],INK)
        b.shape([(x,y+1),(x+2,y+3),(x,y+5),(x-2,y+3)],"#d86ba7")
    elif knight:
        b.shape([(x-ww+1,y-1),(x+ww-2,y-1),(x+ww-2,y+6),
                 (x,y+10),(x-ww+2,y+6)],armor[1],INK)
        b.line([(x-ww+2,y),(x-1,y+3),(x+ww-2,y)],armor[3])
        b.line([(x,y+4),(x,y+8)],armor[2])
    if kind=="lord":
        for side in [-1,1]:
            for j in [2,1,0]:
                fx=x+side*(ww-j*2); fy=y-3+j
                b.shape([(fx-side*3,fy-3),(fx+side*2,fy-4),(fx+side*7,fy+2+j),(fx+side*3,fy+1),(fx+side*2,fy+4)],VIOLET[1+j%2],INK)
                b.line([(fx,fy-2),(fx+side*3,fy)],VIOLET[3])
    if rear and kind in ["knight","skeleton","archer","elite","lord"]:
        hem=22 if kind!="lord" else 28
        if state in ["defeated","dissolve"]:
            hem=min(hem,57-y)
        cloth(b,x,y-3,round(ww+1),hem,robe,yaw,walk,True)
    if kind=="lord" and state=="defeated" and index>=2:
        lord_head(b,headx,heady,yaw,rear,kind,crowned=False)
    elif not rear and kind!="knight":
        painted_head(b,identity,headx,heady,yaw)
    elif kind=="hero":
        hero_head(b,headx,heady,yaw,rear,vector,blink=state=="hurt")
    elif kind in ["goblin","skeleton","archer"]:
        hood_head(b,headx,heady,yaw,rear,kind,robe,corrupt)
    else:
        lord_head(b,headx,heady,yaw,rear,kind)
    near=next(a for a in arms if a[0]!=far_side)
    paint_arm(near)
    primary=next(a for a in arms if a[1])
    gx,gy=primary[4]
    if kind not in ["hero","knight"] and state not in ["assemble","phase","gesture","defeated","final"]:
        # Bow faces diagonally on frontal views to preserve its visible curve.
        heading=vector if yaw>.1 else (.55,-.84 if rear else .84)
        held_weapon(b,kind,(gx,gy),next(a for a in arms if not a[1])[4],heading,reach,state,role,corrupt)
    if role in ["zone","volley"] and state in ["windup","strike"]:
        for a in (arms if kind=="lord" else [primary]):
            ax,ay=a[4]; radius=4+reach*3
            for j in range(3 if role=="volley" else 4):
                t=index*.42+j*math.tau/(3 if role=="volley" else 4)
                xx=min(60,max(2,ax+math.cos(t)*radius))
                yy=min(60,max(3,ay+math.sin(t)*radius))
                b.line([(xx,yy-1),(xx+1,yy),(xx,yy+1)],"#ca8ddd")
    if corrupt and kind in ["goblin","archer","skeleton"]:
        b.line([(shouldx-1,shouldy),(shouldx+1,shouldy+3),(shouldx,shouldy+5)],"#ae5a9a")
    if kind in ["elite","lord"] and state in ["phase","stance","final"]:
        colors=("#aa61a4","#d990d6","#f4c0eb") if kind=="lord" else ("#88656b","#c1879c","#e8b3ae")
        for i,(dx,dy) in enumerate([(-8,3),(-3,9),(5,6),(9,1)]):
            x=shouldx+dx
            y=shouldy+dy
            b.line([(x-2,y-2),(x,y),(x-1,y+3)],colors[i%len(colors)])
            if state in ["phase","final"] and index!=0:
                b.dot(x+2,y-4,colors[2])
    if kind=="elite" and state=="assemble":
        merged=shards(b.im,[3,2,1,0][index],"#cdb8a2")
        b=Brush()
        if index<3:
            for side in [-1,1]:
                offset=(8-index*3)*side
                b.shape([(32+offset-3,54),(32+offset+1,51-index),
                         (32+offset+5,53),(32+offset+2,56)],BONE[2],INK)
        b.im.alpha_composite(merged)
    if kind=="lord" and state=="defeated" and index>=2:
        x,y=24-index,52
        b.shape([(x-4,y-5),(x-2,y-3),(x,y-5),(x+3,y-2),(x+6,y-3),
                 (x+5,y+1),(x-2,y+1)],GOLD[1],INK)
        b.line([(x-2,y-1),(x+4,y-1)],GOLD[2])
    if state=="hurt":
        b.line([(headx-11,heady-3),(headx-14-index,heady-4)],"#e7ad8d")
    if state=="dissolve":
        b.im=shards(b.im,index,"#d59ac3" if corrupt else "#c7ab8b")
    if knight:
        if state=="appear": b.im=shards(b.im,3-index,"#9cddd0")
        elif state=="fade": b.im=shards(b.im,index+1,"#9cddd0")
        b.im.putalpha(b.im.getchannel("A").point(lambda v:round(v*.89)))
    if mirrored:
        b.im=ImageOps.mirror(b.im)
        gx=63-gx
    return b.im,(round(gx)-32,round(gy)-56)


def bake(ids):
    grips={}
    for identity in ids:
        dirs=["s"] if identity=="knight" else DIR8 if identity.startswith("hero") else DIR4
        states=KNIGHT.copy() if identity=="knight" else BASE.copy()
        if identity.startswith("hero"):
            states.append("startled")
        for action in ACTIONS.get(identity,[]):
            states.extend(phase+"_"+action for phase in ["windup","strike","recovery"])
        for name, sheet_states in [(identity, states), (identity+"_poses", BOSS_POSES.get(identity, []))]:
            if not sheet_states:
                continue
            widths = [COUNTS.get(state, COUNTS.get(state.split("_")[0])) for state in sheet_states]
            sheet = Image.new("RGBA", (sum(widths)*64, len(dirs)*64))
            rows = []
            for row, direction in enumerate(dirs):
                positions = []
                col = 0
                for state, count in zip(sheet_states, widths):
                    for index in range(count):
                        if identity.endswith("slime") or identity=="ghost":
                            frame, grip = spirit(identity, direction, state, index)
                        else:
                            frame, grip = humanoid(identity, direction, state, index)
                        if not frame.getbbox():
                            raise ValueError((identity, direction, state, index))
                        sheet.paste(frame, (col*64, row*64))
                        positions.append(grip[0]+32 + (grip[1]+56)*64)
                        col += 1
                rows.append(positions)
            if identity.startswith("hero"):
                grips[identity] = rows
            sheet.save(OUT/(name+".png"), optimize=True)
    if len(grips)==3:
        script=['extends RefCounted','','## Native pixel coordinates encoded as x + y × 64. Generated by tools/art/paint_actors.py.','const POSITIONS := {']
        for identity,rows in grips.items():
            script.append('\t"'+identity+'": [')
            script.extend('\t\t'+str(row)+',' for row in rows)
            script.append('\t],')
        script.append('}')
        (ROOT/"data/upgrade_grips.gd").write_text('\n'.join(script)+'\n')

SPIRIT_CROPS={"slime":(70,105,257,258),"corrupted_slime":(668,379,895,573),"ghost":(365,357,575,586)}
SPIRIT_MASTERS={}


def spirit(identity,direction,state,idx):
    if identity not in SPIRIT_MASTERS:
        sheet=Image.open(ROOT/"assets/edition/actors.png").convert("RGBA")
        bounds=SPIRIT_CROPS[identity]
        width,height=(34,38) if identity=="ghost" else (38,30)
        master=sheet.crop(bounds).resize((width,height),Image.Resampling.LANCZOS)
        master.putalpha(master.getchannel("A").point(lambda p:255 if p>128 else 0))
        SPIRIT_MASTERS[identity]=master
    master=SPIRIT_MASTERS[identity].copy()
    b=Brush()
    is_ghost=identity=="ghost"
    color="#a4decd" if is_ghost else "#d28ee5" if identity=="corrupted_slime" else "#b9d76f"
    # A forward-facing profile of flowing ether turns its face away by filling the eye sockets.
    if direction=="n":
        pixels=master.load()
        for y in range(master.height):
            for x in range(master.width):
                r,g,bl,a=pixels[x,y]
                if is_ghost:
                    if 19<=x<=31 and 5<=y<=18 and a and g<143:
                        pixels[x,y]=(124+(x+y)%11,186+(x+y)%10,159+(x+y)%8,a)
                elif .48*master.height<y<.84*master.height and .24*master.width<x<.9*master.width and a:
                    if (identity=="slime" and r>137 and g>157 and bl>54) or (identity=="corrupted_slime" and r>122 and bl>130):
                        pixels[x,y]=((101,128,34,a) if identity=="slime" else (110,56,114,a))
    stretch,squat,air,shift=1.,1.,0.,0.
    tick=(idx/6)*math.tau
    if state=="walk":
        stretch=[1.13,1.02,.83,.91,1.02,1.2][idx]
        squat=[.73,.94,1.2,1.09,.87,.66][idx]
        air=[0,1,5,7,3,0][idx]
    elif state=="idle":
        stretch=1+idx*.025;squat=1-idx*.03
    elif state=="windup":
        stretch=[1.06,1.16,1.26][idx];squat=[.90,.75,.60][idx];shift=-idx
    elif state=="strike":
        stretch=[1.24,1.20,1.08][idx];squat=[.76,.85,.90][idx];air=[4,6,2][idx];shift=[5,7,3][idx]
    elif state=="recovery":
        stretch=[1.24,1.13,1.03][idx];squat=[.66,.80,.93][idx]
    elif state=="hurt":
        stretch=[1.15,1.04][idx];squat=[.76,.93][idx];shift=[-3,-1][idx]
    if is_ghost:
        air=round(2+2*math.sin(tick)) if state=="walk" else .45*air
        stretch=1+(stretch-1)*.46
        squat=1+(squat-1)*.45
    if direction=="n": air+=shift;shift=0
    elif direction=="s": air-=shift;shift=0
    w,h=master.size
    out_h=max(1,round(h*squat))
    for yy in range(out_h):
        ratio=yy/max(1,out_h-1)
        source_y=round(ratio*(h-1))
        # A slime bulges most strongly near the ground; a ghost's hem drifts behind the skull.
        if is_ghost:
            ribbon=math.sin(tick-ratio*4)*ratio**2*(4.2 if state=="walk" else 1.3)
            width=round(w*stretch+ratio*math.sin(tick-2.2)*2)
        else:
            ribbon=shift*(1-ratio)*.52
            width=round(w*(1+(stretch-1)*(.45+ratio*.9)))
        line=master.crop((0,source_y,w,source_y+1)).resize((width,1),Image.Resampling.NEAREST)
        x=round(32-width/2+shift+ribbon)
        y=round(56-air-out_h+yy)
        b.im.alpha_composite(line,(x,y))
    if state=="walk" and not is_ghost and idx in [2,5]:
        for x,y,r in [(-18,49,1),(17,48,1),(14,45,0)]:
            b.oval(32+x,y+(idx==2)*2,r+1,r,color,INK)
    if state=="strike" and is_ghost:
        xx=45+idx*2
        b.line([(xx-4,37),(xx+3,32),(xx+6,32)],"#94c8b8",2)
        b.line([(xx-1,40),(xx+3,37),(xx+5,36)],"#6ca99b")
    if state=="dissolve":
        b.im=shards(b.im,idx,color)
    if direction=="w":
        b.im=ImageOps.mirror(b.im)
    return b.im,(0,-15)


if __name__=="__main__":
    OUT.mkdir(parents=True,exist_ok=True)
    bake(ALL)
