extends RefCounted

enum Phase { MOVE, WINDUP, STRIKE, RECOVERY, HURT }

const DIRECTIONS := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
const PHASE_NAMES := ["idle", "windup", "strike", "recovery", "hurt"]

var phase := Phase.MOVE
var offset := Vector2.ZERO
var stretch := Vector2.ONE
var tilt := 0.0
var foot_stride := 0.0

var _step_cycle := 0.0
var _breath_cycle := 0.0
var _flip := false
var walk_progress := 0.0
var idle_progress := 0.0

func advance_cycle(delta: float, velocity: Vector2, stride := 60.0) -> bool:
	var speed := velocity.length()
	if speed <= 5.0:
		walk_progress = 0.0
		idle_progress = fposmod(idle_progress + delta * 0.9, 1.0)
		return false
	var next := walk_progress + speed * delta / stride
	var contact := floori(next * 2.0) != floori(walk_progress * 2.0)
	walk_progress = fposmod(next, 1.0)
	return contact

static func direction_name(facing: Vector2) -> String:
	return DIRECTIONS[posmod(roundi(facing.angle() / (TAU / 8.0)), DIRECTIONS.size())]

static func frame_index(progress: float, count: int) -> int:
	return clampi(floori(progress * count), 0, maxi(0, count - 1))

## Transforms affect the supplied art. Collision, aim and telegraphs stay on the actor.
func advance(delta: float, velocity: Vector2, facing: Vector2, next_phase: Phase = Phase.MOVE, progress := 0.0) -> void:
	phase = next_phase
	_breath_cycle = fposmod(_breath_cycle + delta * 3.8, TAU)
	if absf(facing.x) > 0.05:
		_flip = facing.x < 0.0
	var direction := facing.normalized()
	var side := -1.0 if _flip else 1.0
	var fraction := clampf(progress, 0.0, 1.0)
	var breath := sin(_breath_cycle)
	offset = Vector2(0.0, -0.6 * (1.0 + breath))
	stretch = Vector2(1.0 + 0.009 * breath, 1.0 + 0.016 * breath)
	tilt = 0.0
	foot_stride = 0.0
	match phase:
		Phase.MOVE:
			var pace := clampf(velocity.length() / 155.0, 0.0, 1.2)
			if pace > 0.04:
				_step_cycle = fposmod(_step_cycle + delta * (6.5 + 8.5 * pace), TAU)
				foot_stride = sin(_step_cycle) * minf(1.0, pace)
				var lift := absf(foot_stride)
				offset = Vector2(foot_stride * 1.4, -lift * 3.0)
				stretch = Vector2(1.0 - 0.045 * lift, 1.0 + 0.035 * lift)
				tilt = foot_stride * 0.10 + clampf(velocity.x / 185.0, -1.0, 1.0) * 0.055
		Phase.WINDUP:
			var draw_back := smoothstep(0.0, 1.0, fraction)
			offset = -direction * (4.0 * draw_back) + Vector2.DOWN * draw_back
			stretch = Vector2(1.0 + 0.06 * draw_back, 1.0 - 0.10 * draw_back)
			tilt = -side * draw_back * 0.17
		Phase.STRIKE:
			var reach := 1.0 - 0.67 * fraction
			offset = direction * (6.0 * reach) + Vector2.UP * reach
			stretch = Vector2(1.0 + 0.09 * reach, 1.0 - 0.05 * reach)
			tilt = side * reach * 0.19
		Phase.RECOVERY:
			var reset := 1.0 - smoothstep(0.0, 1.0, fraction)
			offset = direction * (1.98 * reset) + Vector2.UP * 0.33 * reset
			stretch = Vector2(1.0 + 0.03 * reset, 1.0 - 0.0165 * reset)
			tilt = side * reset * 0.063
		Phase.HURT:
			var recoil := 1.0 - fraction
			offset = -direction * (5.0 * recoil) + Vector2.UP * (2.0 * recoil)
			stretch = Vector2(1.0 + 0.10 * recoil, 1.0 - 0.13 * recoil)
			tilt = -side * recoil * 0.20

func apply(sprite: Sprite2D, anchor: Vector2, neutral_scale: Vector2) -> void:
	sprite.position = anchor + offset
	sprite.scale = neutral_scale * stretch
	sprite.rotation = tilt
	sprite.flip_h = _flip
