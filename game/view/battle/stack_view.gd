class_name StackView
extends Node3D

## One stack on the 3D field: its model, a ring in the side's colour and its
## animations. Knows only what the events told it (`shown_count`,
## `shown_hp`); `BattleView` drives it and never lets it touch the state.

const SIDE_COLORS: Array[Color] = [Color(0.25, 0.55, 1.0), Color(0.95, 0.3, 0.25)]
const TURN_SPEED: float = 12.0
## Seconds per cell when walking, before the speed setting.
const STEP_TIME: float = 0.22
## Part of the attack animation at which the blow lands.
const IMPACT_AT: float = 0.45

var stack_id: int = -1
var side: int = 0
var size: int = 1
var look: UnitLook = null
var shown_count: int = 0
var shown_hp: int = 0
var max_total_hp: int = 1
var dead: bool = false
## Animation speed multiplier shared by the whole battle view.
var speed: float = 1.0

var _model: Node3D = null
var _player: AnimationPlayer = null
var _ring: MeshInstance3D = null
var _facing: float = 0.0
var _bob_time: float = 0.0


func setup(stack: BattleStack, unit: UnitDef) -> void:
	stack_id = stack.id
	side = stack.side
	size = stack.size
	shown_count = stack.count
	shown_hp = stack.total_hp()
	max_total_hp = maxi(1, stack.initial_count * stack.hp)
	look = UnitLook.of(stack.unit_id)
	name = "Stack%d" % stack.id
	_model = UnitLook.instantiate(unit, look)
	_model.position.y = look.hover
	add_child(_model)
	_player = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for looped: String in [look.idle, look.walk]:
		if _player != null and _player.has_animation(looped):
			_player.get_animation(looped).loop_mode = Animation.LOOP_LINEAR
	_add_ring()
	position = BattleArena.cell_center(stack.cell, stack.size)
	_facing = 90.0 if side == 0 else -90.0
	_model.rotation_degrees.y = _facing
	play_idle()


## The point above the head where the count badge hangs.
func badge_anchor() -> Vector3:
	return global_position + Vector3(0.0, 1.15 * look.scale / UnitLook.DEFAULT_SCALE + look.hover, 0.0)


func play_idle() -> void:
	_play(look.idle)


func set_active(on: bool) -> void:
	if _ring != null:
		var material: StandardMaterial3D = _ring.material_override
		material.emission_energy_multiplier = 2.5 if on else 0.6


## Walks (or flies) through the cell centres of `path`.
func move_along(points: Array[Vector3]) -> void:
	if points.is_empty():
		return
	_play(look.walk)
	for point: Vector3 in points:
		face(point)
		# A flyer's path is one long leg: the time grows with the distance.
		var cells: float = maxf(1.0, position.distance_to(point) / BattleArena.CELL_SIZE)
		var tween: Tween = create_tween()
		tween.tween_property(self, "position", point, STEP_TIME * cells / speed)
		await tween.finished
	play_idle()


## Turns to look at a point on the ground.
func face(point: Vector3) -> void:
	var direction: Vector3 = point - global_position
	if direction.length_squared() < 0.0001:
		return
	_facing = rad_to_deg(atan2(direction.x, direction.z))
	_model.rotation_degrees.y = _facing


## Plays the strike; returns when the blow lands (the rest plays on).
func strike(target: Vector3, ranged: bool) -> void:
	face(target)
	var animation: String = look.shoot if ranged else look.attack
	_play(animation, false)
	await get_tree().create_timer(_length(animation) * IMPACT_AT / speed).timeout
	_queue_idle_after(animation)


func take_hit(damage: int, killed: int) -> void:
	shown_hp = maxi(0, shown_hp - damage)
	shown_count = maxi(0, shown_count - killed)
	if shown_count > 0:
		_play(look.hit, false)
		_queue_idle_after(look.hit)


func heal(amount: int, raised: int) -> void:
	shown_hp += amount
	shown_count += raised


func defend() -> void:
	_play(look.block, false)
	_queue_idle_after(look.block)


func die() -> void:
	dead = true
	shown_count = 0
	shown_hp = 0
	if _ring != null:
		_ring.visible = false
	_play(look.death, false)
	await get_tree().create_timer(_length(look.death) / speed).timeout


func cheer() -> void:
	if not dead:
		_play(look.cheer)


## Puts the view where the state says the stack is (after the events).
func sync(stack: BattleStack) -> void:
	position = BattleArena.cell_center(stack.cell, stack.size)
	shown_count = stack.count
	shown_hp = stack.total_hp()
	if not stack.is_alive() and not dead:
		dead = true
		if _ring != null:
			_ring.visible = false


func _process(delta: float) -> void:
	if look != null and look.hover > 0.0 and not dead:
		_bob_time += delta
		_model.position.y = look.hover + sin(_bob_time * 2.4) * 0.06


func _play(animation: String, restart: bool = true) -> void:
	if _player == null or not _player.has_animation(animation):
		return
	if restart or _player.current_animation != animation:
		_player.play(animation, 0.15, speed)
	else:
		_player.seek(0.0)


func _length(animation: String) -> float:
	if _player == null or not _player.has_animation(animation):
		return 0.4
	return _player.get_animation(animation).length


func _queue_idle_after(animation: String) -> void:
	await get_tree().create_timer(_length(animation) / speed).timeout
	if not dead and _player != null and _player.current_animation == animation:
		play_idle()


func _add_ring() -> void:
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = 0.36 * size
	mesh.outer_radius = 0.44 * size
	mesh.rings = 24
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = SIDE_COLORS[side]
	material.emission_enabled = true
	material.emission = SIDE_COLORS[side]
	material.emission_energy_multiplier = 0.6
	_ring = MeshInstance3D.new()
	_ring.mesh = mesh
	_ring.material_override = material
	_ring.scale = Vector3(1.0, 0.15, 1.0)
	_ring.position.y = 0.03
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
