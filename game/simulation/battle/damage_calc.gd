class_name DamageCalc
extends RefCounted

## Damage of one strike (docs/MECHANICS.md §4), whole numbers and permille.
## `context` reads the battle once, then `roll` (the battle) and `estimate`
## (the hit forecast of the UI and the AI) both use it, so the forecast is
## exactly the battle without the dice.

enum Kind { MELEE, RETALIATION, SHOT }

const NORMAL: int = 1000
const HALF: int = 500
const MAX_ROLLS: int = 10
## +5% per point of attack over defence, at most ×3.
const ATTACK_STEP: int = 50
const MAX_MULT: int = 3000
## −5% (compounded) per point of defence over attack, at most −70%.
const MIN_MULT: int = 300
## +10% per extra enemy stack next to the target, at most +30%.
const FLANK_STEP: int = 100
const FLANK_MAX: int = 300
## "Defend": +30% defence, rounded, and always at least +1.
const DEFEND_PERMILLE: int = 300
## Chance per point of luck, permille.
const LUCK_STEP: int = 100
const LUCK_GOOD: int = 2000
const LUCK_BAD: int = 500
## Shots further than this many cells deal half.
const LONG_RANGE: int = 6


## Everything a strike needs from the state.
class Strike:
	var attack: int = 0
	var defence: int = 0
	## Permille bonus for flanking, 0 … FLANK_MAX.
	var flank: int = 0
	## Product of the other multipliers (range, shooter in melee), permille.
	var extra: int = NORMAL
	## Product of the multipliers abilities add (`AbilityHook.modify_*`), permille.
	var ability: int = NORMAL
	## The anchor the attacker strikes from (in a forecast: where it would stand).
	var from: Vector2i = Vector2i.ZERO


static func attack_multiplier(attack: int, defence: int) -> int:
	if attack >= defence:
		return mini(MAX_MULT, NORMAL + ATTACK_STEP * (attack - defence))
	return maxi(MIN_MULT, NORMAL * NORMAL / (NORMAL + ATTACK_STEP * (defence - attack)))


static func defended(defence: int) -> int:
	return defence + maxi(1, (defence * DEFEND_PERMILLE + NORMAL / 2) / NORMAL)


## Up to 10 rolls of `min_dmg … max_dmg`, scaled to the whole stack.
static func roll_base(rng: SimRng, count: int, min_dmg: int, max_dmg: int) -> int:
	if count <= 0:
		return 0
	var rolls: int = mini(count, MAX_ROLLS)
	var total: int = 0
	for i: int in rolls:
		total += rng.range_int(min_dmg, max_dmg)
	return total * count / rolls


## The lowest and the highest base damage: every roll at the minimum or maximum.
static func base_range(count: int, min_dmg: int, max_dmg: int) -> Vector2i:
	return Vector2i(maxi(0, count) * min_dmg, maxi(0, count) * max_dmg)


static func final_damage(base: int, strike: Strike, luck_mult: int) -> int:
	var mult: int = attack_multiplier(strike.attack, strike.defence) * (NORMAL + clampi(strike.flank, 0, FLANK_MAX)) / NORMAL
	var damage: int = base * mult / NORMAL * luck_mult / NORMAL * strike.extra / NORMAL * strike.ability / NORMAL
	return maxi(1, damage)


## The luck multiplier of one strike; rolls only when luck is not 0.
static func roll_luck(rng: SimRng, luck: int) -> int:
	if luck > 0 and rng.chance_permille(luck * LUCK_STEP):
		return LUCK_GOOD
	if luck < 0 and rng.chance_permille(-luck * LUCK_STEP):
		return LUCK_BAD
	return NORMAL


## Reads the strike of `attacker` (standing at `from`) on `target` from the state.
static func context(state: BattleState, attacker: BattleStack, from: Vector2i, target: BattleStack,
		kind: Kind) -> Strike:
	var strike: Strike = Strike.new()
	strike.from = from
	strike.attack = attacker.attack + state.sides[attacker.side].attack
	strike.defence = target.defence + state.sides[target.side].defence
	if target.defending:
		strike.defence = defended(strike.defence)
	if kind == Kind.SHOT:
		if BattleGrid.distance(from, attacker.size, target.cell, target.size) > LONG_RANGE:
			strike.extra = strike.extra * HALF / NORMAL
	else:
		for other: BattleStack in state.alive_stacks(attacker.side):
			if other.id != attacker.id and BattleGrid.adjacent(other.cell, other.size, target.cell, target.size):
				strike.flank += FLANK_STEP
		strike.flank = mini(strike.flank, FLANK_MAX)
		if attacker.is_shooter():
			strike.extra = strike.extra * HALF / NORMAL
	AbilityHooks.modify_strike(state, attacker, target, kind, strike)
	return strike


## The damage of the strike with dice from the battle's generator.
static func roll(state: BattleState, attacker: BattleStack, from: Vector2i, target: BattleStack,
		kind: Kind, luck_mult: int) -> int:
	var strike: Strike = context(state, attacker, from, target, kind)
	return final_damage(roll_base(state.rng, attacker.count, attacker.min_dmg, attacker.max_dmg), strike, luck_mult)


## The hit forecast without dice and without luck: {min_damage, max_damage,
## min_killed, max_killed}. Changes nothing.
static func estimate(state: BattleState, attacker: BattleStack, from: Vector2i, target: BattleStack,
		kind: Kind) -> Dictionary:
	var strike: Strike = context(state, attacker, from, target, kind)
	var base: Vector2i = base_range(attacker.count, attacker.min_dmg, attacker.max_dmg)
	var low: int = final_damage(base.x, strike, NORMAL)
	var high: int = final_damage(base.y, strike, NORMAL)
	return {
		&"min_damage": low,
		&"max_damage": high,
		&"min_killed": target.copy().take_damage(low),
		&"max_killed": target.copy().take_damage(high),
	}
