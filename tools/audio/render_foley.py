"""Layer the two CC0 Kenney libraries, and turn fire/wind recordings into room loops."""
from argparse import ArgumentParser
from collections import defaultdict
from functools import lru_cache
from pathlib import Path
import math

import numpy as np
import soundfile as sf
from scipy.signal import butter, sosfilt, resample_poly

ROOT = Path(__file__).resolve().parents[2]
RATE = 44100
FOLEY = ROOT / "assets/audio/foley"
AMBIENCE = ROOT / "assets/audio/ambience"

# Each layer is (recording family, delay in seconds, level relative to lead, speed).
# Families resolve to the take number modulo the available original recordings.
RECIPES = {
    "footstep": (5,.59,[("footstep_concrete",0,1,1), ("cloth",.013,.14,1.12)]),
    "footstep_grass": (5,.48,[("footstep_grass",0,1,1), ("cloth",.015,.16,1.03)]),
    "sword": (5,.74,[("cloth",0,.34,1.22), ("knifeSlice",.031,.86,1.12), ("air",.022,.56,1)]),
    "hit": (4,.74,[("impactPunch_medium",0,1,.90), ("impactWood_light",.017,.21,1.2)]),
    "hit_flesh": (4,.75,[("impactPunch_heavy",0,.88,.90), ("impactSoft_medium",.015,.48,1.14)]),
    "hit_bone": (4,.78,[("impactPlank_medium",0,.82,1.36), ("impactWood_light",.021,.51,1.56)]),
    "hit_metal": (4,.75,[("impactPlate_medium",0,.82,.96), ("impactMetal_light",.04,.34,1.22)]),
    "hurt": (3,.72,[("impactSoft_heavy",0,.72,.75), ("impactPunch_medium",.023,.64,.82), ("cloth",.03,.30,.9)]),
    "death": (2,.70,[("dropLeather",0,.58,.75), ("impactSoft_heavy",.17,1,.68), ("fall",.03,.40,1)]),
    "magic": (4,.66,[("air",0,.38,.92), ("spell",.016,.78,1), ("impactGlass_light",.03,.22,1.32)]),
    "enemy_magic": (3,.66,[("air",0,.31,.77), ("hex",.012,.84,.88)]),
    "enemy_chant": (2,.72,[("creak",.025,.26,1.25), ("chant",0,.85,1)]),
    "enemy_arrow": (4,.66,[("drawKnife",0,.35,1.3), ("snap",.005,.88,1.23), ("air",.014,.45,1.46)]),
    "enemy_telegraph": (2,.70,[("metalLatch",.005,.40,1.15), ("warning",0,.84,1)]),
    "enemy_zone_warning": (2,.78,[("charge",0,.80,1), ("impactPlate_light",.035,.40,.83)]),
    "enemy_zone_burst": (3,.78,[("impactPunch_heavy",0,.82,.61), ("rupture",.013,.75,1), ("impactMining",.071,.3,.68)]),
    "enemy_ghost": (3,.60,[("wraith",0,.82,1), ("air",.03,.51,.56)]),
    "enemy_rush": (4,.67,[("cloth",0,.45,.87), ("air",.018,.72,.70), ("footstep_concrete",.028,.26,.95)]),
    "pot_break": (4,.74,[("impactGlass_heavy",0,.61,.79), ("impactPlank_medium",.004,.48,.83),
                         ("impactGlass_light",.071,.53,.91), ("impactGlass_light",.176,.20,1.25)]),
    "trap_warn": (3,.88,[("latch",0,.98,1), ("creak",.035,.48,1.07), ("charge",.028,.37,1.38)]),
    "trap_arrow": (3,.79,[("snap",0,.92,1), ("impactWood_light",.006,.42,1.37), ("air",.023,.42,1.5)]),
    "arrow_impact": (4,.68,[("impactWood_medium",0,.94,1.23), ("impactMetal_light",.014,.22,1.45)]),
    "pickup": (4,.56,[("handleCoins",0,.67,1.2), ("token",.024,.48,1)]),
    "craft": (2,.61,[("impactMetal_light",0,.60,1), ("impactMetal_light",.11,.47,1.20), ("token",.19,.56,1.12)]),
    "potion": (2,.55,[("handleSmallLeather",0,.45,1.13), ("bubble",.032,.74,1), ("bubble",.139,.36,1.25)]),
    "ghost": (2,.64,[("wraith",0,.74,.72), ("aureole",.23,.43,.70)]),
    "pearl_form": (2,.62,[("aureole",0,.76,.83), ("bead",.19,.68,.94)]),
    "pearl_pickup": (3,.62,[("bead",0,.85,1.18), ("handleCoins",.042,.24,1.2)]),
    "corrupt": (2,.69,[("creak",0,.33,.67), ("rupture",.035,.46,.65), ("hex",.12,.79,.75)]),
    "book_open": (3,.50,[("bookOpen",0,.75,1), ("cloth",.015,.27,.96)]),
    "book_page": (3,.44,[("bookFlip",0,1,1)]),
    "book_close": (3,.50,[("bookClose",0,.72,.94), ("bookPlace",.031,.28,.91)]),
    "ui_focus": (3,.34,[("impactWood_light",0,.61,1.85), ("ui",.007,.25,1.12)]),
    "ui_confirm": (3,.45,[("metalClick",0,.64,1.25), ("ui",.01,.40,.95)]),
    "ui_open": (2,.42,[("beltHandle",0,.62,1.14), ("ui",.015,.35,1.08)]),
    "ui_close": (2,.42,[("dropLeather",0,.63,1.18), ("ui",.016,.23,.81)]),
    "equip": (3,.56,[("clothBelt",0,.65,1), ("metalLatch",.078,.52,1.16)]),
    "gate_open": (2,.69,[("creak",0,.61,.57), ("impactMining",.12,.44,.64), ("impactWood_heavy",.32,.60,.71)]),
    "room_drip": (4,.47,[("bubble",0,.60,1.73), ("drip",.005,.46,1)]),
    "room_chain": (3,.52,[("impactMetal_light",0,.67,.63), ("metalLatch",.103,.25,.7)]),
    "room_rift": (3,.49,[("wraith",0,.40,.42), ("hex",.083,.44,.49)]),
    "room_gust": (3,.47,[("air",0,.55,.28), ("cloth",.22,.16,.56)]),
}
STABLE = {"trap_warn", "enemy_telegraph", "enemy_zone_warning", "enemy_chant"}


def hz_filter(data, low, high):
    if low:
        data = sosfilt(butter(3, low, btype="highpass", fs=RATE, output="sos"), data, axis=0)
    if high:
        data = sosfilt(butter(3, high, fs=RATE, output="sos"), data, axis=0)
    return data


@lru_cache(maxsize=128)
def read_clip(path):
    data, sr = sf.read(path, dtype="float32", always_2d=True)
    data = data.mean(axis=1)
    if sr != RATE:
        factor = math.gcd(sr,RATE)
        data = resample_poly(data,RATE//factor,sr//factor)
    peak = max(.0001,np.max(np.abs(data)))
    starts = np.flatnonzero(np.abs(data)>peak*.016)
    if len(starts):
        data = data[max(0,starts[0]-90):starts[-1]+int(.044*RATE)]
    data = hz_filter(data,40,15500)
    return data / max(.0001,np.max(np.abs(data)))


def resonator(t, freq, decay, onset=.006, ratios=(1, 2.02, 3.94), gains=(1,.30,.12)):
    envelope = np.minimum(1,t/onset)
    return envelope*sum(a*np.sin(2*np.pi*freq*r*t)*np.exp(-t*decay*(1+.1*r))
                        for r,a in zip(ratios,gains))


def design(kind, rng):
    duration = {"aureole":1.62,"wraith":1.18,"bead":.91,"rupture":.71,"charge":.48,
                "fall":.65,"chant":.46,"hex":.58,"spell":.48,"drip":.52}.get(kind,.33)
    t = np.arange(int(RATE*duration))/RATE
    noise = rng.normal(size=len(t))
    if kind == "air":
        a = hz_filter(noise, 290, 2400)*np.exp(-((t-.091)/.057)**2)
        a += hz_filter(noise, 1400, 6500)*np.exp(-((t-.116)/.034)**2)*.42
    elif kind in ("latch","snap"):
        # Warning always opens on the same double steel detent (6.8 ms and 57 ms).
        a = resonator(t, 1640 if kind == "latch" else 793, 72, .0018,
                      (1,1.49,2.37),(1,.64,.24))
        delay = round(RATE*(.057 if kind == "latch" else .012))
        a[delay:] += a[:-delay].copy()*.55
    elif kind in ("rupture","fall"):
        a = hz_filter(noise,42,850)*np.exp(-t*13) + np.sin(2*np.pi*(105*t-45*t*t))*np.exp(-t*10)*.72
    elif kind in ("wraith","aureole"):
        base = 185 if kind == "wraith" else 293.665
        envelope = np.sin(np.pi*t/duration)**1.65
        a = envelope*(np.sin(2*np.pi*base*t+.50*np.sin(2*np.pi*2.7*t))
                      + .39*np.sin(2*np.pi*base*1.503*t)+.18*hz_filter(noise,700,3000))
    elif kind in ("warning","chant","charge"):
        base = {"warning":561,"chant":349,"charge":674}[kind]
        a = np.sin(2*np.pi*(base*t+base*.32*t*t))+.33*np.sin(2*np.pi*base*1.51*t)
        a *= np.sin(np.pi*(t/duration)**.76)**.76
    elif kind in ("bubble","drip"):
        pitch = 613 if kind=="bubble" else 1120
        a = np.sin(2*np.pi*(pitch*t+380*t*t))*np.exp(-t*(32 if kind=="bubble" else 17))
        a += .34*hz_filter(noise,350,2400)*np.exp(-t*100)
    else:
        base, interval = {"bead":(587.33,1.5),"spell":(440,1.334),"hex":(246.94,1.059),
                          "ui":(698.46,1.5),"token":(587.33,1.26)}[kind]
        a = resonator(t,base,8)
        start = int(RATE*.059)
        a[start:] += .65*resonator(t[:-start],base*interval,8)
    return a/max(.01,np.max(np.abs(a)))


def render_foley(source_dir):
    pools = defaultdict(list)
    for folder in ("impact-sounds","rpg-audio"):
        for p in sorted((source_dir/folder/"Audio").glob("*.ogg")):
            key = p.stem
            if folder == "impact-sounds":
                key = key.rsplit("_",1)[0]
            else:
                key = key.rstrip("0123456789_")
            pools[key].append(p)
    manifest = []
    for cue, (count, peak, layers) in RECIPES.items():
        for variant in range(count):
            seed = sum((i+1)*ord(c) for i,c in enumerate(cue)) + 901*variant
            rng = np.random.default_rng(seed)
            total = np.zeros(4*RATE)
            used = []
            for j,(family,delay,gain,speed) in enumerate(layers):
                if family in pools:
                    files = pools[family]
                    path = files[(variant+j//2)%len(files)]
                    data = read_clip(path)
                    used.append(str(path.relative_to(source_dir)))
                else:
                    data = design(family,rng)
                    used.append("synthesis/"+family)
                if cue not in STABLE or j != 0:
                    speed *= rng.uniform(.955,1.048)
                positions = np.arange(0,len(data)-1,speed)
                layer = np.interp(positions,np.arange(len(data)),data)
                if cue in ("ui_focus","ui_open","ui_confirm","ui_close"):
                    layer = layer[:int(RATE*.16)]
                duration = len(layer)
                edge = min(int(.019*RATE),duration//2)
                layer[-edge:] *= np.linspace(1,0,edge)
                start = round(delay*RATE)
                total[start:start+duration] += gain*layer
            active = np.flatnonzero(np.abs(total)>.00012)
            total = total[:active[-1]+110]
            if cue.startswith("room_"):
                # Early reflections keep the local one-shot's directional attack.
                total = np.pad(total,(0,int(.42*RATE)))
                dry = total.copy()
                for dt, level in ((.071,.22),(.139,.14),(.217,.10),(.361,.05)):
                    k=int(dt*RATE)
                    total[k:] += dry[:-k]*level
            total[:88] *= np.linspace(0,1,88)
            total[-110:] *= np.linspace(1,0,110)
            total *= peak / max(.01,np.max(np.abs(total)))
            name = f"{cue}_{variant+1:02}.wav"
            sf.write(FOLEY/name, total, RATE, subtype="PCM_16")
            manifest.append(name+"\t"+" | ".join(used))
    (ROOT/"audio_project/foley-sources.tsv").write_text("output\tlayers (recipe order)\n"+"\n".join(manifest)+"\n")


def region(path, start, seconds, mid_side=False):
    with sf.SoundFile(path) as audio:
        sr = audio.samplerate
        audio.seek(round(start*sr))
        x = audio.read(round(seconds*sr), always_2d=True, dtype="float32")
    if mid_side:
        # Freesound 139337 is documented as an undecoded mid/side field recording.
        mid, side = x[:,0], x[:,1]*.50
        x = np.stack([mid+side,mid-side],axis=1)
    d = math.gcd(RATE,sr)
    return resample_poly(x,RATE//d,sr//d,axis=0)


def make_seam(x):
    overlap = RATE*3
    fade = np.linspace(0,1,overlap)[:,None]
    tail = x[-overlap:] * np.cos(np.pi/2*fade) + x[:overlap]*np.sin(np.pi/2*fade)
    return np.concatenate((x[overlap:-overlap],tail))


def render_ambience(source):
    wind, fire = source/"wind.ogg", source/"fireplace.ogg"
    # Each entry takes a different passage, register, room width and spectral window.
    for name, start, length, low, high, rms, width in [
        ("camp",4,36,70,9200,.103,1),("shaft",43,38,55,1850,.083,.65),
        ("garrison",83,35,72,2500,.086,.62),("rift",11,40,41,1360,.078,.54),
        ("crown",112,37,48,2900,.090,.90),("stair_air",69,24,110,3800,.105,.2),
        ("fire",14,25,110,10200,.115,.18)]:
        x = region(fire if name=="fire" else wind,start,length+3,mid_side=name!="fire")
        x = hz_filter(x,low,high)
        t = np.arange(len(x))/RATE
        if name in ("rift","garrison","crown"):
            f = {"rift":55.0,"garrison":146.83,"crown":73.42}[name]
            texture = np.sin(2*np.pi*f*t+.9*np.sin(2*np.pi*.13*t))
            texture += .36*np.sin(2*np.pi*f*1.499*t)
            breath = .65+.35*np.sin(2*np.pi*t/13.3)
            x += (texture*breath*np.sqrt(np.mean(x*x))*.41)[:,None]
        mid = x.mean(axis=1,keepdims=True)
        x = mid + width*(x-mid)
        if name in ("stair_air","fire"):
            x=mid
        x = make_seam(x)
        x *= min(.77 / np.max(np.abs(x)), rms/np.sqrt(np.mean(x*x)))
        sf.write(AMBIENCE/(name+".ogg"), x, RATE, format="OGG", subtype="VORBIS", compression_level=.3)


if __name__ == "__main__":
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("kenney",type=Path)
    parser.add_argument("field_recordings",type=Path)
    args = parser.parse_args()
    render_foley(args.kenney)
    render_ambience(args.field_recordings)
