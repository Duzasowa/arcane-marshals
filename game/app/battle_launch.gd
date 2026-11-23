class_name BattleLaunch
extends RefCounted

## What the next battle screen plays: the two armies, the seed, which sides
## a human controls and how well the bot plays the others. The quick-battle menu fills it; without it the battle
## screen starts a demo battle.

const BATTLE_SCENE: String = "res://game/ui/battle/battle_screen.tscn"
const QUICK_BATTLE_SCENE: String = "res://game/app/quick_battle.tscn"

static var attacker: BattleSideSetup = null
static var defender: BattleSideSetup = null
static var seed_value: int = 1
## Per side: true — a human clicks, false — the bot plays.
static var human: Array[bool] = [true, false]
## Per side: the `BattleAi.Difficulty` of the bot (a human side's "Auto" plays NORMAL).
static var ai_level: Array[int] = [BattleAi.Difficulty.NORMAL, BattleAi.Difficulty.NORMAL]
## Where "back" leads after the battle.
static var return_scene: String = QUICK_BATTLE_SCENE


static func is_set() -> bool:
	return attacker != null and defender != null


## The demo armies: the whole test set on both sides.
static func demo() -> void:
	attacker = BattleSideSetup.new()
	attacker.add(&"throne_militia", 24)
	attacker.add(&"throne_crossbowman", 12)
	attacker.add(&"throne_outrider", 5)
	attacker.add(&"throne_militia", 16)
	defender = BattleSideSetup.new()
	defender.add(&"coven_sporeling", 26)
	defender.add(&"coven_lizard_thrower", 12)
	defender.add(&"coven_dragonfly", 5)
	defender.add(&"coven_sporeling", 14)
	seed_value = 7
	human = [true, false]
