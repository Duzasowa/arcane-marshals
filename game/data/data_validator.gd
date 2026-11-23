class_name DataValidator
extends RefCounted

## Checks the loaded data: every link by id points at an existing definition of
## the right kind, numbers stay in their ranges. Returns readable problems
## "<kind> '<id>': <problem>"; an empty list means valid.
##
## `full_roster` also demands tiers 1..7 of base units and the four key roles in
## every faction. Off until the content phase (Ф12): the test set fills only a
## few tiers.

const MIN_TIER: int = 1
const MAX_TIER: int = 7
const MAX_SPEED: int = 15
const MAX_INITIATIVE: int = 30
const MAX_ARMY_SLOTS: int = 7
const MAX_PLAYERS: int = 8
const MIN_MAP_SIZE: int = 16
const KEY_ROLES: Array[int] = [
	UnitDef.Role.SHOOTER, UnitDef.Role.TANK, UnitDef.Role.FAST, UnitDef.Role.SUPPORT,
]


static func validate(data: GameData, full_roster: bool = false) -> Array[String]:
	var problems: Array[String] = []
	for def: GameDef in data.all_defs():
		if def.name_key.is_empty():
			problems.append(_label(def) + ": empty name_key")
	for def: FactionDef in data.factions.values():
		_check_faction(def, problems)
	for def: UnitDef in data.units.values():
		_check_unit(data, def, problems)
	for def: AbilityDef in data.abilities.values():
		_check_ability(def, problems)
	for def: SpellDef in data.spells.values():
		_check_spell(def, problems)
	for def: OrderDef in data.orders.values():
		_check_order(def, problems)
	for def: HeroClassDef in data.hero_classes.values():
		_check_hero_class(data, def, problems)
	for def: HeroDef in data.heroes.values():
		_check_hero(data, def, problems)
	for def: SkillDef in data.skills.values():
		_check_skill(def, problems)
	for def: PerkDef in data.perks.values():
		_check_perk(data, def, problems)
	for def: ArtifactDef in data.artifacts.values():
		_check_artifact(def, problems)
	for def: BuildingDef in data.buildings.values():
		_check_building(data, def, problems)
	for def: MapObjectDef in data.map_objects.values():
		_check_map_object(def, problems)
	for def: MapTemplateDef in data.map_templates.values():
		_check_map_template(def, problems)
	if full_roster:
		for def: FactionDef in data.factions.values():
			_check_roster(data, def, problems)
	return problems


static func _check_faction(def: FactionDef, problems: Array[String]) -> void:
	if not GameData.SCHOOLS.has(def.school):
		problems.append(_label(def) + ": unknown school '%s'" % def.school)


static func _check_unit(data: GameData, def: UnitDef, problems: Array[String]) -> void:
	var label: String = _label(def)
	_require(data.factions, def.faction, label, "faction", problems)
	_range(def.tier, MIN_TIER, MAX_TIER, label, "tier", problems)
	_range(def.attack, 0, 1000, label, "attack", problems)
	_range(def.defence, 0, 1000, label, "defence", problems)
	_range(def.min_dmg, 1, def.max_dmg, label, "min_dmg (1..max_dmg)", problems)
	_range(def.hp, 1, 100000, label, "hp", problems)
	_range(def.speed, 1, MAX_SPEED, label, "speed", problems)
	_range(def.initiative, 1, MAX_INITIATIVE, label, "initiative", problems)
	_range(def.shots, 0, 1000, label, "shots", problems)
	_range(def.size, 1, 2, label, "size", problems)
	_range(def.mana, 0, 10000, label, "mana", problems)
	_range(def.magic_resist, 0, 1000, label, "magic_resist", problems)
	_range(def.weekly_growth, 0, 1000, label, "weekly_growth", problems)
	_range(def.exp, 0, 100000, label, "exp", problems)
	_check_cost(def.cost, label, "cost", problems)
	if def.role == UnitDef.Role.SHOOTER and def.shots <= 0:
		problems.append(label + ": a SHOOTER needs shots")
	if not def.spells.is_empty() and def.mana <= 0:
		problems.append(label + ": spells without mana")
	if not def.model.is_empty() and not ResourceLoader.exists(def.model):
		problems.append(label + ": model %s not found" % def.model)
	for ability_id: StringName in def.abilities:
		_require(data.abilities, ability_id, label, "ability", problems)
	for spell_id: StringName in def.spells:
		_require(data.spells, spell_id, label, "spell", problems)
	if def.upgrade_of.is_empty():
		return
	var base: UnitDef = data.unit(def.upgrade_of)
	if base == null:
		problems.append(label + ": unknown upgrade_of '%s'" % def.upgrade_of)
	elif base == def or not base.upgrade_of.is_empty():
		problems.append(label + ": upgrade_of must name a base unit")
	elif base.faction != def.faction or base.tier != def.tier:
		problems.append(label + ": upgrade_of must keep faction and tier")


static func _check_ability(def: AbilityDef, problems: Array[String]) -> void:
	_range(def.ai_weight, -1000, 10000, _label(def), "ai_weight", problems)
	if def.handler != null and not (def.handler.can_instantiate() and def.handler.new() is AbilityHook):
		problems.append(_label(def) + ": handler must extend AbilityHook")


static func _check_spell(def: SpellDef, problems: Array[String]) -> void:
	var label: String = _label(def)
	if not GameData.SCHOOLS.has(def.school):
		problems.append(label + ": unknown school '%s'" % def.school)
	_range(def.level, 1, 3, label, "level", problems)
	_range(def.mana_cost, 0, 1000, label, "mana_cost", problems)
	_range(def.area, 0, 10, label, "area", problems)
	if def.base.size() != SpellDef.MASTERY_LEVELS or def.per_power.size() != SpellDef.MASTERY_LEVELS:
		problems.append(label + ": base and per_power need %d values" % SpellDef.MASTERY_LEVELS)
	if def.duration_rule == SpellDef.Duration.FIXED and def.duration <= 0:
		problems.append(label + ": FIXED duration must be positive")
	if def.handler == null:
		problems.append(label + ": no handler")
	elif not (def.handler.can_instantiate() and def.handler.new() is SpellHook):
		problems.append(label + ": handler must extend SpellHook")


static func _check_order(def: OrderDef, problems: Array[String]) -> void:
	var label: String = _label(def)
	_range(def.cost, 1, 10, label, "cost", problems)
	if def.effect.is_empty():
		problems.append(label + ": empty effect")


static func _check_hero_class(data: GameData, def: HeroClassDef, problems: Array[String]) -> void:
	var label: String = _label(def)
	_require(data.factions, def.faction, label, "faction", problems)
	_check_weights(def.attribute_weights, label, problems)
	if def.starting_attributes.size() != GameData.ATTRIBUTES.size():
		problems.append(label + ": starting_attributes need %d values" % GameData.ATTRIBUTES.size())
	else:
		for value: int in def.starting_attributes:
			_range(value, 0, 99, label, "starting attribute", problems)
	for skill_id: StringName in def.skill_weights:
		_require(data.skills, skill_id, label, "skill in skill_weights", problems)
		_range(def.skill_weights[skill_id], 0, 1000, label, "skill weight", problems)
	for skill_id: StringName in def.starting_skills:
		_require(data.skills, skill_id, label, "starting skill", problems)


static func _check_weights(weights: PackedInt32Array, label: String, problems: Array[String]) -> void:
	if weights.size() != GameData.ATTRIBUTES.size():
		problems.append(label + ": attribute_weights need %d values" % GameData.ATTRIBUTES.size())
		return
	var total: int = 0
	for weight: int in weights:
		if weight < 0:
			problems.append(label + ": negative attribute weight")
		total += weight
	if total <= 0:
		problems.append(label + ": attribute_weights sum to zero")


static func _check_hero(data: GameData, def: HeroDef, problems: Array[String]) -> void:
	var label: String = _label(def)
	_require(data.hero_classes, def.hero_class, label, "hero_class", problems)
	if def.specialization.is_empty():
		problems.append(label + ": empty specialization")
	if def.starting_army.size() > MAX_ARMY_SLOTS:
		problems.append(label + ": starting_army over %d slots" % MAX_ARMY_SLOTS)
	for unit_id: StringName in def.starting_army:
		_require(data.units, unit_id, label, "unit in starting_army", problems)
		_range(def.starting_army[unit_id], 1, 10000, label, "starting_army count", problems)
	for spell_id: StringName in def.starting_spells:
		_require(data.spells, spell_id, label, "starting spell", problems)


static func _check_skill(def: SkillDef, problems: Array[String]) -> void:
	var label: String = _label(def)
	if def.effect.is_empty():
		problems.append(label + ": empty effect")
	if def.level_params.size() != SkillDef.LEVELS:
		problems.append(label + ": level_params need %d entries" % SkillDef.LEVELS)


static func _check_perk(data: GameData, def: PerkDef, problems: Array[String]) -> void:
	var label: String = _label(def)
	_require(data.skills, def.skill, label, "skill", problems)
	_range(def.required_level, 1, SkillDef.LEVELS, label, "required_level", problems)
	if def.effect.is_empty():
		problems.append(label + ": empty effect")


static func _check_artifact(def: ArtifactDef, problems: Array[String]) -> void:
	var label: String = _label(def)
	_range(def.value, 0, 1000000, label, "value", problems)
	for bonus_id: StringName in def.bonuses:
		if bonus_id.is_empty():
			problems.append(label + ": empty bonus id")


static func _check_building(data: GameData, def: BuildingDef, problems: Array[String]) -> void:
	var label: String = _label(def)
	if not def.faction.is_empty():
		_require(data.factions, def.faction, label, "faction", problems)
	_check_cost(def.cost, label, "cost", problems)
	for required: StringName in def.requires:
		_require(data.buildings, required, label, "required building", problems)
	if _requires_itself(data, def):
		problems.append(label + ": requires form a cycle")
	if def.effect == BuildingDef.Effect.DWELLING:
		var dwelling_unit: UnitDef = data.unit(def.dwelling_unit)
		if dwelling_unit == null:
			problems.append(label + ": unknown dwelling_unit '%s'" % def.dwelling_unit)
		elif not def.faction.is_empty() and dwelling_unit.faction != def.faction:
			problems.append(label + ": dwelling_unit of another faction")
	elif not def.dwelling_unit.is_empty():
		problems.append(label + ": dwelling_unit on a non-DWELLING building")


## Depth-first walk over `requires`; true when it comes back to `def`.
static func _requires_itself(data: GameData, def: BuildingDef) -> bool:
	var stack: Array[StringName] = def.requires.duplicate()
	var seen: Dictionary[StringName, bool] = {}
	while not stack.is_empty():
		var current: StringName = stack.pop_back()
		if current == def.id:
			return true
		if seen.has(current):
			continue
		seen[current] = true
		var building: BuildingDef = data.building(current)
		if building != null:
			stack.append_array(building.requires)
	return false


static func _check_map_object(def: MapObjectDef, problems: Array[String]) -> void:
	var label: String = _label(def)
	if def.footprint.is_empty():
		problems.append(label + ": empty footprint")
	elif not _entry_touches(def):
		problems.append(label + ": entry must be on or next to the footprint")
	_check_cost(def.reward, label, "reward", problems, false)
	_range(def.guard_value, 0, 10000000, label, "guard_value", problems)
	_range(def.value, 0, 10000000, label, "value", problems)


static func _entry_touches(def: MapObjectDef) -> bool:
	for cell: Vector2i in def.footprint:
		if absi(cell.x - def.entry.x) <= 1 and absi(cell.y - def.entry.y) <= 1:
			return true
	return false


static func _check_map_template(def: MapTemplateDef, problems: Array[String]) -> void:
	var label: String = _label(def)
	_range(def.players_min, 1, MAX_PLAYERS, label, "players_min", problems)
	_range(def.players_max, def.players_min, MAX_PLAYERS, label, "players_max (players_min..)", problems)
	_range(def.size, MIN_MAP_SIZE, 256, label, "size", problems)
	var zone_ids: Dictionary[StringName, bool] = {}
	var starts: int = 0
	for zone: MapZoneDef in def.zones:
		if zone == null or zone.id.is_empty() or zone_ids.has(zone.id):
			problems.append(label + ": zone ids must be present and unique")
			continue
		zone_ids[zone.id] = true
		if zone.kind == MapZoneDef.Kind.START:
			starts += 1
		_range(zone.size_weight, 1, 100000, label, "zone %s size_weight" % zone.id, problems)
		_check_cost(zone.mines, label, "zone %s mines" % zone.id, problems)
	if starts < def.players_max:
		problems.append(label + ": %d start zones for %d players" % [starts, def.players_max])
	for link: MapLinkDef in def.links:
		if link == null or not zone_ids.has(link.zone_a) or not zone_ids.has(link.zone_b) \
				or link.zone_a == link.zone_b:
			problems.append(label + ": a link must join two different known zones")


static func _check_roster(data: GameData, def: FactionDef, problems: Array[String]) -> void:
	var label: String = _label(def)
	var tiers: Dictionary[int, bool] = {}
	var roles: Dictionary[int, bool] = {}
	for unit: UnitDef in data.units_of_faction(def.id):
		if unit.upgrade_of.is_empty():
			tiers[unit.tier] = true
			roles[unit.role] = true
	for tier: int in range(MIN_TIER, MAX_TIER + 1):
		if not tiers.has(tier):
			problems.append(label + ": no base unit of tier %d" % tier)
	for role: int in KEY_ROLES:
		if not roles.has(role):
			problems.append(label + ": no %s unit" % UnitDef.Role.keys()[role])


## Keys are resource ids (only when `resources_only`), amounts are not negative.
static func _check_cost(
		amounts: Dictionary, label: String, what: String, problems: Array[String], resources_only: bool = true
) -> void:
	for key: StringName in amounts:
		if resources_only and not GameData.RESOURCE_IDS.has(key):
			problems.append(label + ": unknown resource '%s' in %s" % [key, what])
		if int(amounts[key]) < 0:
			problems.append(label + ": negative %s" % what)


static func _require(table: Dictionary, id: StringName, label: String, what: String, problems: Array[String]) -> void:
	if not table.has(id):
		problems.append(label + ": unknown %s '%s'" % [what, id])


static func _range(value: int, low: int, high: int, label: String, what: String, problems: Array[String]) -> void:
	if value < low or value > high:
		problems.append(label + ": %s %d outside %d..%d" % [what, value, low, high])


static func _label(def: GameDef) -> String:
	return "%s '%s'" % [GameData.kind_of(def), def.id]
