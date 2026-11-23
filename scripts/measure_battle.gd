extends SceneTree

## Battle measurements, bot against bot (`BattleNearestBot` on both sides):
##   godot --headless --path . -s scripts/measure_battle.gd -- [battles] [first_seed]
## Defaults: 200 battles from seed 1. Two series:
## - mirror: the same random army on both sides — how much the side matters;
## - factions: Throne against Coven, the same tiers per slot and counts set for
##   equal power (`PowerEstimator`), sides swapped every other battle.
## Prints the time per battle, the average actions, the win shares and one
## digest of all results: two runs with the same arguments print the same.

const DEFAULT_BATTLES: int = 200
const MAX_ACTIONS: int = 2000
const TIERS: Array[int] = [1, 2, 4]

var _data: GameData = GameData.new()


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var battles: int = args[0].to_int() if args.size() > 0 else DEFAULT_BATTLES
	var first_seed: int = args[1].to_int() if args.size() > 1 else 1
	if not _data.load_all():
		printerr("measure_battle: data errors: %s" % [_data.errors])
		quit(1)
		return
	var all_results: PackedStringArray = PackedStringArray()
	all_results.append_array(_mirror(battles, first_seed))
	all_results.append_array(_factions(battles, first_seed))
	print("results digest: %s" % "|".join(all_results).sha256_text().substr(0, 16))
	quit()


func _mirror(battles: int, first_seed: int) -> PackedStringArray:
	var results: PackedStringArray = PackedStringArray()
	var side_wins: Array[int] = [0, 0]
	var actions: int = 0
	var unfinished: int = 0
	var started: int = Time.get_ticks_usec()
	for i: int in battles:
		var seed_value: int = first_seed + i
		var army: BattleSideSetup = _random_army(SimRng.new(seed_value))
		var state: BattleState = BattleSetup.create(_data, army, army, seed_value)
		actions += _play(state)
		if state.is_over():
			side_wins[state.result.winner] += 1
			results.append("%d:%d:%d" % [seed_value, state.result.winner, state.turn_count])
		else:
			unfinished += 1
	var elapsed: int = Time.get_ticks_usec() - started
	print("mirror: %d battles, %.1f ms/battle, %.1f actions avg, side 0 wins %.1f%%, unfinished %d" % [
		battles, elapsed / 1000.0 / battles, float(actions) / battles, 100.0 * side_wins[0] / battles, unfinished])
	return results


func _factions(battles: int, first_seed: int) -> PackedStringArray:
	var results: PackedStringArray = PackedStringArray()
	var throne_wins: int = 0
	var side_wins: Array[int] = [0, 0]
	var actions: int = 0
	var unfinished: int = 0
	var power_gap: int = 0
	var started: int = Time.get_ticks_usec()
	var throne: Dictionary[int, UnitDef] = _base_units_by_tier(&"throne")
	var coven: Dictionary[int, UnitDef] = _base_units_by_tier(&"coven")
	for i: int in battles:
		var seed_value: int = first_seed + i
		var rng: SimRng = SimRng.new(seed_value)
		var throne_army: BattleSideSetup = BattleSideSetup.new()
		var coven_army: BattleSideSetup = BattleSideSetup.new()
		var throne_power: int = 0
		var coven_power: int = 0
		for slot: int in rng.range_int(1, BattleSideSetup.MAX_SLOTS):
			var tier: int = TIERS[rng.pick_index(TIERS.size())]
			var count: int = rng.range_int(1, 30)
			var mine: UnitDef = throne[tier]
			var theirs: UnitDef = coven[tier]
			var their_count: int = maxi(1, (count * PowerEstimator.power(mine) * 2 + PowerEstimator.power(theirs))
					/ (2 * PowerEstimator.power(theirs)))
			throne_army.add(mine.id, count)
			coven_army.add(theirs.id, their_count)
			throne_power += count * PowerEstimator.power(mine)
			coven_power += their_count * PowerEstimator.power(theirs)
		power_gap += absi(throne_power - coven_power) * 1000 / maxi(1, throne_power)
		var throne_side: int = i % 2
		var state: BattleState = BattleSetup.create(_data, throne_army if throne_side == 0 else coven_army,
				coven_army if throne_side == 0 else throne_army, seed_value)
		actions += _play(state)
		if state.is_over():
			side_wins[state.result.winner] += 1
			if state.result.winner == throne_side:
				throne_wins += 1
			results.append("%d:%d:%d" % [seed_value, state.result.winner, state.turn_count])
		else:
			unfinished += 1
	var elapsed: int = Time.get_ticks_usec() - started
	print(("throne vs coven: %d battles, %.1f ms/battle, %.1f actions avg, throne wins %.1f%%, side 0 wins %.1f%%, "
			+ "power gap %.1f%%, unfinished %d") % [battles, elapsed / 1000.0 / battles, float(actions) / battles,
			100.0 * throne_wins / battles, 100.0 * side_wins[0] / battles, power_gap / 10.0 / battles, unfinished])
	return results


## Bot against bot; returns the number of actions.
func _play(state: BattleState) -> int:
	var actions: int = 0
	while not state.is_over() and actions < MAX_ACTIONS:
		var cmd: BattleCmd = BattleNearestBot.choose(state)
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
