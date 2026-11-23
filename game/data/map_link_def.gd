class_name MapLinkDef
extends Resource

## A passage between two zones of a map template.

@export var zone_a: StringName = &""
@export var zone_b: StringName = &""
@export var guard: int = 0
## Wide: 3-4 cells, narrow: 1-2.
@export var wide: bool = false
