extends Node
## Music autoload — background music for Vaeloria. The village theme
## (Kevin MacLeod, "Meditation Impromptu 01", CC-BY 4.0) plays in the
## village and on the title screen; the battle theme ("Five Armies",
## CC-BY 4.0) plays in battle. Tracks are looped by hand, not by the
## stream's loop flag: the volume fades out over the last 2 seconds
## of the track and back in after the restart, so the loop point
## never pops. Calling play_village() while the village theme is
## already playing is a no-op, so scene changes never restart it.

const VILLAGE_STREAM := "res://assets/music/music_village.ogg"
const BATTLE_STREAM := "res://assets/music/music_battle.ogg"
const VILLAGE_DB := -14.0
const BATTLE_DB := -10.0
const FADE_SECONDS := 2.0
const SILENCE_DB := -40.0

var _player: AudioStreamPlayer
var _target_db := VILLAGE_DB
var _current := ""


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.volume_db = SILENCE_DB
	_player.finished.connect(_on_finished)
	add_child(_player)


func _process(_delta: float) -> void:
	if _player == null or not _player.playing:
		return
	var stream: AudioStream = _player.stream
	if stream == null:
		return
	var length := stream.get_length()
	if length <= 0.0:
		return
	# Fade out at the end of the track, fade back in at the start
	# of the next loop — the restart is inaudible.
	var pos := _player.get_playback_position()
	var target := _target_db
	if pos > length - FADE_SECONDS:
		target = lerpf(SILENCE_DB, _target_db, clampf((length - pos) / FADE_SECONDS, 0.0, 1.0))
	elif pos < FADE_SECONDS:
		target = lerpf(SILENCE_DB, _target_db, clampf(pos / FADE_SECONDS, 0.0, 1.0))
	_player.volume_db = lerpf(_player.volume_db, target, 0.12)


func play_village() -> void:
	_play("village", VILLAGE_STREAM, VILLAGE_DB)


func play_battle() -> void:
	_play("battle", BATTLE_STREAM, BATTLE_DB)


func stop_music() -> void:
	_current = ""
	_player.stop()


func _play(key: String, path: String, db: float) -> void:
	_target_db = db
	if _current == key and _player.playing:
		return
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	_player.stream = stream
	_player.volume_db = SILENCE_DB
	_player.play()
	_current = key


func _on_finished() -> void:
	# The track ended: loop it by hand. (The stream's own loop flag
	# stays off so the fade-out above always runs.)
	if _current != "" and _player.stream != null:
		_player.volume_db = SILENCE_DB
		_player.play()
