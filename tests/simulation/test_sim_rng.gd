extends TestSuite

const DRAWS: int = 1000


func _sequence(rng: SimRng, count: int) -> PackedInt32Array:
	var values: PackedInt32Array = PackedInt32Array()
	for i: int in count:
		values.append(rng.range_int(0, 1_000_000))
	return values


func test_same_seed_gives_same_sequence() -> void:
	expect_eq(_sequence(SimRng.new(12345), DRAWS), _sequence(SimRng.new(12345), DRAWS), "sequence")


func test_different_seed_gives_different_sequence() -> void:
	expect_ne(_sequence(SimRng.new(1), DRAWS), _sequence(SimRng.new(2), DRAWS), "sequence")


func test_range_int_stays_inside_bounds() -> void:
	var rng: SimRng = SimRng.new(7)
	var seen_low: bool = false
	var seen_high: bool = false
	for i: int in DRAWS:
		var value: int = rng.range_int(3, 6)
		expect_between(3, 6, value, "range_int")
		seen_low = seen_low or value == 3
		seen_high = seen_high or value == 6
	expect_true(seen_low and seen_high, "both bounds reached")


func test_chance_permille_edges() -> void:
	var rng: SimRng = SimRng.new(99)
	var never: int = 0
	var always: int = 0
	var half: int = 0
	for i: int in DRAWS:
		never += 1 if rng.chance_permille(0) else 0
		always += 1 if rng.chance_permille(1000) else 0
		half += 1 if rng.chance_permille(500) else 0
	expect_eq(0, never, "chance 0")
	expect_eq(DRAWS, always, "chance 1000")
	expect_between(400, 600, half, "chance 500")


func test_chance_value_does_not_shift_sequence() -> void:
	var a: SimRng = SimRng.new(5)
	var b: SimRng = SimRng.new(5)
	a.chance_permille(0)
	b.chance_permille(1000)
	expect_eq(a.get_state(), b.get_state(), "state after different chances")


func test_copy_continues_the_same_sequence() -> void:
	var rng: SimRng = SimRng.new(42)
	_sequence(rng, 17)
	var copy: SimRng = rng.duplicate_rng()
	expect_eq(_sequence(rng, 50), _sequence(copy, 50), "copy sequence")


func test_state_restores_position() -> void:
	var rng: SimRng = SimRng.new(42)
	_sequence(rng, 10)
	var saved: int = rng.get_state()
	var expected: PackedInt32Array = _sequence(rng, 20)
	rng.set_state(saved)
	expect_eq(expected, _sequence(rng, 20), "restored sequence")


func test_digest_follows_draws() -> void:
	var a: SimRng = SimRng.new(8)
	var b: SimRng = SimRng.new(8)
	expect_eq(StateHasher.digest(a), StateHasher.digest(b), "same seed digest")
	a.range_int(0, 10)
	expect_ne(StateHasher.digest(a), StateHasher.digest(b), "digest after a draw")
	b.range_int(0, 10)
	expect_eq(StateHasher.digest(a), StateHasher.digest(b), "digest after the same draw")
