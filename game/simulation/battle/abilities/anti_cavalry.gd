extends AbilityHook

## Strikes on a stack with the ability `mark` (riders) deal `mult` permille
## (docs/MECHANICS.md §5): blows, retaliations and shots alike.


func modify_attack(_state: BattleState, _owner: BattleStack, target: BattleStack, _kind: DamageCalc.Kind,
		strike: DamageCalc.Strike, params: Dictionary) -> void:
	if target.has_ability(params[&"mark"]):
		strike.ability = strike.ability * int(params[&"mult"]) / DamageCalc.NORMAL
