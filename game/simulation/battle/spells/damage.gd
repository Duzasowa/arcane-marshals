extends SpellHook

## A damage spell on one stack (docs/MECHANICS.md §6): `SpellCast.strength`
## HP, less the target's magic resistance. No dice: the forecast is exact.


func estimate(_state: BattleState, hero: BattleHero, spell: Dictionary, target: BattleStack) -> Dictionary:
	return SpellCast.damage_estimate(target, _damage(hero, spell, target))


func cast(state: BattleState, hero: BattleHero, spell: Dictionary, target: BattleStack) -> void:
	state.deal_damage(null, target, _damage(hero, spell, target))


func _damage(hero: BattleHero, spell: Dictionary, target: BattleStack) -> int:
	return SpellCast.resisted(target, SpellCast.strength(hero, spell))
