extends SceneTree

## Pictures of a battle played by script, for checking the battle screen:
##   godot --path . -s scripts/screenshot_demo.gd -- [out_dir] [seed]
## Default out_dir: `res://reports/battle_demo` (git-ignored). Needs a window.
## Shots: 01 start, 02 move preview, 03 attack preview with the forecast,
## 04 the strike, 05 the result after both sides play on "Auto".
## The pictures may show private placeholder art: never publish them.

const DEFAULT_OUT: String = "res://reports/battle_demo"
const SETTLE: float = 0.8
const MAX_TURNS: int = 60

var _out: String = DEFAULT_OUT
var _screen: BattleScreen = null


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	# Godot must never import (and so never export) these pictures: they may show placeholder art.
	if _out.begins_with("res://reports"):
		var ignore: FileAccess = FileAccess.open("res://reports/.gdignore", FileAccess.WRITE)
		if ignore != null:
			ignore.close()
	BattleLaunch.demo()
	if args.size() > 1:
		BattleLaunch.seed_value = args[1].to_int()
	BattleLaunch.human = [true, true]
	_screen = (load(BattleLaunch.BATTLE_SCENE) as PackedScene).instantiate()
	root.add_child(_screen)
	_run()


func _run() -> void:
	# The scene gets its _ready once the main loop runs.
	await process_frame
	await _until_idle()
	await _pause(SETTLE)
	_shot("01_start")
	var who: BattleStack = _screen.state.active_stack()
	var far: Vector2i = _farthest_reachable(who)
	_screen.preview(far)
	await _pause(0.2)
	_shot("02_move_preview")
	# Bot moves until somebody can strike; then show the forecast and the blow.
	for turn: int in MAX_TURNS:
		var cmd: BattleCmd = BattleNearestBot.choose(_screen.state)
		if cmd is AttackCmd or cmd is ShootCmd:
			var target: BattleStack = _screen.state.stack(cmd.get(&"target_id"))
			var offset: Vector2 = Vector2.ZERO
			if cmd is AttackCmd:
				var spot: Vector3 = BattleArena.cell_center((cmd as AttackCmd).from, who.size)
				var centre: Vector3 = BattleArena.cell_center(target.cell, target.size)
				offset = Vector2(spot.x - centre.x, spot.z - centre.z).normalized() * 0.35
			_screen.preview(target.cell, offset)
			await _pause(0.2)
			_shot("03_attack_preview")
			_screen.submit(_screen.planned_command() if _screen.planned_command() != null else cmd)
			await _pause(0.55)
			_shot("04_strike")
			break
		_screen.submit(cmd)
		await _until_idle()
		who = _screen.state.active_stack()
	await _until_idle()
	_screen.view.speed = 4.0
	_screen.set_auto(0, true)
	_screen.set_auto(1, true)
	while not _screen.state.is_over():
		await _pause(0.5)
	await _pause(2.0)
	_shot("05_result")
	quit()


func _until_idle() -> void:
	while _screen.is_busy() or not (_screen.state.is_over() or _screen.is_player_turn()):
		await process_frame


func _pause(seconds: float) -> void:
	await create_timer(seconds).timeout


func _farthest_reachable(who: BattleStack) -> Vector2i:
	var best: Vector2i = who.cell
	var best_cost: int = -1
	var reach: Dictionary[int, int] = BattlePathfinder.reachable(_screen.state, who)
	for cell_index: int in reach:
		var cost: int = reach[cell_index]
		if cost > best_cost:
			best = BattleGrid.cell_at(cell_index)
			best_cost = cost
	return best


func _shot(shot_name: String) -> void:
	var path: String = _out.path_join(shot_name + ".png")
	var error: Error = root.get_texture().get_image().save_png(path)
	print("%s %s" % ["saved" if error == OK else "FAILED", ProjectSettings.globalize_path(path)])
