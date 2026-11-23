extends TestSuite

## BattleArena geometry: cell centres and the cell under a ground point agree,
## and the arena builds one highlight quad per cell and one rock per obstacle.


func test_cell_round_trip() -> void:
	for cell_index: int in BattleGrid.CELL_COUNT:
		var cell: Vector2i = BattleGrid.cell_at(cell_index)
		expect_eq(cell, BattleArena.world_to_cell(BattleArena.cell_center(cell)), "cell %s" % cell)
	expect_eq(Vector3.ZERO, BattleArena.cell_center(Vector2i(5, 4), 2), "a 2x2 in the middle is centred")
	expect_eq(Vector2i(-1, 0), BattleArena.world_to_cell(Vector3(-6.2, 0.0, -4.5)), "left of the field")


func test_build() -> void:
	var grid: BattleGrid = BattleGrid.new()
	grid.set_obstacle(Vector2i(5, 5), true)
	grid.set_obstacle(Vector2i(6, 5), true)
	var arena: BattleArena = BattleArena.new()
	arena.build(grid)
	expect_eq(BattleGrid.CELL_COUNT, arena.get_node("Highlights").get_child_count(), "one quad per cell")
	expect_eq(2, arena.get_node("Obstacles").get_child_count(), "one rock per obstacle")
	arena.highlight(Vector2i(10, 8), BattleArena.Highlight.TARGET, 2)
	var shown: int = 0
	for quad: Node in arena.get_node("Highlights").get_children():
		if (quad as MeshInstance3D).visible:
			shown += 1
	expect_eq(4, shown, "2x2 highlight")
	arena.clear_highlights()
	expect_true(arena.is_grid_visible(), "grid shown by default")
	arena.set_grid_visible(false)
	expect_false(arena.is_grid_visible(), "grid hidden")
	arena.free()
