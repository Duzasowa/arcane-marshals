class_name BattleForecast
extends RefCounted

## Forecasts shared by the battle UI and the AI. They read the state through
## `DamageCalc` (the same functions as the battle) and change nothing.


## The retaliation `target` gives when `who`, standing at `spot`, has just
## dealt it `damage`: a `DamageCalc.estimate` dictionary (damage and deaths of
## `who`), or {} when there is none — no retaliation left, an ability forbids
## it (`BattleState.will_retaliate`) or the target dies.
static func retaliation(state: BattleState, who: BattleStack, spot: Vector2i, target: BattleStack,
		damage: int) -> Dictionary:
	if not state.will_retaliate(who, target):
		return {}
	var defender: BattleStack = target.copy()
	defender.take_damage(damage)
	if not defender.is_alive():
		return {}
	# The attacker only moves before its blow, so a copy of it at `spot` is the
	# whole difference: the defender's allies next to `spot` give the flank.
	var attacker: BattleStack = who.copy()
	attacker.cell = spot
	return DamageCalc.estimate(state, defender, defender.cell, attacker, DamageCalc.Kind.RETALIATION)
