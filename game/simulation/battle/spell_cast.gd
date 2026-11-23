class_name SpellCast
extends RefCounted

## Hero spells in battle (docs/MECHANICS.md §6): the spell entries a hero keeps
## in the state, the shared formulas (strength by mastery and spell power, magic
## resistance, duration) and the calls of the spell handlers (`SpellHook`). The
## battle core reaches spells only through here.

## Script path -> handler (null for a path that is not a `SpellHook`).
static var _handlers: Dictionary[String, SpellHook] = {}


## The handler of a script path; null when the path is empty or not a spell hook.
static func handler(path: String) -> SpellHook:
	if path.is_empty():
		return null
	if not _handlers.has(path):
		var made: SpellHook = null
		var script: Script = load(path) as Script
		if script != null and script.can_instantiate():
			var instance: Variant = script.new()
			if instance is SpellHook:
				made = instance
			else:
				push_error("SpellCast: '%s' is not a SpellHook" % path)
		else:
			push_error("SpellCast: cannot load '%s'" % path)
		_handlers[path] = made
	return _handlers[path]


## The spell entry a hero keeps in the battle state.
static func entry_of(def: SpellDef) -> Dictionary:
	return {
		&"id": def.id,
		&"handler": def.handler.resource_path if def.handler != null else "",
		&"school": def.school,
		&"level": def.level,
		&"mana_cost": def.mana_cost,
		&"target": int(def.target),
		&"area": def.area,
		&"base": def.base.duplicate(),
		&"per_power": def.per_power.duplicate(),
		&"effect": int(def.effect),
		&"duration_rule": int(def.duration_rule),
		&"duration": def.duration,
		&"params": def.params.duplicate(true),
	}


## The strength of `spell` cast by `hero`: base[m] + per_power[m] × spell power,
## m — the hero's mastery of the school.
static func strength(hero: BattleHero, spell: Dictionary) -> int:
	var level: int = hero.mastery_of(spell[&"school"])
	var base: PackedInt32Array = spell[&"base"]
	var per_power: PackedInt32Array = spell[&"per_power"]
	var at_base: int = base[level] if level < base.size() else 0
	var at_power: int = per_power[level] if level < per_power.size() else 0
	return maxi(0, at_base + at_power * maxi(0, hero.power))


## Spell damage `amount` after the magic resistance of `target` (at least 1).
static func resisted(target: BattleStack, amount: int) -> int:
	if amount <= 0:
		return 0
	return maxi(1, amount * (1000 - clampi(target.magic_resist, 0, 1000)) / 1000)


## Turns of the target an effect of `spell` lasts (0 — no effect).
static func duration(hero: BattleHero, spell: Dictionary) -> int:
	match int(spell[&"duration_rule"]):
		SpellDef.Duration.BY_POWER:
			return 1 + maxi(0, hero.power) / 4
		SpellDef.Duration.FIXED:
			return int(spell[&"duration"])
	return 0


## Why `hero` may not cast `spell_id` at all now ("" — it may, given a target).
static func cannot_cast(hero: BattleHero, spell_id: StringName) -> String:
	var spell: Dictionary = hero.spell(spell_id)
	if spell.is_empty():
		return "the hero has no spell %s" % spell_id
	if hero.mana < int(spell[&"mana_cost"]):
		return "not enough mana for %s" % spell_id
	return ""


## The stacks `hero` may cast `spell_id` on now (mana aside).
static func targets(state: BattleState, hero: BattleHero, spell_id: StringName) -> Array[BattleStack]:
	var spell: Dictionary = hero.spell(spell_id)
	var hook: SpellHook = handler(spell.get(&"handler", ""))
	return hook.targets(state, hero, spell) if hook != null else []


static func estimate(state: BattleState, hero: BattleHero, spell_id: StringName, target: BattleStack) -> Dictionary:
	var spell: Dictionary = hero.spell(spell_id)
	var hook: SpellHook = handler(spell.get(&"handler", ""))
	return hook.estimate(state, hero, spell, target) if hook != null else no_estimate()


static func cast(state: BattleState, hero: BattleHero, spell_id: StringName, target: BattleStack) -> void:
	var spell: Dictionary = hero.spell(spell_id)
	var hook: SpellHook = handler(spell.get(&"handler", ""))
	if hook != null:
		hook.cast(state, hero, spell, target)


## The estimate of a spell that deals `damage` to `target` (no dice).
static func damage_estimate(target: BattleStack, damage: int) -> Dictionary:
	var probe: BattleStack = target.copy()
	var killed: int = probe.take_damage(damage)
	return {&"min_damage": damage, &"max_damage": damage, &"min_killed": killed, &"max_killed": killed}


static func no_estimate() -> Dictionary:
	return {&"min_damage": 0, &"max_damage": 0, &"min_killed": 0, &"max_killed": 0}
