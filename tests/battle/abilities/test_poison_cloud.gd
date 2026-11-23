extends TestSuite

## "Poison cloud": the death of the stack poisons every enemy next to it — the
## killer too — and nobody farther away or on its own side.


func test_poisons_the_neighbours() -> void:
	var state: BattleState = BattleFixtures.empty_state(29)
	var killer: BattleStack = BattleFixtures.custom(state, 0, Vector2i(4, 4), 10, 100, 5, 5, 10, 10000)
	var beside: BattleStack = BattleFixtures.custom(state, 0, Vector2i(5, 5), 10, 100, 1, 1)
	var far: BattleStack = BattleFixtures.custom(state, 0, Vector2i(0, 9), 10, 100, 1, 1)
	var spores: BattleStack = BattleFixtures.custom(state, 1, Vector2i(5, 4), 20, 1, 1, 1)
	var friend: BattleStack = BattleFixtures.custom(state, 1, Vector2i(6, 4), 10, 100, 1, 1)
	BattleFixtures.give(spores, &"poison_cloud")
	state.start()
	state.take_events()
	state.apply(AttackCmd.new(killer.id, spores.id, killer.cell))
	expect_false(spores.is_alive(), "wiped out")
	expect_true(killer.has_effect(&"poison"), "the killer")
	expect_true(beside.has_effect(&"poison"), "the other neighbour")
	expect_false(far.has_effect(&"poison"), "not the far one")
	expect_false(friend.has_effect(&"poison"), "not a friend")
	# 20 spores at the start × 0.3.
	expect_eq(6, int(killer.effects[0][&"params"][&"damage"]), "the cloud's strength")
	expect_eq(2, AbilityTestKit.count(state.take_events(), BattleEvent.Kind.EFFECT_ADDED), "two effects")
