extends TestSuite

## BattleSetup: deployment at the edges, obstacles that leave a way through,
## the same seed giving the same field.

const SEEDS: int = 200


func test_random_fields_follow_the_rules() -> void:
	var with_obstacles: int = 0
	for seed_value: int in range(1, SEEDS + 1):
		var state: BattleState = BattleSetup.create(BattleFixtures.data(), BattleFixtures.random_army(seed_value, 0),
				BattleFixtures.random_army(seed_value, 1), seed_value)
		var obstacles: int = state.grid.obstacle_count()
		expect_true(obstacles <= BattleSetup.MAX_OBSTACLE_CELLS, "seed %d: %d obstacle cells" % [seed_value, obstacles])
		if obstacles >= 4:
			with_obstacles += 1
		for y: int in BattleGrid.HEIGHT:
			for x: int in [0, 1, BattleGrid.WIDTH - 2, BattleGrid.WIDTH - 1]:
				if state.grid.is_obstacle(Vector2i(x, y)):
					fail("seed %d: obstacle in edge column %d" % [seed_value, x])
		expect_true(BattleSetup.has_passage(state.grid, 2), "seed %d: 2x2 way between the armies" % seed_value)
		_expect_consistent(state, "seed %d" % seed_value)
		expect_true(state.active_id >= 0, "seed %d: somebody has the first turn" % seed_value)
	expect_true(with_obstacles > SEEDS * 3 / 4, "most fields have obstacles: %d" % with_obstacles)


func test_same_seed_same_field() -> void:
	var a: BattleState = BattleSetup.create(BattleFixtures.data(), BattleFixtures.random_army(7, 0), BattleFixtures.random_army(7, 1), 99)
	var b: BattleState = BattleSetup.create(BattleFixtures.data(), BattleFixtures.random_army(7, 0), BattleFixtures.random_army(7, 1), 99)
	var c: BattleState = BattleSetup.create(BattleFixtures.data(), BattleFixtures.random_army(7, 0), BattleFixtures.random_army(7, 1), 100)
	expect_eq(a.digest(), b.digest(), "same seed")
	expect_ne(a.digest(), c.digest(), "other seed")


func test_deployment_columns_and_slots() -> void:
	var attacker: BattleSideSetup = BattleSideSetup.new()
	attacker.set_slot(0, &"throne_militia", 20)
	attacker.set_slot(4, &"throne_crossbowman", 10)
	var defender: BattleSideSetup = BattleSideSetup.new()
	defender.add(&"coven_sporeling", 30)
	var state: BattleState = BattleSetup.create(BattleFixtures.data(), attacker, defender, 5)
	expect_eq(3, state.stacks.size(), "empty slots skipped")
	expect_eq(Vector2i(0, 2), state.stacks[0].cell, "2 stacks spread: first at row 2")
	expect_eq(Vector2i(0, 6), state.stacks[1].cell, "second at row 6")
	expect_eq(4, state.stacks[1].slot, "slot kept")
	expect_eq(Vector2i(11, 4), state.stacks[2].cell, "defender on the right edge, middle")
	for stack: BattleStack in state.stacks:
		expect_between(0, AtbTimeline.FULL + 30 * AtbTimeline.PER_INITIATIVE, stack.atb, "start atb after the first ticks")


func test_seven_big_stacks_fit() -> void:
	var data: GameData = GameData.new()
	var big: UnitDef = BattleFixtures.unit(&"throne_outrider").duplicate()
	big.id = &"big_test"
	big.size = 2
	data.add(big)
	data.add(BattleFixtures.unit(&"coven_sporeling"))
	var attacker: BattleSideSetup = BattleSideSetup.new()
	var defender: BattleSideSetup = BattleSideSetup.new()
	for slot: int in BattleSideSetup.MAX_SLOTS:
		attacker.set_slot(slot, &"big_test", 2)
		defender.set_slot(slot, &"big_test" if slot % 2 == 0 else &"coven_sporeling", 2)
	var state: BattleState = BattleSetup.create(data, attacker, defender, 3)
	expect_eq(14, state.stacks.size(), "all placed")
	_expect_consistent(state, "big stacks")
	for stack: BattleStack in state.stacks:
		var middle: int = stack.cell.x * 2 + stack.size - 1
		if stack.side == 0:
			expect_true(middle < BattleGrid.WIDTH, "attacker %d on the left half" % stack.id)
		else:
			expect_true(middle >= BattleGrid.WIDTH, "defender %d on the right half" % stack.id)


func test_passage_check() -> void:
	var grid: BattleGrid = BattleGrid.new()
	expect_true(BattleSetup.has_passage(grid, 2), "open field")
	for y: int in BattleGrid.HEIGHT:
		if y != 4 and y != 5:
			grid.set_obstacle(Vector2i(6, y), true)
	expect_true(BattleSetup.has_passage(grid, 2), "2-wide gap lets 2x2 through")
	grid.set_obstacle(Vector2i(6, 5), true)
	expect_false(BattleSetup.has_passage(grid, 2), "1-wide gap stops 2x2")
	expect_true(BattleSetup.has_passage(grid, 1), "but not a small stack")


## Every stack covers exactly its cells and nothing overlaps.
func _expect_consistent(state: BattleState, label: String) -> void:
	var covered: int = 0
	for stack: BattleStack in state.stacks:
		for cell: Vector2i in BattleGrid.cells_of(stack.cell, stack.size):
			expect_true(BattleGrid.in_bounds(cell), "%s: stack %d inside" % [label, stack.id])
			if BattleGrid.in_bounds(cell):
				expect_eq(stack.id, state.grid.occupant_at(cell), "%s: stack %d owns its cell" % [label, stack.id])
				expect_false(state.grid.is_obstacle(cell), "%s: stack %d not on an obstacle" % [label, stack.id])
			covered += 1
	var occupied: int = 0
	for who: int in state.grid.occupant:
		if who != BattleGrid.FREE:
			occupied += 1
	expect_eq(covered, occupied, "%s: no overlap" % label)
