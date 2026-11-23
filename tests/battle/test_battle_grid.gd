extends TestSuite

## BattleGrid: bounds, 2 × 2 stacks, occupancy, diagonal steps, distances.


func test_index_round_trip_and_bounds() -> void:
	for cell_index: int in BattleGrid.CELL_COUNT:
		expect_eq(cell_index, BattleGrid.index(BattleGrid.cell_at(cell_index)), "index %d" % cell_index)
	expect_true(BattleGrid.in_bounds(Vector2i(11, 9)), "last cell inside")
	expect_false(BattleGrid.in_bounds(Vector2i(12, 0)), "x = 12 outside")
	expect_false(BattleGrid.in_bounds(Vector2i(0, -1)), "y = -1 outside")


func test_big_stack_near_the_edge() -> void:
	expect_true(BattleGrid.rect_in_bounds(Vector2i(10, 8), 2), "2x2 in the corner")
	expect_false(BattleGrid.rect_in_bounds(Vector2i(11, 8), 2), "2x2 over the right edge")
	expect_false(BattleGrid.rect_in_bounds(Vector2i(10, 9), 2), "2x2 over the bottom edge")
	expect_eq(4, BattleGrid.cells_of(Vector2i(3, 3), 2).size(), "2x2 covers 4 cells")
	var grid: BattleGrid = BattleGrid.new()
	expect_false(grid.is_free(Vector2i(11, 0), 2), "no room for 2x2 at the edge")


func test_occupancy() -> void:
	var grid: BattleGrid = BattleGrid.new()
	grid.place(3, Vector2i(4, 4), 2)
	expect_eq(3, grid.occupant_at(Vector2i(5, 5)), "2x2 covers its far cell")
	expect_false(grid.is_free(Vector2i(5, 5), 1), "occupied cell")
	expect_true(grid.is_free(Vector2i(4, 4), 2, 3), "a stack does not block itself")
	expect_false(grid.is_free(Vector2i(3, 3), 2), "overlap is not free")
	grid.remove(3, Vector2i(4, 4), 2)
	expect_true(grid.is_free(Vector2i(4, 4), 2), "removed")
	grid.set_obstacle(Vector2i(0, 0), true)
	expect_false(grid.is_free(Vector2i(0, 0), 1), "obstacle blocks")
	expect_eq(1, grid.obstacle_count(), "one obstacle")


func test_diagonal_needs_both_orthogonal_cells() -> void:
	var grid: BattleGrid = BattleGrid.new()
	var from: Vector2i = Vector2i(5, 5)
	expect_true(grid.can_step(from, Vector2i(1, 1), 1), "open diagonal")
	grid.set_obstacle(Vector2i(6, 5), true)
	expect_false(grid.can_step(from, Vector2i(1, 1), 1), "corner cut blocked")
	expect_true(grid.can_step(from, Vector2i(0, 1), 1), "orthogonal still open")
	grid.set_obstacle(Vector2i(6, 5), false)
	grid.place(7, Vector2i(5, 6), 1)
	expect_false(grid.can_step(from, Vector2i(1, 1), 1), "a stack also blocks the corner")
	expect_true(grid.can_step(from, Vector2i(1, 1), 1, 7), "unless it is the walker itself")


func test_big_stack_steps() -> void:
	var grid: BattleGrid = BattleGrid.new()
	grid.place(1, Vector2i(2, 2), 2)
	expect_true(grid.can_step(Vector2i(2, 2), Vector2i(1, 0), 2, 1), "2x2 slides over its own cells")
	grid.set_obstacle(Vector2i(4, 3), true)
	expect_false(grid.can_step(Vector2i(2, 2), Vector2i(1, 0), 2, 1), "obstacle under the new column")
	expect_eq(BattleGrid.STEP_DIAGONAL, BattleGrid.step_cost(Vector2i(-1, 1)), "diagonal cost")
	expect_eq(BattleGrid.STEP_ORTHOGONAL, BattleGrid.step_cost(Vector2i(0, -1)), "orthogonal cost")


func test_distance_between_squares() -> void:
	expect_eq(0, BattleGrid.distance(Vector2i(2, 2), 2, Vector2i(3, 3), 1), "overlap")
	expect_eq(1, BattleGrid.distance(Vector2i(2, 2), 2, Vector2i(4, 4), 1), "touching corner")
	expect_true(BattleGrid.adjacent(Vector2i(2, 2), 2, Vector2i(1, 3), 1), "touching side")
	expect_eq(2, BattleGrid.distance(Vector2i(0, 0), 1, Vector2i(2, 1), 1), "two apart")
	expect_eq(9, BattleGrid.distance(Vector2i(0, 0), 2, Vector2i(10, 0), 2), "across the field")
	expect_eq(8, BattleGrid.octile_cost(Vector2i(0, 0), Vector2i(2, 3)), "3 + 3 + 2")


func test_copy_is_independent() -> void:
	var grid: BattleGrid = BattleGrid.new()
	grid.place(0, Vector2i(1, 1), 1)
	var copy: BattleGrid = grid.copy()
	copy.place(1, Vector2i(2, 2), 1)
	expect_eq(BattleGrid.FREE, grid.occupant_at(Vector2i(2, 2)), "original untouched")
	expect_eq(0, copy.occupant_at(Vector2i(1, 1)), "copy keeps old data")
