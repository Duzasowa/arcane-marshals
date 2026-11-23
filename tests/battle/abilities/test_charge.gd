extends TestSuite

## "Charge": +5% per cell between the turn start and the place of the blow;
## the forecast counts the same; no bonus in place, in a retaliation, or for a
## walk on an earlier turn.


func test_bonus_per_cell_matches_the_forecast() -> void:
	for steps: int in [1, 3, 4]:
		var state: BattleState = BattleFixtures.empty_state(13)
		var rider: BattleStack = BattleFixtures.custom(state, 0, Vector2i(1, 4), 20, 10, 10, 10, 10, 10000)
		var target: BattleStack = BattleFixtures.custom(state, 1, Vector2i(2 + steps, 4), 100, 100, 1, 1)
		BattleFixtures.give(rider, &"charge")
		state.start()
		var spot: Vector2i = Vector2i(1 + steps, 4)
		var forecast: Dictionary = DamageCalc.estimate(state, rider, spot, target, DamageCalc.Kind.MELEE)
		state.take_events()
		expect_true(state.apply(AttackCmd.new(rider.id, target.id, spot)), "charges %d" % steps)
		var expected: int = 200 * (1000 + 50 * steps) / 1000
		expect_eq(expected, AbilityTestKit.first_damage(state.take_events(), target.id), "blow after %d cells" % steps)
		expect_eq(expected, forecast[&"max_damage"], "forecast for %d cells" % steps)


func test_no_bonus_in_place_or_in_retaliation() -> void:
	var state: BattleState = BattleFixtures.empty_state(14)
	var rider: BattleStack = BattleFixtures.custom(state, 0, Vector2i(4, 4), 20, 1000, 10, 10, 10, 10000)
	var target: BattleStack = BattleFixtures.custom(state, 1, Vector2i(5, 4), 100, 100, 1, 1, 10, 5000)
	BattleFixtures.give(rider, &"charge")
	state.start()
	state.take_events()
	state.apply(AttackCmd.new(rider.id, target.id, rider.cell))
	expect_eq(200, AbilityTestKit.first_damage(state.take_events(), target.id), "in place")
	expect_eq(target.id, state.active_id, "the target's turn")
	state.apply(AttackCmd.new(target.id, rider.id, target.cell))
	expect_eq(200, AbilityTestKit.first_damage(state.take_events(), target.id), "the answer")


func test_an_earlier_walk_does_not_count() -> void:
	var state: BattleState = BattleFixtures.empty_state(15)
	var rider: BattleStack = BattleFixtures.custom(state, 0, Vector2i(1, 4), 20, 10, 10, 10, 10, 10000)
	var target: BattleStack = BattleFixtures.custom(state, 1, Vector2i(5, 4), 1000, 100, 1, 1, 10, 0)
	BattleFixtures.give(rider, &"charge")
	state.start()
	expect_true(state.apply(MoveCmd.new(rider.id, Vector2i(4, 4))), "walks up")
	AbilityTestKit.pass_until(state, rider)
	state.take_events()
	state.apply(AttackCmd.new(rider.id, target.id, rider.cell))
	expect_eq(200, AbilityTestKit.first_damage(state.take_events(), target.id), "no bonus a turn later")
