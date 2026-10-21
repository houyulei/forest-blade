class_name BoyModel
extends RefCounted
## Cel-shaded young swordsman built from concepts/hero-adol-inspired-v1.png:
## spiky black hair, red neck scarf, silver pauldrons, deep teal-blue tunic over an ivory
## shirt, cream trousers, cuffed brown boots, sword at the left hip and a round back shield.
## Character faces +Z; his left side is +X. Proportions are about five heads tall.

# Painted anime face on the head mesh, in head-local metres (head radius ~0.16).
const FACE_FRAGMENT := """
varying vec3 local;
uniform bool pixel_art = false;
void vertex() {
	local = VERTEX;
}
float fill(float d) {
	// Hard edges at sprite resolution; anti-aliased edges up close.
	return pixel_art ? step(d, 0.0) : 1.0 - smoothstep(-fwidth(d), fwidth(d), d);
}
float ellipse(vec2 p, vec2 c, vec2 r) {
	return (length((p - c) / r) - 1.0) * min(r.x, r.y);
}
void fragment() {
	vec3 col = albedo.rgb;
	vec2 p = local.xy;
	float front = smoothstep(0.02, 0.08, local.z);
	float side = sign(p.x);
	vec2 q = vec2(abs(p.x), p.y);
	if (pixel_art) {
		// At sprite size a face is two solid dark eyes and a hint of blush.
		col = mix(col, vec3(0.95, 0.66, 0.58), 0.3 * front * (1.0 - smoothstep(0.0, 1.0, length((q - vec2(0.088, -0.050)) / vec2(0.03, 0.016)))));
		col = mix(col, vec3(0.16, 0.09, 0.07), fill(ellipse(q, vec2(0.062, -0.016), vec2(0.021, 0.032))) * front);
		ALBEDO = col;
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
	} else {
	// Soft blush under the eyes.
	col = mix(col, vec3(0.95, 0.62, 0.55), 0.35 * front * (1.0 - smoothstep(0.0, 1.0, length((q - vec2(0.085, -0.052)) / vec2(0.034, 0.016)))));
	// Large rounded eye: sclera, dark-brown iris, pupil and catch-lights.
	vec2 e = q - vec2(0.064, -0.012);
	float lid = 0.022 - 12.0 * e.x * e.x;
	float eye = max(ellipse(q, vec2(0.064, -0.014), vec2(0.026, 0.033)), e.y - lid);
	float inside = fill(eye) * front;
	col = mix(col, vec3(0.99, 0.97, 0.94), inside);
	float iris = fill(ellipse(q, vec2(0.062, -0.017), vec2(0.019, 0.028))) * inside;
	vec3 iris_col = mix(vec3(0.33, 0.21, 0.15), vec3(0.11, 0.07, 0.06), smoothstep(-0.040, 0.004, p.y));
	col = mix(col, iris_col, iris);
	col = mix(col, vec3(0.05, 0.03, 0.03), fill(ellipse(q, vec2(0.062, -0.014), vec2(0.009, 0.014))) * inside);
	col = mix(col, vec3(1.0), fill(ellipse(p, vec2(side * 0.062 + 0.007, -0.006), vec2(0.0065, 0.0085))) * inside);
	col = mix(col, vec3(1.0), 0.8 * fill(ellipse(p, vec2(side * 0.062 - 0.006, -0.032), vec2(0.0035, 0.0035))) * inside);
	// Thick upper lash line with a flick at the outer corner, thin lower line.
	float lash = abs(e.y - lid) - 0.0045;
	lash = max(lash, abs(e.x) - 0.030);
	float flick = ellipse(q, vec2(0.093, 0.010), vec2(0.008, 0.004));
	col = mix(col, vec3(0.08, 0.05, 0.05), fill(min(lash, flick)) * front);
	float lower = max(abs(ellipse(q, vec2(0.064, -0.014), vec2(0.026, 0.033))) - 0.0012, e.y + 0.020);
	col = mix(col, vec3(0.45, 0.28, 0.24), 0.8 * fill(lower) * front);
	// Brows (mostly under the fringe), nose hint and a small closed smile.
	float brow = max(abs(q.y - 0.046 + 8.0 * (q.x - 0.066) * (q.x - 0.066)) - 0.003, abs(q.x - 0.066) - 0.024);
	col = mix(col, vec3(0.10, 0.07, 0.07), fill(brow) * front);
	col = mix(col, vec3(0.80, 0.52, 0.44), 0.7 * fill(ellipse(p, vec2(0.004, -0.060), vec2(0.006, 0.0035))) * front);
	float smile = max(abs(p.y - (-0.094 + 9.0 * p.x * p.x)) - 0.0018, abs(p.x) - 0.017);
	col = mix(col, vec3(0.42, 0.18, 0.15), fill(smile) * front);
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	}
}
"""

static var _meshes := {}

static func cached(key: String, maker: Callable) -> Mesh:
	if not _meshes.has(key):
		_meshes[key] = maker.call()
	return _meshes[key]

static func part(parent: Node3D, key: String, maker: Callable, mat: Material, position: Vector3 = Vector3.ZERO, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var n := Craft.mesh(parent, cached(key, maker), position, mat)
	n.rotation = rotation
	return n

static func build(parent: Node3D) -> Dictionary:
	var skin_col := Color("fbe2cc")
	var skin := Craft.toon(skin_col, Color("e2a99c"), 0.0, 1.3, Color("7a4a3a"))
	var face := Craft.toon(skin_col, Color("e2a99c"), 0.0, 1.3, Color("7a4a3a"), Craft.TOON_HEAD + Craft.TOON_LIGHT + FACE_FRAGMENT)
	var hair := Craft.toon(Color("23263a"), Color("7d82a8"), 0.86, 1.4, Color("0a0a12"))
	hair.set_shader_parameter("spec_color", Color("6b789f"))
	hair.set_shader_parameter("band", 0.05)
	face.set_shader_parameter("pixel_art", Craft.pixel_art)
	# Scattered specular on every lock turns to speckle when pixelated; keep the cap's ring only.
	var locks_mat := Craft.toon(Color("23263a"), Color("7d82a8"), 0.0 if Craft.pixel_art else 0.86, 1.4, Color("0a0a12"))
	locks_mat.set_shader_parameter("spec_color", Color("6b789f"))
	locks_mat.set_shader_parameter("band", 0.05)
	var tunic := Craft.toon(Color("2f5281"), Color("8c86b5"), 0.0, 1.4, Color("101b2e"))
	var trim := Craft.toon(Color("aab3bd"), Color("9a98b8"), 0.0, 0.0)
	var shirt := Craft.toon(Color("f6f0e2"), Color("b7aec6"))
	var pants := Craft.toon(Color("efe7d3"), Color("b6abc2"))
	var leather := Craft.toon(Color("7a4a2c"), Color("9a86a8"))
	var dark_leather := Craft.toon(Color("4a2f22"), Color("a08ab0"))
	var boots := Craft.toon(Color("7d4b2e"), Color("a0889f"), 0.0, 1.5)
	var brass := Craft.toon(Color("d4ab58"), Color("9d84a0"), 0.95, 0.0)
	var silver := Craft.toon(Color("c3c9cf"), Color("7f84a6"), 0.95, 1.5, Color("2a2c36"))
	var steel := Craft.toon(Color("dfe7ea"), Color("8b93b0"), 0.9, 1.2, Color("2a2c36"))
	var scarf_mat := Craft.toon(Color("c8322b"), Color("b07a9e"), 0.0, 1.5, Color("4a0f0f"))
	var wood := Craft.toon(Color("5d3a26"), Color("9f8aa8"))
	var root := Node3D.new()
	root.name = "BoyVisual"
	parent.add_child(root)

	# Legs: baggy cream trousers tucked into tall cuffed boots.
	var legs: Array[Node3D] = []
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.088, 0.86, 0)
		root.add_child(leg)
		part(leg, "trousers", func(): return Craft.lathe([Vector3(0.04, 0, 0), Vector3(0.04, 0.090, 0.090), Vector3(-0.02, 0.106, 0.106), Vector3(-0.22, 0.112, 0.114), Vector3(-0.40, 0.106, 0.110), Vector3(-0.50, 0.090, 0.094), Vector3(-0.56, 0, 0)], 14), pants)
		part(leg, "boot", func(): return Craft.lathe([Vector3(-0.83, 0, 0), Vector3(-0.83, 0.068, 0.074), Vector3(-0.70, 0.066, 0.070), Vector3(-0.56, 0.074, 0.078), Vector3(-0.53, 0.096, 0.100), Vector3(-0.47, 0.104, 0.108), Vector3(-0.465, 0.080, 0.084), Vector3(-0.48, 0, 0)], 14), boots)
		part(leg, "foot", func(): return Craft.blob(Vector3(0.070, 0.050, 0.120), func(p: Vector3): return p + Vector3(0, 0, 0.03 if p.z > 0 else 0) - Vector3(0, maxf(0, p.y) * 0.3 * clampf(p.z / 0.12, 0, 1), 0)), boots, Vector3(0, -0.815, 0.040))
		Craft.box(leg, Vector3(0, -0.858, 0.040), Vector3(0.13, 0.026, 0.25), dark_leather)
		part(leg, "ankle_strap", func(): return Craft.lathe([Vector3(-0.765, 0, 0), Vector3(-0.765, 0.073, 0.078), Vector3(-0.735, 0.073, 0.078), Vector3(-0.735, 0, 0)], 14), dark_leather)
		Craft.box(leg, Vector3(side * 0.074, -0.75, 0.010), Vector3(0.012, 0.03, 0.03), brass)
		legs.append(leg)

	# Upper body pivots at the hips so swings can twist and lean the torso.
	var body := Node3D.new()
	body.name = "Body"
	body.position.y = 0.90
	root.add_child(body)
	var torso := [Vector3(-0.18, 0, 0), Vector3(-0.18, 0.196, 0.150), Vector3(-0.12, 0.182, 0.142), Vector3(-0.03, 0.160, 0.126), Vector3(0.08, 0.150, 0.112), Vector4(0.20, 0.166, 0.118, 0.008), Vector4(0.32, 0.182, 0.120, 0.006), Vector3(0.42, 0.168, 0.108), Vector3(0.47, 0.110, 0.088), Vector3(0.50, 0.060, 0.058), Vector3(0.50, 0, 0)]
	part(body, "tunic", func(): return Craft.lathe(torso, 24), tunic)
	part(body, "hem_trim", func(): return Craft.lathe([Vector3(-0.185, 0, 0), Vector3(-0.185, 0.200, 0.154), Vector3(-0.155, 0.192, 0.150), Vector3(-0.15, 0, 0)], 24), trim)
	# Front opening shows the ivory shirt, edged in grey-silver like the concept.
	var slit := Craft.box(body, Vector3(0, -0.105, 0.141), Vector3(0.040, 0.15, 0.010), shirt)
	slit.rotation.x = -0.12
	for side in [-1.0, 1.0]:
		var edge := Craft.box(body, Vector3(side * 0.024, -0.105, 0.142), Vector3(0.010, 0.15, 0.012), trim)
		edge.rotation.x = -0.12
		var v := Craft.box(body, Vector3(side * 0.040, 0.385, 0.098), Vector3(0.012, 0.12, 0.012), trim)
		v.rotation = Vector3(-0.35, 0, side * 0.45)
	Craft.mesh(body, Craft.blob(Vector3(0.050, 0.060, 0.020)), Vector3(0, 0.40, 0.092), shirt).rotation.x = -0.3

	# Belts, cross strap for the shield and a hip pouch.
	part(body, "belt", func(): return Craft.lathe([Vector3(0.03, 0, 0), Vector3(0.03, 0.165, 0.130), Vector3(0.11, 0.162, 0.126), Vector3(0.11, 0, 0)], 24), leather)
	Craft.box(body, Vector3(0, 0.07, 0.131), Vector3(0.058, 0.058, 0.012), brass)
	Craft.box(body, Vector3(0, 0.07, 0.135), Vector3(0.032, 0.030, 0.010), dark_leather)
	if not Craft.pixel_art:
		part(body, "hip_belt", func(): return Craft.lathe([Vector3(-0.02, 0, 0), Vector3(-0.02, 0.182, 0.146), Vector3(0.02, 0.182, 0.146), Vector3(0.02, 0, 0)], 24), dark_leather, Vector3(0, -0.05, 0), Vector3(0, 0, -0.12))
	var strap := part(body, "cross_strap", func(): return Craft.lathe([Vector3(-0.018, 0, 0), Vector4(-0.018, 0.278, 0.146, 0.006), Vector4(0.018, 0.278, 0.146, 0.006), Vector3(0.018, 0, 0)], 28), leather, Vector3(-0.01, 0.215, 0), Vector3(0, 0, 1.0))
	Craft.box(strap, Vector3(-0.07, 0, 0.150), Vector3(0.040, 0.050, 0.010), brass)
	strap.scale = Vector3(1, 0.7, 1) if Craft.pixel_art else Vector3.ONE
	var pouch := Node3D.new()
	pouch.position = Vector3(-0.168, -0.085, 0.07)
	pouch.rotation.y = -0.75
	body.add_child(pouch)
	Craft.box(pouch, Vector3.ZERO, Vector3(0.075, 0.085, 0.045), leather)
	Craft.box(pouch, Vector3(0, 0.030, 0.004), Vector3(0.080, 0.035, 0.050), dark_leather)
	Craft.ball(pouch, Vector3(0, 0.015, 0.030), Vector3.ONE * 0.016, brass)

	# Neck, stand collar and the red scarf (knot at the front, long tail over the left shoulder).
	part(body, "neck", func(): return Craft.lathe([Vector3(0.44, 0, 0), Vector3(0.44, 0.046, 0.044), Vector3(0.66, 0.040, 0.040), Vector3(0.68, 0, 0)], 12), skin)
	part(body, "collar", func(): return Craft.lathe([Vector3(0.49, 0, 0), Vector3(0.49, 0.068, 0.064), Vector3(0.565, 0.062, 0.058), Vector3(0.565, 0, 0)], 18), tunic)
	part(body, "scarf_band", func(): return Craft.lathe([Vector3(0.44, 0, 0), Vector3(0.44, 0.126, 0.104), Vector3(0.475, 0.124, 0.104), Vector3(0.51, 0.094, 0.084), Vector3(0.535, 0.074, 0.070), Vector3(0.535, 0, 0)], 20), scarf_mat)
	Craft.ball(body, Vector3(0.030, 0.455, 0.112), Vector3(0.075, 0.060, 0.050), scarf_mat)
	Craft.ball(body, Vector3(0.060, 0.470, 0.100), Vector3(0.050, 0.040, 0.040), scarf_mat)
	for i in range(2):
		var tail := MeshInstance3D.new()
		tail.mesh = cached("scarf_front%d" % i, func(): return Craft.strand(0.12 + i * 0.03, 0.026, 0.008, 0.25, 0.45))
		tail.material_override = scarf_mat
		body.add_child(tail)
		Craft.orient(tail, Vector3(0.035 + i * 0.012, 0.44, 0.118), Vector3(-0.25 + i * 0.5, -1, 0.10), Vector3(0, 0, -1))
	var scarf := Node3D.new()
	scarf.name = "ScarfTail"
	scarf.position = Vector3(0.075, 0.49, -0.06)
	body.add_child(scarf)
	var long_tail := MeshInstance3D.new()
	long_tail.mesh = cached("scarf_long", func(): return Craft.strand(0.36, 0.040, 0.010, 0.6, 0.6, 8))
	long_tail.material_override = scarf_mat
	scarf.add_child(long_tail)
	Craft.orient(long_tail, Vector3.ZERO, Vector3(0.65, -1, -0.45), Vector3(0, 0.2, -1))

	# Round wood-and-iron travel shield worn on the back, edge showing past the left arm.
	var shield := Craft.orient(Node3D.new(), Vector3(0.10, 0.22, -0.165), Vector3(0.45, 0, -1), Vector3.UP)
	body.add_child(shield)
	part(shield, "shield_face", func(): return Craft.lathe([Vector3(-0.012, 0, 0), Vector3(-0.012, 0.172, 0.172), Vector3(0.012, 0.172, 0.172), Vector3(0.030, 0.12, 0.12), Vector3(0.034, 0, 0)], 28), wood)
	Craft.ring(shield, Vector3.ZERO, 0.19, 0.03, silver).scale.y = 0.8
	Craft.ball(shield, Vector3(0, 0.034, 0), Vector3(0.09, 0.05, 0.09), silver)
	for i in range(8):
		var a := TAU * i / 8
		Craft.ball(shield, Vector3(cos(a) * 0.15, 0.024, sin(a) * 0.15), Vector3.ONE * 0.018, brass)

	# Scabbard on the left hip, angled down and back.
	var mouth := Vector3(0.175, -0.06, 0.075)
	var down := Vector3(0.2, -0.8, -0.56).normalized()
	var scabbard := Craft.orient(Node3D.new(), mouth, -down, Vector3.RIGHT)
	body.add_child(scabbard)
	part(scabbard, "scabbard", func(): return Craft.lathe([Vector3(-0.505, 0, 0), Vector3(-0.50, 0.010, 0.008), Vector3(-0.46, 0.023, 0.013), Vector3(-0.30, 0.029, 0.015), Vector3(0.0, 0.031, 0.016), Vector3(0.0, 0, 0)], 12), dark_leather)
	part(scabbard, "locket", func(): return Craft.lathe([Vector3(-0.045, 0, 0), Vector3(-0.045, 0.035, 0.020), Vector3(0.006, 0.036, 0.021), Vector3(0.006, 0, 0)], 12), brass)
	part(scabbard, "chape", func(): return Craft.lathe([Vector3(-0.512, 0, 0), Vector3(-0.50, 0.014, 0.011), Vector3(-0.43, 0.027, 0.017), Vector3(-0.43, 0, 0)], 12), brass)
	Craft.box(scabbard, Vector3(0, -0.08, 0.02), Vector3(0.05, 0.03, 0.012), leather)

	# Head: round cranium narrowing to a soft pointed chin, painted anime face.
	var head := Node3D.new()
	head.name = "Head"
	# Head is enlarged and tipped back slightly so the face reads from the high game camera.
	head.position.y = 0.765
	head.scale = Vector3.ONE * 1.2
	head.rotation.x = -0.2 if Craft.pixel_art else -0.12
	body.add_child(head)
	part(head, "head", func(): return Craft.blob(Vector3(0.150, 0.165, 0.152), func(p: Vector3):
		var t := smoothstep(0.02, -0.165, p.y)
		return Vector3(p.x * (1.0 - 0.30 * t), p.y - 0.010 * t, p.z * (1.0 - 0.20 * t) + 0.012 * t), 16, 24), face)
	for side in [-1.0, 1.0]:
		part(head, "ear", func(): return Craft.blob(Vector3(0.018, 0.034, 0.026)), skin, Vector3(side * 0.146, -0.020, -0.010), Vector3(0, 0, side * -0.15))
	# Hair cap hugs the skull; the face-side underside is tucked inside the head.
	var cap_center := Vector3(0, 0.025, -0.012)
	part(head, "hair_cap", func(): return Craft.blob(Vector3(0.162, 0.162, 0.168), func(p: Vector3):
		var f := clampf(p.z / 0.168, -1.0, 1.0)
		var cut := lerpf(-0.22, 0.035, smoothstep(-0.4, 0.6, f))
		var k := smoothstep(cut + 0.03, cut - 0.01, p.y)
		return p * lerpf(1.0, 0.84, k), 14, 24), hair, cap_center)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1207
	# (yaw, pitch, length, width, curl, lift) — yaw 0 faces front, +yaw toward his left.
	var locks: Array = []
	for i in range(7):
		var t := float(i) / 6.0
		locks.append([lerpf(-0.95, 0.95, t), 0.66, 0.095 if i == 3 else 0.08 - absf(t - 0.5) * 0.02, 0.036, 0.5, 0.0])
	for side in [-1.0, 1.0]:
		locks.append([side * 1.30, 0.35, 0.10, 0.032, 0.25, -0.15])
		locks.append([side * 1.62, 0.30, 0.11, 0.036, 0.0, -0.35])
		locks.append([side * 1.95, 0.25, 0.10, 0.036, -0.2, -0.45])
		locks.append([side * 1.10, 0.10, 0.075, 0.020, 0.25, 0.0])
	for i in range(7):
		locks.append([PI + lerpf(-1.2, 1.2, i / 6.0), 0.15, 0.13, 0.046, 0.2, -0.20])
	for i in range(4):
		locks.append([PI + lerpf(-0.6, 0.6, i / 3.0), -0.35, 0.10, 0.040, 0.0, -0.30])
	for i in range(11):
		var yaw := TAU * i / 11.0 + 0.2
		locks.append([yaw, 0.95, 0.12 + absf(cos(yaw * 0.5)) * 0.03, 0.050, 0.35, -0.70])
	for i in range(5):
		locks.append([PI * 0.9 + i * 0.95, 1.30, 0.10, 0.046, -0.45, -0.55])
	locks.append([0.35, 1.45, 0.09, 0.012, -0.9, -1.2])
	for l in locks:
		var yaw: float = l[0] + rng.randf_range(-0.05, 0.05)
		var pitch: float = l[1]
		var n := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
		var tangent := Vector3(-sin(yaw) * sin(pitch), cos(pitch), -cos(yaw) * sin(pitch)) * -1.0
		var direction := tangent.lerp(n, -l[5]).normalized() if l[5] < 0 else tangent
		var key := "lock_%.3f_%.3f_%.2f" % [l[2], l[3], l[4]]
		var lock := MeshInstance3D.new()
		lock.mesh = cached(key, func(): return Craft.strand(l[2], l[3], l[3] * 0.38, l[4], 0.0, 6))
		lock.material_override = locks_mat
		head.add_child(lock)
		Craft.orient(lock, cap_center + n * 0.150, direction, -n)
		lock.rotate_object_local(Vector3.UP, rng.randf_range(-0.25, 0.25))
		lock.scale = Vector3(1, rng.randf_range(0.9, 1.1), 1)

	# Arms: puffy rolled ivory sleeves, silver pauldrons, leather bracers.
	var arms: Array[Node3D] = []
	var elbows: Array[Node3D] = []
	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.195, 0.425, -0.005)
		arm.rotation.z = side * 0.10
		body.add_child(arm)
		part(arm, "sleeve", func(): return Craft.lathe([Vector3(0.04, 0, 0), Vector3(0.04, 0.052, 0.052), Vector3(-0.02, 0.064, 0.066), Vector3(-0.13, 0.060, 0.062), Vector3(-0.24, 0.050, 0.052), Vector3(-0.28, 0.045, 0.046), Vector3(-0.28, 0, 0)], 12), shirt)
		var elbow := Node3D.new()
		elbow.position.y = -0.255
		elbow.rotation.x = -0.25
		arm.add_child(elbow)
		part(elbow, "forearm_sleeve", func(): return Craft.lathe([Vector3(0.03, 0, 0), Vector3(0.03, 0.047, 0.048), Vector3(-0.07, 0.052, 0.054), Vector3(-0.10, 0.056, 0.058), Vector3(-0.125, 0.050, 0.052), Vector3(-0.125, 0, 0)], 12), shirt)
		part(elbow, "forearm", func(): return Craft.lathe([Vector3(-0.10, 0, 0), Vector3(-0.10, 0.036, 0.034), Vector3(-0.25, 0.030, 0.028), Vector3(-0.27, 0, 0)], 10), skin)
		part(elbow, "bracer", func(): return Craft.lathe([Vector3(-0.115, 0, 0), Vector3(-0.115, 0.046, 0.044), Vector3(-0.15, 0.044, 0.042), Vector3(-0.235, 0.039, 0.037), Vector3(-0.235, 0, 0)], 12), dark_leather)
		part(elbow, "bracer_strap", func(): return Craft.lathe([Vector3(-0.18, 0, 0), Vector3(-0.18, 0.045, 0.043), Vector3(-0.20, 0.044, 0.042), Vector3(-0.20, 0, 0)], 12), leather)
		part(elbow, "hand", func(): return Craft.blob(Vector3(0.036, 0.046, 0.042)), skin, Vector3(0, -0.295, 0.004))
		Craft.ball(elbow, Vector3(-side * 0.026, -0.282, 0.022), Vector3(0.022, 0.034, 0.022), skin)
		var guard := Node3D.new()
		guard.position = Vector3(side * 0.012, 0.025, 0)
		guard.rotation.z = side * -0.38
		arm.add_child(guard)
		part(guard, "pauldron", func(): return Craft.blob(Vector3(0.096, 0.050, 0.092), func(p: Vector3): return Vector3(p.x, minf(p.y, 0.045) - maxf(0, -p.y) * 0.6, p.z)), silver)
		part(guard, "pauldron_lower", func(): return Craft.blob(Vector3(0.090, 0.034, 0.086)), silver, Vector3(0.0, -0.040, 0), Vector3(0, 0, side * -0.18))
		for z in [-0.05, 0.05]:
			Craft.ball(guard, Vector3(side * 0.03, 0.046, z), Vector3.ONE * 0.016, brass)
		Craft.box(guard, Vector3(-side * 0.04, 0.0, 0.0), Vector3(0.02, 0.06, 0.15), leather)
		arms.append(arm)
		elbows.append(elbow)

	# Compact child-sized arming sword; local +Z is the blade. Starts sheathed.
	var sword := Node3D.new()
	sword.name = "Sword"
	body.add_child(sword)
	Craft.ball(sword, Vector3(0, 0, -0.085), Vector3.ONE * 0.036, brass)
	part(sword, "grip", func(): return Craft.lathe([Vector3(-0.07, 0, 0), Vector3(-0.07, 0.016, 0.016), Vector3(0.05, 0.018, 0.018), Vector3(0.05, 0, 0)], 8), dark_leather, Vector3.ZERO, Vector3(PI / 2, 0, 0))
	part(sword, "guard", func(): return Craft.lathe([Vector3(-0.085, 0, 0), Vector3(-0.085, 0.012, 0.016), Vector3(0.0, 0.016, 0.022), Vector3(0.085, 0.012, 0.016), Vector3(0.085, 0, 0)], 8), brass, Vector3(0, 0, 0.06), Vector3(0, 0, PI / 2))
	for side in [-1.0, 1.0]:
		Craft.ball(sword, Vector3(side * 0.088, 0, 0.06), Vector3.ONE * 0.024, brass)
	part(sword, "blade", func(): return Craft.lathe([Vector3(0.0, 0, 0), Vector3(0.0, 0.026, 0.006), Vector3(0.36, 0.023, 0.006), Vector3(0.42, 0.010, 0.004), Vector3(0.45, 0, 0)], 8), steel, Vector3(0, 0, 0.065), Vector3(PI / 2, 0, 0))
	var sword_rest := Transform3D(Basis(scabbard.basis.x, scabbard.basis.z, -scabbard.basis.y), mouth + down * -0.06)
	sword.transform = sword_rest
	return {"root": root, "body": body, "legs": legs, "arms": arms, "elbows": elbows, "head": head, "sword": sword, "sword_rest": sword_rest, "scarf": scarf}
