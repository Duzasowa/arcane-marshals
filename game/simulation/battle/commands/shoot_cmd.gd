class_name ShootCmd
extends BattleCmd

## Shoot `target_id` from where the stack stands.

var target_id: int = -1


func _init(stack: int = -1, target: int = -1) -> void:
	stack_id = stack
	target_id = target
