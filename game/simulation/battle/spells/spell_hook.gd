class_name SpellHook
extends RefCounted

## The base of a spell handler (docs/MECHANICS.md §6). One shared instance per
## script, without state of its own: everything comes in the arguments. A new
## spell is a new `SpellDef` and, when no handler fits, a new script extending
## this one; the battle core does not change.
##
## `spell` is the hero's spell entry (`SpellCast.entry_of`): id, school, level,
## mana_cost, target, area, base, per_power, effect, duration_rule, duration,
## params.


## The stacks `hero` may cast `spell` on now. Default: by `target` — living
## enemies or living allies. Must not change the state.
func targets(state: BattleState, hero: BattleHero, spell: Dictionary) -> Array[BattleStack]:
	match int(spell[&"target"]):
		SpellDef.Target.ENEMY:
			return state.alive_stacks(1 - hero.side)
		SpellDef.Target.ALLY:
			return state.alive_stacks(hero.side)
	return []


## What casting `spell` on `target` would do, for the UI and the AI:
## {min_damage, max_damage, min_killed, max_killed} (zeros — no damage). Must not
## change the state.
func estimate(_state: BattleState, _hero: BattleHero, _spell: Dictionary, _target: BattleStack) -> Dictionary:
	return SpellCast.no_estimate()


## `hero` casts `spell` on `target` (one of `targets`); the mana is already paid.
func cast(_state: BattleState, _hero: BattleHero, _spell: Dictionary, _target: BattleStack) -> void:
	pass
