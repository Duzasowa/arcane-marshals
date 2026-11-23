class_name UnitLook
extends RefCounted

## How a unit looks on the battlefield: which parts of its model are hidden
## (the KayKit characters carry every weapon of their class), which animations
## it plays, its scale and how high a flyer hovers. The model file itself is
## `UnitDef.model`. Units without an entry get the defaults.

const DEFAULT_SCALE: float = 0.5

## unit id -> overrides of the fields below.
const LOOKS: Dictionary[StringName, Dictionary] = {
	&"throne_militia": {
		&"hide": ["1H_Axe_Offhand", "2H_Axe", "Mug"],
		&"attack": "1H_Melee_Attack_Chop",
	},
	&"throne_crossbowman": {
		&"hide": ["Knife_Offhand", "1H_Crossbow", "Knife", "Throwable"],
		&"idle": "2H_Ranged_Aiming",
		&"attack": "Unarmed_Melee_Attack_Punch_A",
		&"shoot": "2H_Ranged_Shoot",
	},
	&"throne_outrider": {
		&"hide": ["1H_Sword_Offhand", "Rectangle_Shield", "Round_Shield", "Spike_Shield", "2H_Sword"],
		&"walk": "Running_A",
		&"attack": "1H_Melee_Attack_Slice_Diagonal",
		&"scale": 0.56,
	},
	&"coven_sporeling": {
		&"walk": "Walking_D_Skeletons",
		&"attack": "Unarmed_Melee_Attack_Punch_A",
		&"scale": 0.44,
	},
	&"coven_lizard_thrower": {
		&"attack": "Unarmed_Melee_Attack_Kick",
		&"shoot": "Throw",
	},
	&"coven_dragonfly": {
		&"walk": "Idle_B",
		&"attack": "Unarmed_Melee_Attack_Punch_B",
		&"hover": 0.45,
	},
}

var hide: Array[String] = []
var idle: String = "Idle"
var walk: String = "Walking_A"
var attack: String = "1H_Melee_Attack_Chop"
var shoot: String = "1H_Ranged_Shoot"
var hit: String = "Hit_A"
var block: String = "Block"
var death: String = "Death_A"
var cheer: String = "Cheer"
var scale: float = DEFAULT_SCALE
## Height a flyer floats at, metres.
var hover: float = 0.0


static func of(unit_id: StringName) -> UnitLook:
	var look: UnitLook = UnitLook.new()
	var overrides: Dictionary = LOOKS.get(unit_id, {})
	for key: StringName in overrides:
		if key == &"hide":
			look.hide.assign(overrides[key])
		else:
			look.set(key, overrides[key])
	return look


## The unit's model with its look applied, or a plain capsule when the unit has
## no model (or it cannot be loaded).
static func instantiate(unit: UnitDef, look: UnitLook) -> Node3D:
	var scene: PackedScene = null
	if unit != null and not unit.model.is_empty() and ResourceLoader.exists(unit.model):
		scene = load(unit.model)
	if scene == null:
		return _capsule()
	var model: Node3D = scene.instantiate()
	for part: String in look.hide:
		var node: Node = model.find_child(part, true, false)
		if node is Node3D:
			(node as Node3D).visible = false
	model.scale = Vector3.ONE * look.scale
	return model


static func _capsule() -> Node3D:
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = 0.25
	mesh.height = 0.9
	var capsule: MeshInstance3D = MeshInstance3D.new()
	capsule.mesh = mesh
	capsule.position.y = 0.45
	var holder: Node3D = Node3D.new()
	holder.add_child(capsule)
	return holder
