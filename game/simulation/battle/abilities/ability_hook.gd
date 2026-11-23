class_name AbilityHook
extends RefCounted

## Base of every ability handler (docs/MECHANICS.md §5). `AbilityDef.handler`
## names a script that extends this and overrides the hooks it needs; the rest
## do nothing. One handler object serves every stack with the ability, so a
## handler keeps no state of its own: what it must remember goes into `params`
## (the stack's own copy, part of the battle state) or into the stacks.
##
## `owner` — the stack that has the ability. `params` — its parameters from
## `AbilityDef.params`. Two kinds of hooks:
## - `modify_*`, `can_retaliate`, `extra_targets` are asked by forecasts too
##   (the hit forecast, the AI): they must not change anything;
## - `on_*` run only while a command is applied: they may change the state
##   through its public methods and report with `state.emit_ability`.


## Once, when the battle starts (`BattleState.start`).
func on_battle_start(_state: BattleState, _owner: BattleStack, _params: Dictionary) -> void:
	pass


## When `owner` gets its turn, after the morale roll let it act. If the hook
## kills `owner`, the turn goes to the next stack.
func on_turn_start(_state: BattleState, _owner: BattleStack, _params: Dictionary) -> void:
	pass


## `owner` strikes `target`: change `strike` (attack, defence, flank, extra,
## ability multiplier). Must not change the state.
func modify_attack(_state: BattleState, _owner: BattleStack, _target: BattleStack, _kind: DamageCalc.Kind,
		_strike: DamageCalc.Strike, _params: Dictionary) -> void:
	pass


## `attacker` strikes `owner`: change `strike`. Must not change the state.
func modify_damage_taken(_state: BattleState, _owner: BattleStack, _attacker: BattleStack, _kind: DamageCalc.Kind,
		_strike: DamageCalc.Strike, _params: Dictionary) -> void:
	pass


## Aura: `attacker` strikes `ally`, a living stack of `owner`'s side next to
## `owner`: change `strike` (after the target's own hooks). Must not change
## the state.
func modify_ally_damage_taken(_state: BattleState, _owner: BattleStack, _ally: BattleStack, _attacker: BattleStack,
		_kind: DamageCalc.Kind, _strike: DamageCalc.Strike, _params: Dictionary) -> void:
	pass


## Aura: `ally` next to `owner` has just taken `damage` from a strike of
## `attacker` (it may have died of it).
func on_ally_damaged(_state: BattleState, _owner: BattleStack, _ally: BattleStack, _attacker: BattleStack,
		_damage: int, _kind: DamageCalc.Kind, _params: Dictionary) -> void:
	pass


## The morale of `stack` — `owner` itself or a living ally next to it — after
## `morale` so far. Must not change the state.
func modify_morale(_state: BattleState, _owner: BattleStack, _stack: BattleStack, morale: int,
		_params: Dictionary) -> int:
	return morale


## Asked of both sides of a melee blow (`owner` is `attacker` or `defender`):
## false — `defender` does not retaliate. Must not change the state.
func can_retaliate(_state: BattleState, _owner: BattleStack, _attacker: BattleStack, _defender: BattleStack,
		_params: Dictionary) -> bool:
	return true


## Other stacks a melee blow of `owner` on `target` also hits (no retaliation
## from them). Must not change the state.
func extra_targets(_state: BattleState, _owner: BattleStack, _target: BattleStack, _params: Dictionary) -> Array[BattleStack]:
	return []


## After `owner`'s melee blow or shot (and the retaliation) on `target`.
func on_after_attack(_state: BattleState, _owner: BattleStack, _target: BattleStack, _kind: DamageCalc.Kind,
		_params: Dictionary) -> void:
	pass


## After `owner` moved from `from` (a move or the walk before a blow).
func on_after_move(_state: BattleState, _owner: BattleStack, _from: Vector2i, _params: Dictionary) -> void:
	pass


## An active ability (`UseAbilityCmd`): the stacks it may be used on now;
## empty — none (or the ability is not active). Must not change the state.
func use_targets(_state: BattleState, _owner: BattleStack, _params: Dictionary) -> Array[BattleStack]:
	return []


## An active ability: `owner` uses it on `target` (one of `use_targets`).
func on_use(_state: BattleState, _owner: BattleStack, _target: BattleStack, _params: Dictionary) -> void:
	pass


## `owner` has just been wiped out by `killer` (null — not by a stack).
func on_death(_state: BattleState, _owner: BattleStack, _killer: BattleStack, _params: Dictionary) -> void:
	pass
