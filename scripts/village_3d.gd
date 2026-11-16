extends Node3D
## Aldermere village in 3D — Phase 1 of the full game (v1.1.0),
## polished in v1.1.1: talking to a character cuts to a cinematic
## scene (camera close-up, lines spoken aloud, auto-advance) instead
## of a text box, and the village is dressed up (market stall, well,
## flowers, stepping stones, flickering torches, floating embers).
## v1.1.2: talks and boss approaches open with a full-screen movie
## scene (a short cinematic video clip), and background music plays
## (village theme here, battle theme in the fight).
## v1.1.3: the lines were spoken inside the movie (device TTS +
## subtitles, clip looping). v1.1.4: the movie is only an opening
## shot now — the talk itself happens in the close-up, with each
## character's own recorded voice and a mouth that opens and closes
## while they speak. A video clip is fixed footage, so no mouth in
## it can ever move; the live 3D characters are where talking shows.
## Walk with arrows / D-pad / WASD, or tap-to-move on touch screens.
## Talk to Elder Maren and Lyra Voss (Lyra joins the party), then face
## the Ember Wolf at the east gate. Dragging a finger across the screen
## reads aloud whatever is under it (explore-by-touch, raycast from the
## camera). S saves, Back/Esc returns to the title screen.
## The 2D village (village.gd / scenes/village.tscn) stays in the repo
## unused; the title screen now points here.

const WORLD_SIZE := Vector2(48, 36)
const WALK_SPEED := 5.0
const TALK_RANGE := 3.5
const SPAWN := Vector3(0, 0, 12)
# A fingertip tap always drifts a few pixels; 64px is generous enough
# for a real finger while still far below a deliberate drag.
const TAP_TOLERANCE := 64.0
# Movie scenes: one short cinematic video per character. The wolf's
# video also plays when Kael walks up to the gate (see _process).
const VIDEO_SCENES := {
	"maren": "res://assets/cutscenes/cutscene_maren.ogv",
	"lyra": "res://assets/cutscenes/cutscene_lyra.ogv",
	"wolf": "res://assets/cutscenes/cutscene_wolf.ogv",
}
const WOLF_APPROACH_DIST := 4.0
const WOLF_APPROACH_RESET_DIST := 7.0
# How long the opening movie shot stays up before the close-up talk
# starts (the clips are 10 s; the first few seconds are the shot).
const ESTABLISH_SECONDS := 4.0

var _player: CharacterBody3D
var _player_model: Node3D
var _camera_rig: Node3D
var _camera: Camera3D
var _dialogue: DialogueBox
var _cutscene: CutsceneDialogue
var _cutscene_active := false
var _video: VideoCutscene
var _video_active := false
var _video_npc: Dictionary = {}
var _wolf_approach_done := false
var _camera_tween: Tween
var _status_label: Label
var _objective_label: Label
var _prompt_label: Label
var _talk_button: Button
var _npcs: Array = []
var _near_npc: Dictionary = {}
var _pending_battle := ""
var _touch_active := false
var _touch_target := Vector3.ZERO
var _save_button: Button
var _title_button: Button
var _tap_press_pos := Vector2.ZERO
var _tap_press_pick: Dictionary = {}
var _tap_press_npc_id := ""
var _tap_moved := false
var _leaving := false
var _met_maren := false
var _lyra_node: Node3D
var _wolf_body: StaticBody3D
# World animation (torches flicker, pond glints bob, embers rise).
var _torch_lights: Array = []
var _pond_glints: Array = []
var _ember_motes: Array = []
var _anim_time := 0.0


func _ready() -> void:
	ExploreTouch.reset()
	ExploreTouch3D.reset()
	_build_world()
	_build_player()
	_build_camera()
	_build_npcs()
	_build_hud()
	_dialogue = DialogueBox.new()
	# DialogueBox is a Control; add it to a CanvasLayer so it draws on top.
	# It is only used for the opening narration now — NPC talks use the
	# cinematic cutscene below.
	var dialog_layer := CanvasLayer.new()
	dialog_layer.layer = 20
	dialog_layer.add_child(_dialogue)
	add_child(dialog_layer)
	_dialogue.dialogue_finished.connect(_on_dialogue_finished)
	# Cinematic dialogue for NPC conversations (layer 30, above the
	# text box).
	var cut_layer := CanvasLayer.new()
	cut_layer.layer = 30
	_cutscene = CutsceneDialogue.new()
	cut_layer.add_child(_cutscene)
	add_child(cut_layer)
	_cutscene.finished.connect(_on_cutscene_finished)
	_cutscene.skipped.connect(_on_cutscene_skipped)
	# Full-screen movie scenes (layer 40, above the dialogue).
	var video_layer := CanvasLayer.new()
	video_layer.layer = 40
	_video = VideoCutscene.new()
	video_layer.add_child(_video)
	add_child(video_layer)
	_video.finished.connect(_on_video_finished)
	_video.skipped.connect(_on_video_skipped)
	Music.play_village()
	_update_objective()
	if not GameState.intro_done:
		GameState.intro_done = true
		_show_lines("Narrator", [
			"Aldermere village. Home of Kael Arden, a young sword fighter.",
			"The Emberstones that protect the kingdom are fading, and Lord Varik Kane is coming for them.",
			"Talk to Elder Maren and Lyra by the shrine. Then face the Ember Wolf at the east gate.",
		])


# ----------------------------------------------------------------- world ---

func _build_world() -> void:
	add_child(MeshFactory.make_environment())
	add_child(MeshFactory.make_sun())
	add_child(MeshFactory.make_ground(WORLD_SIZE))

	# Paths: east-west road and north-south road (flat dirt slabs).
	_add_path(Vector3(0, 0.03, 0), Vector3(44, 0.06, 3))
	_add_path(Vector3(0, 0.03, 0), Vector3(3, 0.06, 32))

	# Houses (gold trim, black roofs), fronts facing the road.
	_add_house(Vector3(-14, 0, -10), 0.0, "house_west", "A villager's home, gold trim on the roof.")
	_add_house(Vector3(14, 0, -10), 0.0, "house_east", "A villager's home, gold trim on the roof.")
	_add_house(Vector3(-16, 0, 10), PI, "house_sw", "A villager's home, gold trim on the roof.")
	_add_house(Vector3(16, 0, 10), PI, "house_se", "A villager's home, gold trim on the roof.")
	_add_house(Vector3(0, 0, -14), 0.0, "house_north", "Elder Maren's house, gold trim on the roof.")

	# Trees.
	var tree_i := 0
	for tree_pos in [
		Vector3(-20, 0, -14), Vector3(20, 0, -14), Vector3(-20, 0, 14),
		Vector3(20, 0, 14), Vector3(-8, 0, 14), Vector3(8, 0, 14),
		Vector3(-22, 0, -4), Vector3(22, 0, -6), Vector3(10, 0, 6),
		Vector3(-10, 0, -6),
	]:
		tree_i += 1
		var tree := MeshFactory.make_tree("tree_%d" % tree_i, "An old oak tree.")
		tree.position = tree_pos
		add_child(tree)

	# Pond, southwest, with a couple of rocks beside it.
	var pond := MeshFactory.make_pond(3.0)
	pond.position = Vector3(-19, 0, 5)
	add_child(pond)
	for child in pond.get_children():
		if child.name.begins_with("Glint"):
			_pond_glints.append(child)
	for rock_pos in [Vector3(-15.5, 0.35, 7.5), Vector3(-22, 0.3, 2.5)]:
		var rock := MeshInstance3D.new()
		var rock_mesh := SphereMesh.new()
		rock_mesh.radius = 0.6
		rock_mesh.height = 0.9
		rock.mesh = rock_mesh
		rock.scale = Vector3(1, 0.6, 1)
		rock.position = rock_pos
		rock.material_override = MeshFactory.mat(Color(0.55, 0.55, 0.58))
		add_child(rock)

	# Fences along the main road (gaps left at the crossroads).
	for fence in [
		[Vector3(-7, 0, -2.5), 6.0], [Vector3(7, 0, -2.5), 6.0],
		[Vector3(-7, 0, 2.5), 6.0], [Vector3(7, 0, 2.5), 6.0],
	]:
		var run := MeshFactory.make_fence(fence[1])
		run.position = fence[0]
		add_child(run)

	# Emberstone shrine in the center, and the east gate.
	var shrine := MeshFactory.make_shrine()
	shrine.position = Vector3(0, 0, -4)
	add_child(shrine)
	var gate := MeshFactory.make_gate()
	gate.position = Vector3(22, 0, 0)
	add_child(gate)

	# Market stall and well, either side of the crossroads.
	var stall := MeshFactory.make_market_stall()
	stall.position = Vector3(-7, 0, 5)
	stall.rotation.y = PI / 2.0
	add_child(stall)
	var well := MeshFactory.make_well()
	well.position = Vector3(6, 0, -6)
	add_child(well)

	# Flowers and grass tufts (no colliders — the ground handles taps).
	var bloom_colors: Array = [
		Color(0.9, 0.2, 0.2), Color(0.95, 0.75, 0.2),
		Color(0.6, 0.3, 0.85), Color(0.95, 0.95, 0.95),
	]
	var flower_i := 0
	for flower_pos in [
		Vector3(-10, 0, 2), Vector3(-12, 0, -4), Vector3(10, 0, 8),
		Vector3(-18, 0, -8), Vector3(18, 0, 4), Vector3(4, 0, -8),
		Vector3(-4, 0, 12), Vector3(12, 0, -12), Vector3(-2, 0, 8),
		Vector3(18, 0, 12), Vector3(-16, 0, 12), Vector3(8, 0, 12),
		Vector3(-8, 0, -12), Vector3(2, 0, -12),
	]:
		var flower := MeshFactory.make_flower(bloom_colors[flower_i % bloom_colors.size()])
		flower.position = flower_pos
		add_child(flower)
		flower_i += 1
	for tuft_pos in [
		Vector3(-11, 0, 6), Vector3(11, 0, -4), Vector3(-6, 0, -10),
		Vector3(14, 0, 2), Vector3(-19, 0, -2), Vector3(6, 0, 10),
		Vector3(-2, 0, -10), Vector3(16, 0, 8), Vector3(-14, 0, 8),
		Vector3(9, 0, -10),
	]:
		var tuft := MeshFactory.make_grass_tuft()
		tuft.position = tuft_pos
		add_child(tuft)

	# Stepping stones along both roads.
	var stone_i := 0
	for sx in range(-20, 21, 3):
		var stone := MeshFactory.make_stepping_stone()
		stone.position = Vector3(float(sx), 0, 0.4 if stone_i % 2 == 0 else -0.4)
		add_child(stone)
		stone_i += 1
	for sz in range(-14, 15, 3):
		var stone2 := MeshFactory.make_stepping_stone()
		stone2.position = Vector3(0.4 if stone_i % 2 == 0 else -0.4, 0, float(sz))
		add_child(stone2)
		stone_i += 1

	# Torches: two by the gate, two by the shrine. Their lights flicker.
	for torch_pos in [
		Vector3(20, 0, -2.5), Vector3(20, 0, 2.5),
		Vector3(2.5, 0, -4), Vector3(-2.5, 0, -4),
	]:
		var torch := MeshFactory.make_torch()
		torch.position = torch_pos
		add_child(torch)
		for child in torch.get_children():
			if child is OmniLight3D:
				_torch_lights.append(child)

	# Ember motes floating around the shrine crystal.
	for i in range(10):
		var mote := MeshInstance3D.new()
		var mote_mesh := SphereMesh.new()
		mote_mesh.radius = 0.09
		mote_mesh.height = 0.18
		mote.mesh = mote_mesh
		mote.material_override = MeshFactory.mat(Color(1, 0.75, 0.25), Color(1, 0.7, 0.2), 2.5)
		var angle := float(i) * TAU / 10.0
		var base := Vector3(cos(angle) * 1.1, 1.2, sin(angle) * 1.1)
		mote.position = base
		shrine.add_child(mote)
		_ember_motes.append({
			"node": mote, "phase": float(i) * 0.63,
			"speed": 0.35 + float(i % 3) * 0.12, "base": base,
		})


func _add_path(pos: Vector3, size: Vector3) -> void:
	var path := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	path.mesh = mesh
	path.position = pos
	path.material_override = MeshFactory.mat(Color(0.55, 0.42, 0.28))
	add_child(path)


func _add_house(pos: Vector3, yaw: float, key: String, label: String) -> void:
	var house := MeshFactory.make_house(Color(0.85, 0.78, 0.6), key, label)
	house.position = pos
	house.rotation.y = yaw
	add_child(house)


# ---------------------------------------------------------------- player ---

func _build_player() -> void:
	_player = CharacterBody3D.new()
	_player.position = GameState.spawn_pos_3d
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.7
	shape.shape = capsule
	shape.position = Vector3(0, 0.85, 0)
	_player.add_child(shape)
	_player_model = MeshFactory.make_humanoid({
		"tunic": Color(0.15, 0.2, 0.45),
		"hair": Color(0.25, 0.15, 0.08),
		"sword": true,
	})
	_player.add_child(_player_model)
	add_child(_player)


func _build_camera() -> void:
	_camera_rig = Node3D.new()
	_camera_rig.position = _player.position
	add_child(_camera_rig)
	_camera = Camera3D.new()
	# Fixed angle: ~35 degrees down, behind and above Kael. The rig only
	# translates (never rotates), so the view direction never changes.
	_camera.position = Vector3(0, 10, 14)
	_camera.rotation = Vector3(-0.62, 0, 0)
	_camera_rig.add_child(_camera)
	_camera.current = true


# ------------------------------------------------------------------- NPCs ---

func _build_npcs() -> void:
	_add_npc("maren", "Elder Maren", Vector3(2.5, 0, -3), {
		"tunic": Color(0.85, 0.85, 0.9),
		"hair": Color(0.7, 0.7, 0.72),
		"robe": true,
		"name": "Elder Maren",
	}, [
		"Welcome home, Kael. The Emberstones have been flickering all morning.",
		"Long ago, the Emberstones were forged to protect Aldermere. Now they fade, and Lord Varik Kane rides to claim what is left.",
		"Lyra waits by the shrine. She will fight beside you. Then prove yourself against the Ember Wolf at the east gate.",
	], [
		"The east gate is that way. The wolf is no joke, but I believe in you.",
	])
	_add_npc("lyra", "Lyra Voss", Vector3(-3, 0, -2.5), {
		"tunic": Color(0.45, 0.2, 0.6),
		"hair": Color(0.7, 0.15, 0.1),
		"robe": true,
		"staff": true,
		"name": "Lyra Voss",
	}, [
		"Kael! There you are. I felt the stones flicker too.",
		"Fire and lightning answer me, and I will answer you. I am coming with you.",
		"The east gate is that way — the Ember Wolf is waiting.",
	], [
		"Ready when you are. The wolf will not wait forever.",
	])
	var wolf := MeshFactory.make_wolf()
	wolf.position = Vector3(21, 0, 0)
	wolf.rotation.y = -PI / 2.0  # Face west, toward the village.
	add_child(wolf)
	_wolf_body = MeshFactory.add_npc_body(wolf, "wolf", "Ember Wolf. Tap to battle.", "wolf")
	_npcs.append({
		"id": "wolf",
		"name": "Ember Wolf",
		"node": wolf,
		"first_lines": [
			"A wild Ember Wolf blocks the east gate! Its eyes burn like coals.",
		],
		"repeat_lines": [
			"The gate is clear. Aldermere is safe... for now.",
		],
		"enemy": "wolf",
	})


func _add_npc(id: String, display_name: String, pos: Vector3, spec: Dictionary, first_lines: Array, repeat_lines: Array) -> void:
	var npc := MeshFactory.make_humanoid(spec)
	npc.position = pos
	add_child(npc)
	MeshFactory.add_npc_body(npc, "npc_" + id, display_name + ". Tap to talk.", id)
	_npcs.append({
		"id": id,
		"name": display_name,
		"node": npc,
		"first_lines": first_lines,
		"repeat_lines": repeat_lines,
		"enemy": "",
	})
	if id == "lyra":
		_lyra_node = npc


func _npc_already_met(id: String) -> bool:
	match id:
		"maren":
			return _met_maren
		"lyra":
			return GameState.met_lyra
		"wolf":
			return GameState.wolf_defeated
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

	_save_button = Button.new()
	_save_button.text = "Save"
	_save_button.custom_minimum_size = Vector2(140, 48)
	_save_button.add_theme_font_size_override("font_size", 24)
	_save_button.focus_mode = Control.FOCUS_NONE
	_save_button.pressed.connect(_on_save_pressed)
	top_row.add_child(_save_button)

	_title_button = Button.new()
	_title_button.text = "Title"
	_title_button.custom_minimum_size = Vector2(140, 48)
	_title_button.add_theme_font_size_override("font_size", 24)
	_title_button.focus_mode = Control.FOCUS_NONE
	_title_button.pressed.connect(_on_title_pressed)
	top_row.add_child(_title_button)

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

	# Big tappable Talk button: when Kael stands near someone, this
	# appears above the prompt — a second way to start a conversation
	# for fingers that keep missing the character on screen.
	_talk_button = Button.new()
	_talk_button.text = "Talk"
	_talk_button.custom_minimum_size = Vector2(320, 56)
	_talk_button.add_theme_font_size_override("font_size", 26)
	_talk_button.visible = false
	_talk_button.pressed.connect(_on_talk_button_pressed)
	_talk_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_talk_button.offset_left = -160
	_talk_button.offset_right = 160
	_talk_button.offset_top = -124
	_talk_button.offset_bottom = -68
	hud.add_child(_talk_button)

	_update_status()


func _update_status() -> void:
	_status_label.text = "Kael  •  Lv %d  •  HP %d/%d  •  MP %d/%d  •  XP %d/%d" % [
		GameState.level, GameState.hp, GameState.max_hp,
		GameState.mp, GameState.max_mp, GameState.xp, GameState.xp_needed(),
	]


func _update_objective() -> void:
	if not GameState.met_lyra:
		_objective_label.text = "Quest: Talk to Elder Maren and Lyra by the shrine."
	elif not GameState.wolf_defeated:
		_objective_label.text = "Quest: Face the Ember Wolf at the east gate."
	else:
		_objective_label.text = "Quest complete: the village is safe... for now. Lord Varik Kane is still out there."
	if _wolf_body != null:
		_wolf_body.set_meta("explore_label",
			"Ember Wolf. Already defeated." if GameState.wolf_defeated else "Ember Wolf. Tap to battle.")
	_update_status()


func _on_save_pressed() -> void:
	Sfx.play_select()
	GameState.spawn_pos_3d = _player.position
	if GameState.save_game():
		_show_prompt("Game saved!")
		Narration.speak("Game saved.")
	else:
		_show_prompt("Save failed.")
	_update_status()


func _on_title_pressed() -> void:
	if _leaving:
		return
	_leaving = true
	Sfx.play_select()
	GameState.spawn_pos_3d = _player.position
	GameState.save_game()
	get_tree().change_scene_to_file("res://scenes/title.tscn")


func _show_prompt(text: String) -> void:
	_prompt_label.text = text
	_prompt_label.visible = true


func _on_talk_button_pressed() -> void:
	if _near_npc.is_empty():
		return
	Sfx.play_select()
	_talk_to(_near_npc)


# -------------------------------------------------------------- interaction ---

func _physics_process(delta: float) -> void:
	if _dialogue.is_open() or _cutscene_active or _video_active:
		_player.velocity = Vector3(0, -0.5, 0)
		_player.move_and_slide()
		return
	var input_vec := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	# Screen up is world -Z (north); the fixed camera never rotates, so
	# this mapping never changes.
	var dir := Vector3(input_vec.x, 0, input_vec.y)
	if _touch_active:
		var to_target: Vector3 = _touch_target - _player.global_position
		to_target.y = 0
		if to_target.length() > 0.6:
			dir = to_target.normalized()
		else:
			_touch_active = false
	if dir.length() > 1.0:
		dir = dir.normalized()
	var velocity := _player.velocity
	if _player.is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= 22.0 * delta
	velocity.x = dir.x * WALK_SPEED
	velocity.z = dir.z * WALK_SPEED
	_player.velocity = velocity
	_player.move_and_slide()
	if dir.length() > 0.1:
		var target_yaw := atan2(dir.x, dir.z)
		_player_model.rotation.y = lerp_angle(_player_model.rotation.y, target_yaw, 12.0 * delta)


func _process(delta: float) -> void:
	_anim_time += delta
	_animate_world()
	# Camera rig follows the player with light smoothing — but not
	# during a cutscene, when the camera is framed on the two speakers.
	if _player != null and _camera_rig != null and not _cutscene_active:
		var weight := 1.0 - exp(-6.0 * delta)
		_camera_rig.global_position = _camera_rig.global_position.lerp(_player.global_position, weight)
	if _dialogue.is_open() or _cutscene_active or _video_active:
		_prompt_label.visible = false
		_talk_button.visible = false
		return
	_near_npc = {}
	var best_dist := TALK_RANGE
	for npc in _npcs:
		var node: Node3D = npc["node"]
		var dist := _player.global_position.distance_to(node.global_position)
		if dist < best_dist:
			best_dist = dist
			_near_npc = npc
	if _near_npc.is_empty():
		_prompt_label.visible = false
		_talk_button.visible = false
	else:
		_show_prompt("Talk: %s  —  press Enter / A" % _near_npc["name"])
		_talk_button.text = "Talk: %s" % _near_npc["name"]
		_talk_button.visible = true
	# Boss approach: walking up to the Ember Wolf starts its movie
	# scene on its own — no tap needed. The flag resets when Kael
	# walks away, so the scene can trigger again.
	if not GameState.wolf_defeated:
		var wolf_npc := _npc_by_id("wolf")
		if not wolf_npc.is_empty():
			var wolf_node: Node3D = wolf_npc["node"]
			var wolf_dist := _player.global_position.distance_to(wolf_node.global_position)
			if wolf_dist < WOLF_APPROACH_DIST and not _wolf_approach_done:
				_wolf_approach_done = true
				_talk_to(wolf_npc)
			elif wolf_dist > WOLF_APPROACH_RESET_DIST:
				_wolf_approach_done = false


func _npc_by_id(id: String) -> Dictionary:
	for npc in _npcs:
		if npc["id"] == id:
			return npc
	return {}


## Torch flicker, pond shimmer, floating embers — the village stays
## alive even while the player stands still.
func _animate_world() -> void:
	var t := _anim_time
	for i in _torch_lights.size():
		var light: OmniLight3D = _torch_lights[i]
		if is_instance_valid(light):
			var phase := float(i) * 1.7
			light.light_energy = 0.9 + 0.22 * sin(t * 7.0 + phase) + 0.12 * sin(t * 13.0 + phase * 1.7)
	for i in _pond_glints.size():
		var glint: Node3D = _pond_glints[i]
		if is_instance_valid(glint):
			glint.position.y = 0.08 + 0.02 * sin(t * 1.5 + float(i) * 2.1)
	for mote in _ember_motes:
		var node: Node3D = mote["node"]
		if not is_instance_valid(node):
			continue
		var phase: float = mote["phase"]
		var speed: float = mote["speed"]
		var base: Vector3 = mote["base"]
		var rise := fmod(t * speed + phase * 2.2, 2.2)
		node.position = base + Vector3(sin(t * 0.7 + phase) * 0.3, rise, cos(t * 0.5 + phase) * 0.3)
		var s := 1.0 - rise / 2.6
		node.scale = Vector3.ONE * maxf(0.4, s)


func _input(event: InputEvent) -> void:
	# Built-in explore-by-touch: dragging a finger over the 3D world
	# reads it aloud; the HUD buttons read themselves. The dialogue box
	# handles its own explore while it is open, and the cutscene
	# handles its own input while a scene plays.
	if _dialogue.is_open() or _cutscene_active or _video_active:
		return
	var items: Array = []
	items.append({
		"key": "save", "label": "Save game.", "rect": _save_button.get_global_rect(),
	})
	items.append({
		"key": "title", "label": "Title screen.", "rect": _title_button.get_global_rect(),
	})
	if _talk_button.visible and not _near_npc.is_empty():
		items.append({
			"key": "talk", "label": "Talk to " + str(_near_npc.get("name", "someone")) + ".",
			"rect": _talk_button.get_global_rect(),
		})
	ExploreTouch.handle(event, items)
	if event is InputEventScreenDrag or event is InputEventScreenTouch or event is InputEventMouseMotion:
		if not _over_hud_button(_event_position(event)):
			# Exclude Kael's own body from the ray, so it can never
			# block a pick when he stands close to an NPC.
			ExploreTouch3D.handle(event, _camera, [_player.get_rid()])


func _event_position(event: InputEvent) -> Vector2:
	if event is InputEventScreenDrag:
		return (event as InputEventScreenDrag).position
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	if event is InputEventMouseMotion:
		return (event as InputEventMouseMotion).position
	return Vector2.INF


func _over_hud_button(pos: Vector2) -> bool:
	return _save_button.get_global_rect().has_point(pos) or _title_button.get_global_rect().has_point(pos)


func _notification(what: int) -> void:
	# Android system Back button: skip a movie first, exit a cutscene
	# next, then close the dialogue, otherwise back to the title —
	# never straight out of the game.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _video_active:
			_video.skip()
		elif _cutscene_active:
			_cutscene.finish_skip()
		elif _dialogue.is_open():
			_dialogue.dismiss()
		else:
			_on_title_pressed()


func _unhandled_input(event: InputEvent) -> void:
	if _dialogue.is_open() or _cutscene_active or _video_active:
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
		if touch.pressed:
			_tap_press_pos = touch.position
			_tap_moved = false
			_tap_press_npc_id = ""
			# Judge the tap by what was under the finger WHEN IT WENT
			# DOWN, not when it lifts. v1.1.0 judged it at the release
			# position — but pressing on anything started tap-to-move,
			# so Kael walked and the camera followed before the finger
			# lifted, and the release ray no longer pointed at the
			# character. That is why tapping a character did nothing
			# while dragging across it still spoke its name.
			_tap_press_pick = ExploreTouch3D.pick(touch.position, _camera, [_player.get_rid()])
			if not _tap_press_pick.is_empty():
				var node: Node = _tap_press_pick.get("node")
				if node != null:
					_tap_press_npc_id = str(node.get_meta("npc_id", ""))
				# A press on a character must NOT start tap-to-move:
				# the walking is exactly what shifted the camera and
				# broke the tap.
				if _tap_press_npc_id == "":
					_touch_active = true
					_touch_target = _tap_press_pick.get("position", Vector3.ZERO)
		else:
			_touch_active = false
			# A quick tap (finger barely moved) activates what was
			# under it at press time; a drag only moves. This is what
			# makes explore-by-touch possible: dragging across an NPC
			# reads its name without talking to it, and only a
			# deliberate tap starts the talk.
			if not _tap_moved and touch.position.distance_to(_tap_press_pos) < TAP_TOLERANCE:
				if _tap_press_npc_id != "":
					for npc in _npcs:
						if npc["id"] == _tap_press_npc_id:
							_talk_to(npc)
							return
				elif not _tap_press_pick.is_empty():
					_touch_active = true
					_touch_target = _tap_press_pick.get("position", Vector3.ZERO)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		# A drag that started on a character is exploration only —
		# never walk the player while the finger explores an NPC.
		if _tap_press_npc_id == "":
			var hit := ExploreTouch3D.pick(drag.position, _camera, [_player.get_rid()])
			if not hit.is_empty():
				_touch_active = true
				_touch_target = hit["position"]
		if drag.position.distance_to(_tap_press_pos) > TAP_TOLERANCE:
			_tap_moved = true


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
	# Remember which NPC we are talking to for the finish handler.
	_near_npc = npc
	if npc["enemy"] != "" and not _npc_already_met(npc["id"]):
		_pending_battle = npc["enemy"]
	# Movie first: a short silent establishing shot (the clip's first
	# few seconds). The talk itself happens in the close-up dialogue
	# scene that follows — real voices, moving mouths. NPCs without
	# a video go straight to the dialogue scene.
	var video_path: String = VIDEO_SCENES.get(npc["id"], "")
	if video_path != "":
		_video_npc = npc
		_video_active = true
		_video.play(video_path, ESTABLISH_SECONDS)
	else:
		_start_cutscene(npc)


func _show_lines(speaker: String, lines: Array) -> void:
	# Only the opening narration still uses the text box; NPC talks
	# cut to a cinematic scene (see _start_cutscene).
	_dialogue.show_lines(speaker, lines)


func _on_dialogue_finished() -> void:
	# The opening narration uses the text box; NPC talks use cutscenes.
	_finish_talk()


## Lines for a talk, as the dialogue scene consumes them. Each
## entry carries the voice-file key for that line. The wolf's line
## is Kael speaking, so it is labeled Kael and uses his voice.
func _cutscene_lines(npc: Dictionary) -> Array:
	var lines: Array = []
	var raw: Array = _npc_lines(npc)
	var voice_id: String = "kael" if npc["id"] == "wolf" else npc["id"]
	var speaker_name: String = "Kael" if npc["id"] == "wolf" else npc["name"]
	# Repeat lines are voiced after the first-talk lines (maren_04,
	# lyra_04, kael_02), so the file key must skip past them.
	var offset := 0
	if _npc_already_met(npc["id"]):
		offset = (npc["first_lines"] as Array).size()
	for i in raw.size():
		lines.append({
			"speaker": speaker_name,
			"text": raw[i],
			"voice": "%s_%02d" % [voice_id, offset + i + 1],
		})
	return lines


## The 3D model whose mouth moves while this NPC's lines play: the
## NPC's own model, except the wolf's talk, where Kael is the one
## speaking (the wolf has no mouth to move).
func _talk_speaker_node(npc: Dictionary) -> Node3D:
	if npc["id"] == "wolf":
		return _player_model
	return npc["node"]


## Cinematic scene: the camera sweeps in close on the speaker —
## framed from the front-side so their face and moving mouth are
## visible — and the cutscene UI plays their lines in their own
## recorded voice. The listener stands behind the speaker, in shot.
func _start_cutscene(npc: Dictionary) -> void:
	_cutscene_active = true
	var player_pos: Vector3 = _player.global_position
	var npc_node: Node3D = npc["node"]
	var npc_pos: Vector3 = npc_node.global_position
	# Face each other (humanoids are built facing +Z).
	_player_model.rotation.y = atan2(npc_pos.x - player_pos.x, npc_pos.z - player_pos.z)
	npc_node.rotation.y = atan2(player_pos.x - npc_pos.x, player_pos.z - npc_pos.z)
	# Frame the speaker: the camera sits on the side the speaker
	# faces (toward the listener), offset to one side so the shot is
	# a three-quarter view of their face, not a flat profile. A
	# straight side shot hides the mouth entirely.
	var speaker_node := _talk_speaker_node(npc)
	var speaker_pos: Vector3 = speaker_node.global_position
	var listener_pos: Vector3 = npc_pos if npc["id"] == "wolf" else player_pos
	var facing := listener_pos - speaker_pos
	facing.y = 0
	if facing.length() < 0.5:
		facing = Vector3(0, 0, 1)
	facing = facing.normalized()
	var side := facing.cross(Vector3.UP).normalized()
	var cam_pos := speaker_pos + facing * 3.2 + side * 2.4 + Vector3(0, 1.7, 0)
	var look_target := speaker_pos + Vector3(0, 1.5, 0)
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	# During the shot the camera rides the rig at local (0,0,0), so
	# the rig itself carries the whole transform.
	_camera.position = Vector3.ZERO
	_camera.rotation = Vector3.ZERO
	_camera_tween = create_tween()
	_camera_tween.set_parallel(true)
	_camera_tween.tween_property(_camera_rig, "global_position", cam_pos, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var look := Transform3D(Basis(), cam_pos).looking_at(look_target, Vector3.UP)
	_camera_tween.tween_property(_camera_rig, "quaternion", look.basis.get_rotation_quaternion(), 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Build the lines for the cutscene UI, voiced by the speaker.
	_cutscene.play(_cutscene_lines(npc), speaker_node)


## Return the camera to the normal following view after a scene.
func _end_cutscene() -> void:
	_cutscene_active = false
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	_camera_tween = create_tween()
	_camera_tween.set_parallel(true)
	_camera_tween.tween_property(_camera, "position", Vector3(0, 10, 14), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_camera_tween.tween_property(_camera, "rotation", Vector3(-0.62, 0, 0), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_camera_tween.tween_property(_camera_rig, "quaternion", Quaternion.IDENTITY, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_cutscene_finished() -> void:
	_end_cutscene()
	_finish_talk()


func _on_cutscene_skipped() -> void:
	# Skipping exits the conversation without its effects: Lyra does
	# not join, the wolf does not attack. The player can talk again.
	_pending_battle = ""
	_end_cutscene()


## The establishing shot is over (ran its seconds, or the clip
## ended): cut to the close-up, where the talk happens — real
## voices, moving mouths. Skipping the shot does the same thing.
func _on_video_finished() -> void:
	_video_active = false
	_start_cutscene(_video_npc)


## The shot was skipped: go straight to the close-up talk, so the
## talk is never lost. Only skipping the dialogue itself cancels
## the conversation.
func _on_video_skipped() -> void:
	_video_active = false
	_start_cutscene(_video_npc)


func _finish_talk() -> void:
	# Mark party members as met; trigger battle for monsters.
	if _near_npc.is_empty():
		_update_objective()
		return
	match _near_npc["id"]:
		"maren":
			_met_maren = true
		"lyra":
			if not GameState.met_lyra:
				GameState.met_lyra = true
				Narration.speak("Lyra Voss joined the party!")
	if _pending_battle != "":
		var enemy := _pending_battle
		_pending_battle = ""
		GameState.battle_enemy = enemy
		GameState.spawn_pos_3d = _player.position
		GameState.save_game()
		get_tree().change_scene_to_file("res://scenes/battle_3d.tscn")
		return
	_update_objective()
