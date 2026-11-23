class_name BattleSounds
extends Node

## Sounds of the battle by event: strike, shot, hit, death, steps; plus the
## click of the buttons. Ids are `<unit id>/<kind>` and `ui/click`; files come
## through `PlaceholderAssets` (silence without them) until our own sounds
## replace them (Ф13).

const VOICES: int = 6

var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _state: BattleState = null


func setup(state: BattleState) -> void:
	_state = state
	for i: int in VOICES:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


func on_event(event: BattleEvent) -> void:
	match event.kind:
		BattleEvent.Kind.MOVED:
			_unit_sound(event.stack_id, &"move")
		BattleEvent.Kind.ATTACKED, BattleEvent.Kind.RETALIATED:
			_unit_sound(event.stack_id, &"attack")
		BattleEvent.Kind.SHOT:
			_unit_sound(event.stack_id, &"shoot")
		BattleEvent.Kind.DAMAGED:
			_unit_sound(event.target_id, &"hit")
		BattleEvent.Kind.DIED:
			_unit_sound(event.stack_id, &"death")


func click() -> void:
	play(&"ui/click")


func play(id: StringName) -> void:
	var stream: AudioStream = PlaceholderAssets.sound(id)
	if stream == null or _players.is_empty():
		return
	var player: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.play()


func _unit_sound(stack_id: int, kind: StringName) -> void:
	var stack: BattleStack = _state.stack(stack_id) if _state != null else null
	if stack != null:
		play(StringName("%s/%s" % [stack.unit_id, kind]))
