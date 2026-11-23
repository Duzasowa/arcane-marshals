extends TestSuite

## "Weaken": any enemy; its blows and the blows on it change by −4 attack and
## −4 defence; after three of its turns all is as before.


func test_weakens_for_three_turns() -> void:
	var state: BattleState = BattleFixtures.empty_state(37)
	var witch: BattleStack = BattleFixtures.custom(state, 0, Vector2i(1, 4), 5, 30, 10, 10, 10, 10000)
	var target: BattleStack = BattleFixtures.custom(state, 1, Vector2i(10, 4), 10, 100, 10, 10)
	target.attack = 10
	target.defence = 10
	BattleFixtures.give(witch, &"weaken")
	state.start()
	var dealt: int = _dealt(state, target, witch)
	var taken: int = _dealt(state, witch, target)
	expect_true(state.apply(UseAbilityCmd.new(witch.id, &"weaken", target.id)), "weakens")
	expect_true(target.has_effect(&"weaken"), "under the effect")
	expect_true(_dealt(state, target, witch) < dealt, "hits softer")
	expect_true(_dealt(state, witch, target) > taken, "is hit harder")
	for i: int in 3:
		AbilityTestKit.pass_until(state, target)
		state.apply(DefendCmd.new(target.id))
	expect_false(target.has_effect(&"weaken"), "worn off")
	expect_eq(dealt, _dealt(state, target, witch), "as before")


func _dealt(state: BattleState, attacker: BattleStack, target: BattleStack) -> int:
	return DamageCalc.estimate(state, attacker, attacker.cell, target, DamageCalc.Kind.MELEE)[&"max_damage"]
