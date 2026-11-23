extends AbilityHook

## Ignores `share` permille of the target's defence (docs/MECHANICS.md §5),
## in every strike of the owner.


func modify_attack(_state: BattleState, _owner: BattleStack, _target: BattleStack, _kind: DamageCalc.Kind,
		strike: DamageCalc.Strike, params: Dictionary) -> void:
	strike.defence = strike.defence * (DamageCalc.NORMAL - int(params[&"share"])) / DamageCalc.NORMAL
