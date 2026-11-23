extends AbilityHook

## The effect "weakened" (docs/MECHANICS.md §5): `attack` less in the owner's
## strikes and `defence` less against strikes on it (not below 0).


func modify_attack(_state: BattleState, _owner: BattleStack, _target: BattleStack, _kind: DamageCalc.Kind,
		strike: DamageCalc.Strike, params: Dictionary) -> void:
	strike.attack = maxi(0, strike.attack - int(params[&"attack"]))


func modify_damage_taken(_state: BattleState, _owner: BattleStack, _attacker: BattleStack, _kind: DamageCalc.Kind,
		strike: DamageCalc.Strike, params: Dictionary) -> void:
	strike.defence = maxi(0, strike.defence - int(params[&"defence"]))
