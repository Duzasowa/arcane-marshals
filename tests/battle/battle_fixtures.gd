class_name BattleFixtures
extends RefCounted

## Builds battle states for tests: real units from `res://data`, put on chosen
## cells, with chosen ATB values, so a test controls who moves first.

static var _data: GameData = null


static func data() -> GameData:
	if _data == null:
		_data = GameData.new()
		_data.load_all()
	return _data


static func unit(unit_id: StringName) -> UnitDef:
	return data().unit(unit_id)


## A state with no stacks yet.
static func empty_state(seed_value: int = 1) -> BattleState:
	return BattleState.new(seed_value)


## Adds a stack of `unit_id` × `count` for `side` at `anchor`, with `atb`.
static func add(state: BattleState, unit_id: StringName, count: int, side: int, anchor: Vector2i,
		atb: int = 0) -> BattleStack:
	var stack: BattleStack = BattleStack.from_unit(unit(unit_id), side, state.alive_stacks(side).size(), count)
	stack.atb = atb
	state.add_stack(stack, anchor)
	return stack


## A random army of the test units, 1–7 slots of 1–30 creatures; the same
## for the same seed and side.
static func random_army(seed_value: int, side: int) -> BattleSideSetup:
	var rng: SimRng = SimRng.new(seed_value * 2 + side)
	var units: Array[StringName] = []
	for unit_id: StringName in data().units:
		units.append(unit_id)
	var setup: BattleSideSetup = BattleSideSetup.new()
	for i: int in rng.range_int(1, BattleSideSetup.MAX_SLOTS):
		setup.add(units[rng.pick_index(units.size())], rng.range_int(1, 30))
	return setup


## Plays bot against bot until the end or `max_actions`; returns the commands.
static func play_out(state: BattleState, max_actions: int = 1000) -> Array[BattleCmd]:
	var played: Array[BattleCmd] = []
	while not state.is_over() and played.size() < max_actions:
		var cmd: BattleCmd = BattleNearestBot.choose(state)
		if not state.apply(cmd):
			push_error("bot command refused: %s — %s" % [cmd.describe(), state.validate(cmd)])
			break
		played.append(cmd)
	return played


## Gives `stack` the ability `ability_id` from `res://data/abilities`, with
## `overrides` put over its params.
static func give(stack: BattleStack, ability_id: StringName, overrides: Dictionary = {}) -> Dictionary:
	var entry: Dictionary = AbilityHooks.entry_of(data().ability(ability_id))
	(entry[&"params"] as Dictionary).merge(overrides, true)
	stack.abilities.append(entry)
	return entry[&"params"]


## A plain test stack, not from data.
static func custom(state: BattleState, side: int, anchor: Vector2i, count: int, hp: int,
		min_dmg: int, max_dmg: int, initiative: int = 10, atb: int = 0) -> BattleStack:
	var stack: BattleStack = BattleStack.new()
	stack.unit_id = &"custom"
	stack.side = side
	stack.count = count
	stack.initial_count = count
	stack.hp = hp
	stack.top_hp = hp
	stack.min_dmg = min_dmg
	stack.max_dmg = max_dmg
	stack.speed = 5
	stack.initiative = initiative
	stack.atb = atb
	var numbers: UnitDef = UnitDef.new()
	numbers.hp = hp
	numbers.min_dmg = min_dmg
	numbers.max_dmg = max_dmg
	numbers.speed = stack.speed
	numbers.initiative = initiative
	stack.power = PowerEstimator.power(numbers)
	state.add_stack(stack, anchor)
	return stack
