class_name SkillDef
extends GameDef

## A hero skill with three levels (basic, advanced, expert).

const LEVELS: int = 3

## Handler id (Ф8).
@export var effect: StringName = &""
## Parameters of each level; exactly LEVELS entries.
@export var level_params: Array[Dictionary] = [{}, {}, {}]
@export var icon: String = ""
