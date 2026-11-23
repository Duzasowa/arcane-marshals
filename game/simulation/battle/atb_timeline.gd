class_name AtbTimeline
extends RefCounted

## The initiative line (docs/MECHANICS.md §2). Pure functions on arrays of ATB
## values: the battle moves its line with them, and `forecast` runs the same
## functions on a copy, so the queue the UI shows is the queue that happens
## (as long as no morale roll changes it).

const FULL: int = 10000
const START_MAX: int = 2500
## "Wait": the stack moves again later in the same round.
const WAIT: int = FULL / 2
const GOOD_MORALE: int = FULL / 2
const BAD_MORALE: int = FULL / 4
const PER_INITIATIVE: int = 10


## Whole ticks until somebody reaches `FULL` (0 — somebody already has).
static func ticks_to_next(atbs: Array[int], inits: Array[int]) -> int:
	var best: int = -1
	for i: int in atbs.size():
		if atbs[i] >= FULL:
			return 0
		var rate: int = maxi(1, inits[i] * PER_INITIATIVE)
		var need: int = (FULL - atbs[i] + rate - 1) / rate
		if best < 0 or need < best:
			best = need
	return maxi(best, 0)


static func apply_ticks(atbs: Array[int], inits: Array[int], ticks: int) -> void:
	for i: int in atbs.size():
		atbs[i] += maxi(1, inits[i] * PER_INITIATIVE) * ticks


## Index of the one who moves now: the highest ATB at or over `FULL`, then the
## higher initiative, then the smaller id; -1 when nobody is ready.
static func pick(atbs: Array[int], inits: Array[int], ids: Array[int]) -> int:
	var best: int = -1
	for i: int in atbs.size():
		if atbs[i] < FULL:
			continue
		if best < 0 or _goes_before(i, best, atbs, inits, ids):
			best = i
	return best


## Moves the line to the next actor and returns its index (-1 — empty line).
static func next(atbs: Array[int], inits: Array[int], ids: Array[int]) -> int:
	if atbs.is_empty():
		return -1
	apply_ticks(atbs, inits, ticks_to_next(atbs, inits))
	return pick(atbs, inits, ids)


## ATB after an ordinary turn: the overflow is kept.
static func after_turn(atb: int) -> int:
	return maxi(0, atb - FULL)


## Everyone on the line of `state`: the living stacks in id order, then the
## heroes by side (actor id `BattleState.HERO_ACTOR + side`).
static func read_line(state: BattleState, atbs: Array[int], inits: Array[int], ids: Array[int]) -> void:
	for stack: BattleStack in state.alive_stacks():
		atbs.append(stack.atb)
		inits.append(stack.initiative)
		ids.append(stack.id)
	for hero: BattleHero in state.heroes:
		if hero != null:
			atbs.append(hero.atb)
			inits.append(hero.initiative)
			ids.append(BattleState.HERO_ACTOR + hero.side)


## Writes ATB values read by `read_line` back, in the same order.
static func write_line(state: BattleState, atbs: Array[int]) -> void:
	var at: int = 0
	for stack: BattleStack in state.alive_stacks():
		stack.atb = atbs[at]
		at += 1
	for hero: BattleHero in state.heroes:
		if hero != null:
			hero.atb = atbs[at]
			at += 1


## The next `count` turns as actor ids (stack ids and hero actors), the one
## who has the turn first. Works on a copy of the ATB values: the state does
## not change.
static func forecast(state: BattleState, count: int) -> Array[int]:
	var order: Array[int] = []
	var atbs: Array[int] = []
	var inits: Array[int] = []
	var ids: Array[int] = []
	read_line(state, atbs, inits, ids)
	var actor: int = state.active_actor()
	var active: int = ids.find(actor) if actor >= 0 else -1
	if active >= 0 and count > 0:
		order.append(actor)
		atbs[active] = after_turn(atbs[active])
	while order.size() < count and not ids.is_empty():
		var i: int = next(atbs, inits, ids)
		order.append(ids[i])
		atbs[i] = after_turn(atbs[i])
	return order


static func _goes_before(i: int, j: int, atbs: Array[int], inits: Array[int], ids: Array[int]) -> bool:
	if atbs[i] != atbs[j]:
		return atbs[i] > atbs[j]
	if inits[i] != inits[j]:
		return inits[i] > inits[j]
	return ids[i] < ids[j]
