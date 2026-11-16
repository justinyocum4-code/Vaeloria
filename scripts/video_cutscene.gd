class_name VideoCutscene
extends Control
## Full-screen movie scene: plays one short cinematic video clip
## (res://assets/cutscenes/*.ogv) like a film, WITH the characters
## talking — each line is spoken aloud (device TTS, via Narration)
## while it shows as a subtitle at the bottom, like movie captions.
## The clip loops until the lines are done, so a 3-line talk plays
## over the 10-second clip about twice. When the last line finishes,
## the scene ends (finished) and the talk is complete — the lines are
## not repeated afterwards. Tap anywhere, press Enter, or press Back
## to skip: skipping stops the speech and emits skipped, and the
## village falls back to the letterbox dialogue scene so the talk is
## never lost. If the clip file is missing, the scene is skipped the
## same way (skipped) so a bad video never blocks a talk, and the
## lines still get heard in the dialogue scene. With no lines at all
## (plain play), the scene simply ends when the clip ends.

signal finished
signal skipped

const MIN_LINE_TIME := 2.0
const MAX_LINE_TIME := 15.0
const SECONDS_PER_WORD := 0.45
const AFTER_BEAT := 0.9

var _player: VideoStreamPlayer
var _hint: Label
var _subtitle_panel: PanelContainer
var _speaker_label: Label
var _line_label: Label
var _timer: Timer
var _lines: Array = []
var _index := 0
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

	# Subtitle panel above the bottom edge, like the dialogue scene's
	# panel: speaker name in gold, line in large white text.
	_subtitle_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.12, 0.95)
	style.border_color = Color(0.91, 0.72, 0.29)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_subtitle_panel.add_theme_stylebox_override("panel", style)
	_subtitle_panel.set_anchors_preset(PRESET_BOTTOM_WIDE)
	_subtitle_panel.offset_top = -240
	_subtitle_panel.offset_bottom = -60
	_subtitle_panel.offset_left = 12
	_subtitle_panel.offset_right = -12
	_subtitle_panel.mouse_filter = MOUSE_FILTER_IGNORE
	_subtitle_panel.visible = false
	add_child(_subtitle_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.mouse_filter = MOUSE_FILTER_IGNORE
	_subtitle_panel.add_child(vbox)

	_speaker_label = Label.new()
	_speaker_label.add_theme_font_size_override("font_size", 30)
	_speaker_label.add_theme_color_override("font_color", Color(0.91, 0.72, 0.29))
	_speaker_label.mouse_filter = MOUSE_FILTER_IGNORE
	vbox.add_child(_speaker_label)

	_line_label = Label.new()
	_line_label.add_theme_font_size_override("font_size", 32)
	_line_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line_label.custom_minimum_size = Vector2(0, 96)
	_line_label.mouse_filter = MOUSE_FILTER_IGNORE
	vbox.add_child(_line_label)

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

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_line_timeout)
	add_child(_timer)


func is_active() -> bool:
	return _active


## How long a line stays up: speaking time (~140 wpm) plus a beat
## after it, clamped so very short lines still read and very long
## lines do not stall the scene. Same model as the dialogue scene.
static func line_duration(text: String) -> float:
	var words := text.split(" ", false).size()
	return clampf(float(words) * SECONDS_PER_WORD + AFTER_BEAT, MIN_LINE_TIME, MAX_LINE_TIME)


## lines: Array of Dictionaries {"speaker": String, "text": String}.
## Empty lines means a plain silent clip that ends on its own.
func play(video_path: String, lines: Array = []) -> void:
	if _active:
		return
	if not ResourceLoader.exists(video_path):
		skipped.emit()
		return
	var stream: VideoStream = load(video_path)
	_player.stream = stream
	_lines = lines
	_index = 0
	_active = true
	visible = true
	_player.play()
	if not _lines.is_empty():
		_show_current()


func skip() -> void:
	if not _active:
		return
	Narration.stop()
	_stop()
	skipped.emit()


func _show_current() -> void:
	var entry: Dictionary = _lines[_index]
	_speaker_label.text = str(entry.get("speaker", ""))
	var text: String = str(entry.get("text", ""))
	_line_label.text = text
	_subtitle_panel.visible = true
	Narration.speak(text)
	_timer.start(line_duration(text))


func _on_line_timeout() -> void:
	if not _active:
		return
	_index += 1
	if _index >= _lines.size():
		_stop()
		finished.emit()
	else:
		_show_current()


func _on_video_finished() -> void:
	if not _active:
		return
	if _index < _lines.size():
		# Lines still to speak: loop the clip under them.
		_player.play()
	else:
		# No lines left (plain clip): the movie is over.
		_stop()
		finished.emit()


func _stop() -> void:
	_active = false
	_timer.stop()
	_player.stop()
	_subtitle_panel.visible = false
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
