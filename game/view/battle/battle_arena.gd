class_name BattleArena
extends Node3D

## The 3D battlefield: ground, the cell grid, obstacles, cell highlights,
## light and sky. One cell is one metre; the field is centred on the origin,
## cell (0, 0) at the far left from the attacker's view.
## Reads the grid once in `build`; never changes the battle.

const CELL_SIZE: float = 1.0
const MARGIN: float = 3.0
const HIGHLIGHT_HEIGHT: float = 0.02
const GRID_SHADER: Shader = preload("res://game/view/battle/grid_overlay.gdshader")

enum Highlight { NONE, REACHABLE, TARGET, SPOT, ACTIVE, HOVER, PATH }

const HIGHLIGHT_COLORS: Dictionary[Highlight, Color] = {
	Highlight.REACHABLE: Color(0.35, 0.6, 1.0, 0.28),
	Highlight.TARGET: Color(1.0, 0.25, 0.2, 0.42),
	Highlight.SPOT: Color(1.0, 0.85, 0.25, 0.5),
	Highlight.ACTIVE: Color(0.35, 1.0, 0.45, 0.4),
	Highlight.HOVER: Color(1.0, 1.0, 1.0, 0.25),
	Highlight.PATH: Color(0.55, 0.8, 1.0, 0.45),
}

var _grid_overlay: MeshInstance3D = null
var _highlights: Array[MeshInstance3D] = []
var _highlight_materials: Dictionary[Highlight, StandardMaterial3D] = {}


## The centre of a stack of `size` standing at `anchor`, on the ground.
static func cell_center(anchor: Vector2i, size: int = 1) -> Vector3:
	var half: float = size * CELL_SIZE * 0.5
	return Vector3(anchor.x * CELL_SIZE + half - BattleGrid.WIDTH * CELL_SIZE * 0.5, 0.0,
			anchor.y * CELL_SIZE + half - BattleGrid.HEIGHT * CELL_SIZE * 0.5)


## The cell under a point on the ground (may be outside the field).
static func world_to_cell(point: Vector3) -> Vector2i:
	return Vector2i(floori((point.x + BattleGrid.WIDTH * CELL_SIZE * 0.5) / CELL_SIZE),
			floori((point.z + BattleGrid.HEIGHT * CELL_SIZE * 0.5) / CELL_SIZE))


func build(grid: BattleGrid) -> void:
	for child: Node in get_children():
		child.queue_free()
	_highlights.clear()
	_add_environment()
	_add_ground()
	_add_grid_overlay()
	_add_highlights()
	_add_obstacles(grid)


func set_grid_visible(on: bool) -> void:
	if _grid_overlay != null:
		_grid_overlay.visible = on


func is_grid_visible() -> bool:
	return _grid_overlay != null and _grid_overlay.visible


func clear_highlights() -> void:
	for quad: MeshInstance3D in _highlights:
		quad.visible = false


func highlight(cell: Vector2i, kind: Highlight, size: int = 1) -> void:
	for covered: Vector2i in BattleGrid.cells_of(cell, size):
		if not BattleGrid.in_bounds(covered):
			continue
		var quad: MeshInstance3D = _highlights[BattleGrid.index(covered)]
		quad.visible = kind != Highlight.NONE
		if kind != Highlight.NONE:
			quad.material_override = _highlight_materials[kind]


func _add_environment() -> void:
	var environment: Environment = Environment.new()
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.38, 0.55, 0.78)
	sky_material.sky_horizon_color = Color(0.72, 0.78, 0.82)
	sky_material.ground_horizon_color = Color(0.45, 0.48, 0.4)
	sky_material.ground_bottom_color = Color(0.22, 0.24, 0.18)
	var sky: Sky = Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ssao_enabled = true
	var world: WorldEnvironment = WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = environment
	add_child(world)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_energy = 1.5
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	add_child(sun)


func _add_ground() -> void:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(BattleGrid.WIDTH * CELL_SIZE + MARGIN * 2.0, BattleGrid.HEIGHT * CELL_SIZE + MARGIN * 2.0)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.36, 0.16)
	material.roughness = 0.95
	plane.material = material
	var ground: MeshInstance3D = MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = plane
	add_child(ground)
	# A slightly darker field inside the margin, so the edge of the battle is visible.
	var field_plane: PlaneMesh = PlaneMesh.new()
	field_plane.size = Vector2(BattleGrid.WIDTH * CELL_SIZE, BattleGrid.HEIGHT * CELL_SIZE)
	var field_material: StandardMaterial3D = StandardMaterial3D.new()
	field_material.albedo_color = Color(0.31, 0.43, 0.19)
	field_material.roughness = 0.9
	field_plane.material = field_material
	var field: MeshInstance3D = MeshInstance3D.new()
	field.name = "Field"
	field.mesh = field_plane
	field.position.y = 0.005
	add_child(field)


func _add_grid_overlay() -> void:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(BattleGrid.WIDTH * CELL_SIZE, BattleGrid.HEIGHT * CELL_SIZE)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = GRID_SHADER
	material.set_shader_parameter(&"cells", Vector2(BattleGrid.WIDTH, BattleGrid.HEIGHT))
	plane.material = material
	_grid_overlay = MeshInstance3D.new()
	_grid_overlay.name = "GridOverlay"
	_grid_overlay.mesh = plane
	_grid_overlay.position.y = HIGHLIGHT_HEIGHT * 0.5
	_grid_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_grid_overlay)


func _add_highlights() -> void:
	for kind: Highlight in HIGHLIGHT_COLORS:
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = HIGHLIGHT_COLORS[kind]
		_highlight_materials[kind] = material
	var quad_mesh: PlaneMesh = PlaneMesh.new()
	quad_mesh.size = Vector2(CELL_SIZE * 0.92, CELL_SIZE * 0.92)
	var holder: Node3D = Node3D.new()
	holder.name = "Highlights"
	add_child(holder)
	for cell_index: int in BattleGrid.CELL_COUNT:
		var quad: MeshInstance3D = MeshInstance3D.new()
		quad.mesh = quad_mesh
		quad.position = cell_center(BattleGrid.cell_at(cell_index)) + Vector3(0.0, HIGHLIGHT_HEIGHT, 0.0)
		quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		quad.visible = false
		holder.add_child(quad)
		_highlights.append(quad)


## A low-poly rock per obstacle cell; size and turn come from the cell index,
## so the same field always looks the same.
func _add_obstacles(grid: BattleGrid) -> void:
	var holder: Node3D = Node3D.new()
	holder.name = "Obstacles"
	add_child(holder)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.42, 0.4, 0.37)
	material.roughness = 1.0
	for cell_index: int in BattleGrid.CELL_COUNT:
		if grid.blocked[cell_index] == 0:
			continue
		var shape: SphereMesh = SphereMesh.new()
		shape.radial_segments = 7
		shape.rings = 4
		shape.radius = 0.5
		shape.height = 0.8
		shape.material = material
		var rock: MeshInstance3D = MeshInstance3D.new()
		rock.mesh = shape
		var wobble: int = (cell_index * 7919) % 100
		rock.position = cell_center(BattleGrid.cell_at(cell_index)) + Vector3(0.0, 0.25, 0.0)
		rock.rotation.y = wobble * 0.0628
		rock.scale = Vector3(0.9 + wobble * 0.002, 0.8 + (wobble % 37) * 0.012, 0.85 + (wobble % 23) * 0.006)
		holder.add_child(rock)
