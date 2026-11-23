class_name SimRng
extends RefCounted

## The only source of randomness of the simulation. Lives inside the state, so
## the same seed and the same commands give the same game. `chance_permille`
## always rolls the same 0 … 999 range, whatever the chance, so a change of a
## chance value never shifts the rolls that follow.

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value


## A whole number in `low` … `high`, both included.
func range_int(low: int, high: int) -> int:
	return _rng.randi_range(low, high)


## True with probability `permille` / 1000 (0 — never, 1000 — always).
func chance_permille(permille: int) -> bool:
	return _rng.randi_range(0, 999) < permille


## An index in 0 … size - 1 (size must be positive).
func pick_index(size: int) -> int:
	return _rng.randi_range(0, size - 1)


func get_seed() -> int:
	return _rng.seed


## The position in the sequence, for saves.
func get_state() -> int:
	return _rng.state


func set_state(state: int) -> void:
	_rng.state = state


## An independent copy at the same position, for forecasts on a copy of the state.
func duplicate_rng() -> SimRng:
	var copy: SimRng = SimRng.new(_rng.seed)
	copy.set_state(_rng.state)
	return copy
