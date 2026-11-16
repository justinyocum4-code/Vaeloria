extends Node2D
## Aldermere village — the v1 hub map.
## Walk with arrows / D-pad / WASD, or tap-to-move on touch screens.
## Talk to Lyra, Mira and Dax. Face the Ember Wolf (east gate) or the
## Ember Slime (southwest pond) in turn-based battle. S saves, Back/Esc
## returns to the title screen.

const MAP_W := 1280
const MAP_H := 960
const TILE := 32
const WALK_SPEED := 150.0
const TALK_RANGE := 84.0

var _player: CharacterBody2D
var _player_sprite: Sprite2D
var _dialogue: DialogueBox
var _status_label: Label
var _objective_label: Label
var _prompt_label: Label
var _npcs: Array = []
var _near_npc: Dictionary = {}
var _pending_battle := ""
var _touch_active := false
var _touch_target := Vector2.ZERO


func _ready() -> void:
	_build_ground()
	_build_decor()
	_build_player()
	_build_npcs()
	_build_hud()
	_dialogue = DialogueBox.new()
	# DialogueBox is a Control; add it to a CanvasLayer so it draws on top.
	var dialog_layer := CanvasLayer.new()
	dialog_layer.layer = 20
	dialog_layer.add_child(_dialogue)
	add_child(dialog_layer)
	_dialogue.dialogue_finished.connect(_on_dialogue_finished)
	_update_objective()
	if not GameState.intro_done:
		GameState.intro_done = true
		_show_lines("Narrator", [
			"Aldermere village. Home of Kael Arden, a young sword fighter.",
			"The Emberstones that protect the kingdom are fading, and Lord Varik Kane is coming for them.",
			"Talk to Lyra, Mira and Dax. Then face the Ember Wolf at the east gate.",
		])


# ---------------------------------------------------------------- ground ---

func _build_ground() -> void:
	# Build a 2-tile atlas (grass + path) in code and paint the map.
	var grass_img: Image = load("res://assets/sprites/grass.png").get_image()
	var path_img: Image = load("res://assets/sprites/path.png").get_image()
	var atlas := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	atlas.blit_rect(grass_img, Rect2i(0, 0, 32, 32), Vector2i(0, 0))
	atlas.blit_rect(path_img, Rect2i(0, 0, 32, 32), Vector2i(32, 0))
	var atlas_tex := ImageTexture.create_from_image(atlas)

	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE, TILE)
	var source := TileSetAtlasSource.new()
	source.texture = atlas_tex
	source.texture_region_size = Vector2i(TILE, TILE)
	source.create_tile(Vector2i(0, 0))
	source.create_tile(Vector2i(1, 0))
	var source_id := tileset.add_source(source)

	var ground := TileMapLayer.new()
	ground.tile_set = tileset
	add_child(ground)
	for x in range(MAP_W / TILE):
		for y in range(MAP_H / TILE):
			ground.set_cell(Vector2i(x, y), source_id, Vector2i(0, 0))
	# Main paths: east-west road and north-south road.
	for x in range(2, 38):
		ground.set_cell(Vector2i(x, 15), source_id, Vector2i(1, 0))
	for y in range(2, 28):
		ground.set_cell(Vector2i(20, y), source_id, Vector2i(1, 0))

	# Map edge walls.
	_add_wall(Vector2(MAP_W / 2, -16), Vector2(MAP_W + 64, 32))
	_add_wall(Vector2(MAP_W / 2, MAP_H + 16), Vector2(MAP_W + 64, 32))
	_add_wall(Vector2(-16, MAP_H / 2), Vector2(32, MAP_H + 64))
	_add_wall(Vector2(MAP_W + 16, MAP_H / 2), Vector2(32, MAP_H + 64))


func _add_wall(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	add_child(body)


func _add_solid(pos: Vector2, size: Vector2) -> void:
	_add_wall(pos, size)


# ----------------------------------------------------------------- decor ---

func _build_decor() -> void:
	# Houses (sprite + solid base).
	for house_pos in [Vector2(300, 200), Vector2(980, 200), Vector2(300, 700)]:
		var house := Sprite2D.new()
		house.texture = load("res://assets/sprites/house.png")
		house.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		house.position = house_pos
		add_child(house)
		_add_solid(house_pos + Vector2(0, 34), Vector2(116, 56))
	# Trees.
	for tree_pos in [
		Vector2(120, 120), Vector2(1160, 120), Vector2(120, 860),
		Vector2(1160, 860), Vector2(520, 110), Vector2(760, 860),
		Vector2(1100, 520), Vector2(140, 520),
	]:
		var tree := Sprite2D.new()
		tree.texture = load("res://assets/sprites/tree.png")
		tree.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tree.scale = Vector2(1.25, 1.25)
		tree.position = tree_pos
		add_child(tree)
		_add_solid(tree_pos + Vector2(0, 36), Vector2(24, 20))
	# Flowers and rocks (decoration only, no collision).
	for flower_pos in [Vector2(420, 560), Vector2(860, 560), Vector2(640, 300), Vector2(220, 380)]:
		var flower := Sprite2D.new()
		flower.texture = load("res://assets/sprites/flower.png")
		flower.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		flower.position = flower_pos
		add_child(flower)
	for rock_pos in [Vector2(180, 700), Vector2(1100, 760), Vector2(700, 180)]:
		var rock := Sprite2D.new()
		rock.texture = load("res://assets/sprites/rock.png")
		rock.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rock.position = rock_pos
		add_child(rock)


# ---------------------------------------------------------------- player ---

func _build_player() -> void:
	_player = CharacterBody2D.new()
	_player.position = GameState.spawn_pos
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(26, 36)
	shape.shape = rect
	shape.position = Vector2(0, 8)
	_player.add_child(shape)
	_player_sprite = Sprite2D.new()
	_player_sprite.texture = load("res://assets/sprites/hero.png")
	_player_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_player_sprite.scale = Vector2(1.5, 1.5)
	_player.add_child(_player_sprite)
	var camera := Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = MAP_W
	camera.limit_bottom = MAP_H
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	_player.add_child(camera)
	add_child(_player)
	# make_current() only works once the camera is inside the tree.
	camera.make_current()


# ------------------------------------------------------------------- NPCs ---

func _build_npcs() -> void:
	_add_npc("lyra", "Lyra Voss", "res://assets/sprites/lyra.png", Vector2(560, 420), [
		"Kael! There you are. The Emberstones have been flickering all morning.",
		"Lord Varik Kane wants them for himself. If he takes the last stone, Aldermere falls.",
		"Mira and Dax are waiting for you. Talk to them, then prove yourself against the Ember Wolf at the east gate.",
	], [
		"The east gate is that way. The Ember Wolf is no joke, but I believe in you.",
	])
	_add_npc("mira", "Mira Solenne", "res://assets/sprites/mira.png", Vector2(760, 420), [
		"Hello, Kael. I have been praying for Aldermere. The stones feel... afraid.",
		"If you are hurt in battle, come back to me. My light can mend wounds, but it cannot mend a broken heart. Be careful.",
	], [
		"May the light go with you, Kael.",
	])
	_add_npc("dax", "Dax Rook", "res://assets/sprites/dax.png", Vector2(640, 660), [
		"Well, well. The village hero finally shows up. I have been scouting the east gate.",
		"The Ember Wolf is big, fast, and it hates fire. Lyra's magic will help, but your sword does the talking.",
		"There is also an Ember Slime by the old pond, southwest. Easy pickings if you want to warm up first.",
	], [
		"Go on. I will watch your back from the rooftops.",
	])
	_add_npc("wolf", "Ember Wolf", "res://assets/sprites/ember_wolf.png", Vector2(1180, 480), [
		"A wild Ember Wolf blocks the east gate! Its eyes burn like coals.",
	], [
		"The gate is clear. Aldermere is safe... for now.",
	], "wolf")
	_add_npc("slime", "Ember Slime", "res://assets/sprites/ember_slime.png", Vector2(200, 800), [
		"An Ember Slime bubbles by the pond, hissing like a kettle.",
	], [
		"The pond is quiet again.",
	], "slime")


func _add_npc(id: String, display_name: String, texture_path: String, pos: Vector2, first_lines: Array, repeat_lines: Array, enemy := "") -> void:
	var npc := Node2D.new()
	npc.position = pos
	var sprite := Sprite2D.new()
	sprite.texture = load(texture_path)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(1.5, 1.5)
	if id == "wolf":
		sprite.scale = Vector2(2.0, 2.0)
	npc.add_child(sprite)
	var name_label := Label.new()
	name_label.text = display_name
	name_label.position = Vector2(-64, -72)
	name_label.size = Vector2(128, 24)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1))
	name_label.add_theme_constant_override("outline_size", 6)
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	npc.add_child(name_label)
	add_child(npc)
	_npcs.append({
		"id": id,
		"name": display_name,
		"node": npc,
		"first_lines": first_lines,
		"repeat_lines": repeat_lines,
		"enemy": enemy,
	})


func _npc_already_met(id: String) -> bool:
	match id:
		"lyra":
			return GameState.met_lyra
		"mira":
			return GameState.met_mira
		"dax":
			return GameState.met_dax
		"wolf":
			return GameState.wolf_defeated
		"slime":
			return GameState.slime_defeated
	return false


func _npc_lines(npc: Dictionary) -> Array:
	if _npc_already_met(npc["id"]):
		return npc["repeat_lines"]
	return npc["first_lines"]


# ------------------------------------------------------------------- HUD ---

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.layer = 10
	add_child(hud)

	var top_bar := PanelContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 64
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color(0.05, 0.05, 0.12, 0.85)
	top_style.content_margin_left = 16
	top_style.content_margin_right = 16
	top_style.content_margin_top = 8
	top_style.content_margin_bottom = 8
	top_bar.add_theme_stylebox_override("panel", top_style)
	hud.add_child(top_bar)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 16)
	top_bar.add_child(top_row)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 24)
	_status_label.add_theme_color_override("font_color", Color(0.91, 0.72, 0.29))
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(_status_label)

	var save_button := Button.new()
	save_button.text = "Save"
	save_button.custom_minimum_size = Vector2(140, 48)
	save_button.add_theme_font_size_override("font_size", 24)
	save_button.focus_mode = Control.FOCUS_NONE
	save_button.pressed.connect(_on_save_pressed)
	top_row.add_child(save_button)

	var title_button := Button.new()
	title_button.text = "Title"
	title_button.custom_minimum_size = Vector2(140, 48)
	title_button.add_theme_font_size_override("font_size", 24)
	title_button.focus_mode = Control.FOCUS_NONE
	title_button.pressed.connect(_on_title_pressed)
	top_row.add_child(title_button)

	_objective_label = Label.new()
	_objective_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_objective_label.offset_top = 72
	_objective_label.offset_left = 16
	_objective_label.offset_right = -16
	_objective_label.add_theme_font_size_override("font_size", 22)
	_objective_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_objective_label.add_theme_constant_override("outline_size", 6)
	_objective_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hud.add_child(_objective_label)

	_prompt_label = Label.new()
	_prompt_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt_label.offset_top = -56
	_prompt_label.offset_bottom = -12
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 24)
	_prompt_label.add_theme_color_override("font_color", Color(0.91, 0.72, 0.29))
	_prompt_label.add_theme_constant_override("outline_size", 6)
	_prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_prompt_label.visible = false
	hud.add_child(_prompt_label)

	_update_status()


func _update_status() -> void:
	_status_label.text = "Kael  •  Lv %d  •  HP %d/%d  •  MP %d/%d  •  XP %d/%d" % [
		GameState.level, GameState.hp, GameState.max_hp,
		GameState.mp, GameState.max_mp, GameState.xp, GameState.xp_needed(),
	]


func _update_objective() -> void:
	if not (GameState.met_lyra and GameState.met_mira and GameState.met_dax):
		_objective_label.text = "Quest: Talk to Lyra, Mira and Dax in the village."
	elif not GameState.wolf_defeated and not GameState.slime_defeated:
		_objective_label.text = "Quest: Face the Ember Wolf at the east gate — or warm up on the Ember Slime by the pond."
	elif not GameState.wolf_defeated:
		_objective_label.text = "Quest: The Ember Wolf still guards the east gate."
	elif not GameState.slime_defeated:
		_objective_label.text = "Quest: The Ember Slime still bubbles by the pond."
	else:
		_objective_label.text = "Quest complete: the village is safe... for now. Lord Varik Kane is still out there."
	_update_status()


func _on_save_pressed() -> void:
	Sfx.play_select()
	GameState.spawn_pos = _player.position
	if GameState.save_game():
		_show_prompt("Game saved!")
		Narration.speak("Game saved.")
	else:
		_show_prompt("Save failed.")
	_update_status()


func _on_title_pressed() -> void:
	Sfx.play_select()
	GameState.spawn_pos = _player.position
	GameState.save_game()
	get_tree().change_scene_to_file("res://scenes/title.tscn")


func _show_prompt(text: String) -> void:
	_prompt_label.text = text
	_prompt_label.visible = true


# -------------------------------------------------------------- interaction ---

func _physics_process(_delta: float) -> void:
	if _dialogue.is_open():
		_player.velocity = Vector2.ZERO
		_player.move_and_slide()
		return
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if _touch_active and _player.position.distance_to(_touch_target) > 14.0:
		dir = (_touch_target - _player.position).normalized()
		if _player.position.distance_to(_touch_target) <= 14.0:
			_touch_active = false
	if dir.length() > 1.0:
		dir = dir.normalized()
	_player.velocity = dir * WALK_SPEED
	_player.move_and_slide()
	if dir.x < -0.1:
		_player_sprite.flip_h = true
	elif dir.x > 0.1:
		_player_sprite.flip_h = false


func _process(_delta: float) -> void:
	if _dialogue.is_open():
		_prompt_label.visible = false
		return
	_near_npc = {}
	var best_dist := TALK_RANGE
	for npc in _npcs:
		var node: Node2D = npc["node"]
		var dist := _player.position.distance_to(node.position)
		if dist < best_dist:
			best_dist = dist
			_near_npc = npc
	if _near_npc.is_empty():
		_prompt_label.visible = false
	else:
		_show_prompt("Talk: %s  —  press Enter / A" % _near_npc["name"])


func _unhandled_input(event: InputEvent) -> void:
	if _dialogue.is_open():
		return
	if event.is_action_pressed("ui_cancel"):
		_on_title_pressed()
		return
	if event.is_action_pressed("ui_accept"):
		if not _near_npc.is_empty():
			_talk_to(_near_npc)
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		var world_pos: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * touch.position
		if touch.pressed:
			_touch_active = true
			_touch_target = world_pos
			for npc in _npcs:
				var node: Node2D = npc["node"]
				if world_pos.distance_to(node.position) < 70.0:
					_touch_active = false
					_talk_to(npc)
					break
		else:
			_touch_active = false
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_touch_active = true
		_touch_target = get_viewport().get_canvas_transform().affine_inverse() * drag.position
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			var world_pos := get_global_mouse_position()
			for npc in _npcs:
				var node: Node2D = npc["node"]
				if world_pos.distance_to(node.position) < 70.0:
					_talk_to(npc)
					return
			_touch_active = true
			_touch_target = world_pos
		elif mouse.button_index == MOUSE_BUTTON_LEFT and not mouse.pressed:
			_touch_active = false
	elif event is InputEventMouseMotion and _touch_active:
		_touch_target = get_global_mouse_position()


func _unhandled_key_input(event: InputEvent) -> void:
	if _dialogue.is_open():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_S:
			_on_save_pressed()


func _talk_to(npc: Dictionary) -> void:
	Sfx.play_select()
	_touch_active = false
	_pending_battle = ""
	_show_lines(npc["name"], _npc_lines(npc))
	# Remember which NPC we are talking to for the finish handler.
	_near_npc = npc
	if npc["enemy"] != "" and not _npc_already_met(npc["id"]):
		_pending_battle = npc["enemy"]


func _show_lines(speaker: String, lines: Array) -> void:
	_dialogue.show_lines(speaker, lines)


func _on_dialogue_finished() -> void:
	# Mark party members as met; trigger battle for monsters.
	if _near_npc.is_empty():
		_update_objective()
		return
	match _near_npc["id"]:
		"lyra":
			GameState.met_lyra = true
		"mira":
			GameState.met_mira = true
		"dax":
			GameState.met_dax = true
	if _pending_battle != "":
		var enemy := _pending_battle
		_pending_battle = ""
		GameState.battle_enemy = enemy
		GameState.spawn_pos = _player.position
		GameState.save_game()
		get_tree().change_scene_to_file("res://scenes/battle.tscn")
		return
	_update_objective()
