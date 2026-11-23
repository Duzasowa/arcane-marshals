class_name BattleAi
extends RefCounted

## The battle AI (docs/MECHANICS.md §12): scores every action of the active
## stack and returns the best one as a command, like any player. Reads the
## state, never changes it; the same state and the same `ai_seed` give the same
## command.
##
## Score, in power units (creature power × creatures, `BattleStack.power`):
##   gain      — value of the expected blow (+ a bonus for wiping the stack out)
##               minus the value of the expected retaliation;
##   risk      — value the enemies are expected to take from our whole army
##               before this stack's next turn, with it where it ends this one:
##               each enemy strikes once at the target that pays it best, each
##               of our stacks retaliates once, a hurt enemy strikes weaker (full
##               weight for enemies who act before this stack, half for the
##               rest), × the risk weight;
##   position  — for a move: the way made towards the enemy (walkers) and how
##               much better a blow it can deal next turn from there than from
##               where it stands; a small bonus for waiting.
## Difficulty: noise on the score, how much risk counts, and (HARD) a look at
## the best reply of the enemy who moves next, on a copy of the state.

enum Difficulty { EASY, NORMAL, HARD }

## Per difficulty: random spread of the score, permille.
const NOISE: Array[int] = [350, 50, 0]
## Per difficulty: how much the threat of the next turn counts, permille.
const RISK_WEIGHT: Array[int] = [300, 1000, 1000]
## Per difficulty: how many of the best actions are checked one turn deeper.
const LOOKAHEAD: Array[int] = [0, 0, 4]

const NORMAL: int = 1000
## Wiping a stack out ends its turns and its retaliation: bonus over the value.
const KILL_BONUS: int = 300
## Threat of the enemies who act only after this stack's next turn.
const LATE_ENEMY: int = 500
## The blow it could deal next turn from where it stands, permille.
const POTENTIAL: int = 100
## Way made towards the enemy, permille of the stack's own value per full move.
const APPROACH: int = 100
## Waiting lets the enemy come first, permille of the stack's own value.
const WAIT_BONUS: int = 30
## A long battle makes the AI bolder: after `BOLD_TURNS` turns the threat and
## the retaliation count `BOLD_STEP` ‰ less per turn, down to nothing, so a
## side that is behind cannot run from the enemy for ever.
const BOLD_TURNS: int = 100
const BOLD_STEP: int = 5
## Scores for an action that wins or loses the battle on the spot.
const DECISIVE: int = 1 << 40

var difficulty: Difficulty = Difficulty.NORMAL
var ai_seed: int = 0


func _init(level: Difficulty = Difficulty.NORMAL, seed_value: int = 0) -> void:
	difficulty = level
	ai_seed = seed_value


## The command for the active stack or hero; null when nobody has the turn.
## A hero passes for now (spells — step 5.6).
func choose(state: BattleState) -> BattleCmd:
	if state.active_hero >= 0 and not state.is_over():
		return HeroPassCmd.new(state.active_hero)
	var who: BattleStack = state.active_stack()
	if who == null or state.is_over():
		return null
	var scored: Array[Dictionary] = score_actions(state, RISK_WEIGHT[difficulty])
	if scored.is_empty():
		return DefendCmd.new(who.id)
	var noise: int = NOISE[difficulty]
	if noise > 0:
		var rng: SimRng = SimRng.new(_turn_seed(state))
		for entry: Dictionary in scored:
			var score: int = entry[&"score"]
			entry[&"score"] = score + absi(score) * rng.range_int(-noise, noise) / NORMAL
	var depth: int = LOOKAHEAD[difficulty]
	if depth > 0:
		_look_ahead(state, who, scored, depth)
	var best: Dictionary = scored[0]
	for entry: Dictionary in scored:
		if int(entry[&"score"]) > int(best[&"score"]):
			best = entry
	return best[&"cmd"]


## Every action of the active stack with its score parts: {cmd, gain, risk,
## position, score}, in `BattleActions.all` order.
func score_actions(state: BattleState, risk_weight: int) -> Array[Dictionary]:
	var scored: Array[Dictionary] = []
	var who: BattleStack = state.active_stack()
	if who == null:
		return scored
	var view: FieldView = FieldView.new(state, who)
	var careful: int = caution(state.turn_count)
	risk_weight = risk_weight * careful / NORMAL
	var potential_here: int = view.potential(who.cell)
	for cmd: BattleCmd in BattleActions.all(state):
		var gain: int = 0
		var lost: int = 0
		var spot: Vector2i = who.cell
		var hurt_id: int = -1
		var hurt_damage: int = 0
		var defending: bool = false
		var position: int = 0
		if cmd is ShootCmd:
			var target: BattleStack = state.stack((cmd as ShootCmd).target_id)
			hurt_damage = average_damage(state, who, who.cell, target, DamageCalc.Kind.SHOT)
			gain = blow_value(target, hurt_damage)
			hurt_id = target.id
		elif cmd is AttackCmd:
			var attack: AttackCmd = cmd as AttackCmd
			var target: BattleStack = state.stack(attack.target_id)
			spot = attack.from
			hurt_damage = average_damage(state, who, spot, target, DamageCalc.Kind.MELEE)
			gain = blow_value(target, hurt_damage)
			var back: Dictionary = BattleForecast.retaliation(state, who, spot, target, hurt_damage)
			if not back.is_empty():
				lost = blow_value(who, _average(back))
			hurt_id = target.id
		elif cmd is MoveCmd:
			spot = (cmd as MoveCmd).to
			position = view.approach(spot) + view.potential(spot) - potential_here
		elif cmd is WaitCmd:
			position = view.own_value * WAIT_BONUS / NORMAL
		elif cmd is DefendCmd:
			defending = true
		var risk: int = view.threat(spot, defending, hurt_id, hurt_damage)
		var score: int = gain - lost * careful / NORMAL + position - risk * risk_weight / NORMAL
		scored.append({&"cmd": cmd, &"gain": gain - lost, &"risk": risk, &"position": position, &"score": score})
	return scored


## Value of `damage` dealt to `target`: the creatures' worth of HP it takes,
## plus `KILL_BONUS` when the stack is wiped out.
static func blow_value(target: BattleStack, damage: int) -> int:
	if target.hp <= 0 or damage <= 0:
		return 0
	var taken: int = mini(damage, target.total_hp())
	var value: int = taken * target.power / target.hp
	if taken >= target.total_hp():
		value += value * KILL_BONUS / NORMAL
	return value


## Value of a stack: every creature's worth.
static func stack_value(target: BattleStack) -> int:
	return 0 if target.hp <= 0 else target.total_hp() * target.power / target.hp


## The most a blow can be worth on `target`: its whole value with `KILL_BONUS`.
static func wipe_value(target: BattleStack) -> int:
	var value: int = stack_value(target)
	return value + value * KILL_BONUS / NORMAL


## Creatures left in `target` after `damage`, without changing it.
static func count_after(target: BattleStack, damage: int) -> int:
	var left: int = target.total_hp() - maxi(0, damage)
	return 0 if left <= 0 else (left + target.hp - 1) / target.hp


## The middle of a `DamageCalc.estimate` range.
static func _average(estimate: Dictionary) -> int:
	return (int(estimate[&"min_damage"]) + int(estimate[&"max_damage"])) / 2


## The middle of the damage range of a strike, as `DamageCalc.estimate` counts
## it but without copying stacks for the deaths (the AI asks this a lot).
static func average_damage(state: BattleState, attacker: BattleStack, from: Vector2i, target: BattleStack,
		kind: DamageCalc.Kind) -> int:
	var strike: DamageCalc.Strike = DamageCalc.context(state, attacker, from, target, kind)
	var base: Vector2i = DamageCalc.base_range(attacker.count, attacker.min_dmg, attacker.max_dmg)
	return (DamageCalc.final_damage(base.x, strike, NORMAL) + DamageCalc.final_damage(base.y, strike, NORMAL)) / 2


## Permille of caution left after `turn_count` turns (see `BOLD_TURNS`).
static func caution(turn_count: int) -> int:
	return clampi(NORMAL - (turn_count - BOLD_TURNS) * BOLD_STEP, 0, NORMAL)


## Heroes on the initiative line of `state`.
static func hero_count(state: BattleState) -> int:
	var count: int = 0
	for hero: BattleHero in state.heroes:
		if hero != null:
			count += 1
	return count


func _turn_seed(state: BattleState) -> int:
	return ai_seed * 1000003 + state.turn_count * 31 + state.active_id


## HARD: plays the best few actions on copies of the state (fresh dice, so the
## AI cannot peek at the battle's own rolls) and, when an enemy moves next,
## counts its best blow instead of the estimated threat if that is worse.
func _look_ahead(state: BattleState, who: BattleStack, scored: Array[Dictionary], depth: int) -> void:
	var order: Array[Dictionary] = scored.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a[&"score"]) > int(b[&"score"]))
	var risk_weight: int = RISK_WEIGHT[difficulty] * caution(state.turn_count) / NORMAL
	for k: int in mini(depth, order.size()):
		var entry: Dictionary = order[k]
		var copy: BattleState = state.clone()
		copy.rng = SimRng.new(_turn_seed(state) + k + 1)
		copy.apply(entry[&"cmd"])
		if copy.is_over():
			entry[&"score"] = DECISIVE if copy.result.winner == who.side else -DECISIVE
			continue
		var next: BattleStack = copy.active_stack()
		if next == null or next.side == who.side:
			continue
		var reply: int = best_gain(copy, next)
		var risk: int = entry[&"risk"]
		if reply > risk:
			entry[&"score"] = int(entry[&"score"]) - (reply - risk) * risk_weight / NORMAL


## The best gain `who` (the active stack) can take with one shot or blow now.
static func best_gain(state: BattleState, who: BattleStack) -> int:
	var best: int = 0
	var enemies: Array[BattleStack] = state.enemies_of(who)
	if state.can_shoot(who):
		for enemy: BattleStack in enemies:
			best = maxi(best, blow_value(enemy, average_damage(state, who, who.cell, enemy,
					DamageCalc.Kind.SHOT)))
	var reach: Dictionary[int, int] = BattlePathfinder.reachable(state, who)
	for enemy: BattleStack in enemies:
		for spot: Vector2i in state.attack_spots(who, enemy, reach):
			var damage: int = average_damage(state, who, spot, enemy, DamageCalc.Kind.MELEE)
			var gain: int = blow_value(enemy, damage)
			var back: Dictionary = BattleForecast.retaliation(state, who, spot, enemy, damage)
			if not back.is_empty():
				gain -= blow_value(who, _average(back))
			best = maxi(best, gain)
	return best


## What one decision needs about the field, worked out once: where each enemy
## can strike next turn, what it would take from each of our other stacks, who
## acts before this stack does again, the way to the enemy. Then each
## candidate cell costs only the lookups that involve the active stack.
class FieldView:
	var state: BattleState
	var who: BattleStack
	## `who` as if it stood elsewhere (moved by `_place`).
	var probe: BattleStack
	var enemies: Array[BattleStack] = []
	## Our other living stacks.
	var allies: Array[BattleStack] = []
	## Per enemy: permille weight of its threat.
	var weights: Array[int] = []
	## Per enemy: 1 per anchor of `who` it can get next to next turn.
	var touch: Array[PackedByteArray] = []
	## Per enemy: one of `allies` stands next to it, so it cannot shoot.
	var held: Array[bool] = []
	## Per enemy, per ally: value of its shot / its melee blow (0 — cannot
	## reach) on that ally, and the value of the ally's retaliation after it.
	var ally_shot: Array[PackedInt32Array] = []
	var ally_melee: Array[PackedInt32Array] = []
	var ally_answer: Array[PackedInt32Array] = []
	## Per ally: the most it can lose (its value with the wipe-out bonus).
	var ally_cap: PackedInt32Array = PackedInt32Array()
	var own_value: int = 0
	var budget: int = 0
	var walker: bool = false
	var way: PackedInt32Array = PackedInt32Array()

	func _init(battle: BattleState, active: BattleStack) -> void:
		state = battle
		who = active
		probe = active.copy()
		own_value = BattleAi.stack_value(active)
		budget = BattlePathfinder.move_budget(active)
		walker = active.shots_left <= 0
		enemies = battle.enemies_of(active)
		for ally: BattleStack in battle.alive_stacks(active.side):
			if ally.id != active.id:
				allies.append(ally)
				ally_cap.append(BattleAi.wipe_value(ally))
		var order: Array[int] = AtbTimeline.forecast(battle, (battle.alive_stacks().size() + BattleAi.hero_count(battle)) * 2 + 1)
		var next_turn: int = order.find(active.id, 1)
		for enemy: BattleStack in enemies:
			var at: int = order.find(enemy.id, 1)
			weights.append(BattleAi.NORMAL if at >= 0 and (next_turn < 0 or at < next_turn) else BattleAi.LATE_ENEMY)
			var reach: Dictionary[int, int] = BattlePathfinder.reachable(battle, enemy)
			touch.append(_touch_map(enemy, reach))
			var is_held: bool = false
			var shots: PackedInt32Array = PackedInt32Array()
			var blows: PackedInt32Array = PackedInt32Array()
			var answers: PackedInt32Array = PackedInt32Array()
			for ally: BattleStack in allies:
				if BattleGrid.adjacent(ally.cell, ally.size, enemy.cell, enemy.size):
					is_held = true
				var shot: int = 0
				if enemy.shots_left > 0:
					shot = BattleAi.blow_value(ally, BattleAi.average_damage(battle, enemy, enemy.cell, ally,
							DamageCalc.Kind.SHOT))
				shots.append(shot)
				var blow: int = 0
				var answer: int = 0
				if _can_touch(enemy, reach, ally):
					var damage: int = BattleAi.average_damage(battle, enemy, enemy.cell, ally, DamageCalc.Kind.MELEE)
					blow = BattleAi.blow_value(ally, damage)
					answer = _answer(ally.copy(), ally.cell, enemy, damage)
				blows.append(blow)
				answers.append(answer)
			held.append(is_held)
			ally_shot.append(shots)
			ally_melee.append(blows)
			ally_answer.append(answers)
		if walker and not enemies.is_empty():
			way = BattlePathfinder.way_to(battle, active, enemies)

	## Anchors of `who` that `enemy` can stand next to after its move.
	func _touch_map(enemy: BattleStack, reach: Dictionary[int, int]) -> PackedByteArray:
		var marks: PackedByteArray = PackedByteArray()
		marks.resize(BattleGrid.CELL_COUNT)
		marks.fill(0)
		var size: int = who.size
		for cell_index: int in reach:
			var anchor: Vector2i = BattleGrid.cell_at(cell_index)
			for y: int in range(anchor.y - size, anchor.y + enemy.size + 1):
				for x: int in range(anchor.x - size, anchor.x + enemy.size + 1):
					var cell: Vector2i = Vector2i(x, y)
					if BattleGrid.rect_in_bounds(cell, size) and BattleGrid.adjacent(cell, size, anchor, enemy.size):
						marks[BattleGrid.index(cell)] = 1
		return marks

	static func _can_touch(enemy: BattleStack, reach: Dictionary[int, int], target: BattleStack) -> bool:
		for cell_index: int in reach:
			if BattleGrid.adjacent(BattleGrid.cell_at(cell_index), enemy.size, target.cell, target.size):
				return true
		return false

	func _place(spot: Vector2i, defending: bool) -> void:
		probe.cell = spot
		probe.defending = defending

	## Expected value the enemies take from our army before `who`'s next turn,
	## with `who` at `spot`: each enemy strikes once, at the target that pays it
	## best (its blow minus the retaliation it gets back), and each of our
	## stacks retaliates once. `hurt_id` — an enemy this action first deals
	## `hurt_damage` to (it strikes back weaker, or not at all if it dies).
	func threat(spot: Vector2i, defending: bool, hurt_id: int, hurt_damage: int) -> int:
		_place(spot, defending)
		var mine: int = allies.size()
		var taken: PackedInt32Array = PackedInt32Array()
		taken.resize(mine + 1)
		taken.fill(0)
		var answered: PackedInt32Array = PackedInt32Array()
		answered.resize(mine + 1)
		answered.fill(0)
		for i: int in enemies.size():
			var enemy: BattleStack = enemies[i]
			var left: int = enemy.count
			if enemy.id == hurt_id:
				left = BattleAi.count_after(enemy, hurt_damage)
				if left <= 0:
					continue
			var next_to: bool = BattleGrid.adjacent(spot, who.size, enemy.cell, enemy.size)
			var shooting: bool = enemy.shots_left > 0 and not held[i] and not next_to
			var target: int = -1
			var value: int = 0
			var answer: int = 0
			for j: int in mine:
				var blow: int = ally_shot[i][j] if shooting else ally_melee[i][j]
				var back: int = 0 if shooting else ally_answer[i][j]
				if blow > 0 and (target < 0 or blow - back > value - answer):
					target = j
					value = blow
					answer = back
			var damage: int = 0
			if shooting:
				damage = BattleAi.average_damage(state, enemy, enemy.cell, probe, DamageCalc.Kind.SHOT)
			elif next_to or touch[i][BattleGrid.index(spot)] != 0:
				damage = BattleAi.average_damage(state, enemy, enemy.cell, probe, DamageCalc.Kind.MELEE)
			if damage > 0:
				var blow: int = BattleAi.blow_value(who, damage)
				var back: int = 0 if shooting else _answer(probe, spot, enemy, damage)
				if target < 0 or blow - back > value - answer:
					target = mine
					value = blow
					answer = back
			if target < 0:
				continue
			var scale: int = weights[i] * left / maxi(1, enemy.count)
			taken[target] += value * scale / BattleAi.NORMAL
			answered[target] = maxi(answered[target], answer * scale / BattleAi.NORMAL)
		var total: int = 0
		for t: int in mine + 1:
			var cap: int = ally_cap[t] if t < mine else BattleAi.wipe_value(who)
			total += clampi(taken[t] - answered[t], 0, cap)
		return total

	## Value of the retaliation of `defender` (a scratch copy, restored after)
	## at `spot` once it has taken `damage` from `enemy`.
	func _answer(defender: BattleStack, spot: Vector2i, enemy: BattleStack, damage: int) -> int:
		if not state.will_retaliate(enemy, defender):
			return 0
		var count: int = defender.count
		var top_hp: int = defender.top_hp
		defender.take_damage(damage)
		var back: int = 0
		if defender.is_alive():
			back = BattleAi.blow_value(enemy, BattleAi.average_damage(state, defender, spot, enemy,
					DamageCalc.Kind.RETALIATION))
		defender.count = count
		defender.top_hp = top_hp
		return back

	## The best blow `who` could deal next turn from `spot`, × `BattleAi.POTENTIAL`.
	func potential(spot: Vector2i) -> int:
		_place(spot, false)
		var free_to_shoot: bool = who.shots_left > 0
		if free_to_shoot:
			for enemy: BattleStack in enemies:
				if BattleGrid.adjacent(spot, who.size, enemy.cell, enemy.size):
					free_to_shoot = false
		var best: int = 0
		for enemy: BattleStack in enemies:
			var damage: int = 0
			if free_to_shoot:
				damage = BattleAi.average_damage(state, probe, spot, enemy, DamageCalc.Kind.SHOT)
			elif (BattleGrid.distance(spot, who.size, enemy.cell, enemy.size) - 1) * BattleGrid.STEP_ORTHOGONAL <= budget:
				damage = BattleAi.average_damage(state, probe, spot, enemy, DamageCalc.Kind.MELEE)
			if damage > 0:
				best = maxi(best, BattleAi.blow_value(enemy, damage))
		return best * BattleAi.POTENTIAL / BattleAi.NORMAL

	## Value of the way a walker makes towards the nearest enemy by moving to `spot`.
	func approach(spot: Vector2i) -> int:
		if way.is_empty() or budget <= 0:
			return 0
		var before: int = way[BattleGrid.index(who.cell)]
		var after: int = way[BattleGrid.index(spot)]
		if before >= BattlePathfinder.FAR or after >= BattlePathfinder.FAR:
			return 0
		return own_value * BattleAi.APPROACH / BattleAi.NORMAL * clampi(before - after, -budget, budget) / budget
