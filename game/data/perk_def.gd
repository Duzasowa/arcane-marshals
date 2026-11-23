class_name PerkDef
extends GameDef

## A perk of a skill, open from a skill level.

@export var skill: StringName = &""
@export_range(1, 3) var required_level: int = 1
## Handler id (Ф8).
@export var effect: StringName = &""
@export var params: Dictionary = {}
@export var icon: String = ""
