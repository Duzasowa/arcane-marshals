extends TestSuite

## DamageCalc against docs/MECHANICS.md §4: a table of edge cases.


func test_attack_multiplier_table() -> void:
	# [attack, defence, expected permille]
	var rows: Array[Array] = [
		[10, 10, 1000], [11, 10, 1050], [20, 10, 1500], [50, 10, 3000], [70, 10, 3000],
		[10, 20, 666], [10, 30, 500], [10, 70, 300], [0, 200, 300], [0, 0, 1000],
	]
	for row: Array in rows:
		expect_eq(row[2], DamageCalc.attack_multiplier(row[0], row[1]), "A %d vs D %d" % [row[0], row[1]])


func test_defend_bonus() -> void:
	expect_eq(1, DamageCalc.defended(0), "at least +1")
	expect_eq(3, DamageCalc.defended(2), "2 × 1.3 = 2.6 → 3")
	expect_eq(7, DamageCalc.defended(5), "5 × 1.3 = 6.5 → 7")
	expect_eq(13, DamageCalc.defended(10), "10 × 1.3")


func test_base_rolls() -> void:
	var rng: SimRng = SimRng.new(5)
	expect_eq(1500, DamageCalc.roll_base(rng, 500, 3, 3), "10 rolls scaled to 500")
	expect_eq(3, DamageCalc.roll_base(rng, 3, 1, 1), "3 rolls")
	expect_eq(0, DamageCalc.roll_base(rng, 0, 1, 5), "empty stack")
	for i: int in 200:
		expect_between(7, 14, DamageCalc.roll_base(rng, 7, 1, 2), "7 creatures 1–2")
		expect_between(500, 1000, DamageCalc.roll_base(rng, 500, 1, 2), "500 creatures 1–2")
	expect_eq(Vector2i(14, 21), DamageCalc.base_range(7, 2, 3), "range")


func test_final_damage_table() -> void:
	# [base, attack, defence, flank, luck, extra, expected]
	var rows: Array[Array] = [
		[0, 10, 10, 0, 1000, 1000, 1],
		[1, 0, 200, 0, 500, 500, 1],
		[100, 10, 10, 0, 1000, 1000, 100],
		[100, 10, 10, 300, 1000, 1000, 130],
		[100, 10, 10, 900, 1000, 1000, 130],
		[100, 10, 10, 0, 2000, 1000, 200],
		[100, 10, 10, 0, 500, 1000, 50],
		[100, 10, 10, 0, 1000, 500, 50],
		[100, 70, 10, 300, 2000, 1000, 780],
		[100, 10, 70, 0, 1000, 1000, 30],
		[1000000, 30, 10, 0, 1000, 1000, 2000000],
	]
	for row: Array in rows:
		var strike: DamageCalc.Strike = DamageCalc.Strike.new()
		strike.attack = row[1]
		strike.defence = row[2]
		strike.flank = row[3]
		strike.extra = row[5]
		expect_eq(row[6], DamageCalc.final_damage(row[0], strike, row[4]), "row %s" % [row])


func test_luck_rolls() -> void:
	var rng: SimRng = SimRng.new(3)
	var good: int = 0
	var bad: int = 0
	for i: int in 1000:
		if DamageCalc.roll_luck(rng, 3) == DamageCalc.LUCK_GOOD:
			good += 1
		if DamageCalc.roll_luck(rng, -2) == DamageCalc.LUCK_BAD:
			bad += 1
	expect_between(240, 360, good, "luck +3 ≈ 30%")
	expect_between(140, 260, bad, "luck −2 ≈ 20%")
	var before: int = rng.get_state()
	expect_eq(DamageCalc.NORMAL, DamageCalc.roll_luck(rng, 0), "no luck")
	expect_eq(before, rng.get_state(), "luck 0 rolls nothing")


func test_context_reads_the_state() -> void:
	var state: BattleState = BattleFixtures.empty_state()
	var shooter: BattleStack = BattleFixtures.add(state, &"throne_crossbowman", 10, 0, Vector2i(0, 0))
	var target: BattleStack = BattleFixtures.add(state, &"coven_sporeling", 10, 1, Vector2i(7, 0))
	var shot: DamageCalc.Strike = DamageCalc.context(state, shooter, shooter.cell, target, DamageCalc.Kind.SHOT)
	expect_eq(DamageCalc.HALF, shot.extra, "7 cells: long range")
	expect_eq(0, shot.flank, "no flanking for shots")
	shot = DamageCalc.context(state, shooter, Vector2i(1, 0), target, DamageCalc.Kind.SHOT)
	expect_eq(DamageCalc.NORMAL, shot.extra, "6 cells: full damage")
	var melee: DamageCalc.Strike = DamageCalc.context(state, shooter, Vector2i(6, 0), target, DamageCalc.Kind.MELEE)
	expect_eq(DamageCalc.HALF, melee.extra, "shooter in melee")
	state.sides[0].attack = 4
	state.sides[1].defence = 2
	target.defending = true
	melee = DamageCalc.context(state, shooter, Vector2i(6, 0), target, DamageCalc.Kind.MELEE)
	expect_eq(shooter.attack + 4, melee.attack, "hero attack added")
	expect_eq(DamageCalc.defended(target.defence + 2), melee.defence, "hero defence, then defend")


func test_flanking() -> void:
	var state: BattleState = BattleFixtures.empty_state()
	var target: BattleStack = BattleFixtures.custom(state, 1, Vector2i(5, 5), 10, 5, 1, 1)
	var attacker: BattleStack = BattleFixtures.custom(state, 0, Vector2i(4, 5), 10, 5, 1, 1)
	expect_eq(0, DamageCalc.context(state, attacker, attacker.cell, target, DamageCalc.Kind.MELEE).flank, "alone")
	BattleFixtures.custom(state, 0, Vector2i(6, 5), 10, 5, 1, 1)
	expect_eq(100, DamageCalc.context(state, attacker, attacker.cell, target, DamageCalc.Kind.MELEE).flank, "one more")
	BattleFixtures.custom(state, 1, Vector2i(5, 4), 10, 5, 1, 1)
	expect_eq(100, DamageCalc.context(state, attacker, attacker.cell, target, DamageCalc.Kind.MELEE).flank,
			"the target's own side does not count")
	for cell: Vector2i in [Vector2i(5, 6), Vector2i(4, 6), Vector2i(6, 6)]:
		BattleFixtures.custom(state, 0, cell, 10, 5, 1, 1)
	expect_eq(DamageCalc.FLANK_MAX, DamageCalc.context(state, attacker, attacker.cell, target, DamageCalc.Kind.MELEE).flank,
			"capped")


func test_estimate_brackets_the_rolls_and_changes_nothing() -> void:
	var state: BattleState = BattleFixtures.empty_state(11)
	var attacker: BattleStack = BattleFixtures.add(state, &"throne_outrider", 6, 0, Vector2i(4, 4))
	var target: BattleStack = BattleFixtures.add(state, &"coven_sporeling", 40, 1, Vector2i(5, 4))
	var before: String = state.digest()
	var forecast: Dictionary = DamageCalc.estimate(state, attacker, attacker.cell, target, DamageCalc.Kind.MELEE)
	expect_eq(before, state.digest(), "estimate changes nothing")
	expect_eq(40, target.count, "target untouched")
	for i: int in 100:
		var damage: int = DamageCalc.roll(state, attacker, attacker.cell, target, DamageCalc.Kind.MELEE, DamageCalc.NORMAL)
		expect_between(forecast[&"min_damage"], forecast[&"max_damage"], damage, "roll inside the forecast")
	expect_true(forecast[&"min_killed"] <= forecast[&"max_killed"], "kills ordered")
	expect_eq(forecast[&"max_damage"] / target.hp, forecast[&"max_killed"], "whole creatures at full hp")
