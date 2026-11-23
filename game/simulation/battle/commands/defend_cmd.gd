class_name DefendCmd
extends BattleCmd

## +30% defence until the stack's next turn; ends the turn.


func _init(stack: int = -1) -> void:
	stack_id = stack
