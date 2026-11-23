extends AbilityHook

## Cover (docs/MECHANICS.md §5): allies next to the owner take `share` permille
## less from every strike, and the owner takes that part on itself:
## `damage × share / (1000 − share)` of the damage the ally took.

const ID: StringName = &"cover"


func modify_ally_damage_taken(_state: BattleState, _owner: BattleStack, _ally: BattleStack, _attacker: BattleStack,
		_kind: DamageCalc.Kind, strike: DamageCalc.Strike, params: Dictionary) -> void:
	strike.ability = strike.ability * (DamageCalc.NORMAL - int(params[&"share"])) / DamageCalc.NORMAL


func on_ally_damaged(state: BattleState, owner: BattleStack, ally: BattleStack, attacker: BattleStack,
		damage: int, _kind: DamageCalc.Kind, params: Dictionary) -> void:
	var share: int = int(params[&"share"])
	var taken: int = damage * share / (DamageCalc.NORMAL - share)
	if taken > 0:
		state.emit_ability(owner, ID, ally)
		state.deal_damage(attacker, owner, taken)
