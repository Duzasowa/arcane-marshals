class_name BattleGrid
extends RefCounted

## The 12 × 10 battlefield: obstacles and which stack stands where.
##
## A stack of size 2 takes a 2 × 2 square; its `anchor` is the top-left cell.
## Movement is 8-way; a diagonal step needs both orthogonal neighbours free
## (docs/MECHANICS.md §1). Cells are indexed `x + y * WIDTH`.

const WIDTH: int = 12
const HEIGHT: int = 10
const CELL_COUNT: int = WIDTH * HEIGHT
const FREE: int = -1
const STEP_ORTHOGONAL: int = 2
const STEP_DIAGONAL: int = 3
## Orthogonal directions first, then diagonal: the order of every search.
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
]

## 1 — an obstacle.
var blocked: PackedByteArray = PackedByteArray()
## Stack id per cell, `FREE` when empty.
var occupant: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	blocked.resize(CELL_COUNT)
	blocked.fill(0)
	occupant.resize(CELL_COUNT)
	occupant.fill(FREE)


static func index(cell: Vector2i) -> int:
	return cell.x + cell.y * WIDTH


static func cell_at(cell_index: int) -> Vector2i:
	return Vector2i(cell_index % WIDTH, cell_index / WIDTH)


static func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < WIDTH and cell.y < HEIGHT


## Whether a stack of `size` fits on the field with its anchor at `anchor`.
static func rect_in_bounds(anchor: Vector2i, size: int) -> bool:
	return in_bounds(anchor) and in_bounds(anchor + Vector2i(size - 1, size - 1))


## The cells a stack of `size` covers with its anchor at `anchor`, row by row.
static func cells_of(anchor: Vector2i, size: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for dy: int in size:
		for dx: int in size:
			cells.append(anchor + Vector2i(dx, dy))
	return cells


static func step_cost(direction: Vector2i) -> int:
	return STEP_DIAGONAL if direction.x != 0 and direction.y != 0 else STEP_ORTHOGONAL


## Cost of the straight 8-way route with no obstacles (flyers, estimates).
static func octile_cost(from: Vector2i, to: Vector2i) -> int:
	var dx: int = absi(to.x - from.x)
	var dy: int = absi(to.y - from.y)
	return STEP_DIAGONAL * mini(dx, dy) + STEP_ORTHOGONAL * absi(dx - dy)


## Chebyshev gap between two squares: 0 — they overlap, 1 — they touch.
static func distance(anchor_a: Vector2i, size_a: int, anchor_b: Vector2i, size_b: int) -> int:
	var dx: int = maxi(0, maxi(anchor_b.x - (anchor_a.x + size_a - 1), anchor_a.x - (anchor_b.x + size_b - 1)))
	var dy: int = maxi(0, maxi(anchor_b.y - (anchor_a.y + size_a - 1), anchor_a.y - (anchor_b.y + size_b - 1)))
	return maxi(dx, dy)


static func adjacent(anchor_a: Vector2i, size_a: int, anchor_b: Vector2i, size_b: int) -> bool:
	return distance(anchor_a, size_a, anchor_b, size_b) == 1


func is_obstacle(cell: Vector2i) -> bool:
	return blocked[index(cell)] != 0


func set_obstacle(cell: Vector2i, on: bool) -> void:
	blocked[index(cell)] = 1 if on else 0


func obstacle_count() -> int:
	var total: int = 0
	for value: int in blocked:
		total += value
	return total


func occupant_at(cell: Vector2i) -> int:
	return occupant[index(cell)]


## Whether a stack of `size` can stand at `anchor`: inside the field, no
## obstacle, no other stack. The stack `ignore_id` does not block itself.
func is_free(anchor: Vector2i, size: int, ignore_id: int = FREE) -> bool:
	if not rect_in_bounds(anchor, size):
		return false
	for cell: Vector2i in cells_of(anchor, size):
		var cell_index: int = index(cell)
		if blocked[cell_index] != 0:
			return false
		var who: int = occupant[cell_index]
		if who != FREE and who != ignore_id:
			return false
	return true


## Whether a walker of `size` at `from` may take one step in `direction`.
func can_step(from: Vector2i, direction: Vector2i, size: int, ignore_id: int = FREE) -> bool:
	if not is_free(from + direction, size, ignore_id):
		return false
	if direction.x != 0 and direction.y != 0:
		return is_free(from + Vector2i(direction.x, 0), size, ignore_id) \
				and is_free(from + Vector2i(0, direction.y), size, ignore_id)
	return true


func place(stack_id: int, anchor: Vector2i, size: int) -> void:
	for cell: Vector2i in cells_of(anchor, size):
		occupant[index(cell)] = stack_id


func remove(stack_id: int, anchor: Vector2i, size: int) -> void:
	for cell: Vector2i in cells_of(anchor, size):
		if occupant[index(cell)] == stack_id:
			occupant[index(cell)] = FREE


func copy() -> BattleGrid:
	var grid: BattleGrid = BattleGrid.new()
	grid.blocked = blocked.duplicate()
	grid.occupant = occupant.duplicate()
	return grid
