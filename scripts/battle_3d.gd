extends Node3D
## 3D turn-based battle: Kael (+ Lyra if she joined) vs the Ember Wolf.
## Same mechanics as the 2D battle.gd: Attack / Magic: Firebolt / Heal /
## Run, enemy AI, XP and level up on victory. The fight plays out in a
## small 3D arena (Kael and the wolf are low-poly models) with a Control
## overlay for the menu and log — the overlay reuses the 2D layout
## lessons (compact sizes, ScrollContainer safety net, result button
## on screen, victory line says to press Return to Village).
## Win: XP, possible level up. Lose: return to village at half HP.

var _rng := RandomNumberGenerator.new()
var _enemy_name := "Ember Wolf"
var _enemy_hp := 45
var _enemy_max_hp := 45
var _enemy_min_atk := 8
var _enemy_max_atk := 12
var _enemy_xp := 30

var _kael_model: Node3D
var _lyra_model: Node3D
var _wolf_model: Node3D
var _wolf_body: StaticBody3D
var _camera: Camera3D
var _enemy_hp_bar: ProgressBar
var _enemy_label: Label
var _log_label: Label
var _status_label: Label
var _menu_buttons: Array = []
var _result_button: Button
var _battle_over := false
var _scroll: ScrollContainer
var _leaving := false
# Torch flicker.
var _torch_lights: Array = []
var _anim_time := 0.0


func _ready() -> void:
	_rng.randomize()
	Music.play_battle()
	ExploreTouch.reset()
	ExploreTouch3D.reset()
	_build_arena()
	_build_overlay()
	_update_status()
	_log("A wild %s appears!" % _enemy_name)
	(_menu_buttons[0] as Button).grab_focus()


# ----------------------------------------------------------------- arena ---

func _build_arena() -> void:
	add_child(MeshFactory.make_environment())
	add_child(MeshFactory.make_sun())

	# Arena floor: dark stone disc on a wider gold disc.
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 9.0
	floor_mesh.bottom_radius = 9.0
	floor_mesh.height = 0.5
	floor_mesh.radial_segments = 32
	var floor := MeshInstance3D.new()
	floor.mesh = floor_mesh
	floor.position = Vector3(0, -0.25, 0)
	floor.material_override = MeshFactory.mat(Color(0.25, 0.22, 0.28))
	add_child(floor)
	var rim_mesh := CylinderMesh.new()
	rim_mesh.top_radius = 9.6
	rim_mesh.bottom_radius = 9.6
	rim_mesh.height = 0.1
	rim_mesh.radial_segments = 32
	var rim := MeshInstance3D.new()
	rim.mesh = rim_mesh
	rim.position = Vector3(0, -0.07, 0)
	rim.material_override = MeshFactory.mat(MeshFactory.GOLD)
	add_child(rim)

	# Kael faces the wolf (-Z); Lyra stands beside him if she joined.
	_kael_model = MeshFactory.make_humanoid({
		"tunic": Color(0.15, 0.2, 0.45),
		"hair": Color(0.25, 0.15, 0.08),
		"sword": true,
	})
	_kael_model.position = Vector3(0, 0, 3.5)
	_kael_model.rotation.y = PI
	add_child(_kael_model)
	if GameState.met_lyra:
		_lyra_model = MeshFactory.make_humanoid({
			"tunic": Color(0.45, 0.2, 0.6),
			"hair": Color(0.7, 0.15, 0.1),
			"robe": true,
			"staff": true,
		})
		_lyra_model.position = Vector3(-2.2, 0, 4.2)
		_lyra_model.rotation.y = PI
		add_child(_lyra_model)

	_wolf_model = MeshFactory.make_wolf()
	_wolf_model.position = Vector3(0, 0, -3.5)
	add_child(_wolf_model)
	_wolf_body = MeshFactory.add_npc_body(_wolf_model, "enemy", "Ember Wolf.", "wolf")

	# Rocks and trees at the arena edge, torches for mood.
	for rock_pos in [
		Vector3(7, 0.3, -5), Vector3(-7, 0.25, -4), Vector3(6, 0.2, 6),
		Vector3(-6, 0.3, 5),
	]:
		var rock := MeshInstance3D.new()
		var rock_mesh := SphereMesh.new()
		rock_mesh.radius = 0.6
		rock_mesh.height = 0.9
		rock.mesh = rock_mesh
		rock.scale = Vector3(1, 0.6, 1)
		rock.position = rock_pos
		rock.material_override = MeshFactory.mat(Color(0.55, 0.55, 0.58))
		add_child(rock)
	for tree_pos in [Vector3(8, 0, 2), Vector3(-8, 0, 1), Vector3(0, 0, -8)]:
		var tree := MeshFactory.make_tree("arena_tree", "An old oak tree.")
		tree.position = tree_pos
		add_child(tree)
	for torch_pos in [Vector3(6, 0, -6), Vector3(-6, 0, -6)]:
		var torch := MeshFactory.make_torch()
		torch.position = torch_pos
		add_child(torch)
		for child in torch.get_children():
			if child is OmniLight3D:
				_torch_lights.append(child)

	_camera = Camera3D.new()
	_camera.position = Vector3(0, 6.5, 10.5)
	add_child(_camera)
	_camera.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	_camera.current = true


# --------------------------------------------------------------- overlay ---

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	root.add_child(margin)

	# ScrollContainer safety net: the whole battle layout must fit a
	# 540-unit-tall screen (the 2D battle once overflowed it and the
	# "Return to Village" button sat below the fold, looking frozen).
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	var party := "Kael"
	if GameState.met_lyra:
		party = "Kael + Lyra"
	_status_label.text = "%s  •  Lv %d  •  HP %d/%d  •  MP %d/%d" % [
		party, GameState.level, GameState.hp, GameState.max_hp, GameState.mp, GameState.max_mp,
	]
	_enemy_hp_bar.value = _enemy_hp
	if _wolf_body != null:
		_wolf_body.set_meta("explore_label",
			"%s, health %d of %d." % [_enemy_name, maxi(0, _enemy_hp), _enemy_max_hp])


func _log(text: String) -> void:
	_log_label.text = text
	Narration.speak(text)


func _lunge(model: Node3D, toward_z: float) -> void:
	if model == null:
		return
	var home_z: float = model.position.z
	var tween := create_tween()
	tween.tween_property(model, "position:z", toward_z, 0.15)
	tween.tween_property(model, "position:z", home_z, 0.2)


func _flash_enemy() -> void:
	var tween := create_tween()
	tween.tween_property(_wolf_model, "scale", Vector3(1.12, 1.12, 1.12), 0.08)
	tween.tween_property(_wolf_model, "scale", Vector3.ONE, 0.12)


# -------------------------------------------------------------- mechanics ---

func _process(delta: float) -> void:
	# Torch flames flicker while the fight plays out.
	_anim_time += delta
	for i in _torch_lights.size():
		var light: OmniLight3D = _torch_lights[i]
		if is_instance_valid(light):
			var phase := float(i) * 1.7
			light.light_energy = 0.9 + 0.22 * sin(_anim_time * 7.0 + phase) + 0.12 * sin(_anim_time * 13.0 + phase * 1.7)


func _on_attack() -> void:
	if _battle_over:
		return
	_set_menu_enabled(false)
	_lunge(_kael_model, 2.7)
	var dmg := maxi(1, _rng.randi_range(GameState.attack - 2, GameState.attack + 3))
	_enemy_hp -= dmg
	Sfx.play_hit()
	_flash_enemy()
	_update_status()
	_log("Kael attacks the %s for %d damage!" % [_enemy_name, dmg])
	if _enemy_hp <= 0:
		_win()
	else:
		_after_player_action()


func _on_magic() -> void:
	if _battle_over:
		return
	if GameState.mp < 5:
		_log("Not enough MP! Firebolt needs 5 MP.")
		return
	_set_menu_enabled(false)
	_lunge(_kael_model, 2.7)
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
		_after_player_action()


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
	_after_player_action()


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
		_after_player_action()


## After Kael's action, Lyra strikes too if she joined the party.
## Returns after the enemy's turn is queued (or the battle is won).
func _after_player_action() -> void:
	if _battle_over:
		return
	if GameState.met_lyra and _lyra_model != null:
		_lunge(_lyra_model, 3.4)
		var dmg := _rng.randi_range(8, 12)
		_enemy_hp -= dmg
		Sfx.play_hit()
		_flash_enemy()
		_update_status()
		_log("Lyra casts Firebolt for %d damage!" % dmg)
		if _enemy_hp <= 0:
			_win()
			return
	_enemy_turn()


func _enemy_turn() -> void:
	await get_tree().create_timer(0.9).timeout
	if not is_inside_tree() or _battle_over:
		return
	_lunge(_wolf_model, -2.7)
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
	GameState.wolf_defeated = true
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
	GameState.spawn_pos_3d = Vector3(0, 0, 12)
	GameState.save_game()
	get_tree().change_scene_to_file("res://scenes/village_3d.tscn")


# ------------------------------------------------------------------ input ---

func _input(event: InputEvent) -> void:
	# Built-in explore-by-touch: dragging a finger over a menu button
	# reads it; dragging over the 3D wolf reads its health.
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
	ExploreTouch.handle(event, items)
	if _over_menu_button(_event_position(event)):
		return
	ExploreTouch3D.handle(event, _camera)


func _event_position(event: InputEvent) -> Vector2:
	if event is InputEventScreenDrag:
		return (event as InputEventScreenDrag).position
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	if event is InputEventMouseMotion:
		return (event as InputEventMouseMotion).position
	return Vector2.INF


func _over_menu_button(pos: Vector2) -> bool:
	for button in _menu_buttons:
		if (button as Button).get_global_rect().has_point(pos):
			return true
	if _result_button.visible and _result_button.get_global_rect().has_point(pos):
		return true
	return false


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
