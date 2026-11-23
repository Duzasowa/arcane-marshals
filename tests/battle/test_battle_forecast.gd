extends TestSuite

## `BattleForecast.retaliation` (UI and AI) gives the same numbers as working
## the retaliation out on a full copy of the state with the attacker moved.


func test_retaliation_matches_a_moved_copy() -> void:
	var state: BattleState = BattleFixtures.empty_state(5)
	var attacker: BattleStack = BattleFixtures.add(state, &"throne_militia", 20, 0, Vector2i(2, 4), 10000)
	var target: BattleStack = BattleFixtures.add(state, &"coven_sporeling", 25, 1, Vector2i(6, 4))
	var target_friend: BattleStack = BattleFixtures.add(state, &"coven_sporeling", 10, 1, Vector2i(5, 6))
	var archer: BattleStack = BattleFixtures.add(state, &"coven_lizard_thrower", 8, 1, Vector2i(7, 2))
	BattleFixtures.add(state, &"throne_outrider", 3, 0, Vector2i(7, 5))
	state.start()
	var reach: Dictionary[int, int] = BattlePathfinder.reachable(state, attacker)
	var checked: int = 0
	for enemy: BattleStack in [target, target_friend, archer]:
		for spot: Vector2i in state.attack_spots(attacker, enemy, reach):
			var blow: Dictionary = DamageCalc.estimate(state, attacker, spot, enemy, DamageCalc.Kind.MELEE)
			for damage: int in [blow[&"min_damage"], blow[&"max_damage"]]:
				var expected: Dictionary = _on_a_copy(state, attacker, spot, enemy, damage)
				var actual: Dictionary = BattleForecast.retaliation(state, attacker, spot, enemy, damage)
				expect_eq(expected, actual, "%s from %s, damage %d" % [enemy.unit_id, spot, damage])
				checked += 1
	expect_true(checked >= 12, "checked %d cases" % checked)


func test_no_retaliation_left_or_target_dead() -> void:
	var state: BattleState = BattleFixtures.empty_state(6)
	var attacker: BattleStack = BattleFixtures.add(state, &"throne_outrider", 10, 0, Vector2i(4, 4), 10000)
	var target: BattleStack = BattleFixtures.add(state, &"throne_militia", 3, 1, Vector2i(5, 4))
	state.start()
	expect_true(BattleForecast.retaliation(state, attacker, attacker.cell, target, 1).size() > 0, "a weak blow")
	expect_eq({}, BattleForecast.retaliation(state, attacker, attacker.cell, target, 1000), "the target dies")
	target.retaliations_left = 0
	expect_eq({}, BattleForecast.retaliation(state, attacker, attacker.cell, target, 1), "already retaliated")


func test_forecast_changes_nothing() -> void:
	var state: BattleState = BattleFixtures.empty_state(7)
	var attacker: BattleStack = BattleFixtures.add(state, &"throne_militia", 12, 0, Vector2i(4, 4), 10000)
	var target: BattleStack = BattleFixtures.add(state, &"coven_sporeling", 12, 1, Vector2i(6, 4))
	state.start()
	state.take_events()
	var before: String = state.digest()
	BattleForecast.retaliation(state, attacker, Vector2i(5, 4), target, 10)
	expect_eq(before, state.digest(), "same digest")
	expect_eq(0, state.take_events().size(), "no events")


## The way the battle screen used to work it out: a whole copy of the state.
func _on_a_copy(state: BattleState, who: BattleStack, spot: Vector2i, target: BattleStack, damage: int) -> Dictionary:
	if target.retaliations_left <= 0:
		return {}
	var copy: BattleState = state.clone()
	var attacker: BattleStack = copy.stack(who.id)
	copy.grid.remove(attacker.id, attacker.cell, attacker.size)
	attacker.cell = spot
	copy.grid.place(attacker.id, spot, attacker.size)
	var defender: BattleStack = copy.stack(target.id)
	defender.take_damage(damage)
	if not defender.is_alive():
		return {}
	return DamageCalc.estimate(copy, defender, defender.cell, attacker, DamageCalc.Kind.RETALIATION)
