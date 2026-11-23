class_name AbilityTestKit
extends RefCounted

## Helpers for the ability tests: reading the events of a battle.


## The damage of the first `DAMAGED` event on `target_id`; -1 when none.
static func first_damage(events: Array[BattleEvent], target_id: int) -> int:
	for event: BattleEvent in events:
		if event.kind == BattleEvent.Kind.DAMAGED and event.target_id == target_id:
			return event.damage
	return -1


## The sum of every `DAMAGED` event on `target_id`.
static func total_damage(events: Array[BattleEvent], target_id: int) -> int:
	var total: int = 0
	for event: BattleEvent in events:
		if event.kind == BattleEvent.Kind.DAMAGED and event.target_id == target_id:
			total += event.damage
	return total


static func count(events: Array[BattleEvent], kind: BattleEvent.Kind) -> int:
	var found: int = 0
	for event: BattleEvent in events:
		if event.kind == kind:
			found += 1
	return found


## Defends with every other stack until `who` has the turn again.
static func pass_until(state: BattleState, who: BattleStack) -> void:
	for i: int in 30:
		if state.active_id == who.id or state.is_over():
			return
		state.apply(DefendCmd.new(state.active_id))
