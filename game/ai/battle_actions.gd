class_name BattleActions
extends RefCounted

## Every action the active stack may take now, as commands, always in the same
## order: shots, melee attacks (each enemy × each cell to strike from), moves,
## wait, defend. Surrender is not offered. Reads the state, changes nothing.


static func all(state: BattleState) -> Array[BattleCmd]:
	var actions: Array[BattleCmd] = []
	var who: BattleStack = state.active_stack()
	if who == null or state.is_over():
		return actions
	var enemies: Array[BattleStack] = state.enemies_of(who)
	if state.can_shoot(who):
		for enemy: BattleStack in enemies:
			actions.append(ShootCmd.new(who.id, enemy.id))
	var reach: Dictionary[int, int] = BattlePathfinder.reachable(state, who)
	for enemy: BattleStack in enemies:
		for spot: Vector2i in state.attack_spots(who, enemy, reach):
			actions.append(AttackCmd.new(who.id, enemy.id, spot))
	var here: int = BattleGrid.index(who.cell)
	for cell_index: int in reach:
		if cell_index != here:
			actions.append(MoveCmd.new(who.id, BattleGrid.cell_at(cell_index)))
	if not who.waited:
		actions.append(WaitCmd.new(who.id))
	actions.append(DefendCmd.new(who.id))
	return actions
