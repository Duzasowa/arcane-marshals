class_name BuildingDef
extends GameDef

## A town building.

enum Effect { NONE, INCOME, DWELLING, FORT, MAGE_GUILD, MARKET, TAVERN, SPECIAL }

## Empty: a building every faction has.
@export var faction: StringName = &""
@export var cost: Dictionary[StringName, int] = {}
## Building ids that must stand first.
@export var requires: Array[StringName] = []
@export var effect: Effect = Effect.NONE
@export var params: Dictionary = {}
## The unit hired here; required for a DWELLING.
@export var dwelling_unit: StringName = &""
