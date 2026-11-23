class_name HeroDef
extends GameDef

## A named hero.

@export var hero_class: StringName = &""
@export var portrait: String = ""
## Specialization id (Ф8).
@export var specialization: StringName = &""
## Unit id -> count.
@export var starting_army: Dictionary[StringName, int] = {}
@export var starting_spells: Array[StringName] = []
