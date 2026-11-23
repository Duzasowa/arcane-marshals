class_name BattleCmd
extends RefCounted

## A decision for the active stack, from the player's UI or from the AI. The
## battle checks it with `BattleState.validate` before `apply` changes anything.

var stack_id: int = -1


func describe() -> String:
	return "%s stack=%d" % [get_script().get_global_name(), stack_id]
