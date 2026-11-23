class_name BattleSideSetup
extends RefCounted

## The input for one side of a battle: up to 7 army slots and the side bonuses.

const MAX_SLOTS: int = 7

## Unit id per slot; an empty id — an empty slot.
var slot_units: Array[StringName] = []
var slot_counts: PackedInt32Array = PackedInt32Array()
var bonuses: BattleSide = BattleSide.new()
## The hero leading the side; empty — none.
var hero_id: StringName = &""
## Attack, defence, power, knowledge of the hero (`GameData.ATTRIBUTES` order).
var hero_attributes: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
## Mana the hero brings; -1 — full (knowledge × 10).
var hero_mana: int = -1
## Spell ids in the hero's book.
var hero_spells: Array[StringName] = []


func _init() -> void:
	slot_units.resize(MAX_SLOTS)
	slot_units.fill(&"")
	slot_counts.resize(MAX_SLOTS)
	slot_counts.fill(0)


## Puts a fresh hero `id` at the head of the side: the attributes of its class,
## its starting spells, full mana. An unknown or empty id removes the hero.
func set_hero(data: GameData, id: StringName) -> void:
	hero_id = &""
	hero_attributes = PackedInt32Array([0, 0, 0, 0])
	hero_mana = -1
	hero_spells = []
	var def: HeroDef = data.hero(id) if id != &"" else null
	if def == null:
		return
	hero_id = id
	var hero_class: HeroClassDef = data.hero_class(def.hero_class)
	if hero_class != null and hero_class.starting_attributes.size() == GameData.ATTRIBUTES.size():
		hero_attributes = hero_class.starting_attributes.duplicate()
	hero_spells = def.starting_spells.duplicate()


func has_hero() -> bool:
	return hero_id != &""


## Puts `count` × `unit_id` into the first empty slot; false when full.
func add(unit_id: StringName, count: int) -> bool:
	for slot: int in MAX_SLOTS:
		if slot_units[slot] == &"":
			set_slot(slot, unit_id, count)
			return true
	return false


func set_slot(slot: int, unit_id: StringName, count: int) -> void:
	slot_units[slot] = unit_id
	slot_counts[slot] = count


func is_empty() -> bool:
	for slot: int in MAX_SLOTS:
		if slot_units[slot] != &"" and slot_counts[slot] > 0:
			return false
	return true
