extends Node
## GameState autoload — party stats, flags, XP/level, JSON save/load.
## Original characters only: Kael Arden, Lyra Voss, Mira Solenne, Dax Rook.
## Villain (story only in v1): Lord Varik Kane.

const SAVE_PATH := "user://vaeloria_save.json"
const XP_PER_LEVEL := 50

var player_name := "Kael"
var level := 1
var xp := 0
var hp := 50
var max_hp := 50
var mp := 20
var max_mp := 20
var attack := 10
var gold := 0

# Story flags.
var met_lyra := false
var met_mira := false
var met_dax := false
var wolf_defeated := false
var slime_defeated := false
var intro_done := false

# Which enemy the battle scene should spawn ("wolf" or "slime").
var battle_enemy := "wolf"
# Where the player spawns in the 2D village (v1.0.x, kept for the old
# scenes, which stay in the repo unused).
var spawn_pos := Vector2(640, 500)
# Where the player spawns in the 3D village (v1.1.0+). The 3D world is
# ~48 x 36 units; the default spawn is the south road, facing the shrine.
var spawn_pos_3d := Vector3(0, 0, 12)


func xp_needed() -> int:
	return XP_PER_LEVEL * level


func reset_new_game() -> void:
	level = 1
	xp = 0
	hp = 50
	max_hp = 50
	mp = 20
	max_mp = 20
	attack = 10
	gold = 0
	met_lyra = false
	met_mira = false
	met_dax = false
	wolf_defeated = false
	slime_defeated = false
	intro_done = false
	battle_enemy = "wolf"
	spawn_pos = Vector2(640, 500)
	spawn_pos_3d = Vector3(0, 0, 12)


## Adds XP. Returns true if Kael levelled up (may level more than once).
func gain_xp(amount: int) -> bool:
	xp += amount
	var levelled := false
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		max_hp += 10
		max_mp += 4
		attack += 2
		hp = max_hp
		mp = max_mp
		levelled = true
	return levelled


func heal_full() -> void:
	hp = max_hp
	mp = max_mp


func save_game() -> bool:
	var data := {
		"level": level,
		"xp": xp,
		"hp": hp,
		"max_hp": max_hp,
		"mp": mp,
		"max_mp": max_mp,
		"attack": attack,
		"gold": gold,
		"met_lyra": met_lyra,
		"met_mira": met_mira,
		"met_dax": met_dax,
		"wolf_defeated": wolf_defeated,
		"slime_defeated": slime_defeated,
		"intro_done": intro_done,
		"spawn_x": spawn_pos.x,
		"spawn_y": spawn_pos.y,
		"spawn3d_x": spawn_pos_3d.x,
		"spawn3d_y": spawn_pos_3d.y,
		"spawn3d_z": spawn_pos_3d.z,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_game() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	level = int(parsed.get("level", 1))
	xp = int(parsed.get("xp", 0))
	hp = int(parsed.get("hp", 50))
	max_hp = int(parsed.get("max_hp", 50))
	mp = int(parsed.get("mp", 20))
	max_mp = int(parsed.get("max_mp", 20))
	attack = int(parsed.get("attack", 10))
	gold = int(parsed.get("gold", 0))
	met_lyra = bool(parsed.get("met_lyra", false))
	met_mira = bool(parsed.get("met_mira", false))
	met_dax = bool(parsed.get("met_dax", false))
	wolf_defeated = bool(parsed.get("wolf_defeated", false))
	slime_defeated = bool(parsed.get("slime_defeated", false))
	intro_done = bool(parsed.get("intro_done", false))
	spawn_pos = Vector2(float(parsed.get("spawn_x", 640)), float(parsed.get("spawn_y", 500)))
	# Old 2D saves have no 3D spawn: start at the 3D village spawn.
	# (2D saves from v1.0.x do not carry over to the 3D version.)
	if parsed.has("spawn3d_x"):
		spawn_pos_3d = Vector3(float(parsed.get("spawn3d_x", 0)), float(parsed.get("spawn3d_y", 0)), float(parsed.get("spawn3d_z", 12)))
	else:
		spawn_pos_3d = Vector3(0, 0, 12)
	hp = clampi(hp, 1, max_hp)
	mp = clampi(mp, 0, max_mp)
	return true
