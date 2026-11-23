extends TestSuite

## AtbTimeline: ticks, tie-breaks, "wait", and a forecast that matches the
## turns that really happen and does not change the state.


func test_ticks_and_pick() -> void:
	var atbs: Array[int] = [0, 5000]
	var inits: Array[int] = [10, 10]
	expect_eq(50, AtbTimeline.ticks_to_next(atbs, inits), "5000 / 100 per tick")
	expect_eq(-1, AtbTimeline.pick(atbs, inits, [0, 1]), "nobody ready")
	expect_eq(1, AtbTimeline.next(atbs, inits, [0, 1]), "the one ahead goes")
	expect_eq(10000, atbs[1], "exactly full")
	expect_eq(5000, atbs[0], "the other moved too")
	expect_eq(0, AtbTimeline.ticks_to_next([10000], [1]), "already full")
	expect_eq(1, AtbTimeline.ticks_to_next([9999], [1]), "rounds up")


func test_tie_breaks() -> void:
	var ids: Array[int] = [0, 1, 2]
	expect_eq(2, AtbTimeline.pick([10000, 10100, 10200], [10, 10, 10], ids), "higher atb")
	expect_eq(1, AtbTimeline.pick([10000, 10000, 10000], [9, 12, 11], ids), "then higher initiative")
	expect_eq(0, AtbTimeline.pick([10000, 10000, 10000], [10, 10, 10], ids), "then smaller id")
	expect_eq(2, AtbTimeline.pick([9999, 9000, 10000], [30, 30, 1], ids), "only the ready ones")


func test_initiative_sets_the_pace() -> void:
	var state: BattleState = BattleFixtures.empty_state(1)
	BattleFixtures.custom(state, 0, Vector2i(0, 0), 1, 5, 1, 1, 20)
	BattleFixtures.custom(state, 1, Vector2i(11, 0), 1, 5, 1, 1, 10)
	state.start()
	var turns: Array[int] = _play(state, 9)
	expect_eq([0, 0, 1, 0, 0, 1, 0, 0, 1], turns, "twice the initiative, twice the turns")


func test_forecast_matches_real_turns_and_keeps_state() -> void:
	var state: BattleState = BattleFixtures.empty_state(1)
	BattleFixtures.custom(state, 0, Vector2i(0, 0), 1, 5, 1, 1, 13, 400)
	BattleFixtures.custom(state, 0, Vector2i(0, 2), 1, 5, 1, 1, 9, 2100)
	BattleFixtures.custom(state, 1, Vector2i(11, 0), 1, 5, 1, 1, 11, 1300)
	BattleFixtures.custom(state, 1, Vector2i(11, 2), 1, 5, 1, 1, 7, 0)
	state.start()
	var before: String = state.digest()
	var forecast: Array[int] = AtbTimeline.forecast(state, 10)
	expect_eq(before, state.digest(), "forecast changes nothing")
	expect_eq(10, forecast.size(), "10 turns")
	expect_eq(forecast, _play(state, 10), "forecast = real order")


func test_wait_moves_later_in_the_round() -> void:
	var state: BattleState = BattleFixtures.empty_state(1)
	var a: BattleStack = BattleFixtures.custom(state, 0, Vector2i(0, 0), 1, 5, 1, 1, 10, 10000)
	var b: BattleStack = BattleFixtures.custom(state, 1, Vector2i(11, 0), 1, 5, 1, 1, 10, 6000)
	state.start()
	expect_eq(a.id, state.active_id, "a first")
	state._wait_turn(a)
	expect_true(a.waited, "a has waited")
	expect_eq(AtbTimeline.WAIT + 40 * 100, a.atb, "a restarted from half the line")
	expect_eq(b.id, state.active_id, "b goes")
	state._finish_turn(b, false)
	expect_eq(a.id, state.active_id, "a goes before b's next turn")
	state._finish_turn(a, false)
	expect_false(a.waited, "acting clears the wait")


## Ends `count` turns the ordinary way; returns who had them.
func _play(state: BattleState, count: int) -> Array[int]:
	var turns: Array[int] = []
	for i: int in count:
		turns.append(state.active_id)
		state._finish_turn(state.active_stack(), false)
	return turns
