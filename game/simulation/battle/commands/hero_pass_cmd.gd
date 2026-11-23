class_name HeroPassCmd
extends BattleCmd

## The hero of `side` lets its turn go by.

var side: int = -1


func _init(hero_side: int = -1) -> void:
	side = hero_side


func describe() -> String:
	return "HeroPassCmd side=%d" % side
