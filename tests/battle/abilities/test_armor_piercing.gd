extends TestSuite

## "Armor piercing": the owner's strikes ignore 30% of the target's defence,
## in the battle and in the forecast.


func test_ignores_part_of_the_defence() -> void:
	var plain: Array[int] = _blow(false, false)
	var pierced: Array[int] = _blow(true, false)
	# Defence 20 against attack 0: ×0.5; 30% of it ignored — defence 14: ×0.588.
	expect_eq(500, plain[0], "plain blow")
	expect_eq(588, pierced[0], "pierced blow")
	expect_eq(pierced[0], pierced[1], "the forecast agrees")


func test_works_against_a_defending_target() -> void:
	var plain: Array[int] = _blow(false, true)
	var pierced: Array[int] = _blow(true, true)
	expect_true(pierced[0] > plain[0], "more through the defence stance")
	expect_eq(pierced[0], pierced[1], "the forecast agrees")


## [damage dealt, forecast] of one blow of 100 × 10 on defence 20.
func _blow(piercing: bool, defending: bool) -> Array[int]:
	var state: BattleState = BattleFixtures.empty_state(11)
	var attacker: BattleStack = BattleFixtures.custom(state, 0, Vector2i(4, 4), 100, 10, 10, 10, 10, 10000)
	var target: BattleStack = BattleFixtures.custom(state, 1, Vector2i(5, 4), 1000, 100, 1, 1)
	target.defence = 20
	target.defending = defending
	if piercing:
		BattleFixtures.give(attacker, &"armor_piercing")
	state.start()
	target.defending = defending
	var forecast: Dictionary = DamageCalc.estimate(state, attacker, attacker.cell, target, DamageCalc.Kind.MELEE)
	state.take_events()
	state.apply(AttackCmd.new(attacker.id, target.id, attacker.cell))
	return [AbilityTestKit.first_damage(state.take_events(), target.id), forecast[&"max_damage"]]
