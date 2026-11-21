extends Node

var sounds: Dictionary = {}
const EFFECTS_BUS := "Effects"

func _ready() -> void:
	if AudioServer.get_bus_index(EFFECTS_BUS) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, EFFECTS_BUS)
	sounds["sword"] = _tone(530.0, 260.0, 0.09, 0.25)
	sounds["magic"] = _tone(440.0, 800.0, 0.16, 0.24)
	sounds["enemy_magic"] = _tone(280.0, 180.0, 0.12, 0.20)
	sounds["enemy_chant"] = _tone(330.0, 520.0, 0.26, 0.15)
	sounds["enemy_arrow"] = _tone(760.0, 250.0, 0.09, 0.19)
	sounds["hit"] = _tone(170.0, 85.0, 0.07, 0.25)
	sounds["hurt"] = _tone(150.0, 70.0, 0.20, 0.28)
	sounds["death"] = _tone(300.0, 90.0, 0.19, 0.22)
	sounds["choose"] = _tone(450.0, 720.0, 0.12, 0.20)
	sounds["pickup"] = _tone(370.0, 650.0, 0.13, 0.16)
	sounds["craft"] = _tone(310.0, 530.0, 0.23, 0.17)
	sounds["potion"] = _tone(430.0, 870.0, 0.24, 0.17)
	sounds["ghost"] = _tone(128.0, 200.0, 1.1, 0.17)

func set_volumes(master: float, effects: float) -> void:
	_set_bus_volume(0, master)
	_set_bus_volume(AudioServer.get_bus_index(EFFECTS_BUS), effects)

func _set_bus_volume(index: int, level: float) -> void:
	AudioServer.set_bus_mute(index, is_zero_approx(level))
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level, 0.0001)))

func play(kind: String, preview := false) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not sounds.has(kind):
		return
	var audio := AudioStreamPlayer.new()
	audio.stream = sounds[kind]
	audio.bus = EFFECTS_BUS
	if preview:
		audio.process_mode = Node.PROCESS_MODE_ALWAYS
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
