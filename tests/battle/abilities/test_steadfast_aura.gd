extends TestSuite

## "Steadfast aura": with side morale −3, the colossus and its neighbours have
## morale 0 and never lose a turn; a stack far away still does.


func test_neighbours_keep_their_turns() -> void:
	var state: BattleState = BattleFixtures.empty_state(34)
	var colossus: BattleStack = BattleFixtures.custom(state, 0, Vector2i(2, 4), 10, 100, 1, 1)
	var near: BattleStack = BattleFixtures.custom(state, 0, Vector2i(2, 5), 10, 100, 1, 1)
	var far: BattleStack = BattleFixtures.custom(state, 0, Vector2i(2, 9), 10, 100, 1, 1)
	BattleFixtures.custom(state, 1, Vector2i(11, 0), 10, 100, 1, 1)
	BattleFixtures.give(colossus, &"steadfast_aura")
	state.sides[0].morale = -3
	expect_eq(0, state.morale_of(colossus), "the colossus")
	expect_eq(0, state.morale_of(near), "its neighbour")
	expect_eq(-3, state.morale_of(far), "the far one")
	state.start()
	var lost: Dictionary[int, int] = {colossus.id: 0, near.id: 0, far.id: 0}
	for i: int in 120:
		for event: BattleEvent in state.take_events():
			if event.kind == BattleEvent.Kind.MORALE_BAD:
				lost[event.stack_id] = lost.get(event.stack_id, 0) + 1
		state.apply(DefendCmd.new(state.active_id))
	expect_eq(0, lost[colossus.id], "the colossus never")
	expect_eq(0, lost[near.id], "the neighbour never")
	expect_true(lost[far.id] > 0, "the far one does")
