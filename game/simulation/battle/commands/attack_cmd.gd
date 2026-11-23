class_name AttackCmd
extends BattleCmd

## Walk to `from` (the current cell — stay) and strike `target_id` in melee.

var target_id: int = -1
var from: Vector2i = Vector2i.ZERO


func _init(stack: int = -1, target: int = -1, from_cell: Vector2i = Vector2i.ZERO) -> void:
	stack_id = stack
	target_id = target
	from = from_cell
