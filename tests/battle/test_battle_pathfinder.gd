extends TestSuite

## BattlePathfinder: step costs, range, obstacles, corners, big stacks, flyers.


func test_open_field_range() -> void:
	var state: BattleState = BattleFixtures.empty_state()
	var walker: BattleStack = _walker(state, Vector2i(5, 5), 4)
	var reach: Dictionary[int, int] = BattlePathfinder.reachable(state, walker)
	expect_eq(0, reach.get(BattleGrid.index(Vector2i(5, 5)), -1), "start at cost 0")
	expect_eq(8, reach.get(BattleGrid.index(Vector2i(9, 5)), -1), "4 straight steps")
	expect_false(reach.has(BattleGrid.index(Vector2i(10, 5))), "5 steps out of range")
	expect_eq(6, reach.get(BattleGrid.index(Vector2i(7, 7)), -1), "2 diagonals")
	expect_false(reach.has(BattleGrid.index(Vector2i(8, 8))), "3 diagonals cost 9")
	expect_eq(8, reach.get(BattleGrid.index(Vector2i(7, 8)), -1), "2 diagonals + 1 straight")


func test_around_a_wall() -> void:
	var state: BattleState = BattleFixtures.empty_state()
	for y: int in range(3, 8):
		state.grid.set_obstacle(Vector2i(6, y), true)
	var walker: BattleStack = _walker(state, Vector2i(5, 5), 8)
	var reach: Dictionary[int, int] = BattlePathfinder.reachable(state, walker)
	expect_eq(16, reach.get(BattleGrid.index(Vector2i(7, 5)), -1), "8 straight steps around the wall")
	var route: PackedInt32Array = BattlePathfinder.path(state, walker, Vector2i(7, 5))
	_expect_valid_route(state, walker, route, 16)
	expect_eq(BattleGrid.index(Vector2i(7, 5)), route[route.size() - 1], "ends at the target")
	walker.speed = 7
	expect_false(BattlePathfinder.reachable(state, walker).has(BattleGrid.index(Vector2i(7, 5))), "14 is not enough")
	expect_eq(0, BattlePathfinder.path(state, walker, Vector2i(7, 5)).size(), "no path out of range")


func test_no_corner_cutting() -> void:
	var state: BattleState = BattleFixtures.empty_state()
	state.grid.set_obstacle(Vector2i(6, 5), true)
	var walker: BattleStack = _walker(state, Vector2i(5, 5), 4)
	var reach: Dictionary[int, int] = BattlePathfinder.reachable(state, walker)
	expect_eq(4, reach.get(BattleGrid.index(Vector2i(6, 6)), -1), "round the corner, not across it")
	expect_eq(3, reach.get(BattleGrid.index(Vector2i(4, 4)), -1), "open diagonal")


func test_stacks_block_walkers() -> void:
	var state: BattleState = BattleFixtures.empty_state()
	var walker: BattleStack = _walker(state, Vector2i(0, 0), 2)
	BattleFixtures.custom(state, 1, Vector2i(1, 0), 1, 5, 1, 1)
	var reach: Dictionary[int, int] = BattlePathfinder.reachable(state, walker)
	expect_false(reach.has(BattleGrid.index(Vector2i(1, 0))), "cannot stand on a stack")
	expect_false(reach.has(BattleGrid.index(Vector2i(2, 0))), "cannot walk through it in 2 steps")
	expect_eq(4, reach.get(BattleGrid.index(Vector2i(0, 2)), -1), "other ways open")


func test_big_stack_needs_a_wide_gap() -> void:
	var state: BattleState = BattleFixtures.empty_state()
	for y: int in BattleGrid.HEIGHT:
		if y != 4:
			state.grid.set_obstacle(Vector2i(6, y), true)
	var small: BattleStack = _walker(state, Vector2i(5, 4), 3)
	var big: BattleStack = _walker(state, Vector2i(3, 4), 6, 2)
	expect_true(BattlePathfinder.reachable(state, small).has(BattleGrid.index(Vector2i(7, 4))), "small passes")
	small.count = 0
	state.grid.remove(small.id, small.cell, 1)
	expect_false(_reaches_column(state, big, 7), "2x2 stuck at a 1-wide gap")
	state.grid.set_obstacle(Vector2i(6, 5), false)
	expect_true(_reaches_column(state, big, 7), "2x2 passes a 2-wide gap")


func test_flyer_over_a_wall() -> void:
	var state: BattleState = BattleFixtures.empty_state()
	for y: int in BattleGrid.HEIGHT:
		state.grid.set_obstacle(Vector2i(6, y), true)
	var walker: BattleStack = _walker(state, Vector2i(5, 5), 7)
	expect_false(BattlePathfinder.reachable(state, walker).has(BattleGrid.index(Vector2i(7, 5))), "walker stopped")
	walker.flying = true
	var reach: Dictionary[int, int] = BattlePathfinder.reachable(state, walker)
	expect_eq(4, reach.get(BattleGrid.index(Vector2i(7, 5)), -1), "flyer over it")
	expect_false(reach.has(BattleGrid.index(Vector2i(6, 5))), "flyer cannot land on the wall")
	BattleFixtures.custom(state, 1, Vector2i(8, 5), 1, 5, 1, 1)
	reach = BattlePathfinder.reachable(state, walker)
	expect_false(reach.has(BattleGrid.index(Vector2i(8, 5))), "flyer cannot land on a stack")
	var route: PackedInt32Array = BattlePathfinder.path(state, walker, Vector2i(9, 5))
	expect_eq(PackedInt32Array([BattleGrid.index(Vector2i(9, 5))]), route, "straight flight")


func _walker(state: BattleState, anchor: Vector2i, speed: int, size: int = 1) -> BattleStack:
	var stack: BattleStack = BattleStack.new()
	stack.count = 1
	stack.hp = 1
	stack.top_hp = 1
	stack.speed = speed
	stack.size = size
	state.add_stack(stack, anchor)
	return stack


func _reaches_column(state: BattleState, stack: BattleStack, column: int) -> bool:
	for cell_index: int in BattlePathfinder.reachable(state, stack):
		if BattleGrid.cell_at(cell_index).x >= column:
			return true
	return false


func _expect_valid_route(state: BattleState, stack: BattleStack, route: PackedInt32Array, cost: int) -> void:
	var total: int = 0
	var from: Vector2i = stack.cell
	for cell_index: int in route:
		var to: Vector2i = BattleGrid.cell_at(cell_index)
		var step: Vector2i = to - from
		expect_true(absi(step.x) <= 1 and absi(step.y) <= 1 and step != Vector2i.ZERO, "one step %s" % step)
		expect_true(state.grid.can_step(from, step, stack.size, stack.id), "legal step to %s" % to)
		total += BattleGrid.step_cost(step)
		from = to
	expect_eq(cost, total, "route cost")
