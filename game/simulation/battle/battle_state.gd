class_name BattleState
extends RefCounted

## The whole state of one battle: the field, the stacks, both sides and their
## heroes, the random generator and whose turn it is. Changes only through
## `apply(cmd)`, which checks the command with `validate(cmd)` first.
## Stack ids are their indices in `stacks`; dead stacks stay in the list.
## On the initiative line a hero is the actor `HERO_ACTOR + side`.

const HASH_SKIPPED_FIELDS: Array[StringName] = [&"events"]
const SIDE_COUNT: int = 2
## Chance of a morale roll per point of morale, permille.
const MORALE_STEP: int = 100
## Initiative line id of the hero of side 0 (side 1 — the next one). Above any
## stack id, so on equal ATB and initiative the stacks go first.
const HERO_ACTOR: int = 1000

var grid: BattleGrid = BattleGrid.new()
var stacks: Array[BattleStack] = []
var sides: Array[BattleSide] = [BattleSide.new(), BattleSide.new()]
## Per side: its hero, or null.
var heroes: Array[BattleHero] = [null, null]
var rng: SimRng = SimRng.new()
## The stack whose turn it is, -1 before the start and after the end.
var active_id: int = -1
## The side whose hero has the turn (then `active_id` is -1); -1 — a stack's turn or nobody's.
var active_hero: int = -1
## Turns taken by stacks so far (a turn lost to bad morale counts).
var turn_count: int = 0
var result: BattleResult = null
## Events since the last `take_events()`; presentation only, not hashed.
var events: Array[BattleEvent] = []


func _init(seed_value: int = 0) -> void:
	rng = SimRng.new(seed_value)


## Puts a new stack on the field; returns its id.
func add_stack(new_stack: BattleStack, anchor: Vector2i) -> int:
	new_stack.id = stacks.size()
	new_stack.cell = anchor
	stacks.append(new_stack)
	grid.place(new_stack.id, anchor, new_stack.size)
	return new_stack.id


func stack(stack_id: int) -> BattleStack:
	return stacks[stack_id] if stack_id >= 0 and stack_id < stacks.size() else null


func active_stack() -> BattleStack:
	return stack(active_id)


func hero(side: int) -> BattleHero:
	return heroes[side] if side >= 0 and side < heroes.size() else null


## The side whose stack or hero has the turn; -1 — nobody's.
func active_side() -> int:
	if active_hero >= 0:
		return active_hero
	var who: BattleStack = active_stack()
	return who.side if who != null else -1


## The initiative line id of whoever has the turn (a stack id or a hero actor); -1 — nobody.
func active_actor() -> int:
	return HERO_ACTOR + active_hero if active_hero >= 0 else active_id


static func is_hero_actor(actor_id: int) -> bool:
	return actor_id >= HERO_ACTOR


## The side of a hero actor id.
static func hero_actor_side(actor_id: int) -> int:
	return actor_id - HERO_ACTOR


func is_over() -> bool:
	return result != null


## Living stacks in id order; `of_side` -1 — both sides.
func alive_stacks(of_side: int = -1) -> Array[BattleStack]:
	var alive: Array[BattleStack] = []
	for candidate: BattleStack in stacks:
		if candidate.is_alive() and (of_side < 0 or candidate.side == of_side):
			alive.append(candidate)
	return alive


func enemies_of(who: BattleStack) -> Array[BattleStack]:
	return alive_stacks(1 - who.side)


## The stack standing on `cell`, or null.
func stack_at(cell: Vector2i) -> BattleStack:
	if not BattleGrid.in_bounds(cell):
		return null
	return stack(grid.occupant_at(cell))


## Living stacks of `of_side` touching `who`, in id order.
func adjacent_stacks(who: BattleStack, of_side: int) -> Array[BattleStack]:
	var found: Array[BattleStack] = []
	for other: BattleStack in alive_stacks(of_side):
		if other.id != who.id and BattleGrid.adjacent(other.cell, other.size, who.cell, who.size):
			found.append(other)
	return found


func morale_of(who: BattleStack) -> int:
	if who.no_morale:
		return 0
	var morale: int = clampi(sides[who.side].morale, BattleSide.MORALE_MIN, BattleSide.MORALE_MAX)
	return clampi(AbilityHooks.modify_morale(self, who, morale), BattleSide.MORALE_MIN, BattleSide.MORALE_MAX)


func luck_of(who: BattleStack) -> int:
	return clampi(sides[who.side].luck, BattleSide.MORALE_MIN, BattleSide.MORALE_MAX)


## Whether `who` may shoot now: shots left and no enemy next to it.
func can_shoot(who: BattleStack) -> bool:
	return who.shots_left > 0 and adjacent_stacks(who, 1 - who.side).is_empty()


## Cells `who` can strike `target` from this turn (its own cell included),
## cheapest first, then by cell index. `reach` — a ready `reachable()` result.
func attack_spots(who: BattleStack, target: BattleStack, reach: Dictionary[int, int] = {}) -> Array[Vector2i]:
	if reach.is_empty():
		reach = BattlePathfinder.reachable(self, who)
	var spots: Array[Vector2i] = []
	var costs: Array[int] = []
	for cell_index: int in reach:
		var anchor: Vector2i = BattleGrid.cell_at(cell_index)
		if not BattleGrid.adjacent(anchor, who.size, target.cell, target.size):
			continue
		var at: int = 0
		while at < spots.size() and costs[at] <= reach[cell_index]:
			at += 1
		spots.insert(at, anchor)
		costs.insert(at, reach[cell_index])
	return spots


## Whether `defender` answers a melee blow of `attacker` now: alive, a
## retaliation left this round, and no ability of either side forbids it.
func will_retaliate(attacker: BattleStack, defender: BattleStack) -> bool:
	return defender.is_alive() and defender.retaliations_left > 0 \
			and AbilityHooks.can_retaliate(self, attacker, defender)


## Reports what an ability did, for the view and the log.
func emit_ability(owner: BattleStack, ability_id: StringName, target: BattleStack = null) -> void:
	var event: BattleEvent = BattleEvent.make(BattleEvent.Kind.ABILITY, owner.id, target.id if target != null else -1)
	event.ability = ability_id
	_emit(event)


## Deals `damage` to `target` outside a blow (abilities, later spells):
## deaths and events as for a blow. `source` may be null. The battle ends
## after the command, as always.
func deal_damage(source: BattleStack, target: BattleStack, damage: int) -> void:
	if not target.is_alive() or damage <= 0:
		return
	var hit: BattleEvent = BattleEvent.make(BattleEvent.Kind.DAMAGED, source.id if source != null else -1, target.id)
	hit.damage = damage
	hit.killed = target.take_damage(damage)
	_emit(hit)
	if not target.is_alive():
		_on_died(target, source)


## Heals `target` by `amount` HP outside a blow (abilities, later spells);
## `revive` raises the dead up to the starting count, otherwise only the top
## creature heals. Returns the HP healed.
func heal(source: BattleStack, target: BattleStack, amount: int, revive: bool) -> int:
	if not target.is_alive():
		return 0
	var before: int = target.count
	var healed: int = target.restore(amount, target.initial_count if revive else target.count)
	if healed > 0:
		var event: BattleEvent = BattleEvent.make(BattleEvent.Kind.HEALED, source.id if source != null else -1, target.id)
		event.damage = healed
		event.killed = target.count - before
		_emit(event)
	return healed


## Puts the timed effect `effect_id` (an `AbilityHook` script and its params)
## on `target` for `turns` of its turns. The same effect again takes the new
## params and the longer of the two durations. Effects tick down at the
## start of the target's turn, after their `on_turn_start`.
func add_effect(source: BattleStack, target: BattleStack, effect_id: StringName, handler_path: String,
		params: Dictionary, turns: int) -> void:
	if not target.is_alive() or turns <= 0:
		return
	var effect: Dictionary = {}
	for existing: Dictionary in target.effects:
		if existing[&"id"] == effect_id:
			effect = existing
	if effect.is_empty():
		effect = AbilityHooks.entry(effect_id, handler_path, params)
		effect[&"turns"] = turns
		target.effects.append(effect)
	else:
		effect[&"params"] = params.duplicate(true)
		effect[&"turns"] = maxi(int(effect[&"turns"]), turns)
	var event: BattleEvent = BattleEvent.make(BattleEvent.Kind.EFFECT_ADDED, source.id if source != null else -1, target.id)
	event.ability = effect_id
	_emit(event)


## Moves `who` to `to` outside a move command (abilities): along a path, with
## `MOVED` and `on_after_move`. False when the place is off the field or taken.
func move_stack(who: BattleStack, to: Vector2i) -> bool:
	if not who.is_alive() or to == who.cell or not grid.is_free(to, who.size, who.id):
		return false
	_move(who, to)
	return true


## The events since the last call, oldest first.
func take_events() -> Array[BattleEvent]:
	var taken: Array[BattleEvent] = events
	events = []
	return taken


func digest() -> String:
	return StateHasher.digest(self)


## A deep copy with its own random generator at the same position, for
## forecasts and AI. Events are not copied.
func clone() -> BattleState:
	var copy: BattleState = BattleState.new()
	copy.grid = grid.copy()
	copy.stacks = []
	for original: BattleStack in stacks:
		copy.stacks.append(original.copy())
	copy.sides = []
	for original_side: BattleSide in sides:
		copy.sides.append(original_side.copy())
	copy.heroes = []
	for original_hero: BattleHero in heroes:
		copy.heroes.append(original_hero.copy() if original_hero != null else null)
	copy.rng = rng.duplicate_rng()
	copy.active_id = active_id
	copy.active_hero = active_hero
	copy.turn_count = turn_count
	copy.result = result.copy() if result != null else null
	return copy


## Gives the first turn. Call once all stacks are placed and have their ATB.
func start() -> void:
	if is_over() or active_id >= 0:
		return
	for who: BattleStack in alive_stacks():
		AbilityHooks.on_battle_start(self, who)
	_check_end()
	if not is_over():
		_advance()


# --- Commands -----------------------------------------------------------------

## Why `cmd` may not be applied now; "" — it may.
func validate(cmd: BattleCmd) -> String:
	if cmd == null:
		return "no command"
	if is_over():
		return "the battle is over"
	if active_hero >= 0:
		return _validate_hero_turn(cmd)
	var who: BattleStack = active_stack()
	if who == null:
		return "nobody has the turn"
	if cmd is CastSpellCmd or cmd is HeroPassCmd:
		return "not a hero's turn"
	if cmd is SurrenderCmd:
		return "" if (cmd as SurrenderCmd).side == who.side else "only the side in turn may surrender"
	if cmd.stack_id != active_id:
		return "not the turn of stack %d" % cmd.stack_id
	if cmd is MoveCmd:
		return _validate_move(who, cmd as MoveCmd)
	if cmd is AttackCmd:
		return _validate_attack(who, cmd as AttackCmd)
	if cmd is ShootCmd:
		return _validate_shot(who, cmd as ShootCmd)
	if cmd is UseAbilityCmd:
		return _validate_use(who, cmd as UseAbilityCmd)
	if cmd is WaitCmd:
		return "already waited this round" if who.waited else ""
	if cmd is DefendCmd:
		return ""
	return "unknown command %s" % cmd.describe()


## Applies `cmd` if it is valid; an invalid command changes nothing.
func apply(cmd: BattleCmd) -> bool:
	if validate(cmd) != "":
		return false
	if active_hero >= 0:
		_apply_hero_turn(cmd)
		return true
	var who: BattleStack = active_stack()
	if cmd is SurrenderCmd:
		_surrender(who.side)
	elif cmd is MoveCmd:
		_move(who, (cmd as MoveCmd).to)
		_finish_turn(who, true)
	elif cmd is AttackCmd:
		var attack: AttackCmd = cmd as AttackCmd
		var target: BattleStack = stack(attack.target_id)
		_move(who, attack.from)
		var extras: Array[BattleStack] = AbilityHooks.extra_targets(self, who, target)
		# Abilities decide on the retaliation before the blow, as the forecast does.
		var answer: bool = will_retaliate(who, target)
		_strike(who, target, DamageCalc.Kind.MELEE)
		for extra: BattleStack in extras:
			if extra.is_alive() and who.is_alive():
				_strike(who, extra, DamageCalc.Kind.MELEE)
		if answer and who.is_alive() and target.is_alive():
			target.retaliations_left -= 1
			_strike(target, who, DamageCalc.Kind.RETALIATION)
		AbilityHooks.on_after_attack(self, who, target, DamageCalc.Kind.MELEE)
		_finish_turn(who, true)
	elif cmd is ShootCmd:
		var shot_at: BattleStack = stack((cmd as ShootCmd).target_id)
		who.shots_left -= 1
		_strike(who, shot_at, DamageCalc.Kind.SHOT)
		AbilityHooks.on_after_attack(self, who, shot_at, DamageCalc.Kind.SHOT)
		_finish_turn(who, true)
	elif cmd is UseAbilityCmd:
		var use: UseAbilityCmd = cmd as UseAbilityCmd
		var used_on: BattleStack = stack(use.target_id)
		emit_ability(who, use.ability_id, used_on)
		AbilityHooks.use(self, who, use.ability_id, used_on)
		_finish_turn(who, true)
	elif cmd is WaitCmd:
		_wait_turn(who)
	elif cmd is DefendCmd:
		who.defending = true
		_emit(BattleEvent.make(BattleEvent.Kind.DEFENDED, who.id))
		_finish_turn(who, false)
	return true


func _validate_hero_turn(cmd: BattleCmd) -> String:
	var side_of: int = -1
	if cmd is SurrenderCmd:
		side_of = (cmd as SurrenderCmd).side
	elif cmd is HeroPassCmd:
		side_of = (cmd as HeroPassCmd).side
	elif cmd is CastSpellCmd:
		side_of = (cmd as CastSpellCmd).side
	else:
		return "it is the turn of the hero of side %d" % active_hero
	if side_of != active_hero:
		return "not the turn of the hero of side %d" % side_of
	if cmd is CastSpellCmd:
		return _validate_cast(heroes[active_hero], cmd as CastSpellCmd)
	return ""


func _validate_cast(caster: BattleHero, cmd: CastSpellCmd) -> String:
	var reason: String = SpellCast.cannot_cast(caster, cmd.spell_id)
	if reason != "":
		return reason
	var target: BattleStack = stack(cmd.target_id)
	if target == null or not target.is_alive():
		return "no living target %d" % cmd.target_id
	if not SpellCast.targets(self, caster, cmd.spell_id).has(target):
		return "%s cannot be cast on %d now" % [cmd.spell_id, cmd.target_id]
	return ""


func _validate_move(who: BattleStack, cmd: MoveCmd) -> String:
	if cmd.to == who.cell:
		return "already there"
	if not BattleGrid.in_bounds(cmd.to) or not BattlePathfinder.reachable(self, who).has(BattleGrid.index(cmd.to)):
		return "cell %s is out of reach" % cmd.to
	return ""


func _validate_attack(who: BattleStack, cmd: AttackCmd) -> String:
	var target: BattleStack = stack(cmd.target_id)
	if target == null or not target.is_alive():
		return "no living target %d" % cmd.target_id
	if target.side == who.side:
		return "cannot attack an own stack"
	if cmd.from != who.cell and (not BattleGrid.in_bounds(cmd.from)
			or not BattlePathfinder.reachable(self, who).has(BattleGrid.index(cmd.from))):
		return "cell %s is out of reach" % cmd.from
	if not BattleGrid.adjacent(cmd.from, who.size, target.cell, target.size):
		return "the target is not next to %s" % cmd.from
	return ""


func _validate_shot(who: BattleStack, cmd: ShootCmd) -> String:
	var target: BattleStack = stack(cmd.target_id)
	if target == null or not target.is_alive():
		return "no living target %d" % cmd.target_id
	if target.side == who.side:
		return "cannot shoot an own stack"
	if who.shots_left <= 0:
		return "no shots left"
	if not can_shoot(who):
		return "an enemy is next to the shooter"
	return ""


func _validate_use(who: BattleStack, cmd: UseAbilityCmd) -> String:
	var target: BattleStack = stack(cmd.target_id)
	if target == null or not target.is_alive():
		return "no living target %d" % cmd.target_id
	if not who.has_ability(cmd.ability_id):
		return "no ability %s" % cmd.ability_id
	if not AbilityHooks.use_targets(self, who, cmd.ability_id).has(target):
		return "%s cannot be used on %d now" % [cmd.ability_id, cmd.target_id]
	return ""


# --- Rules --------------------------------------------------------------------

func _apply_hero_turn(cmd: BattleCmd) -> void:
	var caster: BattleHero = heroes[active_hero]
	if cmd is SurrenderCmd:
		_surrender(caster.side)
	elif cmd is CastSpellCmd:
		var cast: CastSpellCmd = cmd as CastSpellCmd
		var target: BattleStack = stack(cast.target_id)
		caster.mana -= int(caster.spell(cast.spell_id)[&"mana_cost"])
		var event: BattleEvent = BattleEvent.make(BattleEvent.Kind.SPELL_CAST, -1, target.id)
		event.side = caster.side
		event.ability = cast.spell_id
		_emit(event)
		SpellCast.cast(self, caster, cast.spell_id, target)
		_finish_hero_turn(caster)
	elif cmd is HeroPassCmd:
		var passed: BattleEvent = BattleEvent.make(BattleEvent.Kind.HERO_PASSED)
		passed.side = caster.side
		_emit(passed)
		_finish_hero_turn(caster)


func _surrender(side: int) -> void:
	var surrender: BattleEvent = BattleEvent.make(BattleEvent.Kind.SURRENDERED)
	surrender.side = side
	_emit(surrender)
	_end_battle(1 - side, BattleResult.EndedBy.SURRENDER)


func _move(who: BattleStack, to: Vector2i) -> void:
	if to == who.cell:
		return
	var event: BattleEvent = BattleEvent.make(BattleEvent.Kind.MOVED, who.id)
	event.cells = BattlePathfinder.path(self, who, to)
	var from: Vector2i = who.cell
	grid.remove(who.id, who.cell, who.size)
	who.cell = to
	grid.place(who.id, to, who.size)
	_emit(event)
	AbilityHooks.on_after_move(self, who, from)


## One strike: luck, damage, deaths, and the events of all of it.
func _strike(attacker: BattleStack, target: BattleStack, kind: DamageCalc.Kind) -> void:
	var event_kind: BattleEvent.Kind = BattleEvent.Kind.ATTACKED
	if kind == DamageCalc.Kind.RETALIATION:
		event_kind = BattleEvent.Kind.RETALIATED
	elif kind == DamageCalc.Kind.SHOT:
		event_kind = BattleEvent.Kind.SHOT
	_emit(BattleEvent.make(event_kind, attacker.id, target.id))
	var luck: int = DamageCalc.roll_luck(rng, luck_of(attacker))
	if luck == DamageCalc.LUCK_GOOD:
		_emit(BattleEvent.make(BattleEvent.Kind.LUCK_GOOD, attacker.id, target.id))
	elif luck == DamageCalc.LUCK_BAD:
		_emit(BattleEvent.make(BattleEvent.Kind.LUCK_BAD, attacker.id, target.id))
	var hit: BattleEvent = BattleEvent.make(BattleEvent.Kind.DAMAGED, attacker.id, target.id)
	hit.damage = DamageCalc.roll(self, attacker, attacker.cell, target, kind, luck)
	hit.killed = target.take_damage(hit.damage)
	_emit(hit)
	if not target.is_alive():
		_on_died(target, attacker)
	AbilityHooks.on_ally_damaged(self, target, attacker, hit.damage, kind)


## A stack has just been wiped out: off the field, then its death abilities.
func _on_died(target: BattleStack, killer: BattleStack) -> void:
	grid.remove(target.id, target.cell, target.size)
	_emit(BattleEvent.make(BattleEvent.Kind.DIED, target.id, killer.id if killer != null else -1))
	AbilityHooks.on_death(self, target, killer)


## Ends the turn of `who` the ordinary way and gives the next turn.
func _finish_turn(who: BattleStack, allow_morale: bool) -> void:
	who.waited = false
	who.atb = AtbTimeline.after_turn(who.atb)
	turn_count += 1
	_check_end()
	if is_over():
		return
	if allow_morale and who.is_alive():
		_roll_good_morale(who)
	_advance()


## Ends the turn of a hero and gives the next turn.
func _finish_hero_turn(caster: BattleHero) -> void:
	caster.atb = AtbTimeline.after_turn(caster.atb)
	turn_count += 1
	_check_end()
	if not is_over():
		_advance()


## "Wait": the stack moves later in the same round.
func _wait_turn(who: BattleStack) -> void:
	who.waited = true
	who.atb = AtbTimeline.WAIT
	_emit(BattleEvent.make(BattleEvent.Kind.WAITED, who.id))
	_advance()


## Runs the initiative line to the next stack or hero that gets a turn.
func _advance() -> void:
	active_id = -1
	active_hero = -1
	while true:
		var alive: Array[BattleStack] = alive_stacks()
		var atbs: Array[int] = []
		var inits: Array[int] = []
		var ids: Array[int] = []
		AtbTimeline.read_line(self, atbs, inits, ids)
		var picked: int = AtbTimeline.next(atbs, inits, ids)
		if picked < 0:
			return
		AtbTimeline.write_line(self, atbs)
		if is_hero_actor(ids[picked]):
			active_hero = hero_actor_side(ids[picked])
			var hero_turn: BattleEvent = BattleEvent.make(BattleEvent.Kind.HERO_TURN_STARTED)
			hero_turn.side = active_hero
			_emit(hero_turn)
			return
		var who: BattleStack = alive[picked]
		who.retaliations_left = 1
		who.defending = false
		if _roll_bad_morale(who):
			continue
		active_id = who.id
		_emit(BattleEvent.make(BattleEvent.Kind.TURN_STARTED, who.id))
		AbilityHooks.on_turn_start(self, who)
		if who.is_alive():
			_tick_effects(who)
			return
		# Its turn-start abilities killed it: the line moves on, unless the battle is over.
		active_id = -1
		_check_end()
		if is_over():
			return


## One turn of every effect of `who` has passed: the spent ones go.
func _tick_effects(who: BattleStack) -> void:
	var kept: Array[Dictionary] = []
	for effect: Dictionary in who.effects:
		effect[&"turns"] = int(effect[&"turns"]) - 1
		if int(effect[&"turns"]) > 0:
			kept.append(effect)
		else:
			var event: BattleEvent = BattleEvent.make(BattleEvent.Kind.EFFECT_ENDED, who.id)
			event.ability = effect[&"id"]
			_emit(event)
	who.effects = kept


## Bad morale: the stack loses this turn. True when it did.
func _roll_bad_morale(who: BattleStack) -> bool:
	var morale: int = morale_of(who)
	if morale >= 0 or not rng.chance_permille(-morale * MORALE_STEP):
		return false
	who.atb = AtbTimeline.BAD_MORALE
	who.waited = false
	turn_count += 1
	_emit(BattleEvent.make(BattleEvent.Kind.MORALE_BAD, who.id))
	return true


## Good morale: the stack moves again sooner.
func _roll_good_morale(who: BattleStack) -> void:
	var morale: int = morale_of(who)
	if morale <= 0 or not rng.chance_permille(morale * MORALE_STEP):
		return
	who.atb = maxi(who.atb, AtbTimeline.GOOD_MORALE)
	_emit(BattleEvent.make(BattleEvent.Kind.MORALE_GOOD, who.id))


func _check_end() -> void:
	if is_over():
		return
	for side: int in SIDE_COUNT:
		if alive_stacks(side).is_empty():
			_end_battle(1 - side, BattleResult.EndedBy.DESTROYED)
			return


func _end_battle(winner: int, ended_by: BattleResult.EndedBy) -> void:
	result = BattleResult.new()
	result.winner = winner
	result.ended_by = ended_by
	result.turns = turn_count
	for side: int in SIDE_COUNT:
		result.mana_left[side] = heroes[side].mana if heroes[side] != null else -1
	for side: int in SIDE_COUNT:
		# A packed array inside an array is a value: fill a local one, then store it.
		var row: PackedInt32Array = PackedInt32Array()
		row.resize(BattleSideSetup.MAX_SLOTS)
		row.fill(0)
		for who: BattleStack in stacks:
			if who.side == side and who.slot >= 0 and who.slot < BattleSideSetup.MAX_SLOTS:
				row[who.slot] += who.count
		result.survivors[side] = row
	for who: BattleStack in stacks:
		if who.lost() > 0:
			var losses: Dictionary = result.losses[who.side]
			losses[who.unit_id] = int(losses.get(who.unit_id, 0)) + who.lost()
			result.experience[1 - who.side] += who.lost() * who.exp
	active_id = -1
	active_hero = -1
	var event: BattleEvent = BattleEvent.make(BattleEvent.Kind.BATTLE_ENDED)
	event.side = winner
	_emit(event)


func _emit(event: BattleEvent) -> void:
	events.append(event)
