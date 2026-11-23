extends TestSuite

## The battle AI: reads the state without changing it, repeats itself for the
## same state and seed, plays whole battles with valid commands only, makes
## the plain good choices, and beats the nearest-enemy bot.

const MAX_ACTIONS: int = 1000
const VERSUS_BATTLES: int = 40
## The measurement goal is 80% (scripts/measure_bot_vs_bot.gd); the test keeps
## a margin for the smaller sample.
const VERSUS_MIN_WINS: int = 26


func test_choose_changes_nothing() -> void:
	var state: BattleState = _battle(4)
	for i: int in 10:
		state.apply(BattleNearestBot.choose(state))
	state.take_events()
	var before: String = state.digest()
	for level: int in BattleAi.Difficulty.size():
		var cmd: BattleCmd = BattleAi.new(level as BattleAi.Difficulty, 9).choose(state)
		expect_true(cmd != null, "level %d chose" % level)
		expect_eq(before, state.digest(), "level %d: same digest" % level)
		expect_eq(0, state.take_events().size(), "level %d: no events" % level)


func test_same_state_same_command() -> void:
	var state: BattleState = _battle(5)
	for i: int in 6:
		state.apply(BattleNearestBot.choose(state))
	for level: int in BattleAi.Difficulty.size():
		var first: BattleCmd = BattleAi.new(level as BattleAi.Difficulty, 5).choose(state)
		var second: BattleCmd = BattleAi.new(level as BattleAi.Difficulty, 5).choose(state.clone())
		expect_eq(_key(first), _key(second), "level %d" % level)


func test_whole_battles_with_valid_commands() -> void:
	var pairs: Array[Array] = [
		[BattleAi.Difficulty.NORMAL, BattleAi.Difficulty.EASY],
		[BattleAi.Difficulty.HARD, BattleAi.Difficulty.NORMAL],
	]
	for seed_value: int in range(1, 9):
		var pair: Array = pairs[seed_value % pairs.size()]
		var state: BattleState = _battle(seed_value)
		var ais: Array[BattleAi] = [BattleAi.new(pair[0], seed_value * 2), BattleAi.new(pair[1], seed_value * 2 + 1)]
		var played: int = 0
		while not state.is_over() and played < MAX_ACTIONS:
			var cmd: BattleCmd = ais[state.active_stack().side].choose(state)
			var reason: String = state.validate(cmd)
			if reason != "":
				fail("seed %d: %s refused: %s" % [seed_value, _key(cmd), reason])
				break
			state.apply(cmd)
			played += 1
		expect_true(state.is_over(), "seed %d ended (%d actions)" % [seed_value, played])


func test_shooter_shoots() -> void:
	var state: BattleState = BattleFixtures.empty_state(1)
	BattleFixtures.add(state, &"throne_crossbowman", 10, 0, Vector2i(0, 4), 10000)
	BattleFixtures.add(state, &"throne_militia", 10, 1, Vector2i(11, 4))
	state.start()
	expect_true(_ai().choose(state) is ShootCmd, "shoots from afar")


func test_no_hopeless_attack() -> void:
	# One militia next to twenty outriders: striking only gets it killed by
	# the retaliation, for a scratch.
	var state: BattleState = BattleFixtures.empty_state(2)
	BattleFixtures.add(state, &"throne_militia", 1, 0, Vector2i(5, 4), 10000)
	BattleFixtures.add(state, &"throne_outrider", 20, 1, Vector2i(6, 4))
	state.start()
	var cmd: BattleCmd = _ai().choose(state)
	expect_false(cmd is AttackCmd, "does not strike (chose %s)" % _key(cmd))


func test_strikes_the_one_that_cannot_answer() -> void:
	var state: BattleState = BattleFixtures.empty_state(3)
	BattleFixtures.add(state, &"throne_outrider", 5, 0, Vector2i(5, 4), 10000)
	var answers: BattleStack = BattleFixtures.add(state, &"coven_sporeling", 10, 1, Vector2i(6, 3))
	var spent: BattleStack = BattleFixtures.add(state, &"coven_sporeling", 10, 1, Vector2i(6, 5))
	state.start()
	spent.retaliations_left = 0
	var cmd: BattleCmd = _ai().choose(state)
	expect_true(cmd is AttackCmd, "strikes (chose %s)" % _key(cmd))
	if cmd is AttackCmd:
		expect_eq(spent.id, (cmd as AttackCmd).target_id, "the stack that already retaliated, not %d" % answers.id)


func test_strikes_a_wounded_stack_it_can_wipe_out() -> void:
	# Two equal stacks next to it, one nearly dead: finishing it ends its
	# turns and its retaliation, the other would answer at full strength.
	var state: BattleState = BattleFixtures.empty_state(4)
	BattleFixtures.add(state, &"throne_outrider", 6, 0, Vector2i(5, 4), 10000)
	var whole: BattleStack = BattleFixtures.add(state, &"throne_outrider", 6, 1, Vector2i(6, 3))
	var wounded: BattleStack = BattleFixtures.add(state, &"throne_outrider", 6, 1, Vector2i(6, 5))
	state.start()
	wounded.take_damage(wounded.total_hp() - 20)
	var cmd: BattleCmd = _ai().choose(state)
	expect_true(cmd is AttackCmd, "strikes (chose %s)" % _key(cmd))
	if cmd is AttackCmd:
		expect_eq(wounded.id, (cmd as AttackCmd).target_id, "the wounded stack, not %d" % whole.id)


func test_beats_the_nearest_bot() -> void:
	var wins: int = 0
	for i: int in VERSUS_BATTLES:
		var seed_value: int = 100 + i
		var army: BattleSideSetup = BattleFixtures.random_army(seed_value, 0)
		var state: BattleState = BattleSetup.create(BattleFixtures.data(), army, army, seed_value)
		var ai_side: int = i % 2
		var ai: BattleAi = BattleAi.new(BattleAi.Difficulty.NORMAL, seed_value)
		var played: int = 0
		while not state.is_over() and played < MAX_ACTIONS:
			var cmd: BattleCmd = ai.choose(state) if state.active_stack().side == ai_side \
					else BattleNearestBot.choose(state)
			state.apply(cmd)
			played += 1
		if state.is_over() and state.result.winner == ai_side:
			wins += 1
	expect_true(wins >= VERSUS_MIN_WINS, "AI won %d of %d (need %d)" % [wins, VERSUS_BATTLES, VERSUS_MIN_WINS])


func _ai() -> BattleAi:
	return BattleAi.new(BattleAi.Difficulty.NORMAL, 11)


func _battle(seed_value: int) -> BattleState:
	return BattleSetup.create(BattleFixtures.data(), BattleFixtures.random_army(seed_value, 0),
			BattleFixtures.random_army(seed_value, 1), seed_value)


static func _key(cmd: BattleCmd) -> String:
	if cmd == null:
		return "null"
	if cmd is MoveCmd:
		return "move %d %s" % [cmd.stack_id, (cmd as MoveCmd).to]
	if cmd is AttackCmd:
		return "attack %d %d %s" % [cmd.stack_id, (cmd as AttackCmd).target_id, (cmd as AttackCmd).from]
	if cmd is ShootCmd:
		return "shoot %d %d" % [cmd.stack_id, (cmd as ShootCmd).target_id]
	return cmd.describe()
