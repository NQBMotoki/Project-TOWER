"""Write the editable type-1 MIDI scores for Project TOWER's Lantern theme."""
from pathlib import Path
import random

from mido import Message, MetaMessage, MidiFile, MidiTrack, bpm2tempo

PROJECT = Path(__file__).resolve().parents[2] / "audio_project"
PPQ = 480
# Diatonic through the first phrase; the approach to the dominant borrows C sharp.
ROOTS = [50, 46, 53, 48, 43, 50, 46, 45, 50, 53, 43, 45, 46, 48, 45, 50]
THIRDS = [3, 4, 4, 4, 3, 3, 4, 4, 3, 4, 3, 4, 4, 4, 4, 3]
# (beat within bar, concert MIDI pitch, written duration).
PHRASE = [
    [(0, 62, 1.35), (1.5, 69, .42), (2, 67, 1.25), (3.5, 65, .4)],
    [(0, 65, 2.5), (3, 62, .8)],
    [(0, 60, .9), (1, 65, 1.7), (3, 69, .74)],
    [(0, 67, 2.65)],
    [(0, 67, 1.45), (1.5, 70, .45), (2, 69, 1.5)],
    [(0, 65, 2), (2.5, 64, .45), (3, 62, .85)],
    [(0, 58, 1.6), (2, 62, 1.5)],
    [(0, 61, 2.5)],
    [(0, 69, .85), (1, 74, 1.4), (2.5, 72, .4), (3, 69, .85)],
    [(0, 69, 1.5), (2, 65, 1.65)],
    [(0, 67, .9), (1, 62, .85), (2, 58, 1.75)],
    [(0, 57, 2.7), (3, 61, .75)],
    [(0, 62, 1.35), (1.5, 69, .42), (2, 67, 1.25), (3.5, 65, .4)],
    [(0, 64, 2.3), (3, 60, .7)],
    [(0, 61, .85), (1, 64, 1.6), (3, 57, .65)],
    [(0, 62, 2.6)],
]
# Instruments carry a General MIDI patch as a starting point in GarageBand.
PATCH = {"cello": 42, "viola": 41, "pizz": 45, "harp": 46, "flute": 73,
         "clarinet": 71, "horn": 60, "glock": 9, "timpani": 47}
BPM = {"grounds": 76, "tower": 96, "ending": 70, "cadence": 96, "altar": 76}


def arrange(cue):
    parts = {}
    rng = random.Random(cue)
    def note(group, instrument, beat, pitch, duration, velocity):
        human = rng.uniform(-.014, .018)
        start = max(0, round((beat + human) * PPQ))
        end = start + round(duration * PPQ)
        velocity = max(1, min(127, velocity + rng.randint(-3, 3)))
        parts.setdefault((group, instrument), []).append((start, end, pitch, velocity))
    if cue in ("altar", "cadence"):
        for beat, pitch, length in [(0, 62, .85), (1, 69, .65), (1.75, 67, .65),
                                    (2.5, 65, .85), (3.5, 62, 2)]:
            note("theme", "harp" if cue == "altar" else "clarinet", beat, pitch, length, 72)
        note("bed", "glock" if cue == "altar" else "cello", 0, 74 if cue == "altar" else 46, 3, 54)
        note("bed", "harp", 3.5, 50, 2.5, 73)
        return parts, 2
    for i, bar in enumerate(PHRASE):
        beat = i * 4
        root = ROOTS[i]
        third = root + THIRDS[i]
        if cue == "grounds":
            # A solitary harp plays the first call; breath enters only on the answers.
            for offset, pitch, duration in bar:
                note("theme", "harp", beat + offset, pitch, duration + .45, 78)
                if i in (3, 5, 9, 12, 13, 15):
                    note("air", "flute", beat + offset + .04, pitch + 12, duration * .9, 55)
            note("bed", "harp", beat, root, 2.5, 62)
            if i % 4 in (1, 3):
                note("bed", "cello", beat + .5, root, 2.9, 54)
            if i % 4 == 2:
                note("air", "glock", beat + 2.5, root + 31, 1.15, 42)
        elif cue == "tower":
            note("bed", "cello", beat, root, 3.8, 73)
            note("bed", "viola", beat + .12, root + 7, 3.62, 55)
            for offset, pitch, duration in bar:
                note("theme", "clarinet", beat + offset, pitch, duration, 78)
            pulses = [(0, root, 84), (.75, root+7, 54), (1.5, root+12, 73),
                      (2.5, third+12, 61), (3, root+7, 72)]
            for offset, pitch, velocity in pulses:
                note("pulse", "pizz", beat+offset, pitch, .33, velocity)
            note("pulse", "timpani", beat + (0 if i % 2 == 0 else 2.5), root - 12, .8, 72)
            note("color", "viola", beat+.55, third+12, 1.8, 59)
            note("color", "horn", beat+2.55, root+7, 1.15, 56)
            if i % 4 in (0, 3):
                note("color", "glock", beat+(0 if i % 4 == 0 else 3), root+31, 1.2, 48)
        else:
            # At the exit the figure moves into the upper register, then returns to D.
            for offset, pitch, duration in bar:
                note("theme", "flute" if i < 8 else "viola", beat+offset, pitch + (12 if i < 8 else 0), duration, 68)
            note("bed", "cello", beat+.05, root, 3.65, 58)
            for offset, pitch in [(0, root), (1.5, root+7), (2.5, third+12)]:
                note("harp", "harp", beat+offset, pitch, 1.4, 65)
            if i >= 8 and i % 2 == 0:
                note("harp", "glock", beat+3, root+31, .85, 46)
    return parts, 16


def write_score(cue):
    parts, bars = arrange(cue)
    midi = MidiFile(type=1, ticks_per_beat=PPQ)
    control = MidiTrack()
    midi.tracks.append(control)
    control.extend([MetaMessage("track_name", name="Lantern / " + cue),
                    MetaMessage("set_tempo", tempo=bpm2tempo(BPM[cue])),
                    MetaMessage("time_signature", numerator=4, denominator=4),
                    MetaMessage("key_signature", key="Dm"),
                    MetaMessage("marker", text="START"),
                    MetaMessage("marker", text="END", time=bars*4*PPQ)])
    for channel, ((group, instrument), events) in enumerate(parts.items()):
        track = MidiTrack()
        midi.tracks.append(track)
        track.append(MetaMessage("track_name", name=group + "/" + instrument))
        track.append(Message("program_change", channel=channel, program=PATCH[instrument]))
        ordered = []
        for start, end, pitch, velocity in events:
            ordered.extend([(start, 1, pitch, velocity), (end, 0, pitch, 0)])
        previous = 0
        for tick, on, pitch, velocity in sorted(ordered):
            track.append(Message("note_on" if on else "note_off", channel=channel, note=pitch,
                                 velocity=velocity, time=tick-previous))
            previous = tick
    midi.save(PROJECT / "scores" / (cue + ".mid"))


if __name__ == "__main__":
    for name in BPM:
        write_score(name)
