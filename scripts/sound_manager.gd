extends Node

const RetroScore = preload("res://scripts/retro_score.gd")
const EFFECTS_BUS := "Effects"
const MUSIC_BUS := "Music"
const DANGER_CUES := ["hurt", "enemy_telegraph", "enemy_chant", "enemy_zone_warning", "trap_warn", "trap_arrow"]

@export var effect_assets: Dictionary[String, AudioStream] = {}
@export var music_assets: Dictionary[String, AudioStream] = {}

var sounds: Dictionary = {}
var music: Dictionary = {}
var music_player: AudioStreamPlayer
var music_kind := ""
var music_fade: Tween
var active_effects: Dictionary = {}
var active_count := 0

func _ready() -> void:
	for bus in [EFFECTS_BUS, MUSIC_BUS]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	music_player = AudioStreamPlayer.new()
	music_player.name = "Music"
	music_player.bus = MUSIC_BUS
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music_player)
	sounds["sword"] = _tone(530.0, 260.0, 0.09, 0.25)
	sounds["magic"] = _tone(440.0, 800.0, 0.16, 0.24)
	sounds["enemy_magic"] = _tone(280.0, 180.0, 0.12, 0.20)
	sounds["enemy_chant"] = _tone(330.0, 520.0, 0.26, 0.15)
	sounds["enemy_arrow"] = _tone(760.0, 250.0, 0.09, 0.19)
	sounds["hit"] = _tone(170.0, 85.0, 0.07, 0.25)
	sounds["hurt"] = _tone(150.0, 70.0, 0.20, 0.28)
	sounds["death"] = _tone(300.0, 90.0, 0.19, 0.22)
	sounds["pickup"] = _tone(370.0, 650.0, 0.13, 0.16)
	sounds["craft"] = _tone(310.0, 530.0, 0.23, 0.17)
	sounds["potion"] = _tone(430.0, 870.0, 0.24, 0.17)
	sounds["ghost"] = _tone(128.0, 200.0, 1.1, 0.17)

	sounds["enemy_telegraph"] = _tone(360.0, 530.0, 0.18, 0.16)
	sounds["enemy_zone_warning"] = _tone(530.0, 720.0, 0.31, 0.18)
	sounds["enemy_zone_burst"] = _tone(210.0, 67.0, 0.25, 0.25)
	sounds["enemy_ghost"] = _tone(250.0, 670.0, 0.33, 0.15)
	sounds["enemy_rush"] = _tone(490.0, 177.0, 0.11, 0.17)
	sounds["pot_break"] = _tone(230.0, 83.0, 0.17, 0.26)
	sounds["trap_warn"] = _tone(780.0, 630.0, 0.25, 0.18)
	sounds["trap_arrow"] = _tone(930.0, 240.0, 0.10, 0.24)
	sounds["pearl_form"] = _tone(310.0, 780.0, 0.40, 0.17)
	sounds["pearl_pickup"] = _tone(500.0, 920.0, 0.27, 0.18)
	sounds["corrupt"] = _tone(180.0, 420.0, 0.38, 0.22)
	sounds.merge(effect_assets, true)

func set_music(kind: String) -> void:
	if kind == music_kind:
		return
	music_kind = kind
	if DisplayServer.get_name() == "headless":
		return
	if music_fade != null:
		music_fade.kill()
	music_fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if music_player.playing:
		music_fade.tween_property(music_player, "volume_db", -40.0, 0.20)
	music_fade.tween_callback(_play_music.bind(kind))
	if not kind.is_empty():
		music_fade.tween_property(music_player, "volume_db", 0.0, 0.30)

func _play_music(kind: String) -> void:
	music_player.stop()
	if kind.is_empty():
		return
	if not music.has(kind):
		music[kind] = music_assets[kind] if music_assets.has(kind) else RetroScore.render(kind)
	music_player.stream = music[kind]
	music_player.volume_db = -40.0
	music_player.play()

func set_volumes(master: float, effects: float, music_level: float) -> void:
	_set_bus_volume(0, master)
	_set_bus_volume(AudioServer.get_bus_index(EFFECTS_BUS), effects)
	_set_bus_volume(AudioServer.get_bus_index(MUSIC_BUS), music_level)

func _set_bus_volume(index: int, level: float) -> void:
	AudioServer.set_bus_mute(index, is_zero_approx(level))
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level, 0.0001)))

func play(kind: String, preview := false) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not sounds.has(kind) or active_effects.get(kind, 0) >= 2 or active_count >= (14 if kind in DANGER_CUES else 8):
		return
	active_count += 1
	active_effects[kind] = active_effects.get(kind, 0) + 1
	var audio := AudioStreamPlayer.new()
	audio.stream = sounds[kind]
	audio.bus = EFFECTS_BUS
	if preview:
		audio.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(audio)
	audio.finished.connect(func():
		active_count -= 1
		active_effects[kind] -= 1
		audio.queue_free())
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
		var pulse := 1.0 if sin(phase) > 0.43 else -0.42
		var wave := lerpf(sin(phase), pulse, 0.35)
		var sample := int(wave * envelope * volume * 32767.0)
		data.encode_s16(i * 2, sample)
	wav.data = data
	return wav
