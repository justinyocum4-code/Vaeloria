class_name ExploreTouch3D
extends RefCounted
## Built-in explore-by-touch for the 3D scenes: drag a finger across the
## screen and the game raycasts from the camera into the world and reads
## aloud the label of whatever is under it, using the game's own
## narration — no device accessibility service needed. Speaks only when
## the hovered object CHANGES, like the 2D ExploreTouch helper.
## Objects carry their labels in the "explore_key" / "explore_label"
## metadata of their StaticBody3D colliders (see MeshFactory).

static var _last_key: String = ""


static func reset() -> void:
	_last_key = ""


## Raycasts from the camera through a screen position. Returns a
## dictionary with "key", "label", "position" and "node" (the collider),
## or an empty dictionary when nothing was hit. A hit with no explore
## metadata still returns its position and node with an empty key.
## exclude_rids: bodies the ray must ignore — the village passes the
## player's own CharacterBody3D RID, so the ray can never be blocked
## by Kael himself when he stands close to an NPC.
static func pick(screen_pos: Vector2, camera: Camera3D, exclude_rids: Array = []) -> Dictionary:
	if camera == null:
		return {}
	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 100.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = exclude_rids
	var space := camera.get_world_3d().direct_space_state
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return {}
	var node: Node = hit.get("collider") as Node
	if node == null:
		return {}
	return {
		"key": str(node.get_meta("explore_key", "")),
		"label": str(node.get_meta("explore_label", "")),
		"position": hit.get("position", Vector3.ZERO),
		"node": node,
	}


## Handles a drag / touch / mouse-motion event: speaks the label under
## the finger when it changes. Returns the key under the finger ("" if
## none), so tests and tap logic can tell what was hit.
static func handle(event: InputEvent, camera: Camera3D, exclude_rids: Array = []) -> String:
	var pos := Vector2.INF
	if event is InputEventScreenDrag:
		pos = (event as InputEventScreenDrag).position
	elif event is InputEventScreenTouch:
		pos = (event as InputEventScreenTouch).position
	elif event is InputEventMouseMotion:
		pos = (event as InputEventMouseMotion).position
	else:
		return _last_key
	var result := pick(pos, camera, exclude_rids)
	var key: String = result.get("key", "")
	var label: String = result.get("label", "")
	if key != "" and key != _last_key:
		_last_key = key
		Narration.stop()
		Narration.speak(label)
	elif key == "":
		_last_key = ""
	return key
