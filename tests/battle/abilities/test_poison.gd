extends TestSuite

## "Poison": the target takes damage at the start of each of its next three
## turns, then the effect is gone; poison again renews, not adds; a death from
## poison passes the turn on.


func test_three_turns_of_damage() -> void:
	var state: BattleState = BattleFixtures.empty_state(26)
	var lizards: BattleStack = _lizards(state, 20)
	var target: BattleStack = BattleFixtures.custom(state, 1, Vector2i(9, 4), 100, 100, 1, 1, 10, 0)
	state.start()
	state.apply(ShootCmd.new(lizards.id, target.id))
	expect_true(target.has_effect(&"poison"), "poisoned")
	var poison_hits: int = 0
	var ended: int = 0
	for turn: int in 4:
		state.take_events()
		AbilityTestKit.pass_until(state, target)
		var events: Array[BattleEvent] = state.take_events()
		for event: BattleEvent in events:
			if event.kind == BattleEvent.Kind.DAMAGED and event.target_id == target.id and event.stack_id == -1:
				poison_hits += 1
				expect_eq(10, event.damage, "20 lizards × 0.5")
		ended += AbilityTestKit.count(events, BattleEvent.Kind.EFFECT_ENDED)
		state.apply(DefendCmd.new(target.id))
	expect_eq(3, poison_hits, "three turns")
	expect_eq(1, ended, "then it ends")
	expect_false(target.has_effect(&"poison"), "gone")


func test_poison_again_renews() -> void:
	var state: BattleState = BattleFixtures.empty_state(27)
	var lizards: BattleStack = _lizards(state, 20)
	var target: BattleStack = BattleFixtures.custom(state, 1, Vector2i(9, 4), 100, 100, 1, 1, 10, 0)
	state.start()
	state.apply(ShootCmd.new(lizards.id, target.id))
	AbilityTestKit.pass_until(state, target)
	state.apply(DefendCmd.new(target.id))
	AbilityTestKit.pass_until(state, lizards)
	state.apply(ShootCmd.new(lizards.id, target.id))
	expect_eq(1, target.effects.size(), "one effect")
	# Renewed to 3, and the target's turn began right after the shot: 2 left (1 without renewal).
	expect_eq(2, int(target.effects[0][&"turns"]), "renewed")


func test_death_from_poison_passes_the_turn() -> void:
	var state: BattleState = BattleFixtures.empty_state(28)
	var lizards: BattleStack = _lizards(state, 20)
	var weak: BattleStack = BattleFixtures.custom(state, 1, Vector2i(6, 4), 1, 1000, 1, 1, 10, 5000)
	weak.top_hp = 25
	BattleFixtures.custom(state, 1, Vector2i(9, 8), 10, 100, 1, 1, 10, 0)
	state.start()
	# The shot leaves 5 HP; the weak stack has the next turn, and the poison (10) kills it at its start.
	state.apply(ShootCmd.new(lizards.id, weak.id))
	expect_false(weak.is_alive(), "died of poison")
	expect_false(state.is_over(), "the battle goes on")
	expect_true(state.active_id >= 0 and state.active_id != weak.id, "someone else has the turn")


func _lizards(state: BattleState, count: int) -> BattleStack:
	var lizards: BattleStack = BattleFixtures.custom(state, 0, Vector2i(1, 4), count, 10, 1, 1, 10, 10000)
	lizards.shots = 5
	lizards.shots_left = 5
	BattleFixtures.give(lizards, &"poison")
	return lizards
