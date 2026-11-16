class_name DialogueBox
extends PanelContainer
## Reusable dialogue box: big readable text, D-pad / touch friendly.
## Each line is spoken aloud via Narration (Godot TTS) when available.
## Advance with the Continue button, Enter/Space, joypad A, or a tap.

signal dialogue_finished

var _speaker_label: Label
var _text_label: Label
var _continue_button: Button
var _lines: Array = []
var _index := 0
var _open := false


func _ready() -> void:
	visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.12, 0.95)
	style.border_color = Color(0.91, 0.72, 0.29)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	_speaker_label = Label.new()
	_speaker_label.add_theme_font_size_override("font_size", 26)
	_speaker_label.add_theme_color_override("font_color", Color(0.91, 0.72, 0.29))
	vbox.add_child(_speaker_label)

	_text_label = Label.new()
	_text_label.add_theme_font_size_override("font_size", 26)
	_text_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(0, 76)
	vbox.add_child(_text_label)

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(bottom)

	var hint := Label.new()
	hint.text = "OK / Enter: continue"
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	bottom.add_child(hint)

	_continue_button = Button.new()
	_continue_button.text = "Continue  >"
	_continue_button.custom_minimum_size = Vector2(220, 56)
	_continue_button.add_theme_font_size_override("font_size", 26)
	_continue_button.pressed.connect(_on_continue_pressed)
	bottom.add_child(_continue_button)

	# Bottom-anchored, full width, fixed height.
	set_anchors_preset(PRESET_BOTTOM_WIDE)
	offset_top = -200
	offset_left = 12
	offset_right = -12
	offset_bottom = -12


func is_open() -> bool:
	return _open


func show_lines(speaker: String, lines: Array) -> void:
	if lines.is_empty():
		return
	_lines = lines
	_index = 0
	_open = true
	_speaker_label.text = speaker
	visible = true
	_show_current()
	_continue_button.grab_focus()


func _show_current() -> void:
	var line: String = _lines[_index]
	_text_label.text = line
	Narration.speak(line)


func _on_continue_pressed() -> void:
	advance()


func advance() -> void:
	if not _open:
		return
	Sfx.play_select()
	_index += 1
	if _index >= _lines.size():
		_close()
	else:
		_show_current()


func _close() -> void:
	_open = false
	visible = false
	Narration.stop()
	dialogue_finished.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("ui_accept"):
		# If the Continue button already consumed this press, this never fires.
		advance()
		get_viewport().set_input_as_handled()
