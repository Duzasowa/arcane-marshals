extends TestSuite

## Defend (+30% defence until the own turn), morale (extra turn / lost turn),
## luck (×2 / ×0.5). Seeds are fixed; frequencies are checked with a margin.

const TURNS: int = 400


func test_defend_lowers_damage_until_own_turn() -> void:
	var state: BattleState = BattleFixtures.empty_state(1)
	var defender: BattleStack = BattleFixtures.custom(state, 0, Vector2i(4, 4), 1, 1000, 1, 1, 10, 10000)
	defender.defence = 10
	var attacker: BattleStack = BattleFixtures.custom(state, 1, Vector2i(5, 4), 10, 1000, 10, 10, 10, 9000)
	attacker.attack = 10
	state.start()
	state.take_events()
	expect_true(state.apply(DefendCmd.new(defender.id)), "defend")
	expect_true(defender.defending, "defending")
	expect_eq(attacker.id, state.active_id, "turn passed")
	state.take_events()
	state.apply(AttackCmd.new(attacker.id, defender.id, attacker.cell))
	expect_eq(86, _first_damage(state.take_events()), "D 10 → 13: 100 × 1000 / 1150")
	expect_eq(defender.id, state.active_id, "defender's turn")
	expect_false(defender.defending, "defence ends at its own turn")


func test_good_morale_gives_extra_turns() -> void:
	var counts: Dictionary = _play_moves(3, 0, false)
	expect_between(TURNS * 22 / 100, TURNS * 38 / 100, counts[BattleEvent.Kind.MORALE_GOOD], "morale +3 ≈ 30% of actions")
	expect_eq(0, counts[BattleEvent.Kind.MORALE_BAD], "no bad morale")
	expect_true(counts[&"repeat"] > 0, "a stack with good morale sometimes moves twice in a row")


func test_bad_morale_loses_turns() -> void:
	var counts: Dictionary = _play_moves(-2, 0, false)
	var starts: int = counts[BattleEvent.Kind.TURN_STARTED] + counts[BattleEvent.Kind.MORALE_BAD]
	expect_between(starts * 13 / 100, starts * 27 / 100, counts[BattleEvent.Kind.MORALE_BAD], "morale −2 ≈ 20% of turns")
	expect_eq(0, counts[BattleEvent.Kind.MORALE_GOOD], "no good morale")


func test_no_morale_units_and_defend_never_roll() -> void:
	var counts: Dictionary = _play_moves(3, 0, true)
	expect_eq(0, counts[BattleEvent.Kind.MORALE_GOOD], "no_morale stacks ignore morale")
	var state: BattleState = _duel(7, 3, 0)
	for i: int in 100:
		state.apply(DefendCmd.new(state.active_id))
	var good: int = 0
	for event: BattleEvent in state.take_events():
		if event.kind == BattleEvent.Kind.MORALE_GOOD:
			good += 1
	expect_eq(0, good, "defend gives no morale roll")


func test_luck_doubles_and_halves() -> void:
	for luck: int in [3, -3]:
		var state: BattleState = BattleFixtures.empty_state(21)
		var a: BattleStack = BattleFixtures.custom(state, 0, Vector2i(4, 4), 10, 100000, 10, 10, 10, 10000)
		var b: BattleStack = BattleFixtures.custom(state, 1, Vector2i(5, 4), 10, 100000, 10, 10, 10, 9999)
		state.sides[0].luck = luck
		state.start()
		var lucky: int = 0
		var strikes: int = 0
		for i: int in TURNS:
			var who: BattleStack = state.active_stack()
			state.apply(AttackCmd.new(who.id, (b if who == a else a).id, who.cell))
		var pending_luck: int = DamageCalc.NORMAL
		var attacker_side_zero: bool = false
		for event: BattleEvent in state.take_events():
			match event.kind:
				BattleEvent.Kind.ATTACKED, BattleEvent.Kind.RETALIATED:
					attacker_side_zero = event.stack_id == a.id
					pending_luck = DamageCalc.NORMAL
				BattleEvent.Kind.LUCK_GOOD:
					pending_luck = DamageCalc.LUCK_GOOD
				BattleEvent.Kind.LUCK_BAD:
					pending_luck = DamageCalc.LUCK_BAD
				BattleEvent.Kind.DAMAGED:
					if attacker_side_zero:
						strikes += 1
						expect_eq(100 * pending_luck / DamageCalc.NORMAL, event.damage, "luck %d: damage" % luck)
						if pending_luck != DamageCalc.NORMAL:
							lucky += 1
					else:
						expect_eq(100, event.damage, "the other side has no luck")
		expect_between(strikes * 22 / 100, strikes * 38 / 100, lucky, "luck %d ≈ 30%% of strikes" % luck)


## Two far-apart stacks that only move; `morale` for both sides.
func _duel(seed_value: int, morale: int, luck: int, no_morale: bool = false) -> BattleState:
	var state: BattleState = BattleFixtures.empty_state(seed_value)
	var a: BattleStack = BattleFixtures.custom(state, 0, Vector2i(0, 0), 5, 10, 1, 1, 10, 0)
	var b: BattleStack = BattleFixtures.custom(state, 1, Vector2i(11, 9), 5, 10, 1, 1, 10, 5000)
	a.no_morale = no_morale
	b.no_morale = no_morale
	for side: BattleSide in state.sides:
		side.morale = morale
		side.luck = luck
	state.start()
	return state


## Counts events over TURNS moves back and forth.
func _play_moves(morale: int, luck: int, no_morale: bool) -> Dictionary:
	var state: BattleState = _duel(11, morale, luck, no_morale)
	var counts: Dictionary = {
		BattleEvent.Kind.MORALE_GOOD: 0, BattleEvent.Kind.MORALE_BAD: 0, BattleEvent.Kind.TURN_STARTED: 0, &"repeat": 0,
	}
	var last: int = -1
	for i: int in TURNS:
		var who: BattleStack = state.active_stack()
		if who.id == last:
			counts[&"repeat"] += 1
		last = who.id
		var step: Vector2i = Vector2i(1, 0) if who.cell.x % 2 == 0 else Vector2i(-1, 0)
		if not state.apply(MoveCmd.new(who.id, who.cell + step)):
			fail("move refused: %s" % state.validate(MoveCmd.new(who.id, who.cell + step)))
			break
	for event: BattleEvent in state.take_events():
		if counts.has(event.kind):
			counts[event.kind] += 1
	return counts


func _first_damage(events: Array[BattleEvent]) -> int:
	for event: BattleEvent in events:
		if event.kind == BattleEvent.Kind.DAMAGED:
			return event.damage
	fail("no damage event")
	return -1
