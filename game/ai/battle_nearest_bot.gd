class_name BattleNearestBot
extends RefCounted

## The simplest opponent, a yardstick for tests and measurements: shoot the
## nearest enemy if it can, else strike the nearest enemy it can reach, else
## walk towards the nearest enemy along the real way round the obstacles.
## Only reads the state and returns a command, like any player.

static func choose(state: BattleState) -> BattleCmd:
	if state.active_hero >= 0 and not state.is_over():
		return HeroPassCmd.new(state.active_hero)
	var who: BattleStack = state.active_stack()
	if who == null:
		return null
	var enemies: Array[BattleStack] = _nearest_first(state, who)
	if enemies.is_empty():
		return DefendCmd.new(who.id)
	if state.can_shoot(who):
		return ShootCmd.new(who.id, enemies[0].id)
	var reach: Dictionary[int, int] = BattlePathfinder.reachable(state, who)
	for enemy: BattleStack in enemies:
		var spots: Array[Vector2i] = state.attack_spots(who, enemy, reach)
		if not spots.is_empty():
			return AttackCmd.new(who.id, enemy.id, spots[0])
	var field: PackedInt32Array = BattlePathfinder.way_to(state, who, [enemies[0]])
	var best: int = BattleGrid.index(who.cell)
	for cell_index: int in reach:
		if field[cell_index] < field[best] or (field[cell_index] == field[best] and reach[cell_index] < reach[best]):
			best = cell_index
	if best == BattleGrid.index(who.cell):
		return DefendCmd.new(who.id)
	return MoveCmd.new(who.id, BattleGrid.cell_at(best))


## Living enemies by gap, then by id.
static func _nearest_first(state: BattleState, who: BattleStack) -> Array[BattleStack]:
	var enemies: Array[BattleStack] = state.enemies_of(who)
	var gaps: Dictionary[int, int] = {}
	for enemy: BattleStack in enemies:
		gaps[enemy.id] = BattleGrid.distance(who.cell, who.size, enemy.cell, enemy.size)
	enemies.sort_custom(func(a: BattleStack, b: BattleStack) -> bool:
		return gaps[a.id] < gaps[b.id] or (gaps[a.id] == gaps[b.id] and a.id < b.id))
	return enemies
