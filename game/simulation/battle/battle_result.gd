class_name BattleResult
extends RefCounted

## How a battle ended: who won, what each side lost, how much experience each
## side earned and how many creatures are left in each army slot.

enum EndedBy { DESTROYED, SURRENDER }

const NO_WINNER: int = -1

var winner: int = NO_WINNER
var ended_by: EndedBy = EndedBy.DESTROYED
## Per side: unit id -> creatures lost.
var losses: Array[Dictionary] = [{}, {}]
## Per side: experience for the enemy creatures killed.
var experience: PackedInt32Array = PackedInt32Array([0, 0])
## Per side: army slot -> creatures left (slots without a stack are 0).
var survivors: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array()]
## Turns taken by stacks and heroes over the battle.
var turns: int = 0
## Per side: the hero's mana left (-1 — no hero), to take back to the map.
var mana_left: PackedInt32Array = PackedInt32Array([-1, -1])


func loser() -> int:
	return NO_WINNER if winner == NO_WINNER else 1 - winner


func copy() -> BattleResult:
	var result: BattleResult = BattleResult.new()
	result.winner = winner
	result.ended_by = ended_by
	result.losses = [losses[0].duplicate(), losses[1].duplicate()]
	result.experience = experience.duplicate()
	result.survivors = [survivors[0].duplicate(), survivors[1].duplicate()]
	result.turns = turns
	result.mana_left = mana_left.duplicate()
	return result
