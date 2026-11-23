extends TestSuite

## "Hit and return": after a blow at the end of a walk the stack is back where
## it began; a blow in place leaves it there; a dead stack does not move.


func test_returns_after_the_blow() -> void:
	var state: BattleState = BattleFixtures.empty_state(23)
	var fly: BattleStack = BattleFixtures.custom(state, 0, Vector2i(1, 4), 10, 100, 2, 2, 10, 10000)
	fly.flying = true
	var target: BattleStack = BattleFixtures.custom(state, 1, Vector2i(6, 4), 10, 100, 1, 1)
	BattleFixtures.give(fly, &"hit_and_return")
	state.start()
	state.take_events()
	expect_true(state.apply(AttackCmd.new(fly.id, target.id, Vector2i(5, 4))), "strikes")
	var events: Array[BattleEvent] = state.take_events()
	expect_eq(Vector2i(1, 4), fly.cell, "back at the start")
	expect_eq(fly.id, state.grid.occupant_at(Vector2i(1, 4)), "on the grid")
	expect_eq(BattleGrid.FREE, state.grid.occupant_at(Vector2i(5, 4)), "the spot is free")
	expect_eq(2, AbilityTestKit.count(events, BattleEvent.Kind.MOVED), "there and back")
	expect_eq(1, AbilityTestKit.count(events, BattleEvent.Kind.RETALIATED), "answered before leaving")


func test_stays_after_a_blow_in_place() -> void:
	var state: BattleState = BattleFixtures.empty_state(24)
	var fly: BattleStack = BattleFixtures.custom(state, 0, Vector2i(1, 4), 10, 100, 2, 2, 10, 10000)
	var target: BattleStack = BattleFixtures.custom(state, 1, Vector2i(2, 4), 10, 100, 1, 1, 10, 0)
	BattleFixtures.give(fly, &"hit_and_return")
	state.start()
	expect_true(state.apply(MoveCmd.new(fly.id, Vector2i(1, 5))), "a plain move")
	AbilityTestKit.pass_until(state, fly)
	state.apply(AttackCmd.new(fly.id, target.id, fly.cell))
	expect_eq(Vector2i(1, 5), fly.cell, "stays")


func test_dead_stack_does_not_move() -> void:
	var state: BattleState = BattleFixtures.empty_state(25)
	var fly: BattleStack = BattleFixtures.custom(state, 0, Vector2i(1, 4), 1, 1, 1, 1, 10, 10000)
	var target: BattleStack = BattleFixtures.custom(state, 1, Vector2i(6, 4), 50, 100, 5, 5)
	BattleFixtures.custom(state, 0, Vector2i(0, 9), 10, 100, 1, 1)
	BattleFixtures.give(fly, &"hit_and_return")
	state.start()
	state.take_events()
	state.apply(AttackCmd.new(fly.id, target.id, Vector2i(5, 4)))
	expect_false(fly.is_alive(), "killed by the answer")
	expect_eq(1, AbilityTestKit.count(state.take_events(), BattleEvent.Kind.MOVED), "no return")
