class_name ArtifactDef
extends GameDef

## An artifact worn in one slot.

enum Slot { HEAD, BODY, WEAPON, SHIELD, RING, AMULET }
enum Rarity { MINOR, MAJOR, RELIC }

@export var slot: Slot = Slot.HEAD
## Bonus id (attack, defence, luck...) -> amount.
@export var bonuses: Dictionary[StringName, int] = {}
## Gold value for treasure budgets and the AI.
@export var value: int = 0
@export var rarity: Rarity = Rarity.MINOR
@export var icon: String = ""
