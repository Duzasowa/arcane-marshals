extends TestSuite

## "No retaliation": the target does not answer and keeps its retaliation;
## the knight's variant spares only a wounded target, judged before the blow.


func test_target_does_not_answer() -> void:
	var state: BattleState = BattleFixtures.empty_state(16)
	var attacker: BattleStack = BattleFixtures.custom(state, 0, Vector2i(4, 4), 10, 100, 2, 2, 10, 10000)
	var target: BattleStack = BattleFixtures.custom(state, 1, Vector2i(5, 4), 10, 100, 1, 1)
	BattleFixtures.give(attacker, &"no_retaliation")
	state.start()
	expect_eq({}, BattleForecast.retaliation(state, attacker, attacker.cell, target, 1), "forecast: none")
	state.take_events()
	state.apply(AttackCmd.new(attacker.id, target.id, attacker.cell))
	expect_eq(0, AbilityTestKit.count(state.take_events(), BattleEvent.Kind.RETALIATED), "no answer")
	expect_eq(1, target.retaliations_left, "kept")


func test_does_not_spare_its_own_target_when_attacked() -> void:
	var state: BattleState = BattleFixtures.empty_state(17)
	var enemy: BattleStack = BattleFixtures.custom(state, 0, Vector2i(4, 4), 10, 100, 2, 2, 10, 10000)
	var owner: BattleStack = BattleFixtures.custom(state, 1, Vector2i(5, 4), 10, 100, 1, 1)
	BattleFixtures.give(owner, &"no_retaliation")
	state.start()
	state.take_events()
	state.apply(AttackCmd.new(enemy.id, owner.id, enemy.cell))
	expect_eq(1, AbilityTestKit.count(state.take_events(), BattleEvent.Kind.RETALIATED), "the owner answers")


func test_wounded_only() -> void:
	expect_eq(1, _answers(false), "a whole target answers, though the blow wounds it")
	expect_eq(0, _answers(true), "a wounded target does not")


func _answers(wounded: bool) -> int:
	var state: BattleState = BattleFixtures.empty_state(18)
	var knight: BattleStack = BattleFixtures.custom(state, 0, Vector2i(4, 4), 10, 100, 2, 2, 10, 10000)
	var target: BattleStack = BattleFixtures.custom(state, 1, Vector2i(5, 4), 10, 100, 1, 1)
	BattleFixtures.give(knight, &"no_retaliation_wounded")
	if wounded:
		target.take_damage(5)
	state.start()
	var forecast: Dictionary = BattleForecast.retaliation(state, knight, knight.cell, target, 20)
	expect_eq(wounded, forecast.is_empty(), "the forecast agrees (wounded %s)" % wounded)
	state.take_events()
	state.apply(AttackCmd.new(knight.id, target.id, knight.cell))
	return AbilityTestKit.count(state.take_events(), BattleEvent.Kind.RETALIATED)
