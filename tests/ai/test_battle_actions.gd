extends TestSuite

## `BattleActions.all`: every action it offers is valid, none twice; no shots
## next to an enemy; no second wait before acting.

const SEEDS: Array[int] = [3, 8, 21]
const CHECK_EVERY: int = 4
const MAX_ACTIONS: int = 400


func test_every_action_is_valid_and_unique() -> void:
	for seed_value: int in SEEDS:
		var state: BattleState = BattleSetup.create(BattleFixtures.data(), BattleFixtures.random_army(seed_value, 0),
				BattleFixtures.random_army(seed_value, 1), seed_value)
		var played: int = 0
		while not state.is_over() and played < MAX_ACTIONS:
			if played % CHECK_EVERY == 0:
				_check_all(state, "seed %d action %d" % [seed_value, played])
			state.apply(BattleNearestBot.choose(state))
			played += 1
		expect_true(state.is_over(), "seed %d ended" % seed_value)


func test_no_shots_next_to_an_enemy() -> void:
	var state: BattleState = BattleFixtures.empty_state(1)
	var shooter: BattleStack = BattleFixtures.add(state, &"throne_crossbowman", 10, 0, Vector2i(4, 4), 10000)
	var close: BattleStack = BattleFixtures.add(state, &"coven_sporeling", 10, 1, Vector2i(5, 4))
	BattleFixtures.add(state, &"coven_sporeling", 10, 1, Vector2i(10, 4))
	state.start()
	var actions: Array[BattleCmd] = BattleActions.all(state)
	var shots: int = 0
	var strikes_here: int = 0
	for cmd: BattleCmd in actions:
		if cmd is ShootCmd:
			shots += 1
		elif cmd is AttackCmd and (cmd as AttackCmd).target_id == close.id and (cmd as AttackCmd).from == shooter.cell:
			strikes_here += 1
	expect_eq(0, shots, "no shots")
	expect_eq(1, strikes_here, "may strike the neighbour where it stands")


func test_shots_at_every_enemy_when_free() -> void:
	var state: BattleState = BattleFixtures.empty_state(2)
	BattleFixtures.add(state, &"throne_crossbowman", 10, 0, Vector2i(0, 4), 10000)
	BattleFixtures.add(state, &"coven_sporeling", 10, 1, Vector2i(10, 2))
	BattleFixtures.add(state, &"coven_sporeling", 10, 1, Vector2i(10, 6))
	state.start()
	var shots: int = 0
	for cmd: BattleCmd in BattleActions.all(state):
		if cmd is ShootCmd:
			shots += 1
	expect_eq(2, shots, "one shot per enemy")


func test_wait_only_once() -> void:
	var state: BattleState = BattleFixtures.empty_state(3)
	var waiter: BattleStack = BattleFixtures.add(state, &"throne_crossbowman", 10, 0, Vector2i(0, 0), 10000)
	BattleFixtures.add(state, &"throne_militia", 10, 1, Vector2i(11, 9), 0)
	state.start()
	expect_true(_has_wait(BattleActions.all(state)), "may wait")
	expect_true(state.apply(WaitCmd.new(waiter.id)), "waits")
	expect_eq(waiter.id, state.active_id, "its turn again in the same round")
	expect_false(_has_wait(BattleActions.all(state)), "may not wait twice")


func test_nothing_after_the_end() -> void:
	var state: BattleState = BattleFixtures.empty_state(4)
	var who: BattleStack = BattleFixtures.add(state, &"throne_militia", 10, 0, Vector2i(0, 0), 10000)
	BattleFixtures.add(state, &"throne_militia", 1, 1, Vector2i(11, 9), 0)
	state.start()
	state.apply(SurrenderCmd.new(who.side))
	expect_eq(0, BattleActions.all(state).size(), "no actions")


func _check_all(state: BattleState, label: String) -> void:
	var seen: Dictionary[String, bool] = {}
	var actions: Array[BattleCmd] = BattleActions.all(state)
	expect_true(actions.size() >= 1, "%s: something to do" % label)
	expect_true(actions.back() is DefendCmd, "%s: defend last" % label)
	for cmd: BattleCmd in actions:
		var key: String = _key(cmd)
		var reason: String = state.validate(cmd)
		if reason != "":
			fail("%s: %s refused: %s" % [label, key, reason])
			return
		if seen.has(key):
			fail("%s: %s twice" % [label, key])
			return
		seen[key] = true


static func _key(cmd: BattleCmd) -> String:
	if cmd is MoveCmd:
		return "move %d %s" % [cmd.stack_id, (cmd as MoveCmd).to]
	if cmd is AttackCmd:
		return "attack %d %d %s" % [cmd.stack_id, (cmd as AttackCmd).target_id, (cmd as AttackCmd).from]
	if cmd is ShootCmd:
		return "shoot %d %d" % [cmd.stack_id, (cmd as ShootCmd).target_id]
	return cmd.describe()


static func _has_wait(actions: Array[BattleCmd]) -> bool:
	for cmd: BattleCmd in actions:
		if cmd is WaitCmd:
			return true
	return false
