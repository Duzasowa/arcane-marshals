class_name OrderDef
extends GameDef

## A marshal order: spends command points and the hero's turn.

## Command points.
@export var cost: int = 1
@export var target: SpellDef.Target = SpellDef.Target.ALLY
## Handler id (Ф5).
@export var effect: StringName = &""
@export var params: Dictionary = {}
@export var icon: String = ""
