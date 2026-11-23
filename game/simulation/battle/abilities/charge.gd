extends AbilityHook

## Charge (docs/MECHANICS.md §5): a blow deals `per_cell` permille more for
## every cell between where the owner began its turn and where it strikes from
## (straight-line, diagonals count 1). Not in retaliations or shots.
##
## The walk before a blow is noted in `params` (`walked`, on the turn
## `walked_turn`); a forecast adds the distance to `Strike.from`, where the
## owner would stand. So the battle and every forecast count the same.


func on_after_move(state: BattleState, owner: BattleStack, from: Vector2i, params: Dictionary) -> void:
	params[&"walked"] = BattleGrid.distance(from, 1, owner.cell, 1)
	params[&"walked_turn"] = state.turn_count


func modify_attack(state: BattleState, owner: BattleStack, _target: BattleStack, kind: DamageCalc.Kind,
		strike: DamageCalc.Strike, params: Dictionary) -> void:
	if kind != DamageCalc.Kind.MELEE:
		return
	var walked: int = BattleGrid.distance(owner.cell, 1, strike.from, 1)
	if int(params.get(&"walked_turn", -1)) == state.turn_count:
		walked += int(params.get(&"walked", 0))
	if walked > 0:
		strike.ability = strike.ability * (DamageCalc.NORMAL + int(params[&"per_cell"]) * walked) / DamageCalc.NORMAL
