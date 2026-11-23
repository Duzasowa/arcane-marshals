extends AbilityHook

## Test handler: blows on it deal `mult` permille.


func modify_damage_taken(_state: BattleState, _owner: BattleStack, _attacker: BattleStack, _kind: DamageCalc.Kind,
		strike: DamageCalc.Strike, params: Dictionary) -> void:
	strike.ability = strike.ability * int(params[&"mult"]) / DamageCalc.NORMAL
