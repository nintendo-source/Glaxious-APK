# CityBuilder.gd - builds the whole map from code: 160x160 neon city, perimeter walls, skyline,
# central plaza, server hall + 95 m server tower, sealed core chamber, spawn pad, lamps, cars.
# Layout: road lines every 32 m at x/z = +-16, +-48, +-80. Central plaza is |x|,|z| < 43.
class_name CityBuilder
extends RefCounted

const PACK_POINTS = [Vector2(-48, 48), Vector2(-16, 80), Vector2(48, 48), Vector2(80, 16),
	Vector2(48, -48), Vector2(16, -80), Vector2(-48, -48), Vector2(-80, -16)]
const SPAWN := Vector3(-60.0, 1.0, 60.0)
const NEON = [Color(1.0, 0.1, 0.6), Color(0.1, 0.9, 1.0), Color(1.0, 0.7, 0.1), Color(0.5, 1.0, 0.3)]
const SIGNS = ["NEO MART", "DATA BAR", "SYNTH CAFE", "CYBER DOC", "GLAX CORP", "NOODLE 24", "ARCADE", "HOLO NET"]

var rng := RandomNumberGenerator.new()
var root: Node3D
var door: Node3D
var core_pos := Vector3.ZERO
var _bm: Array = []
var _dark: StandardMaterial3D
var _red: StandardMaterial3D
var _hall: ShaderMaterial
var _cyan: StandardMaterial3D
var _mag: StandardMaterial3D


func build(parent: Node3D) -> void:
	root = parent
	rng.seed = 1337
	_bm = [
		Shaders.building(Color(0.04, 0.05, 0.09), Color(0.3, 0.8, 1.0), Color(1.0, 0.4, 0.8), Vector2(2.4, 3.4), 0.5, 0.0),
		Shaders.building(Color(0.07, 0.05, 0.06), Color(1.0, 0.7, 0.25), Color(0.3, 0.9, 1.0), Vector2(2.8, 3.6), 0.45, 0.0),
		Shaders.building(Color(0.05, 0.04, 0.09), Color(1.0, 0.3, 0.8), Color(0.3, 0.9, 1.0), Vector2(2.2, 3.2), 0.55, 0.0),
		Shaders.building(Color(0.04, 0.07, 0.07), Color(0.4, 1.0, 0.6), Color(1.0, 0.7, 0.25), Vector2(2.6, 3.4), 0.4, 0.0)]
	_hall = Shaders.building(Color(0.06, 0.07, 0.1), Color(0.3, 0.8, 1.0), Color(1.0, 0.3, 0.7), Vector2(4.0, 3.0), 0.18, 0.0)
	_dark = Gfx.mat(Color(0.05, 0.05, 0.07), 0.6, 0.5)
	_red = Gfx.glow(Color(1.0, 0.1, 0.1), 4.0)
	_cyan = Gfx.glow(Color(0.2, 0.9, 1.0), 3.0)
	_mag = Gfx.glow(Color(1.0, 0.2, 0.7), 3.0)
	_ground()
	_walls()
	_skyline()
	_blocks()
	_plaza()
	_complex()
	_spawn_area()
	_lamps()
	_cars()


# ------------------------------------------------------------------ helpers ----
func _trim() -> Vector3:
	var c: Color = NEON[rng.randi() % NEON.size()]
	return Vector3(c.r, c.g, c.b)


func _detail(mi: MeshInstance3D) -> MeshInstance3D:
	mi.visibility_range_end = 120.0
	return mi


func _solid(parent: Node, pos: Vector3, size: Vector3, mat: Material, top_y: float = -1.0) -> MeshInstance3D:
	var body := StaticBody3D.new()
	body.position = pos
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	var mi := Gfx.add(body, Gfx.box(size), mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if top_y >= 0.0:
		mi.set_instance_shader_parameter("top_y", top_y)
		mi.set_instance_shader_parameter("trim_color", _trim())
	parent.add_child(body)
	return mi


func _spinner(parent: Node3D, pos: Vector3, axis: Vector3, speed: float) -> Spinner:
	var s := Spinner.new()
	s.axis = axis
	s.speed = speed
	s.position = pos
	parent.add_child(s)
	return s


func _sign(text: String, pos: Vector3, yaw_deg: float, col: Color, px: float = 0.02) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 96
	l.pixel_size = px
	l.modulate = col
	l.outline_size = 12
	l.outline_modulate = Color(0, 0, 0, 1)
	l.shaded = false
	l.double_sided = true
	l.position = pos
	l.rotation_degrees = Vector3(0, yaw_deg, 0)
	root.add_child(l)


# ------------------------------------------------------------ ground / walls ----
func _ground() -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(500, 2, 500)
	cs.shape = bs
	cs.position = Vector3(0, -1, 0)
	body.add_child(cs)
	var plane := PlaneMesh.new()
	plane.size = Vector2(500, 500)
	var mi := Gfx.add(body, plane, Shaders.ground())
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(body)


func _walls() -> void:
	var h := 16.0
	var half := 88.0
	_solid(root, Vector3(0, h * 0.5, -half), Vector3(half * 2.0 + 6.0, h, 3), _hall, h)
	_solid(root, Vector3(0, h * 0.5, half), Vector3(half * 2.0 + 6.0, h, 3), _hall, h)
	_solid(root, Vector3(-half, h * 0.5, 0), Vector3(3, h, half * 2.0 + 6.0), _hall, h)
	_solid(root, Vector3(half, h * 0.5, 0), Vector3(3, h, half * 2.0 + 6.0), _hall, h)


func _skyline() -> void:
	for i in 56:
		var a: float = TAU * i / 56.0 + rng.randf_range(-0.03, 0.03)
		var r: float = rng.randf_range(115.0, 190.0)
		var h: float = rng.randf_range(50.0, 170.0)
		var w: float = rng.randf_range(14.0, 30.0)
		var mi := Gfx.add(root, Gfx.box(Vector3(w, h, w)), _bm[rng.randi() % _bm.size()], Vector3(cos(a) * r, h * 0.5, sin(a) * r))
		mi.set_instance_shader_parameter("top_y", h)
		mi.set_instance_shader_parameter("trim_color", _trim())


# -------------------------------------------------------------------- blocks ----
func _blocks() -> void:
	var centers := [-64.0, -32.0, 0.0, 32.0, 64.0]
	for cx in centers:
		for cz in centers:
			if absf(cx) <= 32.0 and absf(cz) <= 32.0:
				continue   # central plaza
			if is_equal_approx(cx, -64.0) and is_equal_approx(cz, 64.0):
				continue   # spawn block
			_block(cx, cz)


func _pick_mat() -> Material:
	return _bm[rng.randi() % _bm.size()]


func _block(cx: float, cz: float) -> void:
	match rng.randi() % 4:
		0:
			_building(Vector3(cx, 0, cz), Vector3(19, rng.randf_range(32.0, 70.0), 19), _pick_mat())
		1:
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					_building(Vector3(cx + sx * 5.0, 0, cz + sz * 5.0), Vector3(8.5, rng.randf_range(14.0, 36.0), 8.5), _pick_mat())
		2:
			var m := _pick_mat()
			_building(Vector3(cx, 0, cz), Vector3(19, 10, 19), m)
			_building(Vector3(cx, 10, cz), Vector3(11, rng.randf_range(25.0, 55.0), 11), m)
		_:
			_building(Vector3(cx - 5.0, 0, cz), Vector3(8.5, rng.randf_range(20.0, 45.0), 19), _pick_mat())
			_building(Vector3(cx + 5.0, 0, cz), Vector3(8.5, rng.randf_range(14.0, 38.0), 19), _pick_mat())


func _building(base: Vector3, size: Vector3, mat: Material) -> void:
	_solid(root, base + Vector3(0, size.y * 0.5, 0), size, mat, base.y + size.y)
	var top: float = base.y + size.y
	if rng.randf() < 0.7:
		var h: float = rng.randf_range(4.0, 9.0)
		var ax: float = base.x + rng.randf_range(-size.x * 0.3, size.x * 0.3)
		var az: float = base.z + rng.randf_range(-size.z * 0.3, size.z * 0.3)
		_detail(Gfx.add(root, Gfx.cyl(0.08, 0.12, h), _dark, Vector3(ax, top + h * 0.5, az)))
		_detail(Gfx.add(root, Gfx.sph(0.22, 6), _red, Vector3(ax, top + h, az)))
	for i in 2:
		var ox: float = base.x + rng.randf_range(-size.x * 0.3, size.x * 0.3)
		var oz: float = base.z + rng.randf_range(-size.z * 0.3, size.z * 0.3)
		_detail(Gfx.add(root, Gfx.box(Vector3(1.6, 1.0, 1.2)), _dark, Vector3(ox, top + 0.5, oz)))
	if size.y > 14.0 and rng.randf() < 0.55:
		_billboard(base, size)
	if rng.randf() < 0.4:
		var n := _face_normal()
		var p := base + Vector3(n.x * (size.x * 0.5 + 0.1), 4.2, n.z * (size.z * 0.5 + 0.1))
		_sign(SIGNS[rng.randi() % SIGNS.size()], p, rad_to_deg(atan2(n.x, n.z)), NEON[rng.randi() % NEON.size()], 0.014)


func _face_normal() -> Vector3:
	var dirs := [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
	return dirs[rng.randi() % 4]


func _billboard(base: Vector3, size: Vector3) -> void:
	var n := _face_normal()
	var w: float = minf(size.x, size.z) * 0.85
	var q := QuadMesh.new()
	q.size = Vector2(w, w * 0.5)
	var y: float = base.y + clampf(size.y * rng.randf_range(0.45, 0.7), w * 0.25 + 3.0, size.y - w * 0.25 - 1.0)
	var p := Vector3(base.x + n.x * (size.x * 0.5 + 0.1), y, base.z + n.z * (size.z * 0.5 + 0.1))
	var a: Color = NEON[rng.randi() % NEON.size()]
	var b: Color = NEON[rng.randi() % NEON.size()]
	var mi := Gfx.add(root, q, Shaders.screen(a, b, rng.randf_range(0.6, 1.4), rng.randf() * 10.0), p, Vector3(0, rad_to_deg(atan2(n.x, n.z)), 0))
	mi.visibility_range_end = 170.0


# -------------------------------------------------------------------- plaza ----
func _plaza() -> void:
	var conc := Gfx.mat(Color(0.12, 0.13, 0.15), 0.1, 0.8)
	for i in 26:
		var a: float = rng.randf() * TAU
		var r: float = rng.randf_range(27.0, 40.0)
		var mi := _solid(root, Vector3(cos(a) * r, 0.5, sin(a) * r), Vector3(3.0, 1.0, 0.8), conc)
		var body := mi.get_parent() as Node3D
		body.rotation.y = a + 1.57
		Gfx.add(body, Gfx.box(Vector3(3.02, 0.08, 0.82)), _cyan if i % 2 == 0 else _mag, Vector3(0, 0.3, 0))
	for i in 12:
		var a2: float = TAU * i / 12.0
		_detail(Gfx.add(root, Gfx.cyl(0.2, 0.2, 7.0, 8), _cyan, Vector3(cos(a2) * 26.0, 3.5, sin(a2) * 26.0)))
	for i in 8:
		var a3: float = TAU * (i + 0.5) / 8.0
		var p := Vector3(cos(a3) * 33.0, 0, sin(a3) * 33.0)
		_solid(root, p + Vector3(0, 0.6, 0), Vector3(1.6, 1.2, 1.6), conc)
		_detail(Gfx.add(root, Gfx.sph(0.55, 8), _mag, p + Vector3(0, 1.5, 0)))


# ------------------------------------------------------- server hall + tower ----
func _complex() -> void:
	var h := _hall
	# podium hall 44x44, 10 m tall, entrances on south (+Z) and west (-X)
	_solid(root, Vector3(0, 5, -21.25), Vector3(44, 10, 1.5), h, 10.0)
	_solid(root, Vector3(21.25, 5, 0), Vector3(1.5, 10, 44), h, 10.0)
	_solid(root, Vector3(-13.5, 5, 21.25), Vector3(17, 10, 1.5), h, 10.0)
	_solid(root, Vector3(13.5, 5, 21.25), Vector3(17, 10, 1.5), h, 10.0)
	_solid(root, Vector3(0, 8.5, 21.25), Vector3(10, 3, 1.5), h, 10.0)
	_solid(root, Vector3(-21.25, 5, -13.5), Vector3(1.5, 10, 17), h, 10.0)
	_solid(root, Vector3(-21.25, 5, 13.5), Vector3(1.5, 10, 17), h, 10.0)
	_solid(root, Vector3(-21.25, 8.5, 0), Vector3(1.5, 3, 10), h, 10.0)
	_solid(root, Vector3(0, 10.75, 0), Vector3(44, 1.5, 44), h, 11.5)
	_sign("DATA CORE", Vector3(0, 8.5, 22.1), 0.0, Color(0.2, 0.9, 1.0), 0.015)
	_sign("DATA CORE", Vector3(-22.1, 8.5, 0), -90.0, Color(0.2, 0.9, 1.0), 0.015)
	for px in [-14.0, 14.0]:
		for pz in [-14.0, 14.0]:
			_solid(root, Vector3(px, 5, pz), Vector3(1.6, 10, 1.6), _dark)
			_detail(Gfx.add(root, Gfx.box(Vector3(0.2, 9.0, 1.65)), _cyan, Vector3(px, 5, pz)))

	# core chamber 16x16 with a sliding blast door on the south side
	_solid(root, Vector3(0, 4.5, -8), Vector3(16, 9, 1), h, 9.0)
	_solid(root, Vector3(8, 4.5, 0), Vector3(1, 9, 16), h, 9.0)
	_solid(root, Vector3(-8, 4.5, 0), Vector3(1, 9, 16), h, 9.0)
	_solid(root, Vector3(-5.5, 4.5, 8), Vector3(5, 9, 1), h, 9.0)
	_solid(root, Vector3(5.5, 4.5, 8), Vector3(5, 9, 1), h, 9.0)
	_solid(root, Vector3(0, 8, 8), Vector3(6, 2, 1), h, 9.0)
	_solid(root, Vector3(0, 9.5, 0), Vector3(16, 1, 16), h, 10.0)
	var door_mi := _solid(root, Vector3(0, 3.5, 8), Vector3(6, 7, 0.8), Gfx.mat(Color(0.15, 0.16, 0.2), 0.9, 0.3))
	Gfx.add(door_mi, Gfx.box(Vector3(5.0, 0.2, 0.84)), _red)
	Gfx.add(door_mi, Gfx.box(Vector3(0.2, 6.0, 0.84)), _red)
	door = door_mi.get_parent() as Node3D

	# data server core
	_solid(root, Vector3(0, 3.3, 0), Vector3(2.4, 6.6, 2.4), _dark)
	Gfx.add(root, Gfx.cyl(2.4, 2.6, 0.6), _dark, Vector3(0, 0.3, 0))
	Gfx.add(root, Gfx.cyl(0.9, 0.9, 6.0), _cyan, Vector3(0, 3.6, 0))
	for i in 3:
		var ring := _spinner(root, Vector3(0, 2.0 + i * 1.6, 0), Vector3.UP, 1.2 if i % 2 == 0 else -1.6)
		var rmi := MeshInstance3D.new()
		rmi.mesh = Gfx.tor(1.7, 2.0)
		rmi.material_override = _mag
		ring.add_child(rmi)
	var core_light := OmniLight3D.new()
	core_light.position = Vector3(0, 4, 0)
	core_light.omni_range = 14.0
	core_light.light_energy = 3.0
	core_light.light_color = Color(0.3, 0.9, 1.0)
	root.add_child(core_light)

	# hall lights
	for p in [Vector3(-12, 8, -12), Vector3(12, 8, -12), Vector3(-12, 8, 12), Vector3(12, 8, 12)]:
		var l := OmniLight3D.new()
		l.position = p
		l.omni_range = 22.0
		l.light_energy = 1.6
		l.light_color = Color(0.4, 0.8, 1.0) if p.x < 0.0 else Color(1.0, 0.4, 0.8)
		root.add_child(l)

	# server racks (blinking LEDs) + workstations
	var rack := Shaders.building(Color(0.03, 0.03, 0.04), Color(0.2, 1.0, 0.4), Color(0.2, 0.6, 1.0), Vector2(0.3, 0.18), 0.8, 3.0)
	for i in range(-4, 5):
		_solid(root, Vector3(i * 4.0, 1.5, -18.5), Vector3(1.6, 3.0, 1.0), rack)
		_solid(root, Vector3(i * 4.0, 1.5, -14.6), Vector3(1.6, 3.0, 1.0), rack)
	for i in range(-2, 3):
		_solid(root, Vector3(18.5, 1.5, i * 4.0), Vector3(1.0, 3.0, 1.6), rack)
		_solid(root, Vector3(14.6, 1.5, i * 4.0), Vector3(1.0, 3.0, 1.6), rack)
	for zz in [-14.0, -10.0, 10.0, 14.0]:
		_solid(root, Vector3(-17.0, 0.45, zz), Vector3(1.2, 0.9, 2.6), _dark)
		var qm := QuadMesh.new()
		qm.size = Vector2(1.8, 1.0)
		Gfx.add(root, qm, Shaders.screen(Color(0.1, 0.9, 1.0), Color(0.2, 0.4, 1.0), 1.0, zz), Vector3(-16.3, 1.5, zz), Vector3(0, 90, 0))

	# server tower
	var tower_mat := Shaders.building(Color(0.03, 0.04, 0.07), Color(0.3, 0.9, 1.0), Color(1.0, 0.3, 0.8), Vector2(3.0, 3.6), 0.45, 0.4)
	_solid(root, Vector3(0, 53.5, 0), Vector3(26, 84, 26), tower_mat, 95.5)
	for k in 7:
		_detail(Gfx.add(root, Gfx.box(Vector3(26.6, 0.5, 26.6)), _cyan if k % 2 == 0 else _mag, Vector3(0, 14.0 + k * 12.0, 0))).visibility_range_end = 400.0
	for cx in [-13.0, 13.0]:
		for cz in [-13.0, 13.0]:
			Gfx.add(root, Gfx.box(Vector3(0.7, 84, 0.7)), _cyan, Vector3(cx, 53.5, cz)).visibility_range_end = 400.0
	_solid(root, Vector3(0, 99, 0), Vector3(14, 7, 14), tower_mat, 102.5)
	Gfx.add(root, Gfx.cyl(0.25, 0.4, 14.0), _dark, Vector3(0, 109, 0))
	Gfx.add(root, Gfx.sph(0.7, 8), _red, Vector3(0, 116.5, 0))
	Gfx.add(root, Gfx.cyl(1.2, 1.2, 320.0), Gfx.beam(Color(0.2, 0.9, 1.0), 0.18), Vector3(0, 270, 0))


# ---------------------------------------------------------------- spawn area ----
func _spawn_area() -> void:
	var c := Vector3(SPAWN.x, 0.0, SPAWN.z)
	Gfx.add(root, Gfx.cyl(5.0, 5.0, 0.3), _dark, c + Vector3(0, 0.15, 0))
	var ring := Gfx.add(root, Gfx.tor(4.6, 5.0), _cyan, c + Vector3(0, 0.32, 0))
	ring.scale = Vector3(1, 0.4, 1)
	for a in [45.0, 135.0, 225.0, 315.0]:
		var p := c + Vector3(cos(deg_to_rad(a)) * 6.5, 0, sin(deg_to_rad(a)) * 6.5)
		_solid(root, p + Vector3(0, 2.0, 0), Vector3(0.5, 4.0, 0.5), _dark)
		_detail(Gfx.add(root, Gfx.sph(0.4, 8), _mag, p + Vector3(0, 4.2, 0)))
	_sign("GLAXIOUS", c + Vector3(0, 6.5, 0), 45.0, Color(0.2, 0.9, 1.0), 0.03)
	_sign("SERVER TOWER >>>", c + Vector3(6.0, 3.0, -6.0), 135.0, Color(1.0, 0.7, 0.2), 0.012)


# --------------------------------------------------------------- lamps / cars ----
func _lamps() -> void:
	var lines := [-80.0, -48.0, -16.0, 16.0, 48.0, 80.0]
	var along := [-72.0, -56.0, -40.0, -24.0, -8.0, 8.0, 24.0, 40.0, 56.0, 72.0]
	var pts: Array[Vector3] = []
	for l in lines:
		for a in along:
			for side in [-1.0, 1.0]:
				for p in [Vector3(l + side * 5.6, 0, a), Vector3(a, 0, l + side * 5.6)]:
					if absf(p.x) < 44.0 and absf(p.z) < 44.0:
						continue
					if absf(p.x) > 84.0 or absf(p.z) > 84.0:
						continue
					pts.append(p)
	var poles := MultiMesh.new()
	poles.transform_format = MultiMesh.TRANSFORM_3D
	poles.mesh = Gfx.box(Vector3(0.2, 7.0, 0.2))
	poles.instance_count = pts.size()
	var heads := MultiMesh.new()
	heads.transform_format = MultiMesh.TRANSFORM_3D
	heads.mesh = Gfx.box(Vector3(0.9, 0.2, 0.5))
	heads.instance_count = pts.size()
	for i in pts.size():
		poles.set_instance_transform(i, Transform3D(Basis(), pts[i] + Vector3(0, 3.5, 0)))
		heads.set_instance_transform(i, Transform3D(Basis(), pts[i] + Vector3(0, 7.1, 0)))
	var pm := MultiMeshInstance3D.new()
	pm.multimesh = poles
	pm.material_override = _dark
	pm.visibility_range_end = 130.0
	root.add_child(pm)
	var hm := MultiMeshInstance3D.new()
	hm.multimesh = heads
	hm.material_override = Gfx.glow(Color(1.0, 0.85, 0.5), 3.5)
	hm.visibility_range_end = 130.0
	root.add_child(hm)


func _cars() -> void:
	var list := [[13.0, -62.0, 0.0], [-19.0, 62.0, 0.05], [19.0, -70.0, PI], [-13.0, -58.0, 0.0],
		[45.0, -62.0, 0.0], [51.0, 60.0, PI], [-62.0, 13.0, PI / 2.0], [62.0, -19.0, PI / 2.0],
		[-60.0, 45.0, PI / 2.0], [66.0, 51.0, -PI / 2.0]]
	for i in list.size():
		var c: Color = NEON[i % NEON.size()]
		var e: Array = list[i]
		_car(Vector3(e[0], 0, e[1]), e[2], c)


func _car(pos: Vector3, yaw: float, col: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = yaw
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.0, 1.3, 4.2)
	cs.shape = bs
	cs.position = Vector3(0, 0.65, 0)
	body.add_child(cs)
	_detail(Gfx.add(body, Gfx.box(Vector3(2.0, 0.7, 4.2)), Gfx.mat(col * 0.3, 0.7, 0.3), Vector3(0, 0.55, 0)))
	_detail(Gfx.add(body, Gfx.box(Vector3(1.7, 0.6, 2.2)), _dark, Vector3(0, 1.15, 0.2)))
	_detail(Gfx.add(body, Gfx.box(Vector3(1.9, 0.06, 3.9)), Gfx.glow(col, 2.0), Vector3(0, 0.15, 0)))
	_detail(Gfx.add(body, Gfx.box(Vector3(1.6, 0.12, 0.06)), _red, Vector3(0, 0.7, 2.1)))
	_detail(Gfx.add(body, Gfx.box(Vector3(1.6, 0.12, 0.06)), Gfx.glow(Color(1, 1, 0.9), 3.0), Vector3(0, 0.7, -2.1)))
	root.add_child(body)
