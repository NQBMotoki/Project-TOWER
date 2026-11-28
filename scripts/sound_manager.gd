extends Node

const ROOT := "res://assets/audio/"
const MUSIC_BUS := &"Music"
const EFFECTS_BUS := &"Effects"
const ROOM_BUS := &"TowerFoley"
const AMBIENCE_BUS := &"TowerAmbience"
const PRIORITY_BUS := &"TowerWarnings"
const LAYERS := ["bed", "theme", "pulse", "color"]
const LAYERED_SCORES := ["tower", "elite", "rift", "lord"]
const BOSS_SCORES := ["elite", "lord"]
const ELITE_ENTRANCE_BEAT := 60.0 / 108.0
const DANGER := [
	"trap_warn", "trap_arrow", "hurt", "enemy_telegraph", "enemy_chant", "enemy_zone_warning",
	"slime_coil", "goblin_windup", "skeleton_chant", "archer_draw", "ghost_manifest",
	"elite_entrance", "elite_phase", "lord_phase", "lord_final_phase",
]
const SCORE_DUCK := {
	"trap_warn": .62, "elite_entrance": .70, "elite_phase": .52, "lord_phase": .52,
	"lord_final_phase": .65, "corruption_enter": .33, "crystal_touch": .56,
}
const LEVEL_DB := {
	"footstep": -15.0, "footstep_grass": -15.0, "sword": -8.0, "magic": -8.0,
	"trap_warn": -1.5, "trap_arrow": -4.0, "arrow_impact": -9.0, "hurt": -5.0,
	"book_open": -12.0, "book_page": -12.0, "book_close": -12.0, "ui_focus": -15.0,
	"ui_confirm": -12.0, "ui_open": -12.0, "ui_close": -12.0, "gate_open": -10.0,
	"pearl_form": -8.0, "room_drip": -12.0, "room_chain": -14.0, "room_rift": -14.0,
	"room_gust": -12.0, "goblin_step": -18.0, "skeleton_step": -18.0, "archer_step": -18.0,
	"ghost_drift": -18.0, "crystal_touch": -5.0, "crystal_rumble": -5.5, "sky_darkening": -9.0,
	"magic_enhance": -10.0, "corruption_confirm": -10.0,
}
@export var effect_assets: Dictionary[String, AudioStream] = {}
@export var music_assets: Dictionary[String, AudioStream] = {}

var music_player: AudioStreamPlayer
var music_kind := ""
var _active_score := ""
var _score_floor := 0
var _boss_stage := 1
var _target_boss_stage := 1
var _boss_stage_due := -1.0
var _layers: AudioStreamSynchronized
var _transition: Tween
var _transition_gain := -60.0
var _elite_entrance_rest := 0.0
var _combat := false
var _quiet := false
var _paused := false
var _duck := 0.0
var _cue_paths := {}
var _sounds := {}
var _missing_streams := {}
var _voices: Array[Node] = []
var _room: Node
var _floor := -1
var _target: Node2D
var _ears: AudioListener2D
var _room_ticks := 0.0
var _altar_active := false
var _altar_near := false
var _altar_cooldown := 0.0
var _cadence_due := -1.0
var _cadence_played := false
var _random := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_random.randomize()
	_ensure_bus(EFFECTS_BUS, &"Master")
	_ensure_bus(MUSIC_BUS, &"Master")
	_ensure_bus(ROOM_BUS, EFFECTS_BUS)
	_ensure_bus(AMBIENCE_BUS, EFFECTS_BUS)
	_ensure_bus(PRIORITY_BUS, EFFECTS_BUS)
	var room_index := AudioServer.get_bus_index(ROOM_BUS)
	if AudioServer.get_bus_effect_count(room_index) == 0:
		var stone := AudioEffectReverb.new()
		stone.room_size = 0.48
		stone.damping = 0.74
		stone.wet = 0.10
		stone.dry = 0.96
		AudioServer.add_bus_effect(room_index, stone)
	var limited := false
	for index in AudioServer.get_bus_effect_count(0):
		limited = limited or AudioServer.get_bus_effect(0, index) is AudioEffectHardLimiter
	if not limited:
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -1.2
		AudioServer.add_bus_effect(0, limiter)
	music_player = AudioStreamPlayer.new()
	music_player.name = "Music"
	music_player.bus = MUSIC_BUS
	add_child(music_player)
	for file in ResourceLoader.list_directory(ROOT + "foley"):
		if file.ends_with(".wav"):
			var key := file.get_basename().rsplit("_", true, 1)[0]
			if not _cue_paths.has(key):
				_cue_paths[key] = []
			_cue_paths[key].append(ROOT + "foley/" + file)

func _ensure_bus(bus_name: StringName, destination: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, destination)

func set_volumes(master: float, effects: float, music_level: float) -> void:
	_set_bus_volume(0, master)
	_set_bus_volume(AudioServer.get_bus_index(EFFECTS_BUS), effects)
	_set_bus_volume(AudioServer.get_bus_index(MUSIC_BUS), music_level)

func _set_bus_volume(index: int, level: float) -> void:
	AudioServer.set_bus_mute(index, is_zero_approx(level))
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level, 0.0001)))

func set_paused(paused: bool) -> void:
	_paused = paused

func set_combat(active: bool) -> void:
	_combat = active
	_quiet = false

func set_quiet() -> void:
	_quiet = true
	_combat = false

func _read_ogg(folder: String, key: String) -> AudioStreamOggVorbis:
	var path := ROOT + folder + "/" + key + ".ogg"
	if _missing_streams.has(path):
		return null
	if ResourceLoader.exists(path):
		var stream := load(path) as AudioStreamOggVorbis
		if stream:
			return stream
	_missing_streams[path] = true
	push_warning("Cannot load tower audio: " + path)
	return null

func set_music(kind: String) -> void:
	if kind == music_kind:
		return
	music_kind = kind
	if kind != "elite" and _active_score != "elite":
		_elite_entrance_rest = 0.0
	_quiet = false
	_boss_stage = 1
	_target_boss_stage = 1
	_boss_stage_due = -1.0
	if _transition:
		_transition.kill()
	_transition = create_tween()
	if kind == _active_score and music_player.playing:
		_transition.tween_property(self, "_transition_gain", 0.0, .30)
		return
	if music_player.playing:
		var on_beat := _time_to_score_boundary(1)
		var fade := minf(.28, on_beat) if on_beat > .04 else .23
		if on_beat > fade:
			_transition.tween_interval(on_beat - fade)
		_transition.tween_property(self, "_transition_gain", -56.0, fade)
	_transition.tween_callback(_start_score.bind(kind))
	if not kind.is_empty():
		_transition.tween_property(self, "_transition_gain", 0.0, .72)

func set_floor_music(floor_number: int) -> void:
	_score_floor = floor_number
	match floor_number:
		1, 2, 3, 4:
			set_music("tower")
		5:
			set_music("elite")
		6, 7, 8, 9:
			set_music("rift")
		10:
			set_music("lord")
		_:
			set_music("grounds" if floor_number <= 0 else "rift")

func set_boss_stage(stage: int) -> void:
	if music_kind not in BOSS_SCORES:
		return
	var next := clampi(stage, 1, 2 if music_kind == "elite" else 3)
	if next == _target_boss_stage:
		return
	_target_boss_stage = next
	_boss_stage_due = _time_to_score_boundary(4) if _active_score == music_kind else 0.0

func _time_to_score_boundary(beats: int) -> float:
	var stream := _layers.get_sync_stream(0) as AudioStreamOggVorbis if _layers else music_player.stream as AudioStreamOggVorbis
	if not music_player.playing or not stream or stream.bpm <= 0.0:
		return 0.0
	return fposmod(-music_player.get_playback_position(), beats * 60.0 / stream.bpm)

func _start_score(kind: String) -> void:
	music_player.stop()
	music_player.stream = null
	_active_score = kind
	if kind != "elite":
		_elite_entrance_rest = 0.0
	_layers = null
	if kind.is_empty():
		return
	_transition_gain = -62.0
	if music_assets.has(kind):
		music_player.stream = music_assets[kind]
	elif kind in LAYERED_SCORES:
		_layers = AudioStreamSynchronized.new()
		_layers.stream_count = LAYERS.size()
		for i in LAYERS.size():
			_layers.set_sync_stream(i, _read_ogg("music", kind + "_" + LAYERS[i]))
			_layers.set_sync_stream_volume(i, _layer_db(i))
		music_player.stream = _layers
	else:
		music_player.stream = _read_ogg("music", kind)
	if music_player.stream == null:
		return
	music_player.volume_db = -80.0 if _elite_entrance_rest > 0.0 else -70.0
	music_player.play()

func _layer_db(index: int) -> float:
	var stage_gain := 0.0
	if _active_score in BOSS_SCORES and _combat:
		stage_gain = float(_boss_stage - 1)
	match index:
		0: return -2.0 if _combat else -6.0
		1: return -1.0 if _combat else -8.0
		2: return -3.0 + 1.5 * stage_gain if _combat else -80.0
	var color_db := -20.0 + 2.0 * clampf(maxi(_score_floor, _floor) - 1, 0, 9)
	if _active_score in BOSS_SCORES:
		color_db = -17.0 + 7.0 * stage_gain
	return color_db if _combat else color_db - 8.0

func play_cadence() -> void:
	if _cadence_played or _floor <= 0:
		return
	_cadence_played = true
	# Carry the kill into the next pulse; the answer finishes over the room's air.
	_cadence_due = _time_to_score_boundary(1)

func set_altar_active(active: bool) -> void:
	if active == _altar_active:
		return
	_altar_active = active
	_altar_near = active and is_instance_valid(_target) and _target.global_position.distance_to(ArenaLayout.ALTAR_POSITION) < 148.0

func clear_environment() -> void:
	_floor = -1
	_target = null
	_altar_active = false
	_altar_near = false
	_altar_cooldown = 0.0
	_cadence_due = -1.0
	_cadence_played = false
	if is_instance_valid(_ears):
		_ears.clear_current()
		_ears.queue_free()
	_ears = null
	if is_instance_valid(_room):
		for source in _room.get_children():
			_fade_source(source, -78.0, .25)
		var previous := _room
		var release := create_tween()
		release.tween_interval(.28)
		release.tween_callback(previous.queue_free)
	_room = null
	for voice in _voices.duplicate():
		if is_instance_valid(voice) and voice is AudioStreamPlayer2D:
			_fade_source(voice, -78.0, .10)
			get_tree().create_timer(.12).timeout.connect(voice.queue_free)

func set_environment(floor_number: int, listener: Node2D, fire_positions: Array) -> void:
	clear_environment()
	_floor = floor_number
	_target = listener
	_quiet = false
	if not is_instance_valid(listener):
		return
	_ears = AudioListener2D.new()
	listener.add_child(_ears)
	_ears.make_current()
	_room = Node.new()
	_room.name = "RoomAudio"
	add_child(_room)
	var region := "camp"
	if _floor == 10:
		region = "crown"
	elif _floor >= 6:
		region = "rift"
	elif _floor >= 4:
		region = "garrison"
	elif _floor > 0:
		region = "shaft"
	var stone: AudioEffectReverb = AudioServer.get_bus_effect(AudioServer.get_bus_index(ROOM_BUS), 0)
	stone.room_size = 0.22 if _floor == 0 else minf(0.88, 0.46 + _floor*.038)
	stone.wet = 0.025 if _floor == 0 else 0.08 + _floor*.009
	_add_ambience(region, Vector2.INF, -12.5, 0.0)
	for point in fire_positions:
		_add_ambience("fire", point, 1.0 if _floor == 0 else -2.0, 248.0)
	if _floor > 0:
		_add_ambience("stair_air", ArenaLayout.STAIRS_POSITION, -5.0, 310.0)
	_room_ticks = _random.randf_range(5.0, 10.0)

func _fade_source(source: Node, level: float, seconds: float) -> void:
	if source.has_meta("volume_fade"):
		var former: Tween = source.get_meta("volume_fade")
		former.kill()
	var tween := source.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	source.set_meta("volume_fade", tween)
	tween.tween_property(source, "volume_db", level, seconds)

func _add_ambience(key: String, where: Vector2, gain: float, reach: float) -> void:
	var stream := _read_ogg("ambience", key)
	if stream == null:
		return
	var source = AudioStreamPlayer.new() if where == Vector2.INF else AudioStreamPlayer2D.new()
	source.stream = stream
	source.bus = AMBIENCE_BUS
	source.volume_db = -68
	_room.add_child(source)
	if source is AudioStreamPlayer2D:
		source.global_position = where
		source.max_distance = reach
		source.attenuation = 1.3
		source.panning_strength = 3.0
	source.play(_random.randf_range(0, stream.get_length()*.88))
	_fade_source(source, gain, .78)

func _effect(kind: String) -> AudioStream:
	if effect_assets.has(kind):
		return effect_assets[kind]
	if not _sounds.has(kind) and _cue_paths.has(kind):
		var takes := AudioStreamRandomizer.new()
		takes.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
		for path in _cue_paths[kind]:
			takes.add_stream(takes.streams_count, load(path))
		_sounds[kind] = takes
	return _sounds.get(kind)

func play(kind: String, preview := false) -> void:
	_play_effect(kind, Vector2.INF, preview)

func play_at(kind: String, where: Vector2) -> void:
	_play_effect(kind, where, false)

func _play_effect(kind: String, where: Vector2, preview: bool) -> void:
	if kind == "footstep" and _floor == 0:
		kind = "footstep_grass"
	var danger := kind in DANGER or kind.ends_with("_warn")
	var matching := 0
	for active in _voices:
		if active.get_meta("cue") == kind and not active.is_queued_for_deletion():
			matching += 1
	if matching >= (3 if danger else 2):
		return
	if kind != "trap_warn" and _voices.size() >= (24 if danger else 15):
		return
	var clip := _effect(kind)
	if not clip:
		return
	var source = AudioStreamPlayer.new() if where == Vector2.INF else AudioStreamPlayer2D.new()
	source.stream = clip
	source.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	source.process_mode = Node.PROCESS_MODE_ALWAYS if preview else Node.PROCESS_MODE_PAUSABLE
	source.bus = PRIORITY_BUS if danger else (EFFECTS_BUS if preview else ROOM_BUS)
	source.volume_db = LEVEL_DB.get(kind, -7.5)
	source.set_meta("cue", kind)
	add_child(source)
	if source is AudioStreamPlayer2D:
		source.global_position = where
		source.max_distance = 1800.0 if danger else 1200.0
		source.attenuation = 0.72 if danger else 1.25
		source.panning_strength = 1.7 if danger else 1.35
	_voices.append(source)
	source.finished.connect(source.queue_free)
	source.tree_exiting.connect(_voices.erase.bind(source), CONNECT_ONE_SHOT)
	if kind == "elite_entrance" and music_kind == "elite":
		# Leave a beat for the armor while the four score layers stay in sync.
		_elite_entrance_rest = ELITE_ENTRANCE_BEAT
		music_player.volume_db = -80.0
	source.play()
	_duck = maxf(_duck, float(SCORE_DUCK.get(kind, .30 if danger else 0.0)))

func _atmospheric_event() -> void:
	var event := "room_gust"
	match _floor:
		1, 2, 3: event = "room_drip"
		4, 5: event = "room_chain"
		6, 7, 8, 9: event = "room_rift"
		10: event = "room_chain" if _random.randf() < .42 else "room_gust"
	var anchor: Vector2 = ArenaLayout.SPAWN_POINTS[_random.randi_range(0, ArenaLayout.SPAWN_POINTS.size()-1)]
	play_at(event, anchor)
	_room_ticks = _random.randf_range(8.0, 19.0)

func _process(delta: float) -> void:
	var step := 1.0 - exp(-delta*5.0)
	_duck = maxf(0, _duck - delta)
	var warning_gain := clampf(_duck/.18, 0, 1)
	var top: float = _transition_gain - 2.0 - (7.0 if _paused else 0.0) - 5.5*warning_gain
	if _quiet and _cadence_due < 0.0:
		top = -80.0
	var score_step := 1.0 if _transition and _transition.is_running() else step
	if _quiet:
		score_step = 1.0 - exp(-delta * 1.8)
	if _elite_entrance_rest > 0.0:
		_elite_entrance_rest = maxf(0.0, _elite_entrance_rest - delta)
		music_player.volume_db = -80.0 if _elite_entrance_rest > 0.0 else top
	else:
		music_player.volume_db = lerpf(music_player.volume_db, top, score_step)
	if _boss_stage_due >= 0.0:
		_boss_stage_due -= delta
		if _boss_stage_due <= 0.0:
			_boss_stage_due = -1.0
			_boss_stage = _target_boss_stage
	if _layers:
		for index in LAYERS.size():
			_layers.set_sync_stream_volume(index, lerpf(_layers.get_sync_stream_volume(index), _layer_db(index), step))
	var amb := AudioServer.get_bus_index(AMBIENCE_BUS)
	AudioServer.set_bus_volume_db(amb, lerpf(AudioServer.get_bus_volume_db(amb), (-5.0 if _paused else 0.0) - 3.0*warning_gain, step))
	var foley := AudioServer.get_bus_index(ROOM_BUS)
	AudioServer.set_bus_volume_db(foley, lerpf(AudioServer.get_bus_volume_db(foley), -4.0*warning_gain, step))
	if _paused or not is_instance_valid(_target) or not is_instance_valid(_room):
		return
	if _cadence_due >= 0:
		_cadence_due -= delta
		if _cadence_due <= 0:
			_cadence_due = -1.0
			_play_phrase("cadence", Vector2.INF, -3.0)
	_room_ticks -= delta
	if _room_ticks <= 0:
		_atmospheric_event()
	_altar_cooldown = maxf(0, _altar_cooldown-delta)
	if _altar_active:
		var distance := _target.global_position.distance_to(ArenaLayout.ALTAR_POSITION)
		if distance < 148.0 and not _altar_near and _altar_cooldown <= 0.0:
			_altar_near = true
			_altar_cooldown = 14.0
			_play_phrase("altar", ArenaLayout.ALTAR_POSITION, -9.0)
		elif distance > 210.0:
			_altar_near = false

func _play_phrase(kind: String, where: Vector2, gain: float) -> void:
	var stream := _read_ogg("music", kind)
	if stream == null:
		return
	var source = AudioStreamPlayer.new() if where == Vector2.INF else AudioStreamPlayer2D.new()
	source.stream = stream
	source.bus = MUSIC_BUS if where == Vector2.INF else AMBIENCE_BUS
	source.volume_db = gain
	_room.add_child(source)
	if source is AudioStreamPlayer2D:
		source.global_position = where
		source.max_distance = 385.0
		source.panning_strength = 3.0
	source.finished.connect(source.queue_free)
	source.play()
