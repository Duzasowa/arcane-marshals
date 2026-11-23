extends TestSuite

## Melee: walk + strike + one retaliation until the target's own turn; death.


func test_strike_and_retaliation() -> void:
	var state: BattleState = BattleFixtures.empty_state(3)
	var a: BattleStack = BattleFixtures.add(state, &"throne_militia", 20, 0, Vector2i(4, 4), 10000)
	var b: BattleStack = BattleFixtures.add(state, &"coven_sporeling", 20, 1, Vector2i(5, 4))
	state.start()
	state.take_events()
	expect_true(state.apply(AttackCmd.new(a.id, b.id, a.cell)), "attack applied")
	expect_true(b.count < 20, "target lost creatures")
	expect_true(a.count < 20, "attacker took the retaliation")
	expect_eq(1, b.retaliations_left, "b has the turn now: retaliation back")
	var kinds: Array[BattleEvent.Kind] = _kinds(state.take_events())
	expect_eq([BattleEvent.Kind.ATTACKED, BattleEvent.Kind.DAMAGED, BattleEvent.Kind.RETALIATED,
			BattleEvent.Kind.DAMAGED, BattleEvent.Kind.TURN_STARTED], kinds, "events in order")
	expect_eq(b.id, state.active_id, "b's turn next")


func test_retaliation_once_until_own_turn() -> void:
	var state: BattleState = BattleFixtures.empty_state(4)
	var a: BattleStack = BattleFixtures.add(state, &"throne_militia", 20, 0, Vector2i(4, 4), 10000)
	var c: BattleStack = BattleFixtures.add(state, &"throne_militia", 20, 0, Vector2i(5, 5), 9990)
	var b: BattleStack = BattleFixtures.add(state, &"coven_sporeling", 40, 1, Vector2i(5, 4))
	state.start()
	state.apply(AttackCmd.new(a.id, b.id, a.cell))
	expect_eq(c.id, state.active_id, "c next")
	state.take_events()
	var c_before: int = c.count
	state.apply(AttackCmd.new(c.id, b.id, c.cell))
	expect_false(_kinds(state.take_events()).has(BattleEvent.Kind.RETALIATED), "no second retaliation")
	expect_eq(c_before, c.count, "c unharmed")
	expect_eq(b.id, state.active_id, "b's turn")
	expect_eq(1, b.retaliations_left, "retaliation back on its own turn")


func test_flanking_bonus_applies_in_battle() -> void:
	var state: BattleState = BattleFixtures.empty_state(5)
	var a: BattleStack = BattleFixtures.custom(state, 0, Vector2i(4, 4), 10, 100, 10, 10, 10, 10000)
	BattleFixtures.custom(state, 0, Vector2i(6, 4), 1, 100, 1, 1)
	var b: BattleStack = BattleFixtures.custom(state, 1, Vector2i(5, 4), 10, 1000, 1, 1)
	state.start()
	state.take_events()
	state.apply(AttackCmd.new(a.id, b.id, a.cell))
	var hit: BattleEvent = _first(state.take_events(), BattleEvent.Kind.DAMAGED)
	expect_eq(110, hit.damage, "10 × 10 × 1.1")


func test_kill_frees_cells_and_ends_the_battle() -> void:
	var state: BattleState = BattleFixtures.empty_state(6)
	var a: BattleStack = BattleFixtures.add(state, &"throne_outrider", 30, 0, Vector2i(4, 4), 10000)
	var b: BattleStack = BattleFixtures.add(state, &"coven_sporeling", 1, 1, Vector2i(5, 4))
	state.start()
	state.take_events()
	expect_true(state.apply(AttackCmd.new(a.id, b.id, a.cell)), "attack applied")
	expect_false(b.is_alive(), "target dead")
	expect_eq(BattleGrid.FREE, state.grid.occupant_at(Vector2i(5, 4)), "cell freed")
	var kinds: Array[BattleEvent.Kind] = _kinds(state.take_events())
	expect_true(kinds.has(BattleEvent.Kind.DIED), "death event")
	expect_false(kinds.has(BattleEvent.Kind.RETALIATED), "the dead do not retaliate")
	expect_true(state.is_over(), "last enemy gone")
	expect_eq(0, state.result.winner, "attacker won")
	expect_eq(-1, state.active_id, "nobody's turn")


func test_walk_then_strike() -> void:
	var state: BattleState = BattleFixtures.empty_state(7)
	var a: BattleStack = BattleFixtures.add(state, &"throne_militia", 10, 0, Vector2i(0, 0), 10000)
	var b: BattleStack = BattleFixtures.add(state, &"coven_sporeling", 10, 1, Vector2i(5, 0))
	state.start()
	state.take_events()
	expect_false(state.apply(AttackCmd.new(a.id, b.id, Vector2i(3, 0))), "not adjacent to the target")
	expect_true(state.apply(AttackCmd.new(a.id, b.id, Vector2i(4, 0))), "4 steps for speed 4")
	expect_eq(Vector2i(4, 0), a.cell, "stands next to the target")
	expect_eq(a.id, state.grid.occupant_at(Vector2i(4, 0)), "grid updated")
	expect_eq(BattleGrid.FREE, state.grid.occupant_at(Vector2i(0, 0)), "old cell freed")
	var moved: BattleEvent = _first(state.take_events(), BattleEvent.Kind.MOVED)
	expect_eq(4, moved.cells.size(), "4 cells walked")
	expect_eq(BattleGrid.index(Vector2i(4, 0)), moved.cells[3], "path ends at the spot")


func test_move_ends_the_turn() -> void:
	var state: BattleState = BattleFixtures.empty_state(8)
	var a: BattleStack = BattleFixtures.add(state, &"throne_militia", 10, 0, Vector2i(0, 0), 10000)
	var b: BattleStack = BattleFixtures.add(state, &"coven_sporeling", 10, 1, Vector2i(11, 0), 9000)
	state.start()
	expect_false(state.apply(MoveCmd.new(a.id, Vector2i(5, 0))), "too far")
	expect_true(state.apply(MoveCmd.new(a.id, Vector2i(2, 2))), "diagonal move")
	expect_eq(Vector2i(2, 2), a.cell, "moved")
	expect_eq(b.id, state.active_id, "turn passed")
	expect_eq(1, state.turn_count, "one turn taken")


func test_attack_spots_cheapest_first() -> void:
	var state: BattleState = BattleFixtures.empty_state(9)
	var a: BattleStack = BattleFixtures.add(state, &"throne_militia", 10, 0, Vector2i(2, 4), 10000)
	var b: BattleStack = BattleFixtures.add(state, &"coven_sporeling", 10, 1, Vector2i(5, 4))
	var spots: Array[Vector2i] = state.attack_spots(a, b)
	expect_eq(Vector2i(4, 4), spots[0], "the straight spot is the cheapest")
	expect_eq(5, spots.size(), "the 5 near neighbours of the target in reach")
	for spot: Vector2i in spots:
		expect_true(BattleGrid.adjacent(spot, 1, b.cell, 1), "%s touches the target" % spot)


func _kinds(events: Array[BattleEvent]) -> Array[BattleEvent.Kind]:
	var kinds: Array[BattleEvent.Kind] = []
	for event: BattleEvent in events:
		kinds.append(event.kind)
	return kinds


func _first(events: Array[BattleEvent], kind: BattleEvent.Kind) -> BattleEvent:
	for event: BattleEvent in events:
		if event.kind == kind:
			return event
	fail("no %s event" % BattleEvent.Kind.keys()[kind])
	return BattleEvent.new()
