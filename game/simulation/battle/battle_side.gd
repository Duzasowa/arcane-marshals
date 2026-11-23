class_name BattleSide
extends RefCounted

## What a side brings to the battle besides its stacks: the hero's bonuses
## (attack, defence) and the army's morale and luck (−3 … +3).

const MORALE_MIN: int = -3
const MORALE_MAX: int = 3

var attack: int = 0
var defence: int = 0
var morale: int = 0
var luck: int = 0


func copy() -> BattleSide:
	var side: BattleSide = BattleSide.new()
	side.attack = attack
	side.defence = defence
	side.morale = morale
	side.luck = luck
	return side
