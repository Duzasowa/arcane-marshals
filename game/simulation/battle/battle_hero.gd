class_name BattleHero
extends RefCounted

## The hero of one side in a battle (docs/MECHANICS.md §2, §6): stands on the
## initiative line and on its turn casts one spell or passes. Its attack and
## defence are already in `BattleSide`; power and knowledge drive the spells.
## Copies its spells from `SpellDef` (`SpellCast.entry_of`), so the battle state
## never needs `GameData`.

const INITIATIVE: int = 10
## Mana per point of knowledge.
const MANA_PER_KNOWLEDGE: int = 10

var hero_id: StringName = &""
var side: int = 0
var attack: int = 0
var defence: int = 0
var power: int = 0
var knowledge: int = 0
var mana: int = 0
var max_mana: int = 0
var atb: int = 0
var initiative: int = INITIATIVE
## Spell entries (`SpellCast.entry_of`), in book order.
var spells: Array[Dictionary] = []
## School id -> mastery 0 … 3 (skills, Ф8).
var mastery: Dictionary[StringName, int] = {}


func spell(spell_id: StringName) -> Dictionary:
	for entry: Dictionary in spells:
		if entry[&"id"] == spell_id:
			return entry
	return {}


func mastery_of(school: StringName) -> int:
	return clampi(int(mastery.get(school, 0)), 0, SpellDef.MASTERY_LEVELS - 1)


func copy() -> BattleHero:
	var hero: BattleHero = BattleHero.new()
	for property: Dictionary in get_property_list():
		if (int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var value: Variant = get(property["name"])
		if value is Array or value is Dictionary:
			value = value.duplicate(true)
		hero.set(property["name"], value)
	return hero
