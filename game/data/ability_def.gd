class_name AbilityDef
extends GameDef

## A creature ability: a handler script with hooks and its parameters
## (docs/MECHANICS.md §5). The battle copies `params` into each stack.

## A script extending `AbilityHook`; null — a passive mark other code checks
## with `BattleStack.has_ability`.
@export var handler: Script = null
@export var params: Dictionary = {}
## Extra unit power, permille (PowerEstimator).
@export var ai_weight: int = 0
@export var icon: String = ""
