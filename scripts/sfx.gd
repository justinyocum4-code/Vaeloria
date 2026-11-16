extends Node
## Sfx autoload — short original sound effects (generated sine tones).
## One AudioStreamPlayer per sound so effects can overlap.

var _players := {}


func _ready() -> void:
	_load("select", "res://assets/sounds/select.wav")
	_load("hit", "res://assets/sounds/hit.wav")
	_load("heal", "res://assets/sounds/heal.wav")
	_load("victory", "res://assets/sounds/victory.wav")
	_load("defeat", "res://assets/sounds/defeat.wav")


func _load(sound_name: String, path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "Master"
	add_child(player)
	_players[sound_name] = player


func play(sound_name: String) -> void:
	var player: AudioStreamPlayer = _players.get(sound_name)
	if player != null:
		player.play()


func play_select() -> void:
	play("select")


func play_hit() -> void:
	play("hit")


func play_heal() -> void:
	play("heal")


func play_victory() -> void:
	play("victory")


func play_defeat() -> void:
	play("defeat")
