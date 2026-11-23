class_name BattleStack
extends RefCounted

## One stack on the battlefield. Copies the combat numbers of its `UnitDef` when
## it is created, so the battle state never needs `GameData` (saves, hashes and
## copies stay self-contained).

var id: int = -1
var unit_id: StringName = &""
## 0 — attacker (left), 1 — defender (right).
var side: int = 0
## Army slot 0 … 6 the stack came from, to return survivors.
var slot: int = 0
var count: int = 0
var initial_count: int = 0
## HP left on the top creature; the others are whole.
var top_hp: int = 0

var hp: int = 1
var attack: int = 0
var defence: int = 0
var min_dmg: int = 1
var max_dmg: int = 1
var speed: int = 1
var initiative: int = 10
## Shots per battle (0 — not a shooter).
var shots: int = 0
var shots_left: int = 0
var size: int = 1
var flying: bool = false
var no_morale: bool = false
## Share of spell damage ignored, permille (`SpellCast.resisted`).
var magic_resist: int = 0
## Experience a killed creature of this stack gives.
var exp: int = 0
## Power of one creature (`PowerEstimator`): what the AI weighs losses with.
var power: int = 1

## Top-left cell.
var cell: Vector2i = Vector2i.ZERO
var atb: int = 0
var retaliations_left: int = 1
var defending: bool = false
## Waited this round; may not wait again before acting.
var waited: bool = false
## Abilities, in hook order: {id, handler (script path), params} — see
## `AbilityHooks.entry`. Params are this stack's own copy: handlers may keep
## counters in them.
var abilities: Array[Dictionary] = []
## Timed effects of abilities and later spells: ability entries
## (`AbilityHooks.entry`) with `turns` left; their hooks run after the
## abilities'. See `BattleState.add_effect`.
var effects: Array[Dictionary] = []


static func from_unit(unit: UnitDef, stack_side: int, stack_slot: int, stack_count: int) -> BattleStack:
	var stack: BattleStack = BattleStack.new()
	stack.unit_id = unit.id
	stack.side = stack_side
	stack.slot = stack_slot
	stack.count = stack_count
	stack.initial_count = stack_count
	stack.hp = unit.hp
	stack.top_hp = unit.hp
	stack.attack = unit.attack
	stack.defence = unit.defence
	stack.min_dmg = unit.min_dmg
	stack.max_dmg = unit.max_dmg
	stack.speed = unit.speed
	stack.initiative = unit.initiative
	stack.shots = unit.shots
	stack.shots_left = unit.shots
	stack.size = unit.size
	stack.flying = unit.flying
	stack.no_morale = unit.no_morale
	stack.magic_resist = unit.magic_resist
	stack.exp = unit.exp
	stack.power = PowerEstimator.power(unit)
	return stack


func is_alive() -> bool:
	return count > 0


func is_shooter() -> bool:
	return shots > 0


func total_hp() -> int:
	return 0 if count <= 0 else (count - 1) * hp + top_hp


## Damage taken by the top creature first; returns the number of creatures killed.
func take_damage(damage: int) -> int:
	if damage <= 0 or count <= 0:
		return 0
	var before: int = count
	var left: int = total_hp() - damage
	if left <= 0:
		count = 0
		top_hp = 0
		return before
	count = (left + hp - 1) / hp
	top_hp = left - (count - 1) * hp
	return before - count


## Heals `amount` HP from the top creature up, to at most `max_count` whole
## creatures (never fewer than now). Returns the HP healed.
func restore(amount: int, max_count: int) -> int:
	if count <= 0 or amount <= 0:
		return 0
	var before: int = total_hp()
	var after: int = mini(maxi(max_count, count) * hp, before + amount)
	if after <= before:
		return 0
	count = (after + hp - 1) / hp
	top_hp = after - (count - 1) * hp
	return after - before


func has_effect(effect_id: StringName) -> bool:
	for effect: Dictionary in effects:
		if effect[&"id"] == effect_id:
			return true
	return false


func has_ability(ability_id: StringName) -> bool:
	for ability: Dictionary in abilities:
		if ability[&"id"] == ability_id:
			return true
	return false


func lost() -> int:
	return initial_count - count


func copy() -> BattleStack:
	var stack: BattleStack = BattleStack.new()
	for property: Dictionary in get_property_list():
		if (int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var value: Variant = get(property["name"])
		if value is Array:
			value = (value as Array).duplicate(true)
		stack.set(property["name"], value)
	return stack
