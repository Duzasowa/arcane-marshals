extends TestSuite

## "Regeneration": at its turn start the top creature heals fully; the dead do
## not rise; a whole stack gets nothing.


func test_top_creature_heals() -> void:
	var state: BattleState = BattleFixtures.empty_state(30)
	var troll: BattleStack = BattleFixtures.custom(state, 0, Vector2i(4, 4), 10, 40, 1, 1, 10, 10000)
	BattleFixtures.custom(state, 1, Vector2i(9, 4), 10, 100, 1, 1)
	BattleFixtures.give(troll, &"regeneration")
	troll.take_damage(50)
	expect_eq(9, troll.count, "lost one")
	expect_eq(30, troll.top_hp, "top hurt")
	state.start()
	var events: Array[BattleEvent] = state.take_events()
	expect_eq(9, troll.count, "the dead stay dead")
	expect_eq(40, troll.top_hp, "top healed")
	expect_eq(1, AbilityTestKit.count(events, BattleEvent.Kind.HEALED), "reported")
	for event: BattleEvent in events:
		if event.kind == BattleEvent.Kind.HEALED:
			expect_eq(10, event.damage, "10 HP")
			expect_eq(0, event.killed, "nobody raised")


func test_whole_stack_gets_nothing() -> void:
	var state: BattleState = BattleFixtures.empty_state(31)
	var troll: BattleStack = BattleFixtures.custom(state, 0, Vector2i(4, 4), 10, 40, 1, 1, 10, 10000)
	BattleFixtures.custom(state, 1, Vector2i(9, 4), 10, 100, 1, 1)
	BattleFixtures.give(troll, &"regeneration")
	state.start()
	expect_eq(0, AbilityTestKit.count(state.take_events(), BattleEvent.Kind.HEALED), "no event")
	expect_eq(400, troll.total_hp(), "as it was")
