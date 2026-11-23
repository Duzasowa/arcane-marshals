extends TestSuite

## "Sweeping strike": every enemy next to the owner takes the blow; the far
## ones do not; only the chosen target answers.


func test_hits_every_neighbour() -> void:
	var state: BattleState = BattleFixtures.empty_state(19)
	var hydra: BattleStack = BattleFixtures.custom(state, 0, Vector2i(4, 4), 10, 100, 2, 2, 10, 10000)
	var target: BattleStack = BattleFixtures.custom(state, 1, Vector2i(5, 4), 10, 100, 1, 1)
	var above: BattleStack = BattleFixtures.custom(state, 1, Vector2i(4, 3), 10, 100, 1, 1)
	var corner: BattleStack = BattleFixtures.custom(state, 1, Vector2i(3, 5), 10, 100, 1, 1)
	var far: BattleStack = BattleFixtures.custom(state, 1, Vector2i(9, 8), 10, 100, 1, 1)
	var friend: BattleStack = BattleFixtures.custom(state, 0, Vector2i(0, 0), 10, 100, 1, 1)
	BattleFixtures.give(hydra, &"strike_all_adjacent")
	state.start()
	state.take_events()
	state.apply(AttackCmd.new(hydra.id, target.id, hydra.cell))
	var events: Array[BattleEvent] = state.take_events()
	for hit: BattleStack in [target, above, corner]:
		expect_eq(20, AbilityTestKit.first_damage(events, hit.id), "neighbour %d hit" % hit.id)
	expect_eq(-1, AbilityTestKit.first_damage(events, far.id), "the far one not")
	expect_eq(-1, AbilityTestKit.first_damage(events, friend.id), "a friend not")
	expect_eq(1, AbilityTestKit.count(events, BattleEvent.Kind.RETALIATED), "one answer")
