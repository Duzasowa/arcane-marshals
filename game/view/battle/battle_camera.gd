class_name BattleCamera
extends Node3D

## A camera on a rig over the battlefield: tilted down, slight zoom with the
## wheel, a few turns left / right (Q / E or the arrow keys). Smooth.

const PITCH_DEGREES: float = -52.0
const DISTANCE_MIN: float = 9.0
const DISTANCE_MAX: float = 17.0
const DISTANCE_STEP: float = 1.0
const YAW_STEP_DEGREES: float = 15.0
const YAW_LIMIT_DEGREES: float = 45.0
const SMOOTHING: float = 8.0

var camera: Camera3D = null
var _distance: float = 14.0
var _target_distance: float = 14.0
var _yaw: float = 0.0
var _target_yaw: float = 0.0


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 45.0
	add_child(camera)
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var button: InputEventMouseButton = event
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(-DISTANCE_STEP)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(DISTANCE_STEP)
	elif event is InputEventKey and event.pressed and not event.echo:
		var key: InputEventKey = event
		if key.keycode == KEY_Q or key.keycode == KEY_LEFT:
			turn(-YAW_STEP_DEGREES)
		elif key.keycode == KEY_E or key.keycode == KEY_RIGHT:
			turn(YAW_STEP_DEGREES)


func zoom(delta_distance: float) -> void:
	_target_distance = clampf(_target_distance + delta_distance, DISTANCE_MIN, DISTANCE_MAX)


func turn(delta_degrees: float) -> void:
	_target_yaw = clampf(_target_yaw + delta_degrees, -YAW_LIMIT_DEGREES, YAW_LIMIT_DEGREES)


func _process(delta: float) -> void:
	var weight: float = clampf(delta * SMOOTHING, 0.0, 1.0)
	_distance = lerpf(_distance, _target_distance, weight)
	_yaw = lerpf(_yaw, _target_yaw, weight)
	_apply()


func _apply() -> void:
	rotation_degrees = Vector3(0.0, _yaw, 0.0)
	var pitch: float = deg_to_rad(PITCH_DEGREES)
	camera.position = Vector3(0.0, -sin(pitch) * _distance, cos(pitch) * _distance)
	camera.rotation = Vector3(pitch, 0.0, 0.0)


## The point on the ground under the screen position, or null.
func ground_point(screen_position: Vector2) -> Variant:
	var origin: Vector3 = camera.project_ray_origin(screen_position)
	var direction: Vector3 = camera.project_ray_normal(screen_position)
	return Plane(Vector3.UP, 0.0).intersects_ray(origin, direction)
