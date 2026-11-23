extends TestSuite

## PowerEstimator matches the table of docs/MECHANICS.md §7 within ±20%, both
## for the real test units and for reference units built from the table rows.

## Tier -> table power.
const TABLE_POWER: Array[int] = [0, 80, 160, 280, 520, 1000, 2000, 4500]
const TOLERANCE_PERMILLE: int = 200


func test_test_set_units_match_their_tier() -> void:
	var data: GameData = GameData.new()
	data.load_all()
	expect_true(data.units.size() >= 6, "test set loaded")
	for unit: UnitDef in data.units.values():
		_expect_near_table(unit.tier, PowerEstimator.power(unit, data), String(unit.id))


func test_reference_units_match_the_table() -> void:
	# tier: [attack, defence, min_dmg, max_dmg, hp, speed, initiative] — middles of the §7 rows.
	var rows: Dictionary[int, Array] = {
		1: [2, 1, 1, 2, 5, 5, 10],
		2: [3, 3, 2, 3, 12, 5, 10],
		3: [5, 5, 3, 5, 20, 5, 9],
		4: [7, 7, 6, 9, 30, 6, 13],
		5: [12, 12, 10, 14, 55, 5, 10],
		6: [20, 20, 16, 20, 110, 6, 10],
		7: [27, 27, 30, 40, 200, 7, 10],
	}
	var previous: int = 0
	for tier: int in rows:
		var power: int = PowerEstimator.power(_unit(rows[tier]))
		_expect_near_table(tier, power, "reference tier %d" % tier)
		expect_true(power > previous, "tier %d stronger than tier %d" % [tier, tier - 1])
		previous = power


func test_traits_raise_power() -> void:
	var base: UnitDef = _unit([5, 5, 3, 5, 20, 5, 10])
	var plain: int = PowerEstimator.power(base)
	base.shots = 10
	expect_true(PowerEstimator.power(base) > plain, "shots raise power")
	base.shots = 0
	base.flying = true
	expect_true(PowerEstimator.power(base) > plain, "flying raises power")
	base.flying = false
	base.initiative = 14
	expect_true(PowerEstimator.power(base) > plain, "initiative raises power")


func test_ability_weight_adds_permille() -> void:
	var data: GameData = GameData.new()
	var ability: AbilityDef = DataSamples.ability()
	ability.ai_weight = 200
	data.add(ability)
	var unit: UnitDef = _unit([5, 5, 3, 5, 20, 5, 10])
	var plain: int = PowerEstimator.power(unit, data)
	unit.abilities = [ability.id]
	expect_between(plain * 1190 / 1000, plain * 1210 / 1000, PowerEstimator.power(unit, data), "+20% from ai_weight 200")


func test_isqrt_is_exact() -> void:
	expect_eq(0, PowerEstimator.isqrt(0), "0")
	expect_eq(0, PowerEstimator.isqrt(-4), "negative")
	expect_eq(1, PowerEstimator.isqrt(3), "3")
	expect_eq(2, PowerEstimator.isqrt(4), "4")
	expect_eq(99999, PowerEstimator.isqrt(99999 * 99999 + 199998), "just below a square")
	expect_eq(100000, PowerEstimator.isqrt(100000 * 100000), "square")
	expect_eq(3037000499, PowerEstimator.isqrt(9223372030926249001), "large square")


func _expect_near_table(tier: int, power: int, label: String) -> void:
	var expected: int = TABLE_POWER[tier]
	var margin: int = expected * TOLERANCE_PERMILLE / 1000
	expect_between(expected - margin, expected + margin, power, "%s power %d vs %d" % [label, power, expected])


func _unit(row: Array) -> UnitDef:
	var unit: UnitDef = UnitDef.new()
	unit.attack = row[0]
	unit.defence = row[1]
	unit.min_dmg = row[2]
	unit.max_dmg = row[3]
	unit.hp = row[4]
	unit.speed = row[5]
	unit.initiative = row[6]
	return unit
