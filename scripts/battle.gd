extends Control
## Turn-based battle: Kael vs one enemy (Ember Wolf or Ember Slime).
## Menu: Attack / Magic / Heal / Run. D-pad navigable, touch friendly.
## Win: XP, possible level up. Lose: return to village at half HP.

var _rng := RandomNumberGenerator.new()
var _enemy_name := "Ember Wolf"
var _enemy_hp := 45
var _enemy_max_hp := 45
var _enemy_min_atk := 8
var _enemy_max_atk := 12
var _enemy_xp := 30
var _enemy_texture := "res://assets/sprites/ember_wolf.png"

var _enemy_rect: TextureRect
var _enemy_hp_bar: ProgressBar
var _enemy_label: Label
var _log_label: Label
var _status_label: Label
var _menu_buttons: Array = []
var _result_button: Button
var _battle_over := false
var _scroll: ScrollContainer
var _leaving := false


func _ready() -> void:
	_rng.randomize()
	ExploreTouch.reset()
	_setup_enemy()
	_build()


func _setup_enemy() -> void:
	if GameState.battle_enemy == "slime":
		_enemy_name = "Ember Slime"
		_enemy_hp = 30
		_enemy_max_hp = 30
		_enemy_min_atk = 5
		_enemy_max_atk = 8
		_enemy_xp = 20
		_enemy_texture = "res://assets/sprites/ember_slime.png"
	else:
		_enemy_name = "Ember Wolf"
		_enemy_hp = 45
		_enemy_max_hp = 45
		_enemy_min_atk = 8
		_enemy_max_atk = 12
		_enemy_xp = 30
		_enemy_texture = "res://assets/sprites/ember_wolf.png"


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.03, 0.08)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	# ScrollContainer safety net: the whole battle layout must fit a
	# 540-unit-tall screen. v1.0 overflowed it, so the "Return to Village"
	# button sat below the fold after a win and the screen looked frozen.
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(_scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(vbox)

	_enemy_label = Label.new()
	_enemy_label.text = _enemy_name
	_enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_label.add_theme_font_size_override("font_size", 36)
	_enemy_label.add_theme_color_override("font_color", Color(1, 0.55, 0.4))
	_enemy_label.add_theme_constant_override("outline_size", 6)
	_enemy_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	vbox.add_child(_enemy_label)

	var center := CenterContainer.new()
	vbox.add_child(center)
	_enemy_rect = TextureRect.new()
	_enemy_rect.texture = load(_enemy_texture)
	_enemy_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_enemy_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_enemy_rect.custom_minimum_size = Vector2(160, 96)
	_enemy_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	center.add_child(_enemy_rect)

	var hp_row := HBoxContainer.new()
	hp_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hp_row)
	_enemy_hp_bar = ProgressBar.new()
	_enemy_hp_bar.min_value = 0
	_enemy_hp_bar.max_value = _enemy_max_hp
	_enemy_hp_bar.value = _enemy_hp
	_enemy_hp_bar.show_percentage = false
	_enemy_hp_bar.custom_minimum_size = Vector2(560, 30)
	hp_row.add_child(_enemy_hp_bar)

	_log_label = Label.new()
	_log_label.add_theme_font_size_override("font_size", 26)
	_log_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.custom_minimum_size = Vector2(0, 56)
	_log_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	vbox.add_child(_log_label)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 26)
	_status_label.add_theme_color_override("font_color", Color(0.91, 0.72, 0.29))
	vbox.add_child(_status_label)

	var menu_wrap := CenterContainer.new()
	vbox.add_child(menu_wrap)
	var menu := GridContainer.new()
	menu.columns = 2
	menu.add_theme_constant_override("h_separation", 20)
	menu.add_theme_constant_override("v_separation", 16)
	menu_wrap.add_child(menu)
	_menu_buttons = [
		_make_menu_button("Attack", _on_attack),
		_make_menu_button("Magic: Firebolt (5 MP)", _on_magic),
		_make_menu_button("Heal (5 MP)", _on_heal),
		_make_menu_button("Run", _on_run),
	]
	for button in _menu_buttons:
		menu.add_child(button)

	_result_button = Button.new()
	_result_button.text = "Return to Village"
	_result_button.custom_minimum_size = Vector2(420, 64)
	_result_button.add_theme_font_size_override("font_size", 30)
	_result_button.visible = false
	_result_button.pressed.connect(_on_return_to_village)
	vbox.add_child(_result_button)

	_update_status()
	_log("A wild %s appears!" % _enemy_name)
	Narration.speak("A wild %s appears!" % _enemy_name)
	(_menu_buttons[0] as Button).grab_focus()


func _make_menu_button(text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(340, 56)
	button.add_theme_font_size_override("font_size", 28)
	button.pressed.connect(handler)
	return button


func _set_menu_enabled(enabled: bool) -> void:
	for button in _menu_buttons:
		(button as Button).disabled = not enabled


func _update_status() -> void:
	_status_label.text = "Kael  •  Lv %d  •  HP %d/%d  •  MP %d/%d" % [
		GameState.level, GameState.hp, GameState.max_hp, GameState.mp, GameState.max_mp,
	]
	_enemy_hp_bar.value = _enemy_hp


func _log(text: String) -> void:
	_log_label.text = text
	Narration.speak(text)


func _flash_enemy() -> void:
	_enemy_rect.modulate = Color(1, 0.4, 0.4)
	var tween := create_tween()
	tween.tween_property(_enemy_rect, "modulate", Color(1, 1, 1), 0.35)


func _on_attack() -> void:
	if _battle_over:
		return
	_set_menu_enabled(false)
	var dmg := maxi(1, _rng.randi_range(GameState.attack - 2, GameState.attack + 3))
	_enemy_hp -= dmg
	Sfx.play_hit()
	_flash_enemy()
	_update_status()
	_log("Kael attacks the %s for %d damage!" % [_enemy_name, dmg])
	if _enemy_hp <= 0:
		_win()
	else:
		_enemy_turn()


func _on_magic() -> void:
	if _battle_over:
		return
	if GameState.mp < 5:
		_log("Not enough MP! Firebolt needs 5 MP.")
		return
	_set_menu_enabled(false)
	GameState.mp -= 5
	var dmg := _rng.randi_range(14, 20)
	_enemy_hp -= dmg
	Sfx.play_hit()
	_flash_enemy()
	_update_status()
	_log("Kael casts Firebolt for %d damage!" % dmg)
	if _enemy_hp <= 0:
		_win()
	else:
		_enemy_turn()


func _on_heal() -> void:
	if _battle_over:
		return
	if GameState.mp < 5:
		_log("Not enough MP! Heal needs 5 MP.")
		return
	_set_menu_enabled(false)
	GameState.mp -= 5
	var healed := mini(20, GameState.max_hp - GameState.hp)
	GameState.hp += healed
	Sfx.play_heal()
	_update_status()
	_log("Kael heals for %d HP." % healed)
	_enemy_turn()


func _on_run() -> void:
	if _battle_over:
		return
	_set_menu_enabled(false)
	if _rng.randi_range(1, 100) <= 70:
		_log("Kael ran away safely! Press Return to Village to continue.")
		_battle_over = true
		_show_result()
	else:
		_log("Could not run away!")
		_enemy_turn()


func _enemy_turn() -> void:
	await get_tree().create_timer(0.9).timeout
	if not is_inside_tree() or _battle_over:
		return
	var dmg := _rng.randi_range(_enemy_min_atk, _enemy_max_atk)
	GameState.hp -= dmg
	Sfx.play_hit()
	_update_status()
	_log("The %s hits Kael for %d damage!" % [_enemy_name, dmg])
	if GameState.hp <= 0:
		GameState.hp = 0
		_lose()
	else:
		_set_menu_enabled(true)
		(_menu_buttons[0] as Button).grab_focus()


func _win() -> void:
	_battle_over = true
	if GameState.battle_enemy == "wolf":
		GameState.wolf_defeated = true
	else:
		GameState.slime_defeated = true
	var levelled := GameState.gain_xp(_enemy_xp)
	Sfx.play_victory()
	_update_status()
	var text := "Victory! Kael gained %d XP." % _enemy_xp
	if levelled:
		text += " Kael reached level %d! HP and attack increased!" % GameState.level
	text += " Press Return to Village to continue."
	_log(text)
	_show_result()


func _lose() -> void:
	_battle_over = true
	GameState.hp = GameState.max_hp / 2
	GameState.mp = GameState.max_mp / 2
	Sfx.play_defeat()
	_update_status()
	_log("Kael was defeated... Mira's light brings him back to the village. Press Return to Village to continue.")
	_show_result()


func _show_result() -> void:
	_set_menu_enabled(false)
	_result_button.visible = true
	_result_button.grab_focus()
	# The button must actually be on screen: scroll it into view.
	_scroll.call_deferred("ensure_control_visible", _result_button)


func _on_return_to_village() -> void:
	if _leaving:
		return
	_leaving = true
	Sfx.play_select()
	GameState.spawn_pos = Vector2(640, 500)
	GameState.save_game()
	get_tree().change_scene_to_file("res://scenes/village.tscn")


func _input(event: InputEvent) -> void:
	# Built-in explore-by-touch: dragging a finger over a button reads it.
	var items: Array = []
	for button in _menu_buttons:
		var b := button as Button
		items.append({
			"key": "menu_" + b.text,
			"label": b.text,
			"rect": b.get_global_rect(),
		})
	if _result_button.visible:
		items.append({
			"key": "result",
			"label": "Return to Village. Battle over. Tap it to continue.",
			"rect": _result_button.get_global_rect(),
		})
	items.append({
		"key": "enemy",
		"label": "%s, health %d of %d." % [_enemy_name, maxi(0, _enemy_hp), _enemy_max_hp],
		"rect": _enemy_rect.get_global_rect(),
	})
	ExploreTouch.handle(event, items)


func _unhandled_input(event: InputEvent) -> void:
	# Enter / A / OK after the battle ends continues; Back leaves the
	# battle for the village instead of quitting the whole game.
	if event.is_action_pressed("ui_accept") and _battle_over:
		_on_return_to_village()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_on_return_to_village()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# Android system Back button: same as ui_cancel — back to the village,
	# never straight out of the game.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_return_to_village()
