"""Audit the production score, runtime audio, import metadata and source manifests."""
import csv
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "audio_project"
ASSETS = ROOT / "assets/audio"
from regional_score import BPM as REGIONAL_BPM, SAMPLES

BPM = {"grounds": 76, "tower": 96, "ending": 70, "cadence": 96, "altar": 76} | REGIONAL_BPM
LAYERED = {"tower", *REGIONAL_BPM}


def decode(path):
    info = json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-show_streams", "-of", "json", str(path),
    ]))["streams"][0]
    assert int(info["sample_rate"]) == 44100, path
    raw = subprocess.check_output([
        "ffmpeg", "-v", "error", "-i", str(path), "-f", "f32le", "-c:a", "pcm_f32le", "-",
    ])
    samples = np.frombuffer(raw, dtype="<f4").reshape(-1, info["channels"])
    assert len(samples) == int(info["duration_ts"]), path
    assert np.isfinite(samples).all() and 0.01 < np.abs(samples).max() < 1.0, path
    return info, samples


def read_manifest(name):
    with (PROJECT / name).open() as source:
        return list(csv.reader(source, delimiter="\t"))[1:]


def check_scores():
    materials = read_manifest("orchestra-sources.tsv")
    assert {cue for cue, _ in materials} == set(BPM) - set(REGIONAL_BPM)
    assert {name for name, _ in SAMPLES.values()} == {row[0] for row in read_manifest("instrument-sources.tsv")}
    runtime_files = set()
    count = 0
    for cue, bpm in BPM.items():
        midi = (PROJECT / "scores" / (cue + ".mid")).read_bytes()
        header, size, version, tracks, divisions = struct.unpack(">4sIHHH", midi[:14])
        assert (header, size, version, divisions) == (b"MThd", 6, 1, 480) and tracks >= 3, cue
        assert b"START" in midi and b"END" in midi, cue
        end = round(44100 * (8 if cue in ("altar", "cadence") else 64) * round(60e6 / bpm) / 1e6)
        parts = {}
        for path in sorted((PROJECT / "stems" / cue).glob("*.flac")):
            info, source = decode(path)
            assert info["codec_name"] == "flac" and int(info["bits_per_raw_sample"]) == 24, path
            assert source.shape == (end, 2), path
            parts[path.stem] = source
        assert parts, cue
        count += len(parts)
        if cue in LAYERED:
            assert set(parts) == {"bed", "theme", "color", "pulse"}, cue
            mixes = {cue + "_" + name: part for name, part in parts.items()}
        else:
            mixes = {cue: sum(parts.values())}
        for name, master in mixes.items():
            path = ASSETS / "music" / (name + ".ogg")
            info, render = decode(path)
            assert info["codec_name"] == "vorbis" and render.shape == master.shape, path
            assert np.abs(master).max() < 1, path
            residual = np.mean(np.square(render - master), dtype=np.float64)
            energy = np.mean(np.square(master), dtype=np.float64)
            assert residual < energy / 60, f"Vorbis export does not match its master: {path}"
            metadata = Path(str(path) + ".import").read_text()
            assert f"bpm={bpm}\n" in metadata, path
            runtime_files.add(path)
        print(f"{cue:8} {bpm:3} BPM  {end:7} frames  {', '.join(parts)}")
    assert runtime_files == set((ASSETS / "music").glob("*.ogg"))
    return count


def check_loops():
    largest = 0.0
    for path in sorted(ASSETS.rglob("*.ogg")):
        looping = path.stem not in ("altar", "cadence")
        metadata = Path(str(path) + ".import").read_text()
        assert f"loop={str(looping).lower()}\n" in metadata and "loop_offset=0\n" in metadata, path
        _, audio = decode(path)
        if not looping:
            continue
        jump = float(np.max(np.abs(audio[-1] - audio[0])))
        threshold = float(np.quantile(np.abs(np.diff(audio, axis=0)), .99))
        assert jump <= threshold, f"Loop-boundary step {jump} exceeds {threshold}: {path}"
        largest = max(largest, jump)
    return largest


def check_foley():
    manifest = dict(read_manifest("foley-sources.tsv"))
    paths = sorted((ASSETS / "foley").glob("*.wav"))
    assert set(manifest) == {path.name for path in paths}
    fingerprints = set()
    peak = 0.0
    for path in paths:
        with wave.open(str(path)) as clip:
            assert (clip.getframerate(), clip.getsampwidth(), clip.getnchannels()) == (44100, 2, 1), path
            pcm = clip.readframes(clip.getnframes())
        fingerprint = hashlib.sha256(pcm).digest()
        assert fingerprint not in fingerprints, f"Identical Foley take: {path}"
        fingerprints.add(fingerprint)
        audio = np.frombuffer(pcm, dtype="<i2").astype(np.float32) / 32768
        top = float(np.abs(audio).max())
        assert .05 < top < 1 and abs(audio[0]) < .001 and abs(audio[-1]) < .001, path
        peak = max(peak, top)
        assert "compress/mode=0" in Path(str(path) + ".import").read_text(), path
    return len(paths), peak


if __name__ == "__main__":
    stems = check_scores()
    seam = check_loops()
    takes, peak = check_foley()
    print(f"PASS: {stems} lossless stems, {takes} unique one-shots, Foley peak {20*np.log10(peak):.2f} dBFS, "
          f"largest decoded loop-boundary step {seam:.5f} FS")
