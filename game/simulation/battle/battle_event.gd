class_name BattleEvent
extends RefCounted

## What happened in the battle, for the view, the log and the sounds. The view
## reads events only; it never looks at how the state changed.

enum Kind {
	TURN_STARTED,
	MOVED,
	ATTACKED,
	SHOT,
	RETALIATED,
	DAMAGED,
	DIED,
	WAITED,
	DEFENDED,
	MORALE_GOOD,
	MORALE_BAD,
	LUCK_GOOD,
	LUCK_BAD,
	SURRENDERED,
	BATTLE_ENDED,
	## An ability did something: `ability`, its owner `stack_id`, maybe `target_id`.
	ABILITY,
	## `target_id` is under the effect `ability` now (or again), from `stack_id` (-1 — none).
	EFFECT_ADDED,
	## The effect `ability` of `stack_id` has run out.
	EFFECT_ENDED,
	## `target_id` healed by `stack_id` (-1 — none): `damage` HP, `killed` creatures raised.
	HEALED,
	## The hero of `side` has the turn.
	HERO_TURN_STARTED,
	## The hero of `side` casts `ability` (the spell id) on `target_id`.
	SPELL_CAST,
	## The hero of `side` let its turn go by.
	HERO_PASSED,
}

var kind: Kind = Kind.TURN_STARTED
var stack_id: int = -1
var target_id: int = -1
## MOVED: the path, cell indices after the start, the last one is the new anchor.
var cells: PackedInt32Array = PackedInt32Array()
var damage: int = 0
var killed: int = 0
## SURRENDERED / BATTLE_ENDED / hero events: the side.
var side: int = -1
## ABILITY, EFFECT_*: the ability id; SPELL_CAST: the spell id.
var ability: StringName = &""


static func make(event_kind: Kind, event_stack: int = -1, event_target: int = -1) -> BattleEvent:
	var event: BattleEvent = BattleEvent.new()
	event.kind = event_kind
	event.stack_id = event_stack
	event.target_id = event_target
	return event


func describe() -> String:
	return "%s stack=%d target=%d dmg=%d killed=%d side=%d" % [
		Kind.keys()[kind], stack_id, target_id, damage, killed, side]
