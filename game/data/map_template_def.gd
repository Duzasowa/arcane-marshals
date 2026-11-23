class_name MapTemplateDef
extends GameDef

## A graph of zones the map generator (Ф9) turns into a map.

@export var zones: Array[MapZoneDef] = []
@export var links: Array[MapLinkDef] = []
@export var players_min: int = 2
@export var players_max: int = 2
## Side of the square map in tiles.
@export var size: int = 36
