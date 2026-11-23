extends TestSuite

## "Cover": an ally next to the shield bearer takes 30% less (in the forecast
## too), the bearer takes that part; far from it — as usual; the bearer itself
## is not covered by itself.


func test_neighbour_is_covered() -> void:
	var state: BattleState = BattleFixtures.empty_state(32)
	var attacker: BattleStack = BattleFixtures.custom(state, 0, Vector2i(4, 4), 100, 100, 10, 10, 10, 10000)
	var target: BattleStack = BattleFixtures.custom(state, 1, Vector2i(5, 4), 100, 100, 1, 1)
	var bearer: BattleStack = BattleFixtures.custom(state, 1, Vector2i(6, 5), 100, 100, 1, 1)
	BattleFixtures.give(bearer, &"cover")
	state.start()
	var forecast: Dictionary = DamageCalc.estimate(state, attacker, attacker.cell, target, DamageCalc.Kind.MELEE)
	expect_eq(700, forecast[&"max_damage"], "the forecast")
	state.take_events()
	state.apply(AttackCmd.new(attacker.id, target.id, attacker.cell))
	var events: Array[BattleEvent] = state.take_events()
	expect_eq(700, AbilityTestKit.first_damage(events, target.id), "the target")
	expect_eq(300, AbilityTestKit.first_damage(events, bearer.id), "the bearer's part")
	expect_eq(1, AbilityTestKit.count(events, BattleEvent.Kind.ABILITY), "reported")


func test_far_and_self_are_not_covered() -> void:
	var state: BattleState = BattleFixtures.empty_state(33)
	var attacker: BattleStack = BattleFixtures.custom(state, 0, Vector2i(4, 4), 100, 100, 10, 10, 10, 10000)
	var target: BattleStack = BattleFixtures.custom(state, 1, Vector2i(5, 4), 100, 100, 1, 1)
	var bearer: BattleStack = BattleFixtures.custom(state, 1, Vector2i(9, 9), 100, 100, 1, 1)
	BattleFixtures.give(bearer, &"cover")
	BattleFixtures.give(target, &"cover")
	state.start()
	state.take_events()
	state.apply(AttackCmd.new(attacker.id, target.id, attacker.cell))
	var events: Array[BattleEvent] = state.take_events()
	expect_eq(1000, AbilityTestKit.first_damage(events, target.id), "the bearer struck itself: full")
	expect_eq(-1, AbilityTestKit.first_damage(events, bearer.id), "the far one takes nothing")
