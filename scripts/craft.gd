class_name Craft
extends RefCounted

static func material(color: Color, roughness: float = 0.85, glow: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	return m

static func mesh(parent: Node3D, shape: Mesh, position: Vector3, mat: Material, size: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = shape
	n.material_override = mat
	n.position = position
	n.scale = size
	parent.add_child(n)
	return n

static func box(parent: Node3D, position: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var s := BoxMesh.new()
	s.size = size
	return mesh(parent, s, position, mat)

static func ball(parent: Node3D, position: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radial_segments = 16
	s.rings = 8
	s.radius = 0.5
	s.height = 1.0
	return mesh(parent, s, position, mat, size)

static func cylinder(parent: Node3D, position: Vector3, bottom: float, top: float, height: float, mat: Material, sides: int = 12) -> MeshInstance3D:
	var s := CylinderMesh.new()
	s.bottom_radius = bottom
	s.top_radius = top
	s.height = height
	s.radial_segments = sides
	return mesh(parent, s, position, mat)

static func solid_box(parent: Node3D, position: Vector3, size: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = position
	body.collision_layer = 1
	parent.add_child(body)
	box(body, Vector3.ZERO, size, mat)
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	c.shape = s
	body.add_child(c)
	return body

static func ring(parent: Node3D, position: Vector3, radius: float, thickness: float, mat: Material) -> MeshInstance3D:
	var s := TorusMesh.new()
	s.inner_radius = maxf(0.01, radius - thickness)
	s.outer_radius = radius
	s.rings = 48
	s.ring_segments = 8
	return mesh(parent, s, position, mat)

# --- Cel-shaded character rendering -------------------------------------------------
# Two-tone toon lighting with a tinted shadow band, optional hard specular spot and a
# screen-space inverted-hull outline. Ambient is disabled so the shade tint stays clean.

const TOON_HEAD := """shader_type spatial;
render_mode ambient_light_disabled, cull_back;
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 shade : source_color = vec4(0.62, 0.58, 0.74, 1.0);
uniform vec4 spec_color : source_color = vec4(1.0);
uniform float gloss = 0.0;
uniform float band = 0.0;
uniform float boost = 1.15;
uniform float rim = 0.10;
"""

const TOON_LIGHT := """
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(0.0, 0.05, ndl) * smoothstep(0.3, 0.6, ATTENUATION);
	vec3 sun = LIGHT_COLOR / PI;
	DIFFUSE_LIGHT += mix(shade.rgb, vec3(1.0), lit) * sun * boost;
	DIFFUSE_LIGHT += sun * pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0) * rim * (0.35 + 0.65 * lit);
	if (gloss > 0.0) {
		float d = dot(NORMAL, normalize(LIGHT + VIEW));
		float s = smoothstep(gloss - 0.015, gloss + 0.015, d);
		if (band > 0.0) {
			s *= 1.0 - smoothstep(gloss + band - 0.015, gloss + band + 0.015, d);
		}
		SPECULAR_LIGHT += spec_color.rgb * s * lit * sun;
	}
}
"""

const TOON_FRAGMENT := """
void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
"""

const OUTLINE := """shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
uniform vec4 line : source_color = vec4(0.12, 0.08, 0.07, 1.0);
uniform float width = 1.4;
void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec2 px = (PROJECTION_MATRIX * vec4(mat3(MODELVIEW_MATRIX) * NORMAL, 0.0)).xy * VIEWPORT_SIZE;
	float len = length(px);
	if (len > 0.0001) {
		clip.xy += px / len / VIEWPORT_SIZE * 2.0 * width * clip.w;
	}
	POSITION = clip;
}
void fragment() {
	ALBEDO = line.rgb;
}
"""

static var _shaders := {}
## Multiplies every toon outline width; lowered for the pixel-art view.
static var outline_scale: float = 1.0
## Set by the pixel-art view so models drop detail that turns to noise at low resolution.
static var pixel_art: bool = false

static func shader(key: String, code: String) -> Shader:
	if not _shaders.has(key):
		var s := Shader.new()
		s.code = code
		_shaders[key] = s
	return _shaders[key]

static func outline(color: Color, width: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader("outline", OUTLINE)
	m.set_shader_parameter("line", color)
	m.set_shader_parameter("width", width * outline_scale)
	return m

## Toon material. `shade` multiplies the colour in shadow; `gloss` (0.85–0.99) adds a hard
## highlight; `code` swaps in a custom shader built from the TOON_* snippets.
static func toon(color: Color, shade: Color = Color("a39ac0"), gloss: float = 0.0, line_width: float = 1.4, line_color: Color = Color.TRANSPARENT, code: String = "") -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader("toon" if code == "" else str(code.hash()), code if code != "" else TOON_HEAD + TOON_LIGHT + TOON_FRAGMENT)
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("shade", shade)
	m.set_shader_parameter("gloss", gloss)
	if line_width > 0:
		var line := line_color if line_color.a > 0 else color.darkened(0.7).lerp(Color("21140f"), 0.55)
		m.next_pass = outline(line, line_width)
	return m

# --- Procedural mesh builders -------------------------------------------------------

## Smooth closed surface from stacked rings of points; a one-point ring is a pole.
static func ring_mesh(rings: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var starts: Array[int] = []
	var count := 0
	for ring in rings:
		starts.append(count)
		for p in ring:
			st.add_vertex(p)
		count += ring.size()
	for r in range(rings.size() - 1):
		var a: Array = rings[r]
		var b: Array = rings[r + 1]
		var sa := starts[r]
		var sb := starts[r + 1]
		if a.size() == 1:
			for i in range(b.size()):
				_tri(st, sa, sb + (i + 1) % b.size(), sb + i)
		elif b.size() == 1:
			for i in range(a.size()):
				_tri(st, sa + i, sa + (i + 1) % a.size(), sb)
		else:
			for i in range(a.size()):
				var j := (i + 1) % a.size()
				_tri(st, sa + i, sa + j, sb + j)
				_tri(st, sa + i, sb + j, sb + i)
	st.generate_normals()
	return st.commit()

static func _tri(st: SurfaceTool, a: int, b: int, c: int) -> void:
	st.add_index(a)
	st.add_index(b)
	st.add_index(c)

## Surface of revolution around +Y. Profile items: Vector3(y, radius_x, radius_z) or
## Vector4(y, radius_x, radius_z, z_offset); a zero radius closes the end with a pole.
static func lathe(profile: Array, sides: int = 16) -> ArrayMesh:
	var rings := []
	if profile[0].x > profile[-1].x:
		profile = profile.duplicate()
		profile.reverse()
	for p in profile:
		var dz: float = p.w if p is Vector4 else 0.0
		if p.y <= 0.0001:
			rings.append([Vector3(0, p.x, dz)])
			continue
		var ring := []
		for i in range(sides):
			var a := TAU * i / sides
			ring.append(Vector3(cos(a) * p.y, p.x, sin(a) * p.z + dz))
		rings.append(ring)
	return ring_mesh(rings)

## Ellipsoid with an optional `deform(Vector3) -> Vector3` sculpt pass.
static func blob(radii: Vector3, deform: Callable = Callable(), rings: int = 12, sides: int = 18) -> ArrayMesh:
	var out := []
	for j in range(rings + 1):
		var phi := lerpf(-PI / 2, PI / 2, float(j) / rings)
		var ring := []
		var n := 1 if j == 0 or j == rings else sides
		for i in range(n):
			var a := TAU * i / sides
			var p := Vector3(cos(phi) * cos(a) * radii.x, sin(phi) * radii.y, cos(phi) * sin(a) * radii.z)
			ring.append(deform.call(p) if deform.is_valid() else p)
		out.append(ring)
	return ring_mesh(out)

## Tapered, flattened lock along +Y that bends toward +Z by `curl` radians (hair, cloth tails).
static func strand(length: float, width: float, depth: float, curl: float, tip: float = 0.0, segments: int = 6, sides: int = 6) -> ArrayMesh:
	var rings := []
	var c := Vector3.ZERO
	rings.append([Vector3(0, -depth * 0.5, 0)])
	for s in range(segments + 1):
		var t := float(s) / segments
		var a := curl * t
		var tangent := Vector3(0, cos(a), sin(a))
		var normal := Vector3(0, -sin(a), cos(a))
		var w := width * lerpf(1.0, tip, pow(t, 1.3)) * (1.0 + 0.25 * sin(t * PI))
		var d := depth * lerpf(1.0, maxf(tip, 0.25), t)
		if s == segments and tip <= 0.0:
			rings.append([c])
			break
		var ring := []
		for i in range(sides):
			var r := TAU * i / sides
			ring.append(c + Vector3.RIGHT * cos(r) * w + normal * sin(r) * d)
		rings.append(ring)
		c += tangent * length / segments
	if tip > 0.0:
		rings.append([c - Vector3(0, cos(curl), sin(curl)) * length / segments * 0.5])
	return ring_mesh(rings)

## Orients a node so local +Y follows `direction` and local +Z leans toward `face`.
static func orient(node: Node3D, origin: Vector3, direction: Vector3, face: Vector3) -> Node3D:
	var y := direction.normalized()
	var z := (face - y * face.dot(y)).normalized()
	node.transform = Transform3D(Basis(y.cross(z), y, z), origin)
	return node
