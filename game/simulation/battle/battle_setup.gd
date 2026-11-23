class_name BattleSetup
extends RefCounted

## Builds a battle from two armies: deploys the stacks at the edges, scatters
## obstacles that leave a way between the armies, rolls the starting ATB and
## starts the first turn (docs/MECHANICS.md §1, §2).

## Edge columns of each side, never blocked by obstacles.
const DEPLOY_COLUMNS: int = 2
const OBSTACLE_MIN_X: int = DEPLOY_COLUMNS
const OBSTACLE_MAX_X: int = BattleGrid.WIDTH - DEPLOY_COLUMNS - 1
const BIG_SHAPES: Array[Vector2i] = [Vector2i(2, 2), Vector2i(2, 3), Vector2i(3, 2)]
const BIG_MIN: int = 1
const BIG_MAX: int = 2
const SMALL_MIN: int = 0
const SMALL_MAX: int = 5
const MAX_OBSTACLE_CELLS: int = 18
## Random positions tried for one obstacle before it is dropped.
const PLACE_TRIES: int = 12
## Obstacle layouts tried before the field is left open.
const OBSTACLE_ATTEMPTS: int = 20
## The widest walker the way between the armies must let through.
const PASSAGE_SIZE: int = 2


static func create(data: GameData, attacker: BattleSideSetup, defender: BattleSideSetup,
		seed_value: int) -> BattleState:
	var state: BattleState = BattleState.new(seed_value)
	var setups: Array[BattleSideSetup] = [attacker, defender]
	for side: int in BattleState.SIDE_COUNT:
		state.sides[side] = setups[side].bonuses.copy()
		deploy(state, data, setups[side], side)
	generate_obstacles(state)
	for stack: BattleStack in state.stacks:
		stack.atb = state.rng.range_int(0, AtbTimeline.START_MAX)
	# Heroes roll after the stacks: a battle without heroes rolls as it always did.
	for side: int in BattleState.SIDE_COUNT:
		if setups[side].has_hero():
			state.heroes[side] = make_hero(data, setups[side], side)
			state.sides[side].attack += state.heroes[side].attack
			state.sides[side].defence += state.heroes[side].defence
			state.heroes[side].atb = state.rng.range_int(0, AtbTimeline.START_MAX)
	state.start()
	return state


## The battle hero of a side setup: its attributes, mana and spell book.
static func make_hero(data: GameData, setup: BattleSideSetup, side: int) -> BattleHero:
	var hero: BattleHero = BattleHero.new()
	hero.hero_id = setup.hero_id
	hero.side = side
	var attributes: PackedInt32Array = setup.hero_attributes
	if attributes.size() == GameData.ATTRIBUTES.size():
		hero.attack = attributes[0]
		hero.defence = attributes[1]
		hero.power = attributes[2]
		hero.knowledge = attributes[3]
	hero.max_mana = maxi(0, hero.knowledge) * BattleHero.MANA_PER_KNOWLEDGE
	hero.mana = hero.max_mana if setup.hero_mana < 0 else setup.hero_mana
	for spell_id: StringName in setup.hero_spells:
		var spell: SpellDef = data.spell(spell_id)
		if spell == null:
			push_error("BattleSetup: unknown spell '%s'" % spell_id)
		elif hero.spell(spell_id).is_empty():
			hero.spells.append(SpellCast.entry_of(spell))
	return hero


## Puts the stacks of one side at its edge, spread evenly over the height.
## When they do not fit in one column, fills columns from the edge inwards.
static func deploy(state: BattleState, data: GameData, setup: BattleSideSetup, side: int) -> void:
	var stacks: Array[BattleStack] = []
	var rows_needed: int = 0
	for slot: int in BattleSideSetup.MAX_SLOTS:
		var unit_id: StringName = setup.slot_units[slot]
		var count: int = setup.slot_counts[slot]
		if unit_id == &"" or count <= 0:
			continue
		var unit: UnitDef = data.unit(unit_id)
		if unit == null:
			push_error("BattleSetup: unknown unit '%s'" % unit_id)
			continue
		var stack: BattleStack = BattleStack.from_unit(unit, side, slot, count)
		stack.power = PowerEstimator.power(unit, data)
		for ability_id: StringName in unit.abilities:
			var ability: AbilityDef = data.ability(ability_id)
			if ability != null:
				stack.abilities.append(AbilityHooks.entry_of(ability))
		stacks.append(stack)
		rows_needed += stack.size
	if rows_needed <= BattleGrid.HEIGHT:
		var spare: int = BattleGrid.HEIGHT - rows_needed
		var used: int = 0
		for i: int in stacks.size():
			var stack: BattleStack = stacks[i]
			var y: int = used + spare * (i + 1) / (stacks.size() + 1)
			state.add_stack(stack, Vector2i(_edge_x(side, stack.size, 0), y))
			used += stack.size
		return
	for stack: BattleStack in stacks:
		state.add_stack(stack, _first_free(state, side, stack.size))


## Obstacles in the middle columns: 1–2 big ones and 0–5 single cells, at most
## 18 cells, never next to a stack; retried until a 2 × 2 walker can cross.
static func generate_obstacles(state: BattleState) -> void:
	for attempt: int in OBSTACLE_ATTEMPTS:
		_clear_obstacles(state.grid)
		var used: int = 0
		var big_count: int = state.rng.range_int(BIG_MIN, BIG_MAX)
		for i: int in big_count:
			var shape: Vector2i = BIG_SHAPES[state.rng.pick_index(BIG_SHAPES.size())]
			used += _place_obstacle(state, shape, MAX_OBSTACLE_CELLS - used)
		var small_count: int = state.rng.range_int(SMALL_MIN, SMALL_MAX)
		for i: int in small_count:
			used += _place_obstacle(state, Vector2i.ONE, MAX_OBSTACLE_CELLS - used)
		if has_passage(state.grid, PASSAGE_SIZE):
			return
	_clear_obstacles(state.grid)


## Whether a walker of `size` can get from the left edge to the right one
## past the obstacles (stacks are ignored: they move).
static func has_passage(grid: BattleGrid, size: int) -> bool:
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(BattleGrid.CELL_COUNT)
	seen.fill(0)
	var queue: Array[Vector2i] = []
	for y: int in BattleGrid.HEIGHT - size + 1:
		var start: Vector2i = Vector2i(0, y)
		if _open(grid, start, size):
			seen[BattleGrid.index(start)] = 1
			queue.append(start)
	var head: int = 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		if current.x == BattleGrid.WIDTH - size:
			return true
		for direction: Vector2i in BattleGrid.DIRECTIONS:
			var next: Vector2i = current + direction
			if not _open(grid, next, size) or seen[BattleGrid.index(next)] != 0:
				continue
			if direction.x != 0 and direction.y != 0:
				if not _open(grid, current + Vector2i(direction.x, 0), size) \
						or not _open(grid, current + Vector2i(0, direction.y), size):
					continue
			seen[BattleGrid.index(next)] = 1
			queue.append(next)
	return false


static func _edge_x(side: int, size: int, depth: int) -> int:
	return depth if side == 0 else BattleGrid.WIDTH - size - depth


static func _first_free(state: BattleState, side: int, size: int) -> Vector2i:
	for depth: int in BattleGrid.WIDTH / 2 - size + 1:
		for y: int in BattleGrid.HEIGHT - size + 1:
			var anchor: Vector2i = Vector2i(_edge_x(side, size, depth), y)
			if state.grid.is_free(anchor, size):
				return anchor
	push_error("BattleSetup: no room for a stack of side %d" % side)
	return Vector2i.ZERO


## Tries random spots for a `shape` obstacle; returns the cells it took (0 — none).
static func _place_obstacle(state: BattleState, shape: Vector2i, budget: int) -> int:
	if shape.x * shape.y > budget:
		return 0
	for i: int in PLACE_TRIES:
		var anchor: Vector2i = Vector2i(
				state.rng.range_int(OBSTACLE_MIN_X, OBSTACLE_MAX_X - shape.x + 1),
				state.rng.range_int(0, BattleGrid.HEIGHT - shape.y))
		if _can_block(state.grid, anchor, shape):
			for dy: int in shape.y:
				for dx: int in shape.x:
					state.grid.set_obstacle(anchor + Vector2i(dx, dy), true)
			return shape.x * shape.y
	return 0


## Free of obstacles and of stacks, with no stack touching it.
static func _can_block(grid: BattleGrid, anchor: Vector2i, shape: Vector2i) -> bool:
	for dy: int in range(-1, shape.y + 1):
		for dx: int in range(-1, shape.x + 1):
			var cell: Vector2i = anchor + Vector2i(dx, dy)
			if not BattleGrid.in_bounds(cell):
				continue
			if grid.occupant_at(cell) != BattleGrid.FREE:
				return false
			var inside: bool = dx >= 0 and dy >= 0 and dx < shape.x and dy < shape.y
			if inside and grid.is_obstacle(cell):
				return false
	return true


static func _open(grid: BattleGrid, anchor: Vector2i, size: int) -> bool:
	if not BattleGrid.rect_in_bounds(anchor, size):
		return false
	for cell: Vector2i in BattleGrid.cells_of(anchor, size):
		if grid.is_obstacle(cell):
			return false
	return true


static func _clear_obstacles(grid: BattleGrid) -> void:
	grid.blocked.fill(0)
