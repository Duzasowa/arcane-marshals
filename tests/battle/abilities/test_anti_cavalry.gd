extends TestSuite

## "Anti-cavalry": +50% damage on stacks marked `cavalry`, in blows and
## retaliations; others take the usual damage.


func test_more_damage_on_riders() -> void:
	expect_eq(200, _blow(true, false), "plain on a rider")
	expect_eq(300, _blow(true, true), "halberds on a rider")
	expect_eq(200, _blow(false, true), "halberds on foot soldiers: as usual")


func test_counts_in_the_retaliation() -> void:
	var state: BattleState = BattleFixtures.empty_state(12)
	var rider: BattleStack = BattleFixtures.custom(state, 0, Vector2i(4, 4), 1, 100, 1, 1, 10, 10000)
	var halberds: BattleStack = BattleFixtures.custom(state, 1, Vector2i(5, 4), 20, 100, 10, 10)
	BattleFixtures.give(rider, &"cavalry")
	BattleFixtures.give(halberds, &"anti_cavalry")
	state.start()
	var forecast: Dictionary = BattleForecast.retaliation(state, rider, rider.cell, halberds, 1)
	expect_eq(300, forecast[&"max_damage"], "the forecast of the answer")
	state.take_events()
	state.apply(AttackCmd.new(rider.id, halberds.id, rider.cell))
	expect_eq(300, AbilityTestKit.first_damage(state.take_events(), rider.id), "the answer")


## One blow of 20 × 10 on a target with or without the cavalry mark.
func _blow(rider: bool, halberds: bool) -> int:
	var state: BattleState = BattleFixtures.empty_state(12)
	var attacker: BattleStack = BattleFixtures.custom(state, 0, Vector2i(4, 4), 20, 10, 10, 10, 10, 10000)
	var target: BattleStack = BattleFixtures.custom(state, 1, Vector2i(5, 4), 100, 100, 1, 1)
	if rider:
		BattleFixtures.give(target, &"cavalry")
	if halberds:
		BattleFixtures.give(attacker, &"anti_cavalry")
	state.start()
	state.take_events()
	state.apply(AttackCmd.new(attacker.id, target.id, attacker.cell))
	return AbilityTestKit.first_damage(state.take_events(), target.id)
