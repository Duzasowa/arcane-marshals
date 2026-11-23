class_name GameData
extends RefCounted

## The registry of every definition under data/, by type and id. The simulation
## only reads it. Loading never stops at the first problem: every error is kept
## in `errors`, and `DataValidator` checks the links afterwards.

const DATA_ROOT: String = "res://data"
const RESOURCE_IDS: Array[StringName] = [&"gold", &"wood", &"ore", &"crystal"]
const SCHOOLS: Array[StringName] = [&"order", &"decay"]
const ATTRIBUTES: Array[StringName] = [&"attack", &"defence", &"power", &"knowledge"]

var units: Dictionary[StringName, UnitDef] = {}
var abilities: Dictionary[StringName, AbilityDef] = {}
var spells: Dictionary[StringName, SpellDef] = {}
var orders: Dictionary[StringName, OrderDef] = {}
var factions: Dictionary[StringName, FactionDef] = {}
var hero_classes: Dictionary[StringName, HeroClassDef] = {}
var heroes: Dictionary[StringName, HeroDef] = {}
var skills: Dictionary[StringName, SkillDef] = {}
var perks: Dictionary[StringName, PerkDef] = {}
var artifacts: Dictionary[StringName, ArtifactDef] = {}
var buildings: Dictionary[StringName, BuildingDef] = {}
var map_objects: Dictionary[StringName, MapObjectDef] = {}
var map_templates: Dictionary[StringName, MapTemplateDef] = {}

var errors: Array[String] = []


## Loads every .tres/.res under `root` in sorted path order. True when no error.
func load_all(root: String = DATA_ROOT) -> bool:
	var paths: Array[String] = []
	_collect(root, paths)
	paths.sort()
	for path: String in paths:
		var resource: Resource = ResourceLoader.load(path)
		if resource == null:
			errors.append("%s: cannot load" % path)
		elif not resource is GameDef:
			errors.append("%s: not a GameDef" % path)
		else:
			add(resource as GameDef, path)
	return errors.is_empty()


## Registers one definition; `source` names it in errors. False on a problem.
func add(def: GameDef, source: String = "") -> bool:
	var label: String = source if not source.is_empty() else String(def.id)
	var kind: StringName = kind_of(def)
	if kind.is_empty():
		errors.append("%s: unknown definition type" % label)
		return false
	if def.id.is_empty():
		errors.append("%s: empty id" % label)
		return false
	var table: Dictionary = tables()[kind]
	if table.has(def.id):
		errors.append("%s: duplicate %s id '%s'" % [label, kind, def.id])
		return false
	table[def.id] = def
	return true


## Kind name -> table, in a fixed order.
func tables() -> Dictionary[StringName, Dictionary]:
	return {
		&"faction": factions, &"unit": units, &"ability": abilities, &"spell": spells, &"order": orders,
		&"hero_class": hero_classes, &"hero": heroes, &"skill": skills, &"perk": perks,
		&"artifact": artifacts, &"building": buildings, &"map_object": map_objects,
		&"map_template": map_templates,
	}


## Every definition, kind by kind, each kind in insertion (sorted path) order.
func all_defs() -> Array[GameDef]:
	var result: Array[GameDef] = []
	for table: Dictionary in tables().values():
		for def: GameDef in table.values():
			result.append(def)
	return result


static func kind_of(def: GameDef) -> StringName:
	if def is UnitDef:
		return &"unit"
	if def is AbilityDef:
		return &"ability"
	if def is SpellDef:
		return &"spell"
	if def is OrderDef:
		return &"order"
	if def is FactionDef:
		return &"faction"
	if def is HeroClassDef:
		return &"hero_class"
	if def is HeroDef:
		return &"hero"
	if def is SkillDef:
		return &"skill"
	if def is PerkDef:
		return &"perk"
	if def is ArtifactDef:
		return &"artifact"
	if def is BuildingDef:
		return &"building"
	if def is MapObjectDef:
		return &"map_object"
	if def is MapTemplateDef:
		return &"map_template"
	return &""


func unit(id: StringName) -> UnitDef:
	return units.get(id)


func faction(id: StringName) -> FactionDef:
	return factions.get(id)


func ability(id: StringName) -> AbilityDef:
	return abilities.get(id)


func spell(id: StringName) -> SpellDef:
	return spells.get(id)


func order(id: StringName) -> OrderDef:
	return orders.get(id)


func hero_class(id: StringName) -> HeroClassDef:
	return hero_classes.get(id)


func hero(id: StringName) -> HeroDef:
	return heroes.get(id)


func skill(id: StringName) -> SkillDef:
	return skills.get(id)


func perk(id: StringName) -> PerkDef:
	return perks.get(id)


func artifact(id: StringName) -> ArtifactDef:
	return artifacts.get(id)


func building(id: StringName) -> BuildingDef:
	return buildings.get(id)


func map_object(id: StringName) -> MapObjectDef:
	return map_objects.get(id)


func map_template(id: StringName) -> MapTemplateDef:
	return map_templates.get(id)


## Units of a faction ordered by tier, base before its upgrade, then by id.
func units_of_faction(faction_id: StringName) -> Array[UnitDef]:
	var result: Array[UnitDef] = []
	for def: UnitDef in units.values():
		if def.faction == faction_id:
			result.append(def)
	result.sort_custom(_unit_before)
	return result


static func _unit_before(a: UnitDef, b: UnitDef) -> bool:
	if a.tier != b.tier:
		return a.tier < b.tier
	var a_upgrade: bool = not a.upgrade_of.is_empty()
	var b_upgrade: bool = not b.upgrade_of.is_empty()
	if a_upgrade != b_upgrade:
		return b_upgrade
	return String(a.id) < String(b.id)


## Resource files under `directory_path`. An exported build lists `x.tres.remap`
## instead of `x.tres`; the suffix is dropped and the loader follows the remap.
static func _collect(directory_path: String, into: Array[String]) -> void:
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		return
	for subdirectory: String in directory.get_directories():
		_collect(directory_path.path_join(subdirectory), into)
	for file_name: String in directory.get_files():
		var name: String = file_name.trim_suffix(".remap")
		if name.ends_with(".tres") or name.ends_with(".res"):
			var path: String = directory_path.path_join(name)
			if not into.has(path):
				into.append(path)
