class_name BattlePathfinder
extends RefCounted

## Where a stack can move this turn (docs/MECHANICS.md §1): Dijkstra over the
## 120 cells with steps of 2 (orthogonal) and 3 (diagonal), up to `speed × 2`.
## A stack of size 2 needs its whole square free on every step. Flyers ignore
## obstacles and stacks on the way and may land on any free square in range.
## Ties go to the smaller cell index, so the same state gives the same path.

const UNREACHED: int = -1
## `way_to`: no way at all.
const FAR: int = 1 << 30


static func move_budget(stack: BattleStack) -> int:
	return stack.speed * BattleGrid.STEP_ORTHOGONAL


## Anchor cell index -> movement cost, the current cell (cost 0) included,
## in cell index order.
static func reachable(state: BattleState, stack: BattleStack) -> Dictionary[int, int]:
	var costs: PackedInt32Array = _search(state, stack)[0]
	var found: Dictionary[int, int] = {}
	for cell_index: int in BattleGrid.CELL_COUNT:
		if costs[cell_index] != UNREACHED:
			found[cell_index] = costs[cell_index]
	return found


## The cells the stack passes to reach `target`, the start excluded and the
## target last; a flyer flies straight, so its path is the target alone.
## Empty when `target` is the current cell or out of reach.
static func path(state: BattleState, stack: BattleStack, target: Vector2i) -> PackedInt32Array:
	var route: PackedInt32Array = PackedInt32Array()
	if not BattleGrid.in_bounds(target) or target == stack.cell:
		return route
	var search: Array[PackedInt32Array] = _search(state, stack)
	var target_index: int = BattleGrid.index(target)
	if search[0][target_index] == UNREACHED:
		return route
	var start_index: int = BattleGrid.index(stack.cell)
	var current: int = target_index
	while current != start_index:
		route.append(current)
		current = search[1][current]
	route.reverse()
	return route


## [costs, parents] per cell index.
static func _search(state: BattleState, stack: BattleStack) -> Array[PackedInt32Array]:
	var costs: PackedInt32Array = PackedInt32Array()
	costs.resize(BattleGrid.CELL_COUNT)
	costs.fill(UNREACHED)
	var parents: PackedInt32Array = PackedInt32Array()
	parents.resize(BattleGrid.CELL_COUNT)
	parents.fill(UNREACHED)
	var budget: int = move_budget(stack)
	var start_index: int = BattleGrid.index(stack.cell)
	var grid: BattleGrid = state.grid
	costs[start_index] = 0
	if stack.flying:
		for cell_index: int in BattleGrid.CELL_COUNT:
			var anchor: Vector2i = BattleGrid.cell_at(cell_index)
			var cost: int = BattleGrid.octile_cost(stack.cell, anchor)
			if cell_index != start_index and cost <= budget and grid.is_free(anchor, stack.size, stack.id):
				costs[cell_index] = cost
				parents[cell_index] = start_index
		return [costs, parents]
	var done: PackedByteArray = PackedByteArray()
	done.resize(BattleGrid.CELL_COUNT)
	done.fill(0)
	while true:
		var current: int = UNREACHED
		for cell_index: int in BattleGrid.CELL_COUNT:
			if done[cell_index] == 0 and costs[cell_index] != UNREACHED \
					and (current == UNREACHED or costs[cell_index] < costs[current]):
				current = cell_index
		if current == UNREACHED:
			break
		done[current] = 1
		var from: Vector2i = BattleGrid.cell_at(current)
		for direction: Vector2i in BattleGrid.DIRECTIONS:
			var cost: int = costs[current] + BattleGrid.step_cost(direction)
			if cost > budget or not grid.can_step(from, direction, stack.size, stack.id):
				continue
			var next_index: int = BattleGrid.index(from + direction)
			if done[next_index] != 0:
				continue
			if costs[next_index] == UNREACHED or cost < costs[next_index]:
				costs[next_index] = cost
				parents[next_index] = current
	return [costs, parents]


## Walking cost from every anchor to the nearest spot next to any of `targets`
## for a stack of `walker`'s size, around obstacles; other stacks are ignored
## (they move). Flyers: straight lines. `FAR` — no way. For bots and the AI
## to head somewhere beyond this turn's reach.
static func way_to(state: BattleState, walker: BattleStack, targets: Array[BattleStack]) -> PackedInt32Array:
	var field: PackedInt32Array = PackedInt32Array()
	field.resize(BattleGrid.CELL_COUNT)
	field.fill(FAR)
	for cell_index: int in BattleGrid.CELL_COUNT:
		var anchor: Vector2i = BattleGrid.cell_at(cell_index)
		for target: BattleStack in targets:
			var gap: int = BattleGrid.distance(anchor, walker.size, target.cell, target.size)
			if walker.flying:
				field[cell_index] = mini(field[cell_index], maxi(0, gap - 1) * BattleGrid.STEP_ORTHOGONAL)
			elif gap == 1 and _open(state.grid, anchor, walker.size):
				field[cell_index] = 0
	if walker.flying:
		return field
	var done: PackedByteArray = PackedByteArray()
	done.resize(BattleGrid.CELL_COUNT)
	done.fill(0)
	while true:
		var current: int = -1
		for cell_index: int in BattleGrid.CELL_COUNT:
			if done[cell_index] == 0 and field[cell_index] < FAR and (current < 0 or field[cell_index] < field[current]):
				current = cell_index
		if current < 0:
			break
		done[current] = 1
		var from: Vector2i = BattleGrid.cell_at(current)
		for direction: Vector2i in BattleGrid.DIRECTIONS:
			var next: Vector2i = from + direction
			if not _open(state.grid, next, walker.size):
				continue
			if direction.x != 0 and direction.y != 0 and (not _open(state.grid, from + Vector2i(direction.x, 0), walker.size)
					or not _open(state.grid, from + Vector2i(0, direction.y), walker.size)):
				continue
			var next_index: int = BattleGrid.index(next)
			var cost: int = field[current] + BattleGrid.step_cost(direction)
			if done[next_index] == 0 and cost < field[next_index]:
				field[next_index] = cost
	return field


## No obstacle under a stack of `size` at `anchor` (stacks ignored).
static func _open(grid: BattleGrid, anchor: Vector2i, size: int) -> bool:
	if not BattleGrid.rect_in_bounds(anchor, size):
		return false
	for cell: Vector2i in BattleGrid.cells_of(anchor, size):
		if grid.is_obstacle(cell):
			return false
	return true
