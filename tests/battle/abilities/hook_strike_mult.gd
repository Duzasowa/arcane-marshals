extends AbilityHook

## Test handler: its blows deal `mult` permille.


func modify_attack(_state: BattleState, _owner: BattleStack, _target: BattleStack, _kind: DamageCalc.Kind,
		strike: DamageCalc.Strike, params: Dictionary) -> void:
	strike.ability = strike.ability * int(params[&"mult"]) / DamageCalc.NORMAL
