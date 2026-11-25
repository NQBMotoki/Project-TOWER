"""Edit the existing licensed recordings into variants and synthesize new threat cues."""

from functools import lru_cache
from pathlib import Path
import wave

import numpy as np


ROOT = Path(__file__).resolve().parents[2]
FOLEY = ROOT / "assets/audio/foley"
MANIFEST = ROOT / "audio_project/foley-sources.tsv"
RATE = 44100

# Duration and normalized peak followed by layers (recorded cue, delay, level, pitch speed).
# The final optional tuple is the original synthesizer voice, start Hz and end Hz.
CUES = {
    "slime_coil": (.45, .69, [("potion", .02, .35, .71)], ("swell", 182, 272)),
    "slime_lunge": (.28, .63, [("enemy_rush", 0, .51, 1.18)], ("rush", 244, 119)),
    "slime_land": (.31, .66, [("hit_flesh", 0, .79, .69), ("potion", .047, .29, 1.55)], ("impact", 116, 63)),
    "goblin_step": (.28, .43, [("footstep", 0, .70, .85), ("equip", .019, .19, 1.25)], None),
    "goblin_windup": (.46, .74, [("equip", .01, .48, .86)], ("swell", 154, 209)),
    "goblin_swing": (.34, .73, [("sword", 0, .91, .78), ("enemy_rush", .039, .30, 1.35)], None),
    "goblin_rush_warn": (.59, .75, [("goblin_windup", 0, .45, .89), ("enemy_telegraph", .18, .52, .77)], ("swell", 163, 420)),
    "goblin_rush": (.48, .71, [("enemy_rush", 0, .70, .76), ("goblin_step", .10, .50, 1.40)], ("rush", 240, 75)),
    "skeleton_step": (.26, .44, [("footstep", 0, .58, 1.15), ("hit_bone", .018, .47, 1.35)], None),
    "skeleton_chant": (.58, .70, [("hit_bone", .021, .30, 1.15), ("enemy_chant", .095, .48, .89)], ("swell", 261.63, 314)),
    "skeleton_release": (.53, .67, [("enemy_magic", .025, .63, 1.12)], ("rush", 525, 191)),
    "skeleton_zone_warn": (.67, .76, [("enemy_zone_warning", .012, .60, .79)], ("glass", 392, 294)),
    "skeleton_bone_impact": (.28, .69, [("hit_bone", 0, .72, .97), ("arrow_impact", .023, .34, 1.37)], None),
    "archer_step": (.31, .41, [("footstep", 0, .59, 1.34), ("equip", .015, .25, 1.52)], None),
    "archer_draw": (.61, .73, [("enemy_chant", .06, .29, 1.39), ("trap_warn", .31, .43, 1.32)], ("swell", 488, 654)),
    "archer_release": (.27, .70, [("enemy_arrow", 0, .84, 1.05)], ("rush", 680, 243)),
    "archer_melee_warn": (.37, .72, [("hit_bone", .013, .43, 1.52), ("equip", .062, .45, 1.35)], ("swell", 410, 560)),
    "archer_melee": (.33, .71, [("sword", 0, .78, 1.30), ("hit_bone", .034, .27, 1.21)], None),
    "ghost_drift": (.53, .42, [("room_gust", .03, .47, .79)], ("rush", 297, 189)),
    "ghost_manifest": (.76, .80, [("enemy_ghost", .015, .53, .81)], ("swell", 112, 221)),
    "ghost_strike": (.55, .75, [("enemy_magic", .022, .36, 1.26)], ("rush", 870, 174)),
    "elite_entrance": (1.06, .77, [("hit_metal", .017, .56, .58), ("room_chain", .24, .61, .72)], ("impact", 189, 62)),
    "elite_phase": (.98, .78, [("room_chain", 0, .52, .83), ("hit_metal", .36, .72, .73)], ("swell", 163, 349)),
    "elite_sweep_warn": (.67, .76, [("equip", 0, .43, .78), ("enemy_telegraph", .23, .57, .73)], ("swell", 221, 278)),
    "elite_sweep": (.42, .79, [("sword", 0, .82, .64), ("hit_metal", .048, .46, 1.13)], ("rush", 313, 118)),
    "elite_volley_warn": (.64, .73, [("hit_bone", .01, .30, 1.18), ("hit_bone", .19, .26, 1.34)], ("glass", 330, 392)),
    "elite_volley": (.49, .74, [("enemy_arrow", 0, .72, .77), ("hit_bone", .064, .41, 1.13)], ("rush", 603, 252)),
    "elite_charge_warn": (.72, .77, [("trap_warn", .08, .43, .63), ("goblin_step", .23, .32, .77)], ("swell", 146, 430)),
    "elite_charge": (.61, .79, [("enemy_rush", 0, .53, .70), ("elite_sweep", .025, .52, 1.17)], ("rush", 227, 73)),
    "elite_wall": (.65, .75, [("gate_open", 0, .63, 1.25), ("hit_metal", .045, .51, .68)], ("impact", 152, 51)),
    "lord_phase": (1.07, .75, [("enemy_zone_burst", .07, .48, .66)], ("swell", 146.83, 220)),
    "lord_final_phase": (1.19, .79, [("hit_metal", .31, .49, .62), ("crystal_touch", .065, .28, .86)], ("swell", 110, 370)),
    "lord_sweep_warn": (.79, .76, [("equip", .027, .31, .78), ("hit_metal", .31, .45, .70)], ("swell", 240, 293.66)),
    "lord_sweep": (.64, .83, [("sword", 0, .78, .55), ("enemy_zone_burst", .08, .46, .78)], ("rush", 288, 76)),
    "lord_volley_warn": (.69, .77, [("enemy_chant", .07, .53, .72)], ("glass", 349.23, 440)),
    "lord_volley": (.64, .80, [("enemy_magic", 0, .70, .69), ("enemy_arrow", .07, .38, .84)], ("rush", 530, 131)),
    "lord_seal_warn": (.87, .77, [("enemy_zone_warning", .049, .56, .69), ("pearl_form", .05, .27, .72)], ("glass", 277.18, 415.30)),
    "lord_lanes_warn": (.85, .79, [("trap_warn", .012, .40, .69), ("trap_warn", .23, .29, .74)], ("swell", 165, 492)),
    "lord_lanes": (.83, .81, [("enemy_zone_burst", 0, .87, .57), ("enemy_zone_burst", .18, .41, .73)], ("impact", 160, 53)),
    "corruption_enter": (.64, .75, [("enemy_ghost", 0, .23, 1.61)], ("rush", 750, 143)),
    "corruption_confirm": (.48, .57, [("pearl_pickup", .07, .34, .94)], ("glass", 369.99, 587.33)),
    "magic_enhance": (.68, .62, [("corrupt", .02, .30, 1.35), ("pearl_pickup", .23, .48, 1.22)], ("glass", 293.66, 440)),
    "crystal_touch": (1.02, .78, [("pearl_form", .033, .43, .79), ("hit_metal", .09, .24, .66)], ("glass", 196, 311.13)),
    "crystal_rumble": (2.41, .78, [("gate_open", 0, .53, .56), ("enemy_zone_burst", .227, .45, .55),
                                  ("gate_open", .48, .36, .73)], ("impact", 117, 44)),
    "sky_darkening": (3.51, .64, [("room_gust", 0, .35, .49), ("enemy_ghost", .30, .22, .56)], ("swell", 104, 54)),
}


@lru_cache(maxsize=None)
def source(name):
    paths = sorted(FOLEY.glob(name + "_[0-9][0-9].wav"))
    if not paths:
        raise FileNotFoundError(name)
    return paths


@lru_cache(maxsize=None)
def read_wave(path):
    with wave.open(str(path), "rb") as wav:
        if (wav.getnchannels(), wav.getsampwidth(), wav.getframerate()) != (1, 2, RATE):
            raise ValueError(f"{path} should be mono 16-bit PCM at {RATE} Hz")
        return np.frombuffer(wav.readframes(wav.getnframes()), dtype="<i2").astype(float) / 32768


def synth(profile, start_hz, end_hz, t, rng):
    duration = (len(t) - 1) / RATE
    phase = 2 * np.pi * (start_hz * t + (end_hz - start_hz) * t * t / (2 * duration))
    roughness = rng.uniform(-0.05, 0.05)
    phase *= 1 + roughness
    field = np.fft.rfft(rng.normal(size=len(t)))
    f = np.fft.rfftfreq(len(t), d=1 / RATE)
    center = {"impact": 178, "rush": 1500, "swell": 560, "glass": 3700}[profile]
    mask = np.exp(-((np.log1p(f) - np.log1p(center)) / .9) ** 2)
    air = np.fft.irfft(field * mask, n=len(t))
    air /= max(.05, np.max(np.abs(air)))
    progress = t / duration
    if profile == "impact":
        return (.62 * np.sin(phase) + .46 * air + .20 * np.sin(phase * 2.03)) * np.exp(-4.9 * progress)
    if profile == "rush":
        return (.67 * air + .34 * np.sin(phase) + .22 * np.sin(phase * 1.51)) * np.sin(np.pi * progress) ** 1.7
    if profile == "swell":
        harmonics = .55 * np.sin(phase + .60 * np.sin(phase * .16)) + .26 * np.sin(phase * 1.501) + .26 * air
        return harmonics * np.sin(np.pi * progress ** .76) ** 1.5
    return (.55 * np.sin(phase) + .34 * np.sin(phase * 1.505) + .16 * np.sin(phase * 2.61) + .10 * air) * np.exp(-4 * progress)


def build_cue(cue, recipe):
    duration, peak, layers, voice = recipe
    variants = 1 if cue in {"crystal_rumble", "sky_darkening"} else 3
    t = np.arange(round(duration * RATE)) / RATE
    material = []
    for take in range(variants):
        seed = sum((i + 1) * ord(char) for i, char in enumerate(cue)) + 1201 * take
        rng = np.random.default_rng(seed)
        stem = np.zeros(len(t))
        used = []
        for index, (name, delay, level, speed) in enumerate(layers):
            pool = source(name)
            clip = pool[(take + index) % len(pool)]
            recording = read_wave(clip)
            speed *= rng.uniform(.97, 1.03)
            adjusted = np.interp(np.arange(0, len(recording) - 1, speed), np.arange(len(recording)), recording)
            offset = round(delay * RATE)
            adjusted = adjusted[:len(stem) - offset]
            edge = min(round(.032 * RATE), len(adjusted) // 2)
            adjusted[-edge:] *= np.linspace(1, 0, edge)
            stem[offset:offset + len(adjusted)] += level * adjusted
            used.append(f"game-foley/{clip.name}")
        if voice:
            color = synth(*voice, t, rng)
            stem += .65 * color
            used.append("synthesis/" + voice[0])
        stem[:88] *= np.linspace(0, 1, 88)
        stem[-882:] *= np.linspace(1, 0, 882)
        stem *= peak / max(.001, np.max(np.abs(stem)))
        filename = f"{cue}_{take + 1:02}.wav"
        with wave.open(str(FOLEY / filename), "wb") as target:
            target.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
            target.writeframes(np.round(stem * 32767).astype("<i2").tobytes())
        material.append(filename + "\t" + " | ".join(used))
    return material


if __name__ == "__main__":
    # The early effects retain their original third-party source map and can be used as a local source.
    rows = MANIFEST.read_text().splitlines()
    stock = [row for row in rows[1:] if row.split("\t", 1)[0].rsplit("_", 1)[0] not in CUES]
    order = ["crystal_touch", *(cue for cue in CUES if cue != "crystal_touch")]
    extensions = [row for cue in order for row in build_cue(cue, CUES[cue])]
    MANIFEST.write_text("\n".join([rows[0], *stock, *extensions, ""]))
