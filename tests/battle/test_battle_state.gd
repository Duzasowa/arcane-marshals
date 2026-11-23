extends TestSuite

## BattleStack damage bookkeeping and BattleState copies.


func test_stack_copies_unit_numbers() -> void:
	var unit: UnitDef = BattleFixtures.unit(&"throne_crossbowman")
	var stack: BattleStack = BattleStack.from_unit(unit, 1, 3, 12)
	expect_eq(&"throne_crossbowman", stack.unit_id, "unit id")
	expect_eq(unit.hp, stack.top_hp, "top creature whole")
	expect_eq(unit.shots, stack.shots_left, "full quiver")
	expect_true(stack.is_shooter(), "crossbowman shoots")
	expect_eq(12 * unit.hp, stack.total_hp(), "total hp")
	expect_eq(3, stack.slot, "army slot kept")


func test_take_damage_edges() -> void:
	var stack: BattleStack = _stack(10, 5)
	expect_eq(0, stack.take_damage(0), "zero damage")
	expect_eq(0, stack.take_damage(4), "4 of 5 hp kills nobody")
	expect_eq(1, stack.top_hp, "top creature at 1 hp")
	expect_eq(1, stack.take_damage(1), "the last hp of the top creature")
	expect_eq(9, stack.count, "9 left")
	expect_eq(5, stack.top_hp, "next creature whole")
	expect_eq(2, stack.take_damage(11), "11 damage: 2 dead, 1 hurt")
	expect_eq(4, stack.top_hp, "hurt top creature")
	expect_eq(7, stack.take_damage(1000), "overkill kills only the rest")
	expect_false(stack.is_alive(), "dead")
	expect_eq(0, stack.take_damage(5), "dead takes nothing")
	expect_eq(10, stack.lost(), "all lost")


func test_clone_has_the_same_digest_and_is_independent() -> void:
	var state: BattleState = BattleFixtures.empty_state(42)
	BattleFixtures.add(state, &"throne_militia", 20, 0, Vector2i(0, 0))
	BattleFixtures.add(state, &"coven_dragonfly", 3, 1, Vector2i(10, 4))
	state.grid.set_obstacle(Vector2i(5, 5), true)
	state.sides[0].morale = 2
	var copy: BattleState = state.clone()
	expect_eq(state.digest(), copy.digest(), "same digest")
	copy.stacks[0].take_damage(7)
	copy.rng.range_int(0, 100)
	copy.grid.set_obstacle(Vector2i(6, 6), true)
	copy.sides[0].morale = 0
	expect_ne(state.digest(), copy.digest(), "copy changed")
	expect_eq(20, state.stacks[0].count, "original stack untouched")
	expect_false(state.grid.is_obstacle(Vector2i(6, 6)), "original grid untouched")
	expect_eq(2, state.sides[0].morale, "original side untouched")


func test_events_are_not_hashed() -> void:
	var state: BattleState = BattleFixtures.empty_state(1)
	BattleFixtures.add(state, &"throne_militia", 5, 0, Vector2i(0, 0))
	var before: String = state.digest()
	state.events.append(BattleEvent.make(BattleEvent.Kind.WAITED, 0))
	expect_eq(before, state.digest(), "events skipped")
	expect_eq(1, state.take_events().size(), "event taken")
	expect_eq(0, state.events.size(), "buffer emptied")


func test_queries() -> void:
	var state: BattleState = BattleFixtures.empty_state(1)
	var a: BattleStack = BattleFixtures.add(state, &"throne_militia", 5, 0, Vector2i(3, 3))
	var b: BattleStack = BattleFixtures.add(state, &"coven_sporeling", 5, 1, Vector2i(4, 4))
	var c: BattleStack = BattleFixtures.add(state, &"coven_sporeling", 5, 1, Vector2i(8, 8))
	expect_eq(b, state.stack_at(Vector2i(4, 4)), "stack_at")
	expect_eq(2, state.enemies_of(a).size(), "two enemies")
	expect_eq(1, state.adjacent_stacks(a, 1).size(), "one enemy adjacent")
	c.take_damage(1000)
	expect_eq(1, state.enemies_of(a).size(), "dead stack not counted")


func _stack(count: int, hp: int) -> BattleStack:
	var stack: BattleStack = BattleStack.new()
	stack.count = count
	stack.initial_count = count
	stack.hp = hp
	stack.top_hp = hp
	return stack
