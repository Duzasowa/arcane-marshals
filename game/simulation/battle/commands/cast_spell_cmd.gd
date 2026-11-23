class_name CastSpellCmd
extends BattleCmd

## The hero of `side` casts `spell_id` on the stack `target_id` — on the hero's
## turn (docs/MECHANICS.md §2, §6). Pays the mana and takes the hero's turn.

var side: int = -1
var spell_id: StringName = &""
var target_id: int = -1


func _init(hero_side: int = -1, spell: StringName = &"", target: int = -1) -> void:
	side = hero_side
	spell_id = spell
	target_id = target


func describe() -> String:
	return "CastSpellCmd side=%d spell=%s target=%d" % [side, spell_id, target_id]
