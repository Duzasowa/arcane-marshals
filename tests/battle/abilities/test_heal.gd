extends TestSuite

## "Heal": heals a wounded ally and raises its dead, never above the starting
## count; an enemy or a whole ally is not a target; it takes the turn.


func test_heals_and_raises() -> void:
	var state: BattleState = BattleFixtures.empty_state(35)
	var sister: BattleStack = BattleFixtures.custom(state, 0, Vector2i(1, 4), 5, 30, 1, 1, 10, 10000)
	var ally: BattleStack = BattleFixtures.custom(state, 0, Vector2i(1, 6), 10, 10, 1, 1)
	BattleFixtures.custom(state, 1, Vector2i(10, 4), 10, 10, 1, 1)
	BattleFixtures.give(sister, &"heal")
	ally.take_damage(35)
	expect_eq(7, ally.count, "lost three and a half")
	state.start()
	state.take_events()
	expect_true(state.apply(UseAbilityCmd.new(sister.id, &"heal", ally.id)), "heals")
	# 5 sisters × 10 = 50 HP on 65 left: 115, capped at the starting 100.
	expect_eq(10, ally.count, "all raised")
	expect_eq(100, ally.total_hp(), "not above the start")
	var events: Array[BattleEvent] = state.take_events()
	expect_eq(1, AbilityTestKit.count(events, BattleEvent.Kind.HEALED), "reported")
	expect_eq(1, state.turn_count, "the turn is over")


func test_only_wounded_allies() -> void:
	var state: BattleState = BattleFixtures.empty_state(36)
	var sister: BattleStack = BattleFixtures.custom(state, 0, Vector2i(1, 4), 5, 30, 1, 1, 10, 10000)
	var whole: BattleStack = BattleFixtures.custom(state, 0, Vector2i(1, 6), 10, 10, 1, 1)
	var enemy: BattleStack = BattleFixtures.custom(state, 1, Vector2i(10, 4), 10, 10, 1, 1)
	BattleFixtures.give(sister, &"heal")
	enemy.take_damage(15)
	state.start()
	expect_ne("", state.validate(UseAbilityCmd.new(sister.id, &"heal", whole.id)), "a whole ally")
	expect_ne("", state.validate(UseAbilityCmd.new(sister.id, &"heal", enemy.id)), "an enemy")
	expect_ne("", state.validate(UseAbilityCmd.new(sister.id, &"weaken", enemy.id)), "an ability it lacks")
	expect_ne("", state.validate(UseAbilityCmd.new(whole.id, &"heal", whole.id)), "not its turn")
