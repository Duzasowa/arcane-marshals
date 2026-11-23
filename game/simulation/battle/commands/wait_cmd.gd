class_name WaitCmd
extends BattleCmd

## Move later in the same round (once before acting).


func _init(stack: int = -1) -> void:
	stack_id = stack
