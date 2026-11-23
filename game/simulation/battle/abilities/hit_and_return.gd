extends AbilityHook

## Hit and return (docs/MECHANICS.md §5): after a blow struck at the end of a
## walk, the owner (alive) goes back to where the walk began, if it is free.

const ID: StringName = &"hit_and_return"


func on_after_move(state: BattleState, _owner: BattleStack, from: Vector2i, params: Dictionary) -> void:
	params[&"from"] = from
	params[&"moved_turn"] = state.turn_count


func on_after_attack(state: BattleState, owner: BattleStack, _target: BattleStack, kind: DamageCalc.Kind,
		params: Dictionary) -> void:
	if kind != DamageCalc.Kind.MELEE or int(params.get(&"moved_turn", -1)) != state.turn_count:
		return
	var back: Vector2i = params[&"from"]
	state.emit_ability(owner, ID)
	state.move_stack(owner, back)
	params[&"moved_turn"] = -1
