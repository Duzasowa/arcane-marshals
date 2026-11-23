class_name SurrenderCmd
extends BattleCmd

## The side of the active stack gives up the battle. What it costs (gold, the
## hero, the army) is decided by the adventure map (Ф6).

var side: int = 0


func _init(giving_up_side: int = 0) -> void:
	side = giving_up_side


func describe() -> String:
	return "SurrenderCmd side=%d" % side
