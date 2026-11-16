class_name MeshFactory
extends RefCounted
## Stylized low-poly 3D art for Vaeloria, built from Godot primitives
## (boxes, capsules, spheres, cones, cylinders) with flat
## StandardMaterial3D colors. Gold-and-black palette, no textures —
## cheap enough for a tablet and an old Fire TV Stick (API 28).
## Every builder returns a Node3D. Colliders are StaticBody3D children
## carrying "explore_key" / "explore_label" metadata for ExploreTouch3D,
## and NPC bodies also carry "npc_id".

const GOLD := Color(0.91, 0.72, 0.29)
const BLACK := Color(0.08, 0.08, 0.12)

static var _materials := {}


static func mat(color: Color, emission: Color = Color(0, 0, 0), emission_energy: float = 0.0) -> StandardMaterial3D:
	var key := str(color) + "|" + str(emission) + "|" + str(emission_energy)
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	if emission_energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = emission_energy
	_materials[key] = m
	return m


# ------------------------------------------------------------ primitives ---

static func _box(size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	return node


static func _sphere(radius: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	return node


static func _cylinder(top_radius: float, bottom_radius: float, height: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 16
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	return node


static func _cone(radius: float, height: float, pos: Vector3, material: Material) -> MeshInstance3D:
	return _cylinder(0.0, radius, height, pos, material)


static func _name_label(text: String, pos: Vector3) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 24
	label.pixel_size = 0.01
	label.modulate = Color(1, 1, 1)
	label.outline_size = 8
	label.outline_modulate = Color(0, 0, 0)
	return label


static func _solid_box(root: Node3D, size: Vector3, pos: Vector3, key: String, label: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = pos
	body.add_child(shape)
	body.set_meta("explore_key", key)
	body.set_meta("explore_label", label)
	root.add_child(body)
	return body


## Collider for a person / creature: a capsule the raycast can hit.
## Carries the explore label and the npc_id the village uses for talk.
static func add_npc_body(root: Node3D, key: String, label: String, npc_id: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.55
	capsule.height = 2.0
	shape.shape = capsule
	shape.position = Vector3(0, 1.0, 0)
	body.add_child(shape)
	body.set_meta("explore_key", key)
	body.set_meta("explore_label", label)
	body.set_meta("npc_id", npc_id)
	root.add_child(body)
	return body


# ------------------------------------------------------------- characters ---

## Humanoid, built facing +Z (south, toward the camera).
## spec keys: tunic, skin, hair, pants (Colors), robe, sword, staff (bools),
## name (String, adds a floating name label).
static func make_humanoid(spec: Dictionary) -> Node3D:
	var root := Node3D.new()
	var tunic: Color = spec.get("tunic", Color(0.15, 0.2, 0.45))
	var skin: Color = spec.get("skin", Color(0.9, 0.75, 0.6))
	var hair: Color = spec.get("hair", Color(0.25, 0.15, 0.08))
	var pants: Color = spec.get("pants", Color(0.1, 0.1, 0.15))
	var robe: bool = spec.get("robe", false)
	if robe:
		root.add_child(_cylinder(0.32, 0.5, 1.15, Vector3(0, 0.575, 0), mat(tunic)))
		root.add_child(_cylinder(0.34, 0.36, 0.12, Vector3(0, 1.12, 0), mat(GOLD)))
	else:
		root.add_child(_box(Vector3(0.24, 0.7, 0.24), Vector3(-0.15, 0.35, 0), mat(pants)))
		root.add_child(_box(Vector3(0.24, 0.7, 0.24), Vector3(0.15, 0.35, 0), mat(pants)))
		root.add_child(_box(Vector3(0.72, 0.8, 0.42), Vector3(0, 1.1, 0), mat(tunic)))
		root.add_child(_box(Vector3(0.74, 0.12, 0.44), Vector3(0, 0.78, 0), mat(GOLD)))
	# Arms.
	root.add_child(_box(Vector3(0.18, 0.62, 0.18), Vector3(-0.46, 1.12, 0), mat(tunic)))
	root.add_child(_box(Vector3(0.18, 0.62, 0.18), Vector3(0.46, 1.12, 0), mat(tunic)))
	# Head + hair.
	root.add_child(_sphere(0.32, Vector3(0, 1.78, 0), mat(skin)))
	var hair_mesh := _sphere(0.34, Vector3(0, 1.86, -0.04), mat(hair))
	hair_mesh.scale = Vector3(1, 0.75, 1)
	root.add_child(hair_mesh)
	if bool(spec.get("sword", false)):
		var blade := _box(Vector3(0.07, 1.05, 0.18), Vector3(0.56, 1.35, 0.12), mat(Color(0.85, 0.85, 0.9)))
		blade.rotation = Vector3(0.25, 0, -0.15)
		root.add_child(blade)
		root.add_child(_box(Vector3(0.22, 0.08, 0.08), Vector3(0.55, 0.85, 0.1), mat(GOLD)))
	if bool(spec.get("staff", false)):
		root.add_child(_cylinder(0.05, 0.05, 1.7, Vector3(0.56, 1.25, 0.1), mat(Color(0.4, 0.25, 0.12))))
		root.add_child(_sphere(0.16, Vector3(0.56, 2.15, 0.1), mat(Color(1, 0.5, 0.15), Color(1, 0.45, 0.1), 2.0)))
	var label_text: String = spec.get("name", "")
	if label_text != "":
		root.add_child(_name_label(label_text, Vector3(0, 2.45, 0)))
	return root


## Ember Wolf, built facing +Z. Body runs along Z, head at +Z.
static func make_wolf() -> Node3D:
	var root := Node3D.new()
	var fur := mat(Color(0.2, 0.2, 0.24))
	var ember := mat(Color(1, 0.45, 0.1), Color(1, 0.45, 0.1), 1.6)
	# Body and head.
	root.add_child(_box(Vector3(0.65, 0.7, 1.7), Vector3(0, 0.8, 0), fur))
	root.add_child(_box(Vector3(0.55, 0.55, 0.62), Vector3(0, 1.05, 1.0), fur))
	root.add_child(_box(Vector3(0.32, 0.26, 0.38), Vector3(0, 0.92, 1.45), fur))
	# Ears.
	root.add_child(_cone(0.16, 0.34, Vector3(0.2, 1.45, 0.9), fur))
	root.add_child(_cone(0.16, 0.34, Vector3(-0.2, 1.45, 0.9), fur))
	# Legs.
	for leg in [
		Vector3(0.22, 0.35, 0.6), Vector3(-0.22, 0.35, 0.6),
		Vector3(0.22, 0.35, -0.6), Vector3(-0.22, 0.35, -0.6),
	]:
		root.add_child(_box(Vector3(0.2, 0.7, 0.2), leg, fur))
	# Tail, angled up.
	var tail := _box(Vector3(0.16, 0.16, 0.55), Vector3(0, 1.05, -1.05), fur)
	tail.rotation = Vector3(0.5, 0, 0)
	root.add_child(tail)
	# Ember mane along the back and glowing eyes.
	root.add_child(_box(Vector3(0.4, 0.22, 1.0), Vector3(0, 1.2, -0.1), ember))
	root.add_child(_sphere(0.07, Vector3(0.2, 1.12, 1.28), ember))
	root.add_child(_sphere(0.07, Vector3(-0.2, 1.12, 1.28), ember))
	root.add_child(_name_label("Ember Wolf", Vector3(0, 2.0, 0)))
	return root


# --------------------------------------------------------------- buildings ---

## House, front (+Z) has the door and lit windows. Roof is a box turned
## ~40 degrees; its lower half hides inside the walls, so only the
## pitched top shows. Gold trim band along the top of the walls.
static func make_house(wall_color: Color, key: String, label: String) -> Node3D:
	var root := Node3D.new()
	root.add_child(_box(Vector3(4.0, 2.4, 3.5), Vector3(0, 1.2, 0), mat(wall_color)))
	root.add_child(_box(Vector3(4.1, 0.16, 3.6), Vector3(0, 2.38, 0), mat(GOLD)))
	var roof := _box(Vector3(4.4, 1.2, 4.0), Vector3(0, 2.5, 0), mat(BLACK))
	roof.rotation = Vector3(0, 0, 0.7)
	root.add_child(roof)
	# Door and lit windows on the front face.
	root.add_child(_box(Vector3(0.9, 1.6, 0.12), Vector3(0, 0.8, 1.78), mat(Color(0.3, 0.2, 0.1))))
	root.add_child(_box(Vector3(0.6, 0.6, 0.1), Vector3(1.3, 1.4, 1.78), mat(Color(1, 0.8, 0.3), Color(1, 0.8, 0.3), 1.2)))
	root.add_child(_box(Vector3(0.6, 0.6, 0.1), Vector3(-1.3, 1.4, 1.78), mat(Color(1, 0.8, 0.3), Color(1, 0.8, 0.3), 1.2)))
	# Chimney poking through the roof.
	root.add_child(_box(Vector3(0.5, 1.1, 0.5), Vector3(1.2, 3.4, -0.8), mat(Color(0.55, 0.55, 0.58))))
	_solid_box(root, Vector3(4.0, 2.4, 3.5), Vector3(0, 1.2, 0), key, label)
	return root


static func make_tree(key: String, label: String) -> Node3D:
	var root := Node3D.new()
	root.add_child(_cylinder(0.22, 0.3, 1.2, Vector3(0, 0.6, 0), mat(Color(0.4, 0.25, 0.12))))
	root.add_child(_cone(1.1, 1.8, Vector3(0, 2.0, 0), mat(Color(0.15, 0.45, 0.2))))
	root.add_child(_cone(0.8, 1.2, Vector3(0, 3.0, 0), mat(Color(0.2, 0.55, 0.25))))
	_solid_box(root, Vector3(0.6, 1.4, 0.6), Vector3(0, 0.7, 0), key, label)
	return root


## Emberstone shrine: stone pedestal, gold band, a glowing gold crystal
## (two cones base to base) and a warm point light.
static func make_shrine() -> Node3D:
	var root := Node3D.new()
	var stone := mat(Color(0.7, 0.7, 0.72))
	root.add_child(_box(Vector3(2.4, 0.4, 2.4), Vector3(0, 0.2, 0), stone))
	root.add_child(_box(Vector3(1.7, 0.4, 1.7), Vector3(0, 0.6, 0), stone))
	root.add_child(_box(Vector3(1.8, 0.14, 1.8), Vector3(0, 0.85, 0), mat(GOLD)))
	var crystal_mat := mat(Color(1, 0.75, 0.25), Color(1, 0.7, 0.2), 2.5)
	root.add_child(_cone(0.5, 1.1, Vector3(0, 2.15, 0), crystal_mat))
	var bottom := _cone(0.5, 0.9, Vector3(0, 1.15, 0), crystal_mat)
	bottom.rotation = Vector3(PI, 0, 0)
	root.add_child(bottom)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 2.6, 0)
	light.light_color = Color(1, 0.8, 0.35)
	light.light_energy = 1.6
	light.omni_range = 9.0
	root.add_child(light)
	_solid_box(root, Vector3(2.4, 1.0, 2.4), Vector3(0, 0.5, 0), "shrine",
		"Emberstone Shrine. A glowing gold crystal hums with old magic.")
	return root


## Pond: a shallow blue disc. No collider (the ground below handles it).
static func make_pond(radius: float) -> Node3D:
	var root := Node3D.new()
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.15, 0.4, 0.7, 0.9)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.14
	mesh.radial_segments = 24
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = Vector3(0, 0.07, 0)
	node.material_override = water
	root.add_child(node)
	return root


## Fence run of the given length along X, with rails, posts and a solid.
static func make_fence(length: float) -> Node3D:
	var root := Node3D.new()
	var wood := mat(Color(0.45, 0.3, 0.15))
	root.add_child(_box(Vector3(length, 0.14, 0.12), Vector3(0, 0.75, 0), wood))
	root.add_child(_box(Vector3(length, 0.14, 0.12), Vector3(0, 0.45, 0), wood))
	var count := int(length / 2.0) + 1
	for i in range(count):
		var x := -length / 2.0 + float(i) * 2.0
		root.add_child(_box(Vector3(0.16, 0.95, 0.16), Vector3(x, 0.475, 0), wood))
	_solid_box(root, Vector3(length, 1.0, 0.3), Vector3(0, 0.5, 0), "fence", "A wooden fence.")
	return root


## East gate: two posts with a gold beam across the top.
static func make_gate() -> Node3D:
	var root := Node3D.new()
	var wood := mat(Color(0.45, 0.3, 0.15))
	root.add_child(_box(Vector3(0.5, 4.2, 0.5), Vector3(0, 2.1, -2.0), wood))
	root.add_child(_box(Vector3(0.5, 4.2, 0.5), Vector3(0, 2.1, 2.0), wood))
	root.add_child(_box(Vector3(0.6, 0.5, 5.2), Vector3(0, 4.1, 0), mat(GOLD)))
	root.add_child(_box(Vector3(0.7, 0.35, 4.6), Vector3(0, 3.6, 0), mat(BLACK)))
	_solid_box(root, Vector3(0.6, 4.2, 0.6), Vector3(0, 2.1, -2.0), "gate", "The east gate of Aldermere.")
	_solid_box(root, Vector3(0.6, 4.2, 0.6), Vector3(0, 2.1, 2.0), "gate", "The east gate of Aldermere.")
	return root


## Torch post with a glowing ember and a warm point light.
static func make_torch() -> Node3D:
	var root := Node3D.new()
	root.add_child(_cylinder(0.09, 0.12, 1.6, Vector3(0, 0.8, 0), mat(Color(0.35, 0.22, 0.1))))
	root.add_child(_sphere(0.22, Vector3(0, 1.75, 0), mat(Color(1, 0.55, 0.15), Color(1, 0.5, 0.1), 2.0)))
	var light := OmniLight3D.new()
	light.position = Vector3(0, 1.9, 0)
	light.light_color = Color(1, 0.6, 0.2)
	light.light_energy = 0.9
	light.omni_range = 7.0
	root.add_child(light)
	return root


## Village ground: grass slab with a raycast body, plus invisible bounds.
static func make_ground(size: Vector2) -> Node3D:
	var root := Node3D.new()
	root.add_child(_box(Vector3(size.x, 0.5, size.y), Vector3(0, -0.25, 0), mat(Color(0.25, 0.5, 0.25))))
	_solid_box(root, Vector3(size.x, 0.5, size.y), Vector3(0, -0.25, 0), "ground",
		"Village ground. Soft grass underfoot.")
	# Invisible walls around the map edge.
	for wall in [
		[Vector3(size.x + 2.0, 4.0, 1.0), Vector3(0, 1.0, size.y / 2.0 + 0.5)],
		[Vector3(size.x + 2.0, 4.0, 1.0), Vector3(0, 1.0, -size.y / 2.0 - 0.5)],
		[Vector3(1.0, 4.0, size.y + 2.0), Vector3(size.x / 2.0 + 0.5, 1.0, 0)],
		[Vector3(1.0, 4.0, size.y + 2.0), Vector3(-size.x / 2.0 - 0.5, 1.0, 0)],
	]:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = wall[0]
		shape.shape = box
		shape.position = wall[1]
		body.add_child(shape)
		root.add_child(body)
	return root


# ------------------------------------------------------------ light & sky ---

static func make_environment() -> WorldEnvironment:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.25, 0.45, 0.75)
	sky_mat.sky_horizon_color = Color(0.85, 0.75, 0.55)
	sky_mat.ground_bottom_color = Color(0.15, 0.2, 0.15)
	sky_mat.ground_horizon_color = Color(0.7, 0.65, 0.5)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.75, 0.7, 0.6)
	env.fog_density = 0.012
	var we := WorldEnvironment.new()
	we.environment = env
	return we


static func make_sun() -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, -0.5, 0.0)
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	return sun
