class_name BladeFX
extends Node3D
## Geometry/shader effects stay transparent; no opaque discs covering the character.
var arena: Node3D
var kind := "wind"
var life := 0.45
var age := 0.0
var color := Color("80e8f0")
var radius := 0.7
var direction := Vector3.FORWARD
var end_point := Vector3.ZERO
var meshes: Array[MeshInstance3D] = []
var flame_material: ShaderMaterial
var painted: Sprite3D
func material(tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = tint
	return m
func ribbon(points: Array[Vector3], width: float, tint: Color) -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size()-1):
		var axis := points[i+1]-points[i]
		var side := axis.cross(arena.camera.global_basis.z).normalized()*width
		for p in [points[i]-side,points[i]+side,points[i+1]+side,points[i]-side,points[i+1]+side,points[i+1]-side]:
			mesh.surface_add_vertex(p)
	mesh.surface_end()
	var draw := MeshInstance3D.new()
	draw.mesh = mesh
	draw.material_override = material(tint)
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(draw)
	meshes.append(draw)
func _ready() -> void:
	add_to_group("blade_fx")
	if kind in ["wind","tornado","fire","fireball"]:
		painted = Sprite3D.new()
		painted.texture = preload("res://assets/hero/three-swords/effects.png")
		painted.hframes = 4
		painted.vframes = 3
		painted.frame_coords = Vector2i(0,0 if kind in ["wind","tornado"] else (1 if kind=="fire" else 2))
		painted.pixel_size = radius*2.0/300.0*(0.86 if kind=="tornado" else 1.0)
		painted.offset.y = 140
		painted.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		painted.shaded = false
		painted.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		painted.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		if kind=="fireball":
			painted.position.y = 0.72
			painted.offset.y = 45
			painted.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			painted.basis = arena.camera.global_basis*Basis(Vector3.BACK,atan2(direction.dot(arena.camera.global_basis.y),direction.dot(arena.camera.global_basis.x)))
		add_child(painted)
		return
	if kind=="charge":
		var shader := Shader.new()
		shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform float age = 0.0;
void fragment(){
 float y=1.0-UV.y;
 float flicker=sin(y*14.0-age*22.0)*0.05+sin(y*31.0+age*17.0)*0.025;
 float x=abs(UV.x-0.5+flicker*y);
 float w=(1.0-y)*0.43+0.015;
 float shape=(1.0-smoothstep(w*0.36,w,x))*(1.0-smoothstep(0.54,0.96,y));
 shape*=smoothstep(0.0,0.08,y);
 ALBEDO=mix(vec3(1.0,0.14,0.025),vec3(1.0,0.87,0.40),pow(1.0-y,2.5));
 ALPHA=shape*0.84;
}"""
		flame_material = ShaderMaterial.new()
		flame_material.shader = shader
		var right := Vector3(-direction.z,0,direction.x)
		for i in range(3):
			var quad := QuadMesh.new()
			quad.size = Vector2(radius*1.12,0.7)
			var draw := MeshInstance3D.new()
			draw.mesh = quad
			draw.material_override = flame_material
			draw.basis = arena.camera.global_basis
			draw.position = right*(i-1)*radius*0.48+Vector3.UP*0.35
			draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(draw)
			meshes.append(draw)
	elif kind=="arc":
		var points: Array[Vector3] = []
		for i in range(9):
			var t := i/8.0
			points.append(end_point*t+arena.camera.global_basis.y*(sin(i*12.7)*0.15 if i>0 and i<8 else 0))
		ribbon(points,0.055,Color(color,0.45))
		ribbon(points,0.018,Color("fff9d4"))
	elif kind=="thunder":
		for band in range(3):
			var points: Array[Vector3] = []
			for i in range(25):
				var angle := i/24.0*TAU
				var jag := 1.0+sin(i*8.9+band*2.1)*0.17
				points.append(Vector3(cos(angle)*radius*jag,sin(angle)*radius*0.7*jag+0.8,sin(angle+band)*radius*0.5))
			ribbon(points,0.018,Color(color,0.78))
func _physics_process(delta: float) -> void:
	if arena.menu_open:
		return
	age += delta
	if flame_material:
		flame_material.set_shader_parameter("age",age)
	if kind=="thunder":
		rotation.y += delta*11
	var fade := clampf((age/life-0.65)/0.35,0,1) if life<100 else 0.0
	if painted:
		var row := painted.frame_coords.y
		painted.frame_coords = Vector2i(int(age/0.075)%4,row)
		painted.modulate.a = (1.0-fade)*(0.82 if kind=="tornado" else 1.0)
	for draw in meshes:
		draw.transparency = fade
	if age>=life:
		queue_free()
