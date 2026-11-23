extends TestSuite

## Shooters: shots, long-range half damage, no shooting with an enemy adjacent,
## half damage in melee (attack and retaliation), no retaliation on shots.


func test_shot_damage_and_range() -> void:
	var state: BattleState = BattleFixtures.empty_state(1)
	var shooter: BattleStack = _shooter(state, Vector2i(0, 0), 10000)
	var near: BattleStack = _target(state, Vector2i(6, 0))
	var far: BattleStack = _target(state, Vector2i(8, 5))
	state.start()
	state.take_events()
	expect_true(state.apply(ShootCmd.new(shooter.id, near.id)), "shot at 6 cells")
	var events: Array[BattleEvent] = state.take_events()
	expect_eq(100, _damage(events), "full damage")
	expect_false(_has(events, BattleEvent.Kind.RETALIATED), "no retaliation on a shot")
	expect_eq(2, shooter.shots_left, "one shot spent")
	_pass_until(state, shooter)
	expect_true(state.apply(ShootCmd.new(shooter.id, far.id)), "shot at 8 cells")
	expect_eq(50, _damage(state.take_events()), "long range: half")


func test_out_of_shots() -> void:
	var state: BattleState = BattleFixtures.empty_state(2)
	var shooter: BattleStack = _shooter(state, Vector2i(0, 0), 10000)
	var target: BattleStack = _target(state, Vector2i(5, 0))
	shooter.shots_left = 0
	state.start()
	expect_eq("no shots left", state.validate(ShootCmd.new(shooter.id, target.id)), "empty quiver")
	expect_false(state.apply(ShootCmd.new(shooter.id, target.id)), "cannot shoot")
	expect_true(state.apply(AttackCmd.new(shooter.id, target.id, Vector2i(4, 0))), "can still fight in melee")


func test_no_shot_with_an_enemy_adjacent() -> void:
	var state: BattleState = BattleFixtures.empty_state(3)
	var shooter: BattleStack = _shooter(state, Vector2i(4, 4), 10000)
	var far: BattleStack = _target(state, Vector2i(9, 4))
	_target(state, Vector2i(5, 5))
	state.start()
	expect_false(state.can_shoot(shooter), "enemy next to it")
	expect_eq("an enemy is next to the shooter", state.validate(ShootCmd.new(shooter.id, far.id)), "reason")
	expect_false(state.apply(ShootCmd.new(shooter.id, far.id)), "refused")


func test_shooter_half_damage_in_melee() -> void:
	var state: BattleState = BattleFixtures.empty_state(4)
	var shooter: BattleStack = _shooter(state, Vector2i(4, 4), 10000)
	var target: BattleStack = _target(state, Vector2i(5, 4))
	state.start()
	state.take_events()
	state.apply(AttackCmd.new(shooter.id, target.id, shooter.cell))
	expect_eq(50, _damage(state.take_events()), "shooter strikes at half")


func test_shooter_half_damage_retaliating() -> void:
	var state: BattleState = BattleFixtures.empty_state(5)
	var shooter: BattleStack = _shooter(state, Vector2i(4, 4), 0)
	var attacker: BattleStack = BattleFixtures.custom(state, 1, Vector2i(5, 4), 1, 1000, 1, 1, 10, 10000)
	state.start()
	state.take_events()
	state.apply(AttackCmd.new(attacker.id, shooter.id, attacker.cell))
	var retaliation: int = 0
	var after_retaliation: bool = false
	for event: BattleEvent in state.take_events():
		if event.kind == BattleEvent.Kind.RETALIATED:
			after_retaliation = true
		elif after_retaliation and event.kind == BattleEvent.Kind.DAMAGED:
			retaliation = event.damage
			break
	expect_eq(50, retaliation, "shooter retaliates at half")


func test_real_crossbowmen_shoot() -> void:
	var state: BattleState = BattleFixtures.empty_state(6)
	var crossbow: BattleStack = BattleFixtures.add(state, &"throne_crossbowman", 12, 0, Vector2i(0, 3), 10000)
	var target: BattleStack = BattleFixtures.add(state, &"coven_sporeling", 20, 1, Vector2i(11, 3))
	state.start()
	var forecast: Dictionary = DamageCalc.estimate(state, crossbow, crossbow.cell, target, DamageCalc.Kind.SHOT)
	state.take_events()
	expect_true(state.apply(ShootCmd.new(crossbow.id, target.id)), "shot across the field")
	expect_between(forecast[&"min_damage"], forecast[&"max_damage"], _damage(state.take_events()), "inside the forecast")


## 10 shooters × 10 damage, attack 0, 3 shots.
func _shooter(state: BattleState, anchor: Vector2i, atb: int) -> BattleStack:
	var shooter: BattleStack = BattleFixtures.custom(state, 0, anchor, 10, 1000, 10, 10, 10, atb)
	shooter.shots = 3
	shooter.shots_left = 3
	return shooter


## A big sponge on side 1, defence 0, slow.
func _target(state: BattleState, anchor: Vector2i) -> BattleStack:
	return BattleFixtures.custom(state, 1, anchor, 10, 1000, 1, 1, 1)


## Defends with everybody else until `who` has the turn again.
func _pass_until(state: BattleState, who: BattleStack) -> void:
	for i: int in 50:
		if state.active_id == who.id:
			state.take_events()
			return
		state.apply(DefendCmd.new(state.active_id))
	fail("stack %d never got the turn" % who.id)


func _damage(events: Array[BattleEvent]) -> int:
	for event: BattleEvent in events:
		if event.kind == BattleEvent.Kind.DAMAGED:
			return event.damage
	fail("no damage event")
	return -1


func _has(events: Array[BattleEvent], kind: BattleEvent.Kind) -> bool:
	for event: BattleEvent in events:
		if event.kind == kind:
			return true
	return false
