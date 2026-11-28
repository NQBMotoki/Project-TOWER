"""Compose and render the new tower scores from editable Type 1 MIDI."""

from argparse import ArgumentParser
from collections import defaultdict
from ctypes import CDLL, POINTER, Structure, byref, c_char_p, c_double, c_float, c_int, c_int64, c_void_p
from ctypes.util import find_library
from functools import lru_cache
from os import environ, fsencode
from pathlib import Path
import random
import struct
import subprocess

import numpy as np


ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "audio_project"
RUNTIME = ROOT / "assets/audio/music"
RATE = 44100
PPQ = 480
SFM_WRITE = 0x20
SFC_SET_VBR_ENCODING_QUALITY = 0x1300
SOUNDFILE_FORMATS = {"flac": 0x170003, "ogg": 0x200060}  # FLAC | PCM_24, OGG | VORBIS
BPM = {"elite": 108, "rift": 84, "lord": 114}
HARMONY = {
    "elite": [38, 38, 34, 33, 38, 41, 31, 33, 38, 36, 34, 33, 38, 34, 33, 38],
    "rift": [38, 38, 39, 34, 38, 37, 34, 33, 38, 46, 43, 39, 38, 35, 33, 38],
    "lord": [38, 34, 41, 36, 43, 38, 34, 33, 38, 34, 43, 33, 38, 46, 33, 38],
}
PATCH = {"cello": 42, "viola": 41, "reed": 71, "brass": 60,
         "pizz": 45, "metal": 14, "drum": 47, "glass": 9}
# Duration, position and gain share the relative space of the existing tower stems.
VOICE = {
    "cello": (.32, -.23, .62), "viola": (.34, .25, .49),
    "reed": (.20, -.13, .76), "brass": (.30, .16, .77),
    "pizz": (.16, -.28, .48), "metal": (.50, .25, .53),
    "drum": (.42, -.05, .69), "glass": (.73, .36, .44),
}
SAMPLES = {"reed": ("reed_d4.flac", 62), "brass": ("horn_d3.flac", 50)}


def compose(cue):
    events = defaultdict(list)
    rng = random.Random(cue)

    def note(layer, instrument, beat, pitch, length, velocity):
        start = max(0.0, beat + rng.uniform(-.013, .013))
        events[layer, instrument].append((start, pitch, length, velocity + rng.randrange(-3, 4)))

    for bar, root in enumerate(HARMONY[cue]):
        beat = bar * 4
        final = bar == 15
        if cue == "elite":
            # Uneven groups of 3+3+2 keep the sentry march pressing forward.
            note("bed", "cello", beat, root, 3.70, 79)
            note("bed", "viola", beat + .08, root + (9 if root == 33 else 7), 3.44, 58)
            call = [(0, 62, .63), (.75, 69, .48), (1.50, 67, .60), (2.50, 65, .74)]
            replies = [[(0, 57, .96), (1.50, 60, .41), (2.25, 58, .88)],
                       [(.5, 65, .7), (1.50, 67, .68), (2.5, 70, .71)],
                       [(0, 69, .71), (1.5, 64, .51), (2.5, 61, .75)]]
            phrase = ([(0, 62, 2.75)] if final else call if bar % 4 == 0
                      else replies[bar % 4 - 1])
            for offset, pitch, length in phrase:
                note("theme", "brass" if bar % 4 in (0, 3) else "reed",
                     beat + offset, pitch - (12 if bar % 4 in (0, 3) else 0), length, 83)
            for offset in [0, 1.5, 3]:
                note("pulse", "drum", beat + offset, root - 3, .26, 89 if offset == 0 else 67)
                note("pulse", "pizz", beat + offset + .24, root + 12, .24, 84)
            note("pulse", "metal", beat + (3.5 if bar % 2 else .5), root + 24, .24, 67)
            for offset, pitch in [(0, root + 7), (1.5, root + 12), (3, root + 7)]:
                note("color", "brass", beat + offset, pitch, .49, 83)
            if bar % 2:
                note("color", "metal", beat + 2.45, root + 31, .47, 64)
        elif cue == "rift":
            # Long, locally dissonant drones and missing downbeats leave room for warnings.
            note("bed", "cello", beat, root, 3.75, 62)
            note("bed", "viola", beat + .18, root + (13 if bar % 4 == 2 else 19), 3.61, 41)
            phrase = [
                [(0, 62, .94), (1.25, 69, .47), (2.20, 67, .52), (3.04, 65, .43)],
                [(1.75, 58, .56)], [(.6, 63, 1.1), (2.95, 62, .51)], [(2.19, 61, 1.02)],
            ][bar % 4]
            if final:
                phrase = [(2, 62, 1.12)]
            for offset, pitch, length in phrase:
                note("theme", "reed" if bar % 3 else "glass", beat + offset, pitch, length, 59)
            for offset, pitch in [(.66, root + 12), (1.62, root + 7), (3.20, root + 1)]:
                note("pulse", "pizz", beat + offset, pitch, .25, 59)
            if not bar % 2:
                note("pulse", "drum", beat + 2.55, root - 8, .43, 65)
            note("color", "viola", beat + 1.24, root + 24 + (1 if bar % 4 in (1, 3) else 0), 2.21, 60)
            if bar % 4 in (1, 2):
                note("color", "glass", beat + 2.48, root + 37, .44, 60)
        else:
            # The summit answers the old tower call with lower brass and a second string voice.
            note("bed", "cello", beat, root, 3.66, 87)
            note("bed", "viola", beat + .08, root + 19, 3.48, 65)
            fanfare = [
                [(0, 62, .93), (1.18, 69, .69), (2.04, 67, .71), (3.02, 65, .63)],
                [(0, 70, 1.42), (1.7, 69, .49), (2.5, 65, 1.20)],
                [(0, 72, .70), (.85, 74, 1.25), (2.42, 69, 1.18)],
                [(0, 67, 1.14), (1.45, 65, .61), (2.25, 64, .66), (3, 61, .71)],
            ][bar % 4]
            if final:
                fanfare = [(0, 69, 1.16), (1.5, 65, .58), (2.25, 62, 1.33)]
            for offset, pitch, length in fanfare:
                note("theme", "brass", beat + offset, pitch - 12, length, 93)
                if bar % 4 in (1, 2):
                    note("theme", "reed", beat + offset + .035, pitch, length * .86, 63)
            for step, interval in enumerate([12, 19, 24, 19, 12, 15, 19, 24]):
                chord_interval = 16 if interval == 15 and root % 12 in (0, 5, 9, 10) else interval
                note("pulse", "pizz", beat + step * .5, root + chord_interval, .29, 81 if step % 2 == 0 else 67)
            for offset in [0, 1.5, 3]:
                note("pulse", "drum", beat + offset, root - 5, .32, 89 if offset == 0 else 72)
            for offset, pitch in [(0, root + 7), (1.75, root + 12), (3, root + 19)]:
                note("color", "brass", beat + offset, pitch, .62, 88)
                note("color", "viola", beat + offset + .1, pitch + 12, .47, 74)
            if bar % 2 == 0:
                note("color", "metal", beat, root + 36, .66, 70)
    return events


def variable_length(value):
    result = [value & 127]
    value >>= 7
    while value:
        result.insert(0, (value & 127) | 128)
        value >>= 7
    return bytes(result)


def meta(kind, payload):
    return b"\xff" + bytes([kind]) + variable_length(len(payload)) + payload


def track(events):
    result = bytearray()
    previous = 0
    for tick, _, message in sorted(events):
        result += variable_length(tick - previous) + message
        previous = tick
    result += b"\x00\xff\x2f\x00"
    return b"MTrk" + struct.pack(">I", len(result)) + result


def write_midi(cue):
    tempo = round(60_000_000 / BPM[cue])
    tracks = [track([
        (0, 0, meta(3, ("Lantern / " + cue).encode())),
        (0, 1, meta(81, tempo.to_bytes(3, "big"))),
        (0, 2, meta(88, bytes([4, 2, 24, 8]))),
        (0, 3, meta(89, bytes([255, 1]))),
        (0, 4, meta(6, b"START")),
        (64 * PPQ, 0, meta(6, b"END")),
    ])]
    for channel, ((layer, instrument), notes) in enumerate(compose(cue).items()):
        events = [(0, -2, meta(3, f"{layer}/{instrument}".encode())),
                  (0, -1, bytes([0xC0 + channel, PATCH[instrument]]))]
        for start, pitch, length, velocity in notes:
            begin = round(start * PPQ)
            events.extend([
                (begin, 1, bytes([0x90 + channel, pitch, velocity])),
                (begin + round(length * PPQ), 0, bytes([0x80 + channel, pitch, 0])),
            ])
        tracks.append(track(events))
    header = b"MThd" + struct.pack(">IHHH", 6, 1, len(tracks), PPQ)
    (PROJECT / "scores" / f"{cue}.mid").write_bytes(header + b"".join(tracks))


def number(data, offset):
    value = 0
    while data[offset] & 128:
        value = (value << 7) | (data[offset] & 127)
        offset += 1
    return (value << 7) | data[offset], offset + 1


def events_in(data):
    tick = offset = status = 0
    while offset < len(data):
        delta, offset = number(data, offset)
        tick += delta
        code = data[offset]
        if code >= 128:
            status = code
            offset += 1
        if status in (0xFF, 0xF0, 0xF7):
            kind = data[offset] if status == 0xFF else 0
            offset += int(status == 0xFF)
            length, offset = number(data, offset)
            yield tick, status, kind, data[offset:offset + length]
            offset += length
        else:
            length = 1 if status & 0xF0 in (0xC0, 0xD0) else 2
            yield tick, status, 0, data[offset:offset + length]
            offset += length


def read_midi(cue):
    data = (PROJECT / "scores" / f"{cue}.mid").read_bytes()
    size, form, count, resolution = struct.unpack(">IHHH", data[4:14])
    if data[:4] != b"MThd" or form != 1 or resolution & 0x8000:
        raise ValueError(f"{cue} needs Type 1 MIDI with a PPQ timebase")
    tempo = end = 0
    offset = size + 8
    notes = defaultdict(list)
    for index in range(count):
        if data[offset:offset + 4] != b"MTrk":
            raise ValueError(f"{cue} track {index + 1} is missing")
        length = struct.unpack(">I", data[offset + 4:offset + 8])[0]
        offset += 8
        name = ""
        active = {}
        for tick, status, kind, payload in events_in(data[offset:offset + length]):
            if status == 0xFF:
                if kind == 81:
                    value = int.from_bytes(payload, "big")
                    if tempo and value != tempo:
                        raise ValueError(f"{cue} requires a fixed tempo for synchronized stems")
                    tempo = value
                elif kind == 6 and payload == b"END":
                    end = tick
                elif kind == 3:
                    name = payload.decode()
                continue
            family = status & 0xF0
            if family not in (0x80, 0x90):
                continue
            pitch, velocity = payload
            key = (status & 15, pitch)
            if family == 0x90 and velocity:
                active[key] = tick, velocity
            elif key in active:
                start, gain = active.pop(key)
                layer, instrument = name.split("/")
                if layer not in ("bed", "theme", "pulse", "color") or instrument not in VOICE:
                    raise ValueError(f"{cue}: invalid track name {name!r}")
                notes[layer].append((instrument, start, pitch, tick - start, gain))
        offset += length
    if not tempo or not end or set(notes) != {"bed", "theme", "pulse", "color"}:
        raise ValueError(f"{cue} is missing one of its four stems, tempo, or END marker")
    return tempo / (1e6 * resolution), end, notes


@lru_cache(maxsize=None)
def sampled_attack(instrument):
    filename, pitch = SAMPLES[instrument]
    raw = subprocess.check_output([
        "ffmpeg", "-v", "error", "-i", str(PROJECT / "instruments" / filename),
        "-ar", str(RATE), "-ac", "1", "-f", "f32le", "-",
    ])
    data = np.frombuffer(raw, dtype="<f4")
    return data / max(.06, np.quantile(np.abs(data), .995)), pitch


def render_note(instrument, pitch, duration, velocity):
    release, pan, gain = VOICE[instrument]
    t = np.arange(round((duration + release) * RATE)) / RATE
    attack = .008
    hz = 440 * 2 ** ((pitch - 69) / 12)
    p = 2 * np.pi * hz * t
    a = np.sin(p)
    if instrument in ("cello", "viola"):
        vib = .21 * np.sin(2 * np.pi * (4.4 if instrument == "cello" else 5.05) * t) * np.minimum(1, 3.3 * t)
        a = (.58 * np.sin(p + vib) + .23 * np.sin(2 * p + vib + .6)
             + .11 * np.sin(3 * p + 2 * vib) + .075 * np.sin(4 * p + 1.4)
             + .13 * np.sin(p * 1.003 + .36 + .7 * vib))
        a *= .83 + .17 * np.cos(2 * np.pi * 1.5 * t)
        attack = .085 if instrument == "cello" else .11
    elif instrument in SAMPLES:
        sample, root = sampled_attack(instrument)
        position = t * RATE * 2 ** ((pitch - root) / 12)
        recorded = np.interp(position, np.arange(len(sample)), sample, right=0.0)
        sustain = .58 * np.sin(p) + (.27 if instrument == "brass" else .08) * np.sin(2 * p + .9)
        sustain += .16 * np.sin(3 * p + .24 + .26 * np.sin(2 * np.pi * 4.7 * t))
        a = .74 * recorded + .40 * sustain * np.minimum(1, t / .20)
        attack = .043 if instrument == "brass" else .027
    elif instrument == "pizz":
        a = (.66 * a + .18 * np.sin(2 * p + .24) + .10 * np.sin(3 * p + .7)) * np.exp(-t * 8)
        a += .11 * np.sin(8.42 * p) * np.exp(-57 * t)
    elif instrument == "drum":
        a = .67 * np.sin(p + 2.6 * (1 - np.exp(-t * 22))) * np.exp(-9.2 * t)
        a += .34 * np.sin(1.51 * p) * np.exp(-17 * t) + .21 * np.sin(4.744 * p) * np.exp(-49 * t)
        attack = .005
    elif instrument == "metal":
        a = sum(v * np.sin(multiplier * p) * np.exp(-t * decay)
                for multiplier, v, decay in [(1, .67, 12), (1.491, .37, 22), (2.683, .22, 32), (5.19, .12, 55)])
        attack = .003
    elif instrument == "glass":
        a = .64 * a * np.exp(-t * 4) + .35 * np.sin(1.507 * p) * np.exp(-t * 9)
        a += .16 * np.sin(3.185 * p) * np.exp(-t * 17)
    envelope = np.minimum(1, t / attack) * np.cos(np.clip((t - duration) / release, 0, 1) * np.pi / 2) ** 2
    level = a * envelope * gain * (velocity / 100) ** 1.9
    balance = (pan + 1) * np.pi / 4
    return np.column_stack([level * np.cos(balance), level * np.sin(balance)]).astype("float32")


class AudioFileInfo(Structure):
    _fields_ = [
        ("frames", c_int64), ("samplerate", c_int), ("channels", c_int),
        ("format", c_int), ("sections", c_int), ("seekable", c_int),
    ]


@lru_cache(maxsize=1)
def sndfile():
    library = environ.get("TOWER_SNDFILE_LIBRARY") or find_library("sndfile")
    if not library:
        raise RuntimeError("Install libsndfile or set TOWER_SNDFILE_LIBRARY to its library path")
    handle = CDLL(library)
    handle.sf_open.argtypes = (c_char_p, c_int, POINTER(AudioFileInfo))
    handle.sf_open.restype = c_void_p
    handle.sf_writef_float.argtypes = (c_void_p, POINTER(c_float), c_int64)
    handle.sf_writef_float.restype = c_int64
    handle.sf_command.argtypes = (c_void_p, c_int, c_void_p, c_int)
    handle.sf_close.argtypes = (c_void_p,)
    return handle


def encode(data, path, codec):
    lib = sndfile()
    info = AudioFileInfo(0, RATE, 2, SOUNDFILE_FORMATS[codec], 0, 0)
    samples = np.ascontiguousarray(data, dtype=np.float32)
    output = lib.sf_open(fsencode(path), SFM_WRITE, byref(info))
    if not output:
        raise OSError(f"Cannot open audio output {path}")
    try:
        if codec == "ogg":
            quality = c_double(.58)
            lib.sf_command(output, SFC_SET_VBR_ENCODING_QUALITY, byref(quality), 8)
        written = lib.sf_writef_float(output, samples.ctypes.data_as(POINTER(c_float)), len(samples))
        if written != len(samples):
            raise OSError(f"Short audio write to {path}")
    finally:
        if lib.sf_close(output):
            raise OSError(f"Cannot finalize audio output {path}")


def render(cue):
    tick_seconds, last_tick, parts = read_midi(cue)
    frames = round(last_tick * tick_seconds * RATE)
    stems = {}
    reflection = {"elite": .69, "rift": 1.19, "lord": 1.31}[cue]
    for layer, notes in parts.items():
        stem = np.zeros((frames, 2), dtype="float32")
        for instrument, start, pitch, length, gain in notes:
            note = render_note(instrument, pitch, length * tick_seconds, gain)
            index = round(start * tick_seconds * RATE) % frames
            room = min(len(note), frames - index)
            stem[index:index + room] += note[:room]
            if room < len(note):
                stem[:len(note) - room] += note[room:]
        mono = stem.mean(axis=1)
        for index, strength in enumerate((.115, .083, .062, .045, .031, .022, .016)):
            for channel, delay in enumerate((.035, .048)):
                time = reflection * (delay + .056 * index + .009 * index * channel)
                stem[:, channel] += np.roll(mono, round(time * RATE)) * strength
        stems[layer] = stem
    master = sum(stems.values())
    gain = min(.74 / np.max(np.abs(master)), .093 / np.sqrt(np.mean(master ** 2)))
    directory = PROJECT / "stems" / cue
    directory.mkdir(exist_ok=True)
    for layer, stem in stems.items():
        encode(stem * gain, directory / f"{layer}.flac", "flac")
        encode(stem * gain, RUNTIME / f"{cue}_{layer}.ogg", "ogg")
    print(f"{cue}: 4 parts at {BPM[cue]} BPM, {frames:,} aligned stereo frames", flush=True)


if __name__ == "__main__":
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("--compose", action="store_true", help="rewrite the regional MIDI with the written arrangements")
    parser.add_argument("--score", choices=BPM, help="render only this regional score")
    args = parser.parse_args()
    for cue in [args.score] if args.score else BPM:
        if args.compose:
            write_midi(cue)
        render(cue)
