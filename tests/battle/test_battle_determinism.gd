extends TestSuite

## The same seed and the same commands give the same battle; 100 random
## battles of bot against bot all end without a refused command.

const RANDOM_BATTLES: int = 100
const MAX_ACTIONS: int = 1000


func test_random_battles_end() -> void:
	var wins: Array[int] = [0, 0]
	var longest: int = 0
	for seed_value: int in range(1, RANDOM_BATTLES + 1):
		var state: BattleState = _battle(seed_value)
		var played: Array[BattleCmd] = BattleFixtures.play_out(state, MAX_ACTIONS)
		expect_true(state.is_over(), "seed %d ended (%d actions)" % [seed_value, played.size()])
		if state.is_over():
			wins[state.result.winner] += 1
			expect_true(state.alive_stacks(state.result.loser()).is_empty(), "seed %d: loser destroyed" % seed_value)
		longest = maxi(longest, played.size())
	expect_eq(RANDOM_BATTLES, wins[0] + wins[1], "every battle has a winner")
	expect_true(longest < MAX_ACTIONS, "longest battle: %d actions" % longest)


func test_same_seed_same_battle() -> void:
	var first: BattleState = _battle(42)
	var played: Array[BattleCmd] = BattleFixtures.play_out(first)
	var second: BattleState = _battle(42)
	BattleFixtures.play_out(second)
	expect_eq(first.digest(), second.digest(), "bot against bot twice")
	var replay: BattleState = _battle(42)
	for cmd: BattleCmd in played:
		expect_true(replay.apply(cmd), "replayed %s" % cmd.describe())
	expect_eq(first.digest(), replay.digest(), "recorded commands replayed")
	expect_ne(first.digest(), _finished(43).digest(), "another seed, another battle")


func test_clone_continues_the_same() -> void:
	var state: BattleState = _battle(7)
	for i: int in 15:
		state.apply(BattleNearestBot.choose(state))
	var copy: BattleState = state.clone()
	expect_eq(state.digest(), copy.digest(), "copy mid-battle")
	BattleFixtures.play_out(state)
	BattleFixtures.play_out(copy)
	expect_eq(state.digest(), copy.digest(), "both copies end the same")


func test_field_digests_point_at_the_difference() -> void:
	var a: BattleState = _battle(9)
	var b: BattleState = _battle(9)
	b.stacks[0].count += 1
	var digests_a: Dictionary = StateHasher.field_digests(a)
	var digests_b: Dictionary = StateHasher.field_digests(b)
	expect_ne(digests_a[&"stacks"], digests_b[&"stacks"], "stacks differ")
	expect_eq(digests_a[&"grid"], digests_b[&"grid"], "grid the same")
	expect_false(digests_a.has(&"events"), "events not hashed")


func _battle(seed_value: int) -> BattleState:
	return BattleSetup.create(BattleFixtures.data(), BattleFixtures.random_army(seed_value, 0),
			BattleFixtures.random_army(seed_value, 1), seed_value)


func _finished(seed_value: int) -> BattleState:
	var state: BattleState = _battle(seed_value)
	BattleFixtures.play_out(state)
	return state
