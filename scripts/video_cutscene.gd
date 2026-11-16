class_name VideoCutscene
extends Control
## Full-screen movie scene: plays one short cinematic video clip
## (res://assets/cutscenes/*.ogv) like a film, then hands back to
## the game. Tap anywhere, press Enter, or press Back to skip.
## Emits finished when the clip plays to the end, skipped when the
## player cuts it short. The village treats both the same way — the
## talk goes ahead either way; only the dialogue cutscene's own
## Skip cancels the conversation. If the clip file is missing, the
## scene is skipped silently so a bad video never blocks a talk.

signal finished
signal skipped

var _player: VideoStreamPlayer
var _hint: Label
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
	add_child(_hint)


func is_active() -> bool:
	return _active


func play(video_path: String) -> void:
	if _active:
		return
	if not ResourceLoader.exists(video_path):
		finished.emit()
		return
	var stream: VideoStream = load(video_path)
	_player.stream = stream
	_active = true
	visible = true
	_player.play()


func skip() -> void:
	if not _active:
		return
	_stop()
	skipped.emit()


func _on_video_finished() -> void:
	if not _active:
		return
	_stop()
	finished.emit()


func _stop() -> void:
	_active = false
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
