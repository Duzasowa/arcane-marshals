class_name AbilityHooks
extends RefCounted

## Calls the ability hooks of stacks (docs/MECHANICS.md §5). Every hook of the
## battle core goes through here, so the core never knows a single ability:
## a new ability is a new `AbilityDef` and a new `AbilityHook` script.
## Hooks run in the order of the stack's `abilities`, then of its `effects`.
##
## Handlers are loaded once per script path and shared: they hold no state.

## Script path -> handler (null for a path that is not an `AbilityHook`).
static var _handlers: Dictionary[String, AbilityHook] = {}


## The handler of a script path; null when the path is empty or not a hook.
static func handler(path: String) -> AbilityHook:
	if path.is_empty():
		return null
	if not _handlers.has(path):
		var made: AbilityHook = null
		var script: Script = load(path) as Script
		if script != null and script.can_instantiate():
			var instance: Variant = script.new()
			if instance is AbilityHook:
				made = instance
			else:
				push_error("AbilityHooks: '%s' is not an AbilityHook" % path)
		else:
			push_error("AbilityHooks: cannot load '%s'" % path)
		_handlers[path] = made
	return _handlers[path]


## The ability entry a stack keeps in the state.
static func entry(ability_id: StringName, handler_path: String, params: Dictionary) -> Dictionary:
	return {&"id": ability_id, &"handler": handler_path, &"params": params.duplicate(true)}


## The entry of an `AbilityDef` (no handler — a passive mark).
static func entry_of(ability: AbilityDef) -> Dictionary:
	var path: String = ability.handler.resource_path if ability.handler != null else ""
	return entry(ability.id, path, ability.params)


## The abilities, then the effects of `owner`. No copy while it has no effects.
static func _entries(owner: BattleStack) -> Array[Dictionary]:
	return owner.abilities if owner.effects.is_empty() else owner.abilities + owner.effects


static func on_battle_start(state: BattleState, owner: BattleStack) -> void:
	for ability: Dictionary in _entries(owner):
		var hook: AbilityHook = handler(ability[&"handler"])
		if hook != null:
			hook.on_battle_start(state, owner, ability[&"params"])


static func on_turn_start(state: BattleState, owner: BattleStack) -> void:
	for ability: Dictionary in _entries(owner):
		var hook: AbilityHook = handler(ability[&"handler"])
		if hook != null and owner.is_alive():
			hook.on_turn_start(state, owner, ability[&"params"])


## Lets the attacker's abilities, then the target's, change one strike.
static func modify_strike(state: BattleState, attacker: BattleStack, target: BattleStack, kind: DamageCalc.Kind,
		strike: DamageCalc.Strike) -> void:
	for ability: Dictionary in _entries(attacker):
		var hook: AbilityHook = handler(ability[&"handler"])
		if hook != null:
			hook.modify_attack(state, attacker, target, kind, strike, ability[&"params"])
	for ability: Dictionary in _entries(target):
		var hook: AbilityHook = handler(ability[&"handler"])
		if hook != null:
			hook.modify_damage_taken(state, target, attacker, kind, strike, ability[&"params"])
	for other: BattleStack in state.stacks:
		if _holds_aura_over(other, target):
			for ability: Dictionary in _entries(other):
				var hook: AbilityHook = handler(ability[&"handler"])
				if hook != null:
					hook.modify_ally_damage_taken(state, other, target, attacker, kind, strike, ability[&"params"])


## The stacks the active ability `ability_id` of `owner` may be used on now.
static func use_targets(state: BattleState, owner: BattleStack, ability_id: StringName) -> Array[BattleStack]:
	for ability: Dictionary in owner.abilities:
		if ability[&"id"] == ability_id:
			var hook: AbilityHook = handler(ability[&"handler"])
			if hook != null:
				return hook.use_targets(state, owner, ability[&"params"])
	return []


## `owner` uses its active ability `ability_id` on `target`.
static func use(state: BattleState, owner: BattleStack, ability_id: StringName, target: BattleStack) -> void:
	for ability: Dictionary in owner.abilities:
		if ability[&"id"] == ability_id:
			var hook: AbilityHook = handler(ability[&"handler"])
			if hook != null:
				hook.on_use(state, owner, target, ability[&"params"])
			return


## Lets the allies next to `target` react to the `damage` of a strike.
static func on_ally_damaged(state: BattleState, target: BattleStack, attacker: BattleStack, damage: int,
		kind: DamageCalc.Kind) -> void:
	for other: BattleStack in state.stacks:
		if _holds_aura_over(other, target):
			for ability: Dictionary in _entries(other):
				var hook: AbilityHook = handler(ability[&"handler"])
				if hook != null and other.is_alive():
					hook.on_ally_damaged(state, other, target, attacker, damage, kind, ability[&"params"])


## The morale of `stack` after its own abilities, then the auras of its neighbours.
static func modify_morale(state: BattleState, stack: BattleStack, morale: int) -> int:
	for ability: Dictionary in _entries(stack):
		var hook: AbilityHook = handler(ability[&"handler"])
		if hook != null:
			morale = hook.modify_morale(state, stack, stack, morale, ability[&"params"])
	for other: BattleStack in state.stacks:
		if _holds_aura_over(other, stack):
			for ability: Dictionary in _entries(other):
				var hook: AbilityHook = handler(ability[&"handler"])
				if hook != null:
					morale = hook.modify_morale(state, other, stack, morale, ability[&"params"])
	return morale


## Whether `other` is a living ally of `stack` next to it with any hooks (by id:
## `stack` may be a forecast copy).
static func _holds_aura_over(other: BattleStack, stack: BattleStack) -> bool:
	return other.side == stack.side and other.id != stack.id and other.is_alive() 			and not (other.abilities.is_empty() and other.effects.is_empty()) 			and BattleGrid.adjacent(other.cell, other.size, stack.cell, stack.size)


## False when an ability of either side forbids `defender` to retaliate.
static func can_retaliate(state: BattleState, attacker: BattleStack, defender: BattleStack) -> bool:
	for owner: BattleStack in [attacker, defender]:
		for ability: Dictionary in _entries(owner):
			var hook: AbilityHook = handler(ability[&"handler"])
			if hook != null and not hook.can_retaliate(state, owner, attacker, defender, ability[&"params"]):
				return false
	return true


## Living enemies a melee blow of `attacker` on `target` also hits, each once,
## `target` itself excluded, in the order the abilities name them.
static func extra_targets(state: BattleState, attacker: BattleStack, target: BattleStack) -> Array[BattleStack]:
	var found: Array[BattleStack] = []
	for ability: Dictionary in _entries(attacker):
		var hook: AbilityHook = handler(ability[&"handler"])
		if hook == null:
			continue
		for other: BattleStack in hook.extra_targets(state, attacker, target, ability[&"params"]):
			if other != null and other.is_alive() and other.side != attacker.side and other.id != target.id \
					and not found.has(other):
				found.append(other)
	return found


static func on_after_attack(state: BattleState, owner: BattleStack, target: BattleStack, kind: DamageCalc.Kind) -> void:
	for ability: Dictionary in _entries(owner):
		var hook: AbilityHook = handler(ability[&"handler"])
		if hook != null and owner.is_alive():
			hook.on_after_attack(state, owner, target, kind, ability[&"params"])


static func on_after_move(state: BattleState, owner: BattleStack, from: Vector2i) -> void:
	for ability: Dictionary in _entries(owner):
		var hook: AbilityHook = handler(ability[&"handler"])
		if hook != null and owner.is_alive():
			hook.on_after_move(state, owner, from, ability[&"params"])


static func on_death(state: BattleState, owner: BattleStack, killer: BattleStack) -> void:
	for ability: Dictionary in _entries(owner):
		var hook: AbilityHook = handler(ability[&"handler"])
		if hook != null:
			hook.on_death(state, owner, killer, ability[&"params"])
