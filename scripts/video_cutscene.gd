class_name VideoCutscene
extends Control
## Full-screen movie scene: plays one short cinematic video clip
## (res://assets/cutscenes/*.ogv) as an establishing shot before a
## talk — silent, like a film's opening shot. It runs for at most
## max_seconds (or the whole clip if that is shorter), then ends
## with finished and the village cuts to the close-up dialogue,
## where the characters talk with real voices and moving mouths.
## Tap anywhere, press Enter, or press Back to skip the shot: that
## also ends with skipped and the village goes straight to the
## dialogue, so skipping the intro never loses the talk. If the clip
## file is missing, the scene is skipped the same way, so a bad
## video never blocks a talk.

signal finished
signal skipped

var _player: VideoStreamPlayer
var _hint: Label
var _cap_timer: Timer
var _active := false


func _ready() -> void:
	visible = false
	set_anchors_preset(PRESET_FULL_RECT)
	# Taps are read in _input (not the GUI), so the root ignores the
	# mouse; the video itself has no buttons.
	mouse_filter = MOUSE_FILTER_IGNORE
	_player = VideoStreamPlayer.new()
	_player.set_anchors_preset(PRESET_FULL_RECT)
	_player.finished.connect(_on_video_finished)
	add_child(_player)

	_hint = Label.new()
	_hint.text = "Tap to skip"
	_hint.set_anchors_preset(PRESET_BOTTOM_WIDE)
	_hint.offset_top = -64
	_hint.offset_bottom = -16
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 24)
	_hint.add_theme_color_override("font_color", Color(0.91, 0.72, 0.29))
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_hint.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_hint)

	_cap_timer = Timer.new()
	_cap_timer.one_shot = true
	_cap_timer.timeout.connect(_on_cap_timeout)
	add_child(_cap_timer)


func is_active() -> bool:
	return _active


## Play the clip as an establishing shot. max_seconds caps how long
## it stays up (0 = the whole clip). The scene ends with finished
## either way; skip() ends it with skipped instead.
func play(video_path: String, max_seconds: float = 0.0) -> void:
	if _active:
		return
	if not ResourceLoader.exists(video_path):
		skipped.emit()
		return
	var stream: VideoStream = load(video_path)
	_player.stream = stream
	_active = true
	visible = true
	_player.play()
	if max_seconds > 0.0:
		_cap_timer.start(max_seconds)


func skip() -> void:
	if not _active:
		return
	_stop()
	skipped.emit()


func _on_cap_timeout() -> void:
	if not _active:
		return
	_stop()
	finished.emit()


func _on_video_finished() -> void:
	if not _active:
		return
	# The clip ran out before the cap: the shot is over.
	_stop()
	finished.emit()


func _stop() -> void:
	_active = false
	_cap_timer.stop()
	_player.stop()
	visible = false


func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		skip()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		skip()
		get_viewport().set_input_as_handled()
