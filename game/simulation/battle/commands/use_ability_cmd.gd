class_name UseAbilityCmd
extends BattleCmd

## Use the active ability `ability_id` of the stack on `target_id` — instead
## of a move or a blow (docs/MECHANICS.md §5). Takes the turn.

var ability_id: StringName = &""
var target_id: int = -1


func _init(stack: int = -1, ability: StringName = &"", target: int = -1) -> void:
	stack_id = stack
	ability_id = ability
	target_id = target
