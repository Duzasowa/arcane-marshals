extends TestSuite

## "Swallow": after the blow, one weak creature per own creature is gone; a
## strong stack is safe; never more than there are.


func test_swallows_weak_creatures() -> void:
	var state: BattleState = BattleFixtures.empty_state(20)
	var toad: BattleStack = BattleFixtures.custom(state, 0, Vector2i(4, 4), 3, 100, 1, 1, 10, 10000)
	var weak: BattleStack = BattleFixtures.custom(state, 1, Vector2i(5, 4), 20, 10, 1, 1)
	BattleFixtures.give(toad, &"swallow")
	state.start()
	state.take_events()
	state.apply(AttackCmd.new(toad.id, weak.id, toad.cell))
	var events: Array[BattleEvent] = state.take_events()
	# The blow (3 damage) leaves 20 creatures, the top one with 7 HP; 3 are swallowed.
	expect_eq(17, weak.count, "3 more gone")
	expect_eq(10, weak.top_hp, "whole creatures")
	expect_eq(1, AbilityTestKit.count(events, BattleEvent.Kind.ABILITY), "reported")


func test_strong_creatures_are_safe() -> void:
	var state: BattleState = BattleFixtures.empty_state(21)
	var toad: BattleStack = BattleFixtures.custom(state, 0, Vector2i(4, 4), 3, 100, 1, 1, 10, 10000)
	var strong: BattleStack = BattleFixtures.custom(state, 1, Vector2i(5, 4), 20, 40, 1, 1)
	BattleFixtures.give(toad, &"swallow")
	state.start()
	state.apply(AttackCmd.new(toad.id, strong.id, toad.cell))
	expect_eq(20, strong.count, "only the blow")


func test_not_more_than_there_are() -> void:
	var state: BattleState = BattleFixtures.empty_state(22)
	var toad: BattleStack = BattleFixtures.custom(state, 0, Vector2i(4, 4), 10, 100, 1, 1, 10, 10000)
	var weak: BattleStack = BattleFixtures.custom(state, 1, Vector2i(5, 4), 4, 10, 1, 1)
	BattleFixtures.custom(state, 1, Vector2i(11, 9), 10, 100, 1, 1)
	BattleFixtures.give(toad, &"swallow")
	state.start()
	state.apply(AttackCmd.new(toad.id, weak.id, toad.cell))
	expect_false(weak.is_alive(), "all swallowed")
	expect_true(weak.lost() == 4, "four lost")
