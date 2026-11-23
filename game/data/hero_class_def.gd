class_name HeroClassDef
extends GameDef

## A hero class: how attributes and skills grow on level-up.

@export var faction: StringName = &""
## Weights of attack, defence, power, knowledge (GameData.ATTRIBUTES order).
@export var attribute_weights: PackedInt32Array = PackedInt32Array([1, 1, 1, 1])
## Attack, defence, power, knowledge of a new hero of this class.
@export var starting_attributes: PackedInt32Array = PackedInt32Array([0, 0, 1, 1])
## Skill id -> weight of being offered.
@export var skill_weights: Dictionary[StringName, int] = {}
@export var starting_skills: Array[StringName] = []
