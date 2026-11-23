class_name MoveCmd
extends BattleCmd

## Move to `to` (the new anchor) and end the turn.

var to: Vector2i = Vector2i.ZERO


func _init(stack: int = -1, to_cell: Vector2i = Vector2i.ZERO) -> void:
	stack_id = stack
	to = to_cell
