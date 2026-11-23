class_name SpellDef
extends GameDef

## A spell of a school. base/per_power are indexed by the school mastery 0..3.

enum Target { ENEMY, ALLY, CELL, ALL }
enum Effect { DAMAGE, STATUS, SUMMON }
## BY_POWER: 1 + spell power / 4 unit turns; FIXED: `duration` turns.
enum Duration { NONE, BY_POWER, FIXED }

const MASTERY_LEVELS: int = 4

@export var school: StringName = &""
@export_range(1, 3) var level: int = 1
@export var mana_cost: int = 0
@export var target: Target = Target.ENEMY
## Radius in cells around the target cell; 0 hits one stack.
@export var area: int = 0
@export var base: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
@export var per_power: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
@export var effect: Effect = Effect.DAMAGE
@export var duration_rule: Duration = Duration.NONE
@export var duration: int = 0
## A script extending `SpellHook`: whom the spell may target and what it does.
@export var handler: Script = null
@export var params: Dictionary = {}
@export var icon: String = ""
@export var vfx: String = ""
