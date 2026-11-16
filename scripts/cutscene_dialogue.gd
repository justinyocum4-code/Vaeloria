class_name CutsceneDialogue
extends Control
## Cinematic dialogue for NPC conversations in the 3D village: the
## camera cuts in close on the two speakers (the village drives that
## part) and each line plays like a movie scene — spoken aloud
## automatically, then auto-advancing on a timer. The timer length is
## estimated from the word count; it never depends on TTS callbacks,
## which are unreliable headless and vary by device. Tap anywhere or
## press Enter to move to the next line now; Back or the Skip button
## exits the scene early (and the talk does not count — Lyra does not
## join, the wolf does not attack — so the player can simply talk
## again). Letterbox bars top and bottom sell the movie feel. The
## speaker's name and the line are also shown as large text.

signal finished
signal skipped

const MIN_LINE_TIME := 2.0
const MAX_LINE_TIME := 15.0
const SECONDS_PER_WORD := 0.45
const AFTER_BEAT := 0.9

var _speaker_label: Label
var _line_label: Label
var _skip_button: Button
var _timer: Timer
var _lines: Array = []
var _index := 0
var _active := false


func _ready() -> void:
	visible = false
	set_anchors_preset(PRESET_FULL_RECT)
	# Taps are read in _input (not the GUI), so the root ignores the
	# mouse; the Skip button still gets its own presses.
	mouse_filter = MOUSE_FILTER_IGNORE

	# Letterbox bars.
	var top_bar := ColorRect.new()
	top_bar.color = Color(0, 0, 0, 0.92)
	top_bar.set_anchors_preset(PRESET_TOP_WIDE)
	top_bar.offset_bottom = 48
	add_child(top_bar)
	var bottom_bar := ColorRect.new()
	bottom_bar.color = Color(0, 0, 0, 0.92)
	bottom_bar.set_anchors_preset(PRESET_BOTTOM_WIDE)
	bottom_bar.offset_top = -48
	add_child(bottom_bar)

	# Dialogue panel above the bottom bar.
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.12, 0.95)
	style.border_color = Color(0.91, 0.72, 0.29)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(PRESET_BOTTOM_WIDE)
	panel.offset_top = -240
	panel.offset_bottom = -60
	panel.offset_left = 12
	panel.offset_right = -12
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	_speaker_label = Label.new()
	_speaker_label.add_theme_font_size_override("font_size", 30)
	_speaker_label.add_theme_color_override("font_color", Color(0.91, 0.72, 0.29))
	vbox.add_child(_speaker_label)

	_line_label = Label.new()
	_line_label.add_theme_font_size_override("font_size", 32)
	_line_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line_label.custom_minimum_size = Vector2(0, 96)
	vbox.add_child(_line_label)

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(bottom)

	var hint := Label.new()
	hint.text = "Tap / Enter: next line"
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(hint)

	_skip_button = Button.new()
	_skip_button.text = "Skip  >>"
	_skip_button.custom_minimum_size = Vector2(180, 56)
	_skip_button.add_theme_font_size_override("font_size", 26)
	_skip_button.pressed.connect(finish_skip)
	bottom.add_child(_skip_button)

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(advance)
	add_child(_timer)


func is_active() -> bool:
	return _active


## How long a line stays up: speaking time (~140 wpm) plus a beat
## after it, clamped so very short lines still read and very long
## lines do not stall the scene.
static func line_duration(text: String) -> float:
	var words := text.split(" ", false).size()
	return clampf(float(words) * SECONDS_PER_WORD + AFTER_BEAT, MIN_LINE_TIME, MAX_LINE_TIME)


## lines: Array of Dictionaries {"speaker": String, "text": String}.
func play(lines: Array) -> void:
	if lines.is_empty() or _active:
		return
	_lines = lines
	_index = 0
	_active = true
	visible = true
	_show_current()


func _show_current() -> void:
	var entry: Dictionary = _lines[_index]
	_speaker_label.text = str(entry.get("speaker", ""))
	var text: String = str(entry.get("text", ""))
	_line_label.text = text
	Narration.speak(text)
	_timer.start(line_duration(text))


func advance() -> void:
	if not _active:
		return
	Sfx.play_select()
	_timer.stop()
	_index += 1
	if _index >= _lines.size():
		_finish_complete()
	else:
		_show_current()


func _finish_complete() -> void:
	_timer.stop()
	_active = false
	visible = false
	Narration.stop()
	finished.emit()


## Exit early: the conversation does not count. The village treats
## this as "never happened" — no recruitment, no battle.
func finish_skip() -> void:
	if not _active:
		return
	_timer.stop()
	_active = false
	visible = false
	Narration.stop()
	skipped.emit()


func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		var pos := (event as InputEventScreenTouch).position
		# A tap on the Skip button is the button's own press, not a
		# "next line" tap.
		if _skip_button.get_global_rect().has_point(pos):
			return
		advance()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("ui_accept"):
		advance()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		finish_skip()
		get_viewport().set_input_as_handled()
