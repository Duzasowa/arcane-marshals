extends AbilityHook

## Swallow (docs/MECHANICS.md §5): after a blow on a stack of weak creatures
## (`hp` ≤ `max_hp`) that survived it, `per_creature` permille of a creature
## per owner's creature (at least one) is swallowed whole.

const ID: StringName = &"swallow"


func on_after_attack(state: BattleState, owner: BattleStack, target: BattleStack, kind: DamageCalc.Kind,
		params: Dictionary) -> void:
	if kind != DamageCalc.Kind.MELEE or not target.is_alive() or target.hp > int(params[&"max_hp"]):
		return
	var eaten: int = mini(target.count, maxi(1, owner.count * int(params[&"per_creature"]) / DamageCalc.NORMAL))
	state.emit_ability(owner, ID, target)
	state.deal_damage(owner, target, target.top_hp + (eaten - 1) * target.hp)
