extends TestSuite

## The ability hooks of the battle core (docs/MECHANICS.md §5), with test
## handlers from `tests/battle/abilities/`: strike modifiers count in the battle
## and in the forecast alike, retaliation can be forbidden, extra targets, the
## `on_*` hooks run at their moments, a death and a turn-start death, abilities
## come from the data and are part of the state.

const HANDLERS: String = "res://tests/battle/abilities/"


func test_attack_modifier_in_battle_and_forecast() -> void:
	var state: BattleState = BattleFixtures.empty_state(1)
	var attacker: BattleStack = BattleFixtures.custom(state, 0, Vector2i(4, 4), 10, 10, 2, 2, 10, 10000)
	var target: BattleStack = BattleFixtures.custom(state, 1, Vector2i(5, 4), 10, 100, 1, 1)
	_give(attacker, "hook_strike_mult.gd", {&"mult": 2000})
	state.start()
	var forecast: Dictionary = DamageCalc.estimate(state, attacker, attacker.cell, target, DamageCalc.Kind.MELEE)
	expect_eq(40, forecast[&"max_damage"], "forecast doubled")
	state.take_events()
	state.apply(AttackCmd.new(attacker.id, target.id, attacker.cell))
	expect_eq(40, _first_damage(state.take_events(), target.id), "blow doubled")


func test_damage_taken_modifier() -> void:
	var state: BattleState = BattleFixtures.empty_state(2)
	var attacker: BattleStack = BattleFixtures.custom(state, 0, Vector2i(4, 4), 10, 10, 2, 2, 10, 10000)
	var target: BattleStack = BattleFixtures.custom(state, 1, Vector2i(5, 4), 10, 100, 1, 1)
	_give(target, "hook_tough.gd", {&"mult": 500})
	state.start()
	state.take_events()
	state.apply(AttackCmd.new(attacker.id, target.id, attacker.cell))
	expect_eq(10, _first_damage(state.take_events(), target.id), "blow halved")


func test_no_retaliation() -> void:
	var state: BattleState = BattleFixtures.empty_state(3)
	var attacker: BattleStack = BattleFixtures.custom(state, 0, Vector2i(4, 4), 10, 10, 2, 2, 10, 10000)
	var target: BattleStack = BattleFixtures.custom(state, 1, Vector2i(5, 4), 10, 100, 1, 1)
	_give(attacker, "hook_no_retaliation.gd")
	state.start()
	expect_false(state.will_retaliate(attacker, target), "forbidden")
	expect_eq({}, BattleForecast.retaliation(state, attacker, attacker.cell, target, 5), "forecast: none")
	state.take_events()
	state.apply(AttackCmd.new(attacker.id, target.id, attacker.cell))
	expect_false(_has(state.take_events(), BattleEvent.Kind.RETALIATED), "no retaliation")
	expect_eq(1, target.retaliations_left, "retaliation kept")


func test_extra_targets() -> void:
	var state: BattleState = BattleFixtures.empty_state(4)
	var attacker: BattleStack = BattleFixtures.custom(state, 0, Vector2i(4, 4), 10, 10, 2, 2, 10, 10000)
	var target: BattleStack = BattleFixtures.custom(state, 1, Vector2i(5, 4), 10, 100, 1, 1)
	var beside: BattleStack = BattleFixtures.custom(state, 1, Vector2i(4, 5), 10, 100, 1, 1)
	var far: BattleStack = BattleFixtures.custom(state, 1, Vector2i(10, 9), 10, 100, 1, 1)
	_give(attacker, "hook_sweep.gd")
	state.start()
	state.take_events()
	state.apply(AttackCmd.new(attacker.id, target.id, attacker.cell))
	var events: Array[BattleEvent] = state.take_events()
	expect_eq(20, _first_damage(events, target.id), "the target")
	expect_eq(20, _first_damage(events, beside.id), "the neighbour too")
	expect_eq(-1, _first_damage(events, far.id), "not the far one")
	var answers: int = 0
	for event: BattleEvent in events:
		if event.kind == BattleEvent.Kind.RETALIATED:
			answers += 1
			expect_eq(target.id, event.stack_id, "only the target retaliates")
	expect_eq(1, answers, "one retaliation")


func test_on_hooks_run_at_their_moments() -> void:
	var state: BattleState = BattleFixtures.empty_state(5)
	var who: BattleStack = BattleFixtures.custom(state, 0, Vector2i(2, 4), 10, 10, 2, 2, 10, 10000)
	var enemy: BattleStack = BattleFixtures.custom(state, 1, Vector2i(9, 4), 10, 100, 1, 1, 10, 0)
	_give(who, "hook_counter.gd")
	var params: Dictionary = who.abilities[0][&"params"]
	state.start()
	expect_eq(1, params.get(&"battle_start", 0), "battle start")
	expect_eq(1, params.get(&"turn_start", 0), "first turn")
	var events: Array[BattleEvent] = state.take_events()
	expect_true(_has(events, BattleEvent.Kind.ABILITY), "reported")
	expect_true(state.apply(MoveCmd.new(who.id, Vector2i(5, 4))), "moves")
	expect_eq(1, params.get(&"after_move", 0), "after the move")
	_pass_until(state, who)
	expect_eq(2, params.get(&"turn_start", 0), "second turn")
	expect_true(state.apply(AttackCmd.new(who.id, enemy.id, Vector2i(8, 4))), "walks and strikes")
	expect_eq(2, params.get(&"after_move", 0), "the walk before the blow")
	expect_eq(1, params.get(&"after_attack", 0), "after the blow")


func test_death_ability() -> void:
	var state: BattleState = BattleFixtures.empty_state(6)
	var attacker: BattleStack = BattleFixtures.custom(state, 0, Vector2i(4, 4), 10, 10, 5, 5, 10, 10000)
	var victim: BattleStack = BattleFixtures.custom(state, 1, Vector2i(5, 4), 1, 10, 1, 1)
	BattleFixtures.custom(state, 1, Vector2i(11, 9), 10, 100, 1, 1)
	_give(victim, "hook_death_blast.gd", {&"damage": 7})
	state.start()
	state.take_events()
	state.apply(AttackCmd.new(attacker.id, victim.id, attacker.cell))
	var events: Array[BattleEvent] = state.take_events()
	expect_false(victim.is_alive(), "victim dead")
	expect_eq(7, _first_damage(events, attacker.id), "the blast hits the attacker")
	expect_eq(93, attacker.total_hp(), "attacker HP")
	var died_at: int = -1
	var blast_at: int = -1
	for i: int in events.size():
		if events[i].kind == BattleEvent.Kind.DIED and died_at < 0:
			died_at = i
		if events[i].kind == BattleEvent.Kind.ABILITY:
			blast_at = i
	expect_true(died_at >= 0 and blast_at > died_at, "the blast after the death")


func test_turn_start_death_passes_the_turn() -> void:
	var state: BattleState = BattleFixtures.empty_state(7)
	var bleeding: BattleStack = BattleFixtures.custom(state, 0, Vector2i(0, 0), 1, 10, 1, 1, 10, 10000)
	var friend: BattleStack = BattleFixtures.custom(state, 0, Vector2i(0, 5), 10, 10, 1, 1, 10, 5000)
	BattleFixtures.custom(state, 1, Vector2i(11, 9), 10, 10, 1, 1, 10, 0)
	_give(bleeding, "hook_bleeding.gd", {&"damage": 50})
	state.start()
	expect_false(bleeding.is_alive(), "died at its turn start")
	expect_false(state.is_over(), "the battle goes on")
	expect_eq(friend.id, state.active_id, "the next stack has the turn")


func test_turn_start_death_can_end_the_battle() -> void:
	var state: BattleState = BattleFixtures.empty_state(8)
	var bleeding: BattleStack = BattleFixtures.custom(state, 0, Vector2i(0, 0), 1, 10, 1, 1, 10, 10000)
	BattleFixtures.custom(state, 1, Vector2i(11, 9), 10, 10, 1, 1, 10, 0)
	_give(bleeding, "hook_bleeding.gd", {&"damage": 50})
	state.start()
	expect_true(state.is_over(), "over")
	if state.is_over():
		expect_eq(1, state.result.winner, "the other side wins")


func test_setup_copies_abilities_from_data() -> void:
	var data: GameData = GameData.new()
	var ability: AbilityDef = AbilityDef.new()
	ability.id = &"test_counter"
	ability.handler = load(HANDLERS + "hook_counter.gd")
	ability.params = {&"start": 1}
	ability.ai_weight = 200
	data.abilities[ability.id] = ability
	var unit: UnitDef = BattleFixtures.unit(&"throne_militia").duplicate()
	unit.id = &"test_counter_unit"
	unit.abilities = [ability.id]
	data.units[unit.id] = unit
	var army: BattleSideSetup = BattleSideSetup.new()
	army.add(unit.id, 5)
	var state: BattleState = BattleSetup.create(data, army, army, 9)
	var stack: BattleStack = state.stacks[0]
	expect_true(stack.has_ability(&"test_counter"), "has it")
	expect_eq(ability.handler.resource_path, stack.abilities[0][&"handler"], "handler path")
	expect_eq(1, stack.abilities[0][&"params"].get(&"battle_start", 0), "its hooks run")
	expect_false(ability.params.has(&"battle_start"), "the data is not touched")
	expect_false(is_same(stack.abilities[0][&"params"], state.stacks[1].abilities[0][&"params"]), "own copy per stack")
	expect_eq(PowerEstimator.power(unit, data), stack.power, "power counts the ability weight")


func test_abilities_are_state() -> void:
	var state: BattleState = BattleFixtures.empty_state(10)
	var who: BattleStack = BattleFixtures.custom(state, 0, Vector2i(2, 4), 10, 10, 2, 2, 10, 10000)
	BattleFixtures.custom(state, 1, Vector2i(9, 4), 10, 100, 1, 1)
	_give(who, "hook_counter.gd")
	state.start()
	var copy: BattleState = state.clone()
	expect_eq(state.digest(), copy.digest(), "a copy hashes the same")
	copy.stacks[who.id].abilities[0][&"params"][&"turn_start"] = 99
	expect_ne(state.digest(), copy.digest(), "params are hashed")
	expect_eq(1, who.abilities[0][&"params"][&"turn_start"], "the copy has its own params")


func _give(stack: BattleStack, handler_file: String, params: Dictionary = {}) -> void:
	stack.abilities.append(AbilityHooks.entry(StringName(handler_file.get_basename()), HANDLERS + handler_file, params))


static func _first_damage(events: Array[BattleEvent], target_id: int) -> int:
	for event: BattleEvent in events:
		if event.kind == BattleEvent.Kind.DAMAGED and event.target_id == target_id:
			return event.damage
	return -1


static func _has(events: Array[BattleEvent], kind: BattleEvent.Kind) -> bool:
	for event: BattleEvent in events:
		if event.kind == kind:
			return true
	return false


## Defends with everyone else until `who` has the turn again.
static func _pass_until(state: BattleState, who: BattleStack) -> void:
	for i: int in 20:
		if state.active_id == who.id or state.is_over():
			return
		state.apply(DefendCmd.new(state.active_id))
