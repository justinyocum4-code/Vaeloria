extends Control
## Title screen: VAELORIA. Big buttons, D-pad focusable, touch friendly.
## New Game / Continue / Narration toggle. Shows the party sprites.

var _new_button: Button
var _continue_button: Button
var _narration_button: Button


func _ready() -> void:
	ExploreTouch.reset()
	Music.play_village()
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.043, 0.047, 0.098)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var title := Label.new()
	title.text = "VAELORIA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 84)
	title.add_theme_color_override("font_color", Color(0.91, 0.72, 0.29))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "An original tale of the Emberstones"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 28)
	subtitle.add_theme_color_override("font_color", Color(0.95, 0.95, 1))
	vbox.add_child(subtitle)

	# Party sprites row.
	var party := HBoxContainer.new()
	party.alignment = BoxContainer.ALIGNMENT_CENTER
	party.add_theme_constant_override("separation", 24)
	vbox.add_child(party)
	for path in [
		"res://assets/sprites/hero.png",
		"res://assets/sprites/lyra.png",
		"res://assets/sprites/mira.png",
		"res://assets/sprites/dax.png",
	]:
		var tex: Texture2D = load(path)
		var rect := TextureRect.new()
		rect.texture = tex
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.custom_minimum_size = Vector2(96, 128)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		party.add_child(rect)

	_new_button = _make_button("New Game")
	_new_button.pressed.connect(_on_new_game)
	vbox.add_child(_new_button)

	_continue_button = _make_button("Continue")
	_continue_button.pressed.connect(_on_continue)
	if GameState.has_save():
		var saved_level := 1
		# Peek at the save to show the level without loading fully.
		if GameState.load_game():
			saved_level = GameState.level
		_continue_button.text = "Continue  —  Kael, Level %d" % saved_level
	else:
		_continue_button.disabled = true
		_continue_button.text = "Continue  (no save yet)"
	vbox.add_child(_continue_button)

	_narration_button = _make_button("Narration: On")
	_narration_button.pressed.connect(_on_toggle_narration)
	_update_narration_text()
	vbox.add_child(_narration_button)

	var footer := Label.new()
	footer.text = "A Lynxos RPG  •  Godot 4.6  •  D-pad, touch and TV friendly\nWalk with arrows or D-pad. Talk with Enter, Space or the A button.\nMusic: Kevin MacLeod (incompetech.com) — CC BY 4.0"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 20)
	footer.add_theme_color_override("font_color", Color(0.7, 0.7, 0.78))
	vbox.add_child(footer)

	_new_button.grab_focus()
	Narration.speak("Vaeloria. An original tale of the Emberstones.")


func _input(event: InputEvent) -> void:
	# Built-in explore-by-touch: dragging a finger over a button reads it.
	var items: Array = []
	for button in [_new_button, _continue_button, _narration_button]:
		var b := button as Button
		items.append({
			"key": "title_" + b.text,
			"label": b.text,
			"rect": b.get_global_rect(),
		})
	ExploreTouch.handle(event, items)


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(420, 68)
	button.add_theme_font_size_override("font_size", 30)
	button.focus_mode = Control.FOCUS_ALL
	return button


func _update_narration_text() -> void:
	_narration_button.text = "Narration: On" if Narration.enabled else "Narration: Off"


func _on_new_game() -> void:
	Sfx.play_select()
	GameState.reset_new_game()
	get_tree().change_scene_to_file("res://scenes/village_3d.tscn")


func _on_continue() -> void:
	Sfx.play_select()
	if GameState.load_game():
		get_tree().change_scene_to_file("res://scenes/village_3d.tscn")


func _on_toggle_narration() -> void:
	Sfx.play_select()
	Narration.toggle()
	_update_narration_text()
	if Narration.enabled:
		Narration.speak("Narration on.")
