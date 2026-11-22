extends RefCounted

# Each row is a two-bar part. MIDI pitches are transposed by the track's bass roots.
const PARTS := {
	"grounds": {"tempo": 88.0, "roots": [45, 41, 48, 43], "lead": [19, -1, 15, -1, 12, -1, 7, -1], "pulse": false},
	"tower": {"tempo": 118.0, "roots": [45, 43, 41, 40], "lead": [12, 7, 15, -1, 12, 7, 17, 15], "pulse": true},
	"lord": {"tempo": 143.0, "roots": [40, 41, 38, 39], "lead": [19, 13, 12, 6, 19, 15, 13, 12], "pulse": true},
	"ending": {"tempo": 82.0, "roots": [45, 48, 41, 43], "lead": [7, -1, 12, 15, 19, -1, 15, -1], "pulse": false},
}
const RATE := 22050

static func render(kind: String) -> AudioStreamWAV:
	var part: Dictionary = PARTS[kind]
	var step_samples := roundi(RATE * 30.0 / part.tempo)
	var sample_count: int = part.roots.size() * part.lead.size() * step_samples
	var samples := PackedByteArray()
	samples.resize(sample_count * 2)
	for bar in range(part.roots.size()):
		var root: int = part.roots[bar]
		for step in range(part.lead.size()):
			var bass_hz := _frequency(root + (7 if step % 4 == 2 else 0))
			var note: int = part.lead[step]
			var lead_hz := _frequency(root + note + 12)
			var harmony_hz := _frequency(root + (15 if bar % 2 == 0 else 16))
			var offset: int = (bar * part.lead.size() + step) * step_samples
			for i in range(step_samples):
				var t := float(i) / RATE
				var remaining := float(step_samples - i) / RATE
				var edge := minf(1.0, minf(t, remaining) * 160.0)
				var triangle := absf(fmod(t * bass_hz, 1.0) - 0.5) * 4.0 - 1.0
				var sample := triangle * 0.052 * exp(-t * 3.0)
				if note >= 0:
					var lead := 1.0 if fmod(t * lead_hz, 1.0) < 0.25 else -0.333
					sample += lead * 0.041 * exp(-t * 7.0)
				sample += sin(TAU * t * harmony_hz) * 0.023
				if part.pulse and step % 2 == 0:
					sample += sin(TAU * (t * 54.0 + 4.0 * (1.0 - exp(-t * 31.0)))) * exp(-t * 41.0) * 0.045
				samples.encode_s16((offset + i) * 2, roundi(sample * edge * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = sample_count
	wav.data = samples
	return wav

static func _frequency(note: int) -> float:
	return 440.0 * pow(2.0, float(note - 69) / 12.0)
