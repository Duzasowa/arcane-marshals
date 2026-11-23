extends TestSuite

## BattleResult after a fight to the end: winner, losses, experience, survivors.


func test_fight_to_the_end() -> void:
	var state: BattleState = BattleFixtures.empty_state(31)
	var riders: BattleStack = BattleFixtures.add(state, &"throne_outrider", 6, 0, Vector2i(4, 4), 10000)
	var spores: BattleStack = BattleFixtures.add(state, &"coven_sporeling", 30, 1, Vector2i(5, 4))
	state.start()
	for i: int in 200:
		if state.is_over():
			break
		var who: BattleStack = state.active_stack()
		var other: BattleStack = spores if who == riders else riders
		expect_true(state.apply(AttackCmd.new(who.id, other.id, who.cell)), "attack %d" % i)
	expect_true(state.is_over(), "battle ended")
	var result: BattleResult = state.result
	var winner: BattleStack = riders if result.winner == 0 else spores
	var loser: BattleStack = spores if result.winner == 0 else riders
	expect_false(loser.is_alive(), "loser destroyed")
	expect_eq(BattleResult.EndedBy.DESTROYED, result.ended_by, "destroyed")
	expect_eq(loser.initial_count, result.losses[loser.side].get(loser.unit_id, 0), "loser lost all")
	expect_eq(winner.lost(), result.losses[winner.side].get(winner.unit_id, 0), "winner's losses")
	expect_eq(loser.initial_count * loser.exp, result.experience[winner.side], "winner's experience")
	expect_eq(winner.lost() * winner.exp, result.experience[loser.side], "loser's experience")
	expect_eq(winner.count, result.survivors[winner.side][winner.slot], "survivors in the slot")
	expect_eq(0, result.survivors[loser.side][loser.slot], "nobody left")
	expect_eq(state.turn_count, result.turns, "turns")
	expect_eq(1 - result.winner, result.loser(), "loser()")


func test_losses_sum_by_unit_and_slots() -> void:
	var state: BattleState = BattleFixtures.empty_state(32)
	var a: BattleStack = BattleFixtures.add(state, &"throne_militia", 10, 0, Vector2i(0, 0))
	var b: BattleStack = BattleFixtures.add(state, &"throne_militia", 7, 0, Vector2i(0, 4))
	var enemy: BattleStack = BattleFixtures.add(state, &"coven_sporeling", 5, 1, Vector2i(11, 0), 10000)
	a.slot = 2
	b.slot = 5
	a.take_damage(a.hp * 3)
	b.take_damage(b.hp * 2)
	state.start()
	expect_true(state.apply(SurrenderCmd.new(1)), "enemy surrenders")
	var result: BattleResult = state.result
	expect_eq(5, result.losses[0].get(&"throne_militia", 0), "losses of two stacks of one unit summed")
	expect_eq(PackedInt32Array([0, 0, 7, 0, 0, 5, 0]), result.survivors[0], "survivors by slot")
	expect_eq(5 * a.exp, result.experience[1], "experience for the militia killed")
	expect_eq(0, result.experience[0], "nothing killed by side 0")
	expect_eq(5, result.survivors[1][enemy.slot], "the surrendered army is still there")


func test_copy() -> void:
	var result: BattleResult = BattleResult.new()
	result.winner = 1
	result.losses[0][&"x"] = 3
	var copy: BattleResult = result.copy()
	copy.losses[0][&"x"] = 4
	expect_eq(3, result.losses[0][&"x"], "deep copy")
	expect_eq(1, copy.winner, "winner copied")
