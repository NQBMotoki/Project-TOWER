extends Node

var sounds: Dictionary = {}

func _ready() -> void:
	sounds["sword"] = _tone(530.0, 260.0, 0.09, 0.25)
	sounds["magic"] = _tone(440.0, 800.0, 0.16, 0.24)
	sounds["enemy_magic"] = _tone(280.0, 180.0, 0.12, 0.20)
	sounds["hit"] = _tone(170.0, 85.0, 0.07, 0.25)
	sounds["hurt"] = _tone(150.0, 70.0, 0.20, 0.28)
	sounds["death"] = _tone(300.0, 90.0, 0.19, 0.22)
	sounds["choose"] = _tone(450.0, 720.0, 0.12, 0.20)

func play(kind: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not sounds.has(kind):
		return
	var audio := AudioStreamPlayer.new()
	audio.stream = sounds[kind]
	add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()

func _tone(start_hz: float, end_hz: float, duration: float, volume: float) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var count := int(duration * wav.mix_rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in range(count):
		var t := float(i) / float(count)
		phase += TAU * lerpf(start_hz, end_hz, t) / float(wav.mix_rate)
		var envelope := minf(1.0, t * 30.0) * (1.0 - t)
		var sample := int(sin(phase) * envelope * volume * 32767.0)
		data.encode_s16(i * 2, sample)
	wav.data = data
	return wav
