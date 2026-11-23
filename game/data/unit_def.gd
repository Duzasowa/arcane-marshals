class_name UnitDef
extends GameDef

## A creature type. Numbers of the rules are integers; permille where a share.

## Battle role (docs/GAME_SKELETON.md §5): every full faction needs a shooter,
## a tank, a fast unit and a support.
enum Role { MASS, SHOOTER, TANK, FAST, SUPPORT, ELITE, CHAMPION }

@export var faction: StringName = &""
@export_range(1, 7) var tier: int = 1
@export var role: Role = Role.MASS
## Id of the base unit this one upgrades; empty for a base unit.
@export var upgrade_of: StringName = &""

@export var attack: int = 0
@export var defence: int = 0
@export var min_dmg: int = 1
@export var max_dmg: int = 1
@export var hp: int = 1
@export var speed: int = 4
@export var initiative: int = 10
## Shots per battle; 0 for a melee unit.
@export var shots: int = 0
## Cells per side: 1, or 2 for a large 2x2 creature.
@export var size: int = 1
@export var flying: bool = false

@export var abilities: Array[StringName] = []
@export var spells: Array[StringName] = []
@export var mana: int = 0
## Share of spell damage ignored, permille.
@export var magic_resist: int = 0
@export var no_morale: bool = false

@export var weekly_growth: int = 0
## Resource id -> amount per creature.
@export var cost: Dictionary[StringName, int] = {}
## Experience a hero gets for each killed creature.
@export var exp: int = 0

## Our own art (Ф3/Ф13); placeholders come from PlaceholderAssets by id.
@export var model: String = ""
@export var portrait: String = ""
## Event (attack, hit, death...) -> sound path.
@export var sounds: Dictionary[StringName, String] = {}


func is_shooter() -> bool:
	return shots > 0
