extends TestSuite

## BattleState.validate / apply: every invalid command is refused with a reason
## and changes nothing (same digest, no events).


func test_invalid_commands_change_nothing() -> void:
	var state: BattleState = _state()
	var a: BattleStack = state.stacks[0]
	var friend: BattleStack = state.stacks[1]
	var shooter_enemy: BattleStack = state.stacks[2]
	var near_enemy: BattleStack = state.stacks[3]
	var dead: BattleStack = state.stacks[4]
	expect_eq(a.id, state.active_id, "a has the turn")
	var cases: Dictionary = {
		"null": null,
		"not its turn": DefendCmd.new(friend.id),
		"dead stack": WaitCmd.new(dead.id),
		"move nowhere": MoveCmd.new(a.id, a.cell),
		"move too far": MoveCmd.new(a.id, Vector2i(9, 9)),
		"move off the field": MoveCmd.new(a.id, Vector2i(-1, 4)),
		"move onto a stack": MoveCmd.new(a.id, friend.cell),
		"move onto an obstacle": MoveCmd.new(a.id, Vector2i(2, 2)),
		"attack a friend": AttackCmd.new(a.id, friend.id, a.cell),
		"attack the dead": AttackCmd.new(a.id, dead.id, a.cell),
		"attack nobody": AttackCmd.new(a.id, 99, a.cell),
		"attack from afar": AttackCmd.new(a.id, shooter_enemy.id, a.cell),
		"attack from out of reach": AttackCmd.new(a.id, shooter_enemy.id, Vector2i(10, 1)),
		"shoot without a bow": ShootCmd.new(a.id, shooter_enemy.id),
		"surrender out of turn": SurrenderCmd.new(1),
	}
	for label: String in cases:
		_expect_refused(state, cases[label], label)
	expect_eq("", state.validate(AttackCmd.new(a.id, near_enemy.id, a.cell)), "a valid attack passes")


func test_shooter_rules() -> void:
	var state: BattleState = _state()
	state.apply(DefendCmd.new(state.active_id))
	state.apply(DefendCmd.new(state.active_id))
	var shooter: BattleStack = state.active_stack()
	expect_eq(2, shooter.id, "the enemy shooter's turn")
	_expect_refused(state, ShootCmd.new(shooter.id, 3), "shoot a friend")
	expect_eq("", state.validate(ShootCmd.new(shooter.id, 0)), "shot allowed")
	shooter.shots_left = 0
	_expect_refused(state, ShootCmd.new(shooter.id, 0), "no shots")


func test_wait_once() -> void:
	var state: BattleState = _state()
	var a: BattleStack = state.active_stack()
	expect_true(state.apply(WaitCmd.new(a.id)), "first wait")
	for i: int in 10:
		if state.active_id == a.id:
			break
		state.apply(DefendCmd.new(state.active_id))
	expect_eq(a.id, state.active_id, "a back in the same round")
	_expect_refused(state, WaitCmd.new(a.id), "second wait")
	expect_true(state.apply(DefendCmd.new(a.id)), "acting is fine")


func test_surrender_and_after_the_end() -> void:
	var state: BattleState = _state()
	state.take_events()
	expect_true(state.apply(SurrenderCmd.new(0)), "the side in turn surrenders")
	expect_true(state.is_over(), "battle over")
	expect_eq(1, state.result.winner, "the other side wins")
	expect_eq(BattleResult.EndedBy.SURRENDER, state.result.ended_by, "by surrender")
	var kinds: Array = []
	for event: BattleEvent in state.take_events():
		kinds.append(event.kind)
	expect_eq([BattleEvent.Kind.SURRENDERED, BattleEvent.Kind.BATTLE_ENDED], kinds, "events")
	_expect_refused(state, DefendCmd.new(0), "nothing after the end")
	_expect_refused(state, SurrenderCmd.new(1), "no second surrender")


## a (side 0, active), its friend, an enemy shooter far away, an enemy next to
## a, and a dead enemy; an obstacle at (2, 2).
func _state() -> BattleState:
	var state: BattleState = BattleFixtures.empty_state(17)
	state.grid.set_obstacle(Vector2i(2, 2), true)
	BattleFixtures.add(state, &"throne_militia", 10, 0, Vector2i(1, 3), 10000)
	BattleFixtures.add(state, &"throne_militia", 10, 0, Vector2i(1, 5), 9950)
	BattleFixtures.add(state, &"coven_lizard_thrower", 10, 1, Vector2i(11, 0), 9900)
	BattleFixtures.add(state, &"coven_sporeling", 10, 1, Vector2i(2, 4), 0)
	var dead: BattleStack = BattleFixtures.add(state, &"coven_sporeling", 10, 1, Vector2i(6, 6), 0)
	dead.count = 0
	state.grid.remove(dead.id, dead.cell, dead.size)
	state.start()
	state.take_events()
	return state


func _expect_refused(state: BattleState, cmd: BattleCmd, label: String) -> void:
	state.take_events()
	var before: String = state.digest()
	expect_ne("", state.validate(cmd), "%s: has a reason" % label)
	expect_false(state.apply(cmd), "%s: refused" % label)
	expect_eq(before, state.digest(), "%s: state unchanged" % label)
	expect_eq(0, state.events.size(), "%s: no events" % label)
