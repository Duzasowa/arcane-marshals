extends AbilityHook

## Weaken, an active ability (docs/MECHANICS.md §5): instead of acting, puts
## "weakened" (−`attack`, −`defence`) on any enemy for `turns` of its turns.

const ID: StringName = &"weaken"
const WEAKENED: String = "res://game/simulation/battle/abilities/effects/weakened.gd"


func use_targets(state: BattleState, owner: BattleStack, _params: Dictionary) -> Array[BattleStack]:
	return state.enemies_of(owner)


func on_use(state: BattleState, owner: BattleStack, target: BattleStack, params: Dictionary) -> void:
	state.add_effect(owner, target, ID, WEAKENED, {&"attack": params[&"attack"], &"defence": params[&"defence"]},
			int(params[&"turns"]))
