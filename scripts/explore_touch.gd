class_name ExploreTouch
extends RefCounted
## Built-in explore-by-touch: drag a finger across the screen and the game
## reads aloud whatever is under it, using the game's own narration — no
## device accessibility service needed. Scenes call handle() from _input()
## with the items currently on screen. Speech only fires when the hovered
## item CHANGES, so dragging across one button speaks it once, and lifting
## the finger on a button still activates it normally.

static var _last_key: String = ""


static func reset() -> void:
	_last_key = ""


static func handle(event: InputEvent, items: Array) -> void:
	var pos := Vector2.INF
	if event is InputEventScreenDrag:
		pos = (event as InputEventScreenDrag).position
	elif event is InputEventScreenTouch:
		pos = (event as InputEventScreenTouch).position
	elif event is InputEventMouseMotion:
		pos = (event as InputEventMouseMotion).position
	else:
		return
	var key := ""
	var label := ""
	for item in items:
		var rect: Rect2 = item.get("rect", Rect2())
		if rect.has_point(pos):
			key = str(item.get("key", ""))
			label = str(item.get("label", ""))
			break
	if key != "" and key != _last_key:
		_last_key = key
		Narration.stop()
		Narration.speak(label)
	elif key == "":
		_last_key = ""
