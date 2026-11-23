class_name MapObjectDef
extends GameDef

## An adventure map object type.

enum Visit { ONCE, WEEKLY, CAPTURE }

## Occupied cells relative to the object origin.
@export var footprint: Array[Vector2i] = [Vector2i.ZERO]
## The cell a hero visits from, relative to the origin.
@export var entry: Vector2i = Vector2i.ZERO
@export var visit_rule: Visit = Visit.ONCE
## Resource or bonus id -> amount.
@export var reward: Dictionary[StringName, int] = {}
## Strength of the guard the generator places (Ф9).
@export var guard_value: int = 0
## Treasure value for the generator budget (Ф9).
@export var value: int = 0
@export var model: String = ""
