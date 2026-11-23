class_name PowerEstimator
extends RefCounted

## Unit power from its numbers (docs/MECHANICS.md §7): the one figure balance,
## the AI and map guards compare. Integer only, so the same data gives the same
## power on every machine.
##
##   power = K × √(avg_dmg × hp) × (1 + A/80) × (1 + D/80)
##           × ranged × mobility × flying × (1 + Σ ability ai_weight)

const K: int = 28
## Permille per point of attack and of defence, over 2000 (12.5 ‰ = 25 / 2000).
const ATTRIBUTE_STEP: int = 25
const RANGED: int = 1150
const FLYING: int = 1100
const SPEED_BASE: int = 5
const SPEED_STEP: int = 30
const INITIATIVE_BASE: int = 10
const INITIATIVE_STEP: int = 15


## `data` supplies ability weights; null ignores abilities.
static func power(unit: UnitDef, data: GameData = null) -> int:
	# √(avg × hp) in thousandths: avg = (min + max) / 2, so the radicand is (min + max) × hp × 10⁶ / 2.
	var value: int = isqrt((unit.min_dmg + unit.max_dmg) * unit.hp * 500000) * K
	value = value * (2000 + ATTRIBUTE_STEP * unit.attack) / 2000
	value = value * (2000 + ATTRIBUTE_STEP * unit.defence) / 2000
	if unit.shots > 0:
		value = value * RANGED / 1000
	value = value * mobility(unit) / 1000
	if unit.flying:
		value = value * FLYING / 1000
	value = value * (1000 + ability_weight(unit, data)) / 1000
	return maxi(1, value / 1000)


## Speed and initiative around an average unit (speed 5, initiative 10), permille.
static func mobility(unit: UnitDef) -> int:
	return maxi(500, 1000 + SPEED_STEP * (unit.speed - SPEED_BASE) + INITIATIVE_STEP * (unit.initiative - INITIATIVE_BASE))


static func ability_weight(unit: UnitDef, data: GameData) -> int:
	if data == null:
		return 0
	var total: int = 0
	for ability_id: StringName in unit.abilities:
		var ability: AbilityDef = data.ability(ability_id)
		if ability != null:
			total += ability.ai_weight
	return total


## Largest r with r² ≤ n; 0 for n ≤ 0. The float root is only a first guess:
## the integer loops make the result exact on every machine.
static func isqrt(n: int) -> int:
	if n <= 0:
		return 0
	# Compared through division, so a root near 2^31.5 does not overflow when squared.
	var root: int = maxi(1, int(sqrt(float(n))))
	while root > n / root:
		root -= 1
	while root + 1 <= n / (root + 1):
		root += 1
	return root
