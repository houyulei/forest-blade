class_name ChapterLandscape
extends ForestSanctuary
## Three authored rooms share painted scenery, actual ground and solid obstacles.
var zone := "village"
var extent := Vector2(11,11)
var route: Array[Vector3] = []
var gate: StaticBody3D
var gate_art: Node3D

func build() -> void:
	rng.seed = 20261023
	anchors = JSON.parse_string(FileAccess.get_file_as_string(ART+"anchors.json"))
	for key in anchors:
		artwork[key] = load(ART+key+".png")
	var extra: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/chapter-one/regions.json"))
	for key in extra:
		var texture: Texture2D = load("res://assets/chapter-one/"+key+".png")
		artwork[key] = texture
		anchors[key] = {"anchor":float(extra[key].anchor)}
	match zone:
		"village":
			extent = Vector2(11,11)
			route = [Vector3(0,0,8),Vector3(0,0,2),Vector3(0,0,-3),Vector3(0,0,-9)]
		"forest":
			extent = Vector2(12,20)
			route = [Vector3(0,0,18),Vector3(-2,0,11),Vector3(2,0,4),Vector3(-2,0,-3),Vector3(2,0,-10),Vector3(0,0,-18)]
		"cave":
			extent = Vector2(10,16)
			route = [Vector3(0,0,14),Vector3(-1,0,7),Vector3(0,0,1),Vector3(0,0,-7)]
	chapter_ground()
	for i in range(route.size()-1):
		path_strip(route[i],route[i+1],2.5 if zone!="cave" else 3.2)
	match zone:
		"village": village()
		"forest": goblin_forest()
		"cave": cavern()

func chapter_ground() -> void:
	collider(Vector3(0,-0.2,0),Vector3(extent.x*2+12,0.4,extent.y*2+12))
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = extent*2+Vector2(60,60)
	mesh.mesh = plane
	mesh.position.y = 0.005
	var shader := Shader.new()
	shader.code = """shader_type spatial; render_mode unshaded;
uniform sampler2D paint : source_color,filter_linear_mipmap_anisotropic;
uniform vec3 tint=vec3(1.0); uniform vec2 tile_origin=vec2(0.0);
void fragment(){vec2 p=tile_origin+vec2(0.004)+fract(UV*24.0)*0.492;vec3 c=texture(paint,p).rgb;ALBEDO=c*tint;ROUGHNESS=1.0;}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("paint",terrain_texture())
	mat.set_shader_parameter("tile_origin",Vector2(0,0.5) if zone=="cave" else Vector2.ZERO)
	mat.set_shader_parameter("tint",Vector3(0.66,0.73,0.80) if zone=="cave" else (Vector3(0.79,0.90,0.78) if zone=="forest" else Vector3(1.0,1.0,0.92)))
	mesh.material_override = mat
	add_child(mesh)
	for side in [-1,1]:
		collider(Vector3(side*extent.x,2,0),Vector3(0.6,4,extent.y*2))
		collider(Vector3(0,2,side*extent.y),Vector3(extent.x*2,4,0.6))

func path_strip(a: Vector3,b: Vector3,width: float) -> void:
	var node := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(width,a.distance_to(b)+1.2)
	node.mesh = plane
	node.position = (a+b)*0.5+Vector3.UP*0.012
	node.rotation.y = atan2(b.x-a.x,b.z-a.z)
	var shader := Shader.new()
	shader.code = """shader_type spatial; render_mode unshaded,depth_draw_never;
uniform vec3 dirt=vec3(1.0); uniform vec2 tile_origin=vec2(0.5,0.0); uniform sampler2D paint : source_color,filter_linear_mipmap_anisotropic;
float hash(vec2 p){return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453);}
void fragment(){float n=hash(floor(UV*vec2(60.,180.)));float edge=1.0-smoothstep(0.28,0.50,abs(UV.x-0.5)+n*0.08);vec3 c=texture(paint,tile_origin+vec2(0.004)+fract(UV*vec2(1.0,3.0))*0.492).rgb;ALBEDO=c*dirt;ALPHA=edge*0.88*smoothstep(0.0,0.12,UV.y)*(1.0-smoothstep(0.88,1.0,UV.y));}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("paint",terrain_texture())
	mat.set_shader_parameter("tile_origin",Vector2(0.5,0.5) if zone=="village" else (Vector2(0,0.5) if zone=="cave" else Vector2(0.5,0)))
	mat.set_shader_parameter("dirt",Vector3(0.85,0.90,0.98) if zone=="cave" else Vector3(1.0,1.0,0.95))
	node.material_override = mat
	add_child(node)

func terrain_texture() -> Texture2D:
	return load("res://assets/chapter-one/terrain-source.png")

func signpost(text: String,p: Vector3,color: Color = Color("ecd5a0")) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 27
	label.pixel_size = 0.007
	label.position = p+camera.global_basis.y*1.35
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color
	label.outline_modulate = Color("15271f")
	add_child(label)

func tree(p: Vector3,height: float,type_: String = "oak") -> void:
	var item := card(type_,p,height)
	item.set_meta("painted_height",height)
	tall_cards.append(item)
	collider(p+Vector3.UP,Vector3(0.65,2,0.65))
	contact_shadow(p,Vector2(2,1.25),0.24)

func village() -> void:
	for data in [["cottage",Vector3(-4.5,0,-2.8),3.8],["inn",Vector3(4.4,0,-3.5),4.0],["cottage",Vector3(-6,0,4.3),3.4]]:
		card(data[0],data[1],data[2])
		collider(data[1]+Vector3(0,0.85,-0.25),Vector3(2.4,1.7,1.6))
	card("well",Vector3(-2.7,0,0.4),1.65)
	collider(Vector3(-2.7,0.55,0.4),Vector3(0.9,1.1,0.8))
	signpost("青芽村 · 新手村",Vector3(0,0,6))
	signpost("北行 · 波克布林森林",Vector3(0,0,-8))
	signpost("林间旅舍",Vector3(4.4,0,-3.5))
	for data in [[-8,-7],[8,-8],[-9,0],[8,7],[-7,8]]:
		tree(Vector3(data[0],0,data[1]),4.6,"birch")
	for i in range(16):
		var p := Vector3(-8.5+i%4*1.1,0,-7.5+i/4*0.7)
		card("flowers",p,0.35+rng.randf()*0.25)
	lantern(Vector3(-1.5,0,-6))
	lantern(Vector3(1.5,0,5))
	card("log",Vector3(5.9,0,3.8),0.75)
	card("ferns",Vector3(-4.3,0,2.0),0.65)

func goblin_forest() -> void:
	# Broad, winding clearings stay open; trunks never sit on the authored route.
	for z in range(-18,20,4):
		for side in [-1,1]:
			tree(Vector3(side*(7.5+rng.randf()*2),0,z+rng.randf()),4.5+rng.randf()*1.0,"oak" if z%8!=0 else "birch")
			for j in range(3):
				card("ferns" if j%2==0 else "bramble",Vector3(side*(6.4+rng.randf()*2),0,z+j*0.65),0.55+rng.randf()*0.3)
	for data in [[Vector3(-3.5,0,10),"南林哨点"],[Vector3(3.5,0,0),"倒木营地"],[Vector3(-3.5,0,-10),"深林入口"]]:
		card("log",data[0]+Vector3(-1,0,0),0.8)
		card("fallen",data[0]+Vector3(1,0,-1),0.7)
		lantern(data[0]+Vector3(0,0,-1.5))
		signpost(data[1],data[0]+Vector3(0,0,-2))
	card("cave",Vector3(0,0,-18.0),4.0)
	collider(Vector3(-1.85,1,-18),Vector3(0.65,2,0.7))
	collider(Vector3(1.85,1,-18),Vector3(0.65,2,0.7))
	signpost("深林深处 · 幽根洞穴",Vector3(0,0,-16))
	signpost("南行 · 返回青芽村",Vector3(0,0,17))
	for p in [Vector3(4,0,7),Vector3(-4.7,0,-5),Vector3(5,0,-13)]:
		card("rocks",p,0.8)
		collider(p+Vector3.UP*0.3,Vector3(0.7,0.6,0.7))
	atmosphere()

func lantern(p: Vector3) -> void:
	card("lantern",p,1.0)
	var light := OmniLight3D.new()
	light.position = p+Vector3.UP*0.7
	light.light_color = Color("ffbd70")
	light.light_energy = 0.7
	light.omni_range = 3.0
	add_child(light)

func cavern() -> void:
	for z in range(-14,16,4):
		for side in [-1,1]:
			var p := Vector3(side*8.7,0,z)
			card("cave_wall",p,3.8)
			collider(p+Vector3.UP,Vector3(1.0,2.0,3.0))
			card("stalagmites",p+Vector3(-side*0.5,0,1),1.5)
	for x in [-6,-3,0,3,6]:
		card("cave_wall",Vector3(x,0,-14),4.4)
	for side in [-1,1]:
		card("cave_wall",Vector3(side*4.5,0,5.2),2.7)
		collider(Vector3(side*4.5,1,5.2),Vector3(2.1,2,2.4))
		card("stalagmites",Vector3(side*5.7,0,-5),1.5)
		lantern(Vector3(side*3.5,0,-10))
	card("cave",Vector3(0,0,15),3.5)
	signpost("返回波克布林森林",Vector3(0,0,13))
	signpost("黄金波克布林 · 巢穴",Vector3(0,0,-11),Color("ffcb71"))
	# A visible seal closes only after the player enters the boss clearing.
	gate = collider(Vector3(0,1,1.2),Vector3(17.0,2,0.35))
	gate.name = "BossSealCollision"
	gate_art = Node3D.new()
	add_child(gate_art)
	for x in range(-8,9):
		var ring := Craft.ring(gate_art,Vector3(x,0.08,1.2),0.38,0.04,Craft.material(Color("e9b653"),0.5,0.8))
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Craft.box(gate_art,Vector3(0,0.12,1.2),Vector3(16.5,0.025,0.12),Craft.material(Color(0.95,0.65,0.22,0.65),0.5,0.5))
	set_gate(false)

func set_gate(closed: bool) -> void:
	if is_instance_valid(gate):
		gate.get_child(0).set_deferred("disabled",not closed)
		gate_art.visible = closed
