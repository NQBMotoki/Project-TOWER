"""Render edited MIDI to aligned, lossless FLAC stems and the game's Vorbis mix."""
from argparse import ArgumentParser
from collections import defaultdict
from functools import lru_cache
from pathlib import Path
import re

import mido
import numpy as np
from scipy.signal import butter, sosfilt, oaconvolve
import soundfile as sf
from compose import BPM as RECORDED_CUES

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "audio_project"
RATE = 44100
PITCHES = dict(C=0, D=2, E=4, F=5, G=7, A=9, B=11)
# Sample root octaves were checked against concert pitch. VSCO's harp uses C4 = 60.
INSTRUMENTS = {
    "cello": ("Strings/Cello Section/susvib/*v1_1.wav", 2, -.20, .015, .30, .95),
    "viola": ("Strings/Viola Section/susvib/*v1_1.wav", 2, .20, .016, .27, .70),
    "pizz": ("Strings/Cello Section/pizzT/*v1_RR1.wav", 2, -.30, .002, .33, .75),
    "harp": ("Strings/Harp/*.wav", 1, -.19, .002, 1.25, .85),
    "clarinet": ("Woodwinds/Clarinet/susLong/*v1_rr1_sum.wav", 2, -.08, .019, .13, .80),
    "flute": ("Woodwinds/Flute/susNV/*v1_1.wav", 2, .14, .025, .16, .75),
    "horn": ("Brass/F Horn/sus/*v1_1.wav", 2, .26, .020, .26, .83),
    "glock": ("Percussion/Glock/*.wav", 2, .33, .002, .98, .37),
    "timpani": ("Percussion/Timpani/*_Hit_v1_rr1_Sum.wav", 0, -.11, .003, .55, .82),
}
SCORE = ROOT / "assets/audio/music"


def make_map(library):
    mapped = {}
    for name, (pattern, base, *_) in INSTRUMENTS.items():
        notes = {}
        for path in sorted(library.glob(pattern)):
            if name == "timpani":
                root = {1:41, 2:47, 3:49, 4:52, 5:55}[int(path.name[7])]
            else:
                token = re.search(r"(?:_|^)([A-G])(#?)(\d)(?:_|\.)", path.name)
                if not token:
                    continue
                letter, sharp, octave = token.groups()
                root = (int(octave) + base) * 12 + PITCHES[letter] + bool(sharp)
            notes[root] = path
        if not notes:
            raise ValueError("Missing VSCO samples for " + name)
        mapped[name] = notes
    return mapped


@lru_cache(maxsize=32)
def read_sample(path):
    source, rate = sf.read(path, dtype="float32", always_2d=True)
    if rate != RATE:
        raise ValueError("Unexpected VSCO sample rate")
    mid = source.mean(axis=1)
    smooth = np.convolve(np.abs(mid[:RATE//2]), np.ones(96)/96, mode="same")
    onset = np.flatnonzero(smooth > max(np.max(smooth)*.028, .00002))
    offset = max(0, int(onset[0]) - int(RATE*.013)) if len(onset) else 0
    source = source[offset:]
    mid = source.mean(axis=1)
    side = (source[:,0] - source[:,-1]) * .25
    energy = np.percentile(np.abs(mid[:RATE*2]), 95)
    gain = min(10, .29 / max(energy, .004))
    return np.stack([mid+side, mid-side], axis=1) * gain


def read_midi(path):
    midi = mido.MidiFile(path)
    conductor = midi.tracks[0]
    tempo = next(m.tempo for m in conductor if m.type == "set_tempo")
    seconds_per_tick = tempo / (1e6 * midi.ticks_per_beat)
    end = sum(m.time for m in conductor) * seconds_per_tick
    parts = defaultdict(list)
    for track in midi.tracks[1:]:
        group, instrument = track.name.split("/")
        active = {}
        tick = 0
        for msg in track:
            tick += msg.time
            if msg.type == "note_on" and msg.velocity:
                active[msg.note] = (tick, msg.velocity)
            elif msg.type in ("note_off", "note_on") and msg.note in active:
                start, velocity = active.pop(msg.note)
                parts[group].append((instrument, start*seconds_per_tick, msg.note,
                                     (tick-start)*seconds_per_tick, velocity))
    return end, parts


def render_note(instrument, key, duration, velocity, mapped, sources):
    bank = mapped[instrument]
    root = min(bank, key=lambda candidate: abs(key-candidate))
    path = bank[root]
    sources.add(path)
    raw = read_sample(path)
    _, _, pan, attack, release, gain = INSTRUMENTS[instrument]
    rate = 2**((key-root)/12)
    count = min(int((duration+release)*RATE), int((len(raw)-2)/rate))
    t = np.arange(count)/RATE
    indices = np.arange(count)*rate
    env = np.minimum(1, t / attack) * np.cos(np.clip((t-duration)/release, 0, 1)*np.pi/2)**2
    amplitude = gain*(velocity/100)**1.65
    pos = (pan+1)*np.pi/4
    return np.column_stack([
        np.interp(indices, np.arange(len(raw)), raw[:,ch])*env*g*amplitude
        for ch, g in enumerate((np.cos(pos), np.sin(pos)))
    ]).astype("float32")


def chamber(cue):
    """Stereo return: asymmetrical early reflections and a damped diffusion tail."""
    decay = {"grounds": .83, "tower": 1.32, "ending": 1.9,
             "cadence": 1.5, "altar": 1.6}[cue]
    rng = np.random.default_rng(92)
    n = int(RATE*decay)
    ir = np.zeros((n,2), dtype="float32")
    for ch, delays in enumerate(((.025,.056,.082,.117), (.034,.049,.093,.138))):
        for dt, amp in zip(delays,(.10,.067,.043,.026)):
            ir[round(dt*RATE),ch] = amp
        noise = sosfilt(butter(2, 3100, fs=RATE, output="sos"), rng.normal(size=n))
        t = np.arange(n)/RATE
        diffuse = noise*np.exp(-7*t/decay)*np.minimum(t/.12,1)
        ir[:,ch] += diffuse*.16/np.linalg.norm(diffuse)
    return ir


def render(cue, mapped, library):
    seconds, parts = read_midi(PROJECT / "scores" / (cue + ".mid"))
    n = round(seconds*RATE)
    one_shot = cue in ("cadence", "altar")
    impulse = chamber(cue)
    stems = {}
    sources = set()
    for group, events in parts.items():
        dry = np.zeros((n+RATE*4, 2), dtype="float32")
        for instrument, start, pitch, duration, velocity in events:
            note = render_note(instrument, pitch, duration, velocity, mapped, sources)
            offset = round(start*RATE)
            dry[offset:offset+len(note)] += note
        mid = dry.mean(axis=1)
        for channel in range(2):
            dry[:,channel] += oaconvolve(mid, impulse[:,channel])[:len(dry)]
        if not one_shot:
            spill = dry[n:]
            dry[:len(spill)] += spill
        stem = dry[:n]
        if one_shot:
            stem[-RATE//4:] *= np.linspace(1,0,RATE//4)[:,None]
        stems[group] = stem
    master = sum(stems.values())
    rms = np.sqrt(np.mean(master**2))
    gain = min(.72/np.max(np.abs(master)), .095/max(.001,rms))
    folder = PROJECT / "stems" / cue
    folder.mkdir(exist_ok=True)
    for group, stem in stems.items():
        sf.write(folder/(group+".flac"), stem*gain, RATE, subtype="PCM_24")
        if cue == "tower":
            sf.write(SCORE/(cue+"_"+group+".ogg"), stem*gain, RATE, format="OGG",
                     subtype="VORBIS", compression_level=.30)
    if cue != "tower":
        sf.write(SCORE/(cue+".ogg"), master*gain, RATE, format="OGG", subtype="VORBIS",
                 compression_level=.30)
    return sorted(str(path.relative_to(library)) for path in sources)


if __name__ == "__main__":
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("vsco", type=Path)
    args = parser.parse_args()
    bank = make_map(args.vsco)
    with (PROJECT/"orchestra-sources.tsv").open("w") as f:
        print("score\tVSCO-file", file=f)
        for cue in sorted(RECORDED_CUES):
            for path in render(cue, bank, args.vsco):
                print(cue + "\t" + path, file=f)
            print("Rendered", cue, flush=True)
