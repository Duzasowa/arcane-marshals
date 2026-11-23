class_name MapZoneDef
extends Resource

## One zone of a map template (Ф9 extends it). Lives inside MapTemplateDef.

enum Kind { START, NEUTRAL, RESOURCE, JUNCTION }

## Unique inside its template; links refer to it.
@export var id: StringName = &""
@export var kind: Kind = Kind.NEUTRAL
## Player slot 0..; -1 for no owner.
@export var player: int = -1
## Relative size, permille of an average zone.
@export var size_weight: int = 1000
@export var has_town: bool = false
@export var town_guard: int = 0
## Mine resource id -> count.
@export var mines: Dictionary[StringName, int] = {}
@export var treasure_budget: int = 0
## Objects per 100 cells.
@export var density: int = 0
