extends SceneTree

## Battle AI measurements (`BattleAi` against `BattleNearestBot` and itself):
##   godot --headless --path . -s scripts/measure_bot_vs_bot.gd -- [battles] [first_seed]
## Defaults: 100 battles per series from seed 1. Series:
## - NORMAL against the nearest-enemy bot, mirror armies, sides swapped every
##   other battle (goal: the AI wins ≥ 80%);
## - NORMAL against NORMAL, mirror armies (goal: about 50% per side);
## - HARD / NORMAL / EASY against each other, mirror armies, sides swapped
##   (the harder one should win more);
## - Throne against Coven, equal power (`PowerEstimator`), NORMAL on both sides.
## Prints win shares, actions and ms per decision for each AI level, and one
## digest of all results: two runs with the same arguments print the same.

const DEFAULT_BATTLES: int = 100
const MAX_ACTIONS: int = 2000
const TIERS: Array[int] = [1, 2, 4]
const NEAREST: int = -1
const LEVEL_NAMES: Array[String] = ["easy", "normal", "hard"]

var _data: GameData = GameData.new()
var _results: PackedStringArray = PackedStringArray()
## Per AI level: decisions and microseconds spent on them.
var _decisions: Array[int] = [0, 0, 0]
var _usec: Array[int] = [0, 0, 0]


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var battles: int = args[0].to_int() if args.size() > 0 else DEFAULT_BATTLES
	var first_seed: int = args[1].to_int() if args.size() > 1 else 1
	if not _data.load_all():
		printerr("measure_bot_vs_bot: data errors: %s" % [_data.errors])
		quit(1)
		return
	_versus("normal vs nearest", BattleAi.Difficulty.NORMAL, NEAREST, battles, first_seed, true)
	_versus("normal vs normal (side 0 = first)", BattleAi.Difficulty.NORMAL, BattleAi.Difficulty.NORMAL, battles,
			first_seed, false)
	_versus("hard vs normal", BattleAi.Difficulty.HARD, BattleAi.Difficulty.NORMAL, battles, first_seed, true)
	_versus("normal vs easy", BattleAi.Difficulty.NORMAL, BattleAi.Difficulty.EASY, battles, first_seed, true)
	_versus("hard vs easy", BattleAi.Difficulty.HARD, BattleAi.Difficulty.EASY, battles, first_seed, true)
	_factions(battles, first_seed)
	for level: int in LEVEL_NAMES.size():
		if _decisions[level] > 0:
			print("%s: %.1f ms per decision (%d decisions)" % [LEVEL_NAMES[level],
					_usec[level] / 1000.0 / _decisions[level], _decisions[level]])
	print("results digest: %s" % "|".join(_results).sha256_text().substr(0, 16))
	quit()


## `first` against `second` on mirror armies; with `swap` they change sides
## every other battle. Prints the share of wins of `first`.
func _versus(label: String, first: int, second: int, battles: int, first_seed: int, swap: bool) -> void:
	var first_wins: int = 0
	var actions: int = 0
	var unfinished: int = 0
	for i: int in battles:
		var seed_value: int = first_seed + i
		var army: BattleSideSetup = _random_army(SimRng.new(seed_value))
		var state: BattleState = BattleSetup.create(_data, army, army, seed_value)
		var first_side: int = i % 2 if swap else 0
		var players: Array[int] = [first, second]
		if first_side == 1:
			players.reverse()
		actions += _play(state, players, seed_value)
		if state.is_over():
			if state.result.winner == first_side:
				first_wins += 1
			_results.append("%s:%d:%d:%d" % [label, seed_value, state.result.winner, state.turn_count])
		else:
			unfinished += 1
	print("%s: %d battles, first wins %.1f%%, %.1f actions avg, unfinished %d" % [label, battles,
			100.0 * first_wins / battles, float(actions) / battles, unfinished])


## Throne against Coven: the same tiers per slot, counts set for equal power,
## NORMAL on both sides, sides swapped every other battle.
func _factions(battles: int, first_seed: int) -> void:
	var throne_wins: int = 0
	var actions: int = 0
	var unfinished: int = 0
	var throne: Dictionary[int, UnitDef] = _base_units_by_tier(&"throne")
	var coven: Dictionary[int, UnitDef] = _base_units_by_tier(&"coven")
	for i: int in battles:
		var seed_value: int = first_seed + i
		var rng: SimRng = SimRng.new(seed_value)
		var throne_army: BattleSideSetup = BattleSideSetup.new()
		var coven_army: BattleSideSetup = BattleSideSetup.new()
		for slot: int in rng.range_int(1, BattleSideSetup.MAX_SLOTS):
			var tier: int = TIERS[rng.pick_index(TIERS.size())]
			var count: int = rng.range_int(1, 30)
			var mine: UnitDef = throne[tier]
			var theirs: UnitDef = coven[tier]
			throne_army.add(mine.id, count)
			coven_army.add(theirs.id, maxi(1, (count * PowerEstimator.power(mine) * 2 + PowerEstimator.power(theirs))
					/ (2 * PowerEstimator.power(theirs))))
		var throne_side: int = i % 2
		var state: BattleState = BattleSetup.create(_data, throne_army if throne_side == 0 else coven_army,
				coven_army if throne_side == 0 else throne_army, seed_value)
		actions += _play(state, [BattleAi.Difficulty.NORMAL, BattleAi.Difficulty.NORMAL], seed_value)
		if state.is_over():
			if state.result.winner == throne_side:
				throne_wins += 1
			_results.append("factions:%d:%d:%d" % [seed_value, state.result.winner, state.turn_count])
		else:
			unfinished += 1
	print("throne vs coven (normal both): %d battles, throne wins %.1f%%, %.1f actions avg, unfinished %d" % [
			battles, 100.0 * throne_wins / battles, float(actions) / battles, unfinished])


## Plays the battle out; `players` per side: an AI level or `NEAREST`.
## Returns the number of actions.
func _play(state: BattleState, players: Array[int], seed_value: int) -> int:
	var ais: Array[BattleAi] = []
	for side: int in players.size():
		ais.append(BattleAi.new(players[side] as BattleAi.Difficulty, seed_value * 2 + side) if players[side] != NEAREST else null)
	var actions: int = 0
	while not state.is_over() and actions < MAX_ACTIONS:
		var side: int = state.active_stack().side
		var cmd: BattleCmd = null
		if ais[side] == null:
			cmd = BattleNearestBot.choose(state)
		else:
			var started: int = Time.get_ticks_usec()
			cmd = ais[side].choose(state)
			_usec[players[side]] += Time.get_ticks_usec() - started
			_decisions[players[side]] += 1
		if not state.apply(cmd):
			printerr("refused %s: %s" % [cmd.describe(), state.validate(cmd)])
			break
		state.take_events()
		actions += 1
	return actions


func _random_army(rng: SimRng) -> BattleSideSetup:
	var units: Array[StringName] = []
	for unit_id: StringName in _data.units:
		units.append(unit_id)
	var setup: BattleSideSetup = BattleSideSetup.new()
	for i: int in rng.range_int(1, BattleSideSetup.MAX_SLOTS):
		setup.add(units[rng.pick_index(units.size())], rng.range_int(1, 30))
	return setup


func _base_units_by_tier(faction: StringName) -> Dictionary[int, UnitDef]:
	var by_tier: Dictionary[int, UnitDef] = {}
	for unit: UnitDef in _data.units_of_faction(faction):
		if unit.upgrade_of == &"" and not by_tier.has(unit.tier):
			by_tier[unit.tier] = unit
	return by_tier
