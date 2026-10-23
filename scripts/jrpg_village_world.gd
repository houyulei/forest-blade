class_name JRPGVillageWorld
extends Node3D
## Shared authored layout, two genuinely different scenery pipelines.
const ART := "res://assets/jrpg-style-study/"
const HOUSES := [Vector3(-6.5,0,1.0),Vector3(6,0,-6),Vector3(-5.8,0,-12)]
const TREES := [Vector3(-12,0,9),Vector3(-12,0,-5),Vector3(13.5,0,-8),Vector3(2,0,-19),Vector3(-12,0,-18),Vector3(13,0,-20),Vector3(17,0,3)]
var route := "vesperia"
var rng := RandomNumberGenerator.new()
var mats := {}
var solids := 0
var painted_cards: Array[Sprite3D] = []
var house_roots: Array[Node3D] = []
var scenery_root: Node3D
const GROUND := """shader_type spatial;
render_mode cull_disabled;
uniform bool retro=false;
uniform sampler2D meadow:source_color,filter_linear_mipmap,repeat_enable;
varying vec3 world;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float line_dist(vec2 p,vec2 a,vec2 b){vec2 d=b-a;return length(p-a-clamp(dot(p-a,d)/dot(d,d),0.0,1.0)*d);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float n=noise(world.xz*0.4)*0.65+noise(world.xz*1.8)*0.35;
 vec3 c=mix(vec3(0.21,0.35,0.16),vec3(0.37,0.50,0.22),n);
 if(!retro){c=mix(vec3(0.29,0.42,0.20),vec3(0.46,0.58,0.30),n);}
 vec3 painted_grass=texture(meadow,world.xz*0.21).rgb;
 c=mix(c,painted_grass,retro?0.42:0.32);
 float d=min(line_dist(world.xz,vec2(0,19),vec2(0,2)),line_dist(world.xz,vec2(0,2),vec2(-0.5,-22)));
 d=min(d,line_dist(world.xz,vec2(0,5),vec2(-6.5,4)));
 d=min(d,line_dist(world.xz,vec2(0,-4),vec2(6,-3)));
 d=min(d,line_dist(world.xz,vec2(0,-9),vec2(-5.8,-9)));
 d=min(d,line_dist(world.xz,vec2(0,9),vec2(11,9)));
 float road=1.0-smoothstep(1.15,1.65,d+noise(world.xz*3.0)*0.12);
 vec3 soil=mix(vec3(0.49,0.40,0.28),vec3(0.66,0.56,0.39),n);
 c=mix(c,soil,road);
 float square=1.0-smoothstep(2.2,2.6,length(world.xz-vec2(-0.4,2.8)));
 vec2 grid=world.xz*2.3;grid.x+=mod(floor(grid.y),2.0)*0.5;
 vec2 f=fract(grid);float edge=smoothstep(0.03,0.09,min(min(f.x,f.y),min(1.0-f.x,1.0-f.y)));
 c=mix(c,mix(vec3(0.37,0.38,0.32),vec3(0.61,0.61,0.50),edge)*(0.94+hash(floor(grid))*0.12),square);
 ALBEDO=c*0.73;ROUGHNESS=1.0;SPECULAR=0.0;
}
"""

func height_at(x: float,z: float) -> float:
	var h := 0.12*sin(x*0.18)*cos(z*0.13)+0.7*(1.0-smoothstep(-24.0,-8.0,z))
	var creek := absf(x-(11.5+sin(z*0.13)*0.7))
	return lerpf(-0.65,h,smoothstep(1.1,2.0,creek))

func ground_point(p: Vector3) -> Vector3:
	return Vector3(p.x,height_at(p.x,p.z),p.z)

func mat(id: String,color: Color,texture_path: String = "") -> Material:
	if mats.has(id):
		return mats[id]
	var m: Material
	if route=="vesperia":
		var code := ""
		if texture_path!="":
			code = Craft.TOON_HEAD+"uniform sampler2D artwork:source_color,filter_linear_mipmap,repeat_enable;\n"+Craft.TOON_LIGHT+"void fragment(){ALBEDO=texture(artwork,UV).rgb*albedo.rgb;ROUGHNESS=1.0;SPECULAR=0.0;}"
		if id.begins_with("cloth"):
			code = Craft.TOON_HEAD.replace("cull_back;","cull_back, shadows_disabled;")+Craft.TOON_LIGHT+Craft.TOON_FRAGMENT
		m = Craft.toon(color,Color("b4bfd0"),0,0.7,Color("514d50"),code)
		m.set_shader_parameter("boost",1.0)
		m.set_shader_parameter("rim",0.025)
		if texture_path!="":
			m.set_shader_parameter("artwork",load(texture_path))
	else:
		var standard := StandardMaterial3D.new()
		standard.albedo_color = color
		standard.roughness = 1.0
		standard.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		if texture_path!="":
			standard.albedo_texture = load(texture_path)
		m = standard
	mats[id] = m
	return m

func box(parent: Node3D,p: Vector3,size_: Vector3,m: Material,solid := false) -> Node3D:
	if solid:
		solids += 1
		return Craft.solid_box(parent,p,size_,m)
	return Craft.box(parent,p,size_,m)

func collider(parent: Node3D,p: Vector3,size_: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	cube.size = size_
	shape.shape = cube
	body.position = p
	body.add_child(shape)
	parent.add_child(body)
	solids += 1

func beam(parent: Node3D,a: Vector3,b: Vector3,width: float,m: Material) -> void:
	var node := Craft.box(parent,(a+b)*0.5,Vector3(width,a.distance_to(b),width),m)
	Craft.orient(node,(a+b)*0.5,b-a,Vector3.FORWARD)

func build() -> void:
	rng.seed = 20261025
	terrain()
	scenery_root = Node3D.new()
	scenery_root.name = "Scenery"
	add_child(scenery_root)
	water_and_bridge()
	for i in range(HOUSES.size()):
		var root_ := Node3D.new()
		root_.name = "House%d"%i
		root_.position = ground_point(HOUSES[i])
		scenery_root.add_child(root_)
		house_roots.append(root_)
		collider(root_,Vector3(0,1.7,0),Vector3(4.8,3.4,4.5))
		if route=="vesperia":
			modeled_house(root_,i)
		else:
			painted_card(root_,"ys-cottage.png",Vector3(1.5,0,1.5),6.9)
			contact_shadow(root_.position,Vector2(6.7,5.5),0.27)
	for i in range(TREES.size()):
		var p := ground_point(TREES[i])
		collider(scenery_root,p+Vector3.UP*1.4,Vector3(0.65,2.8,0.65))
		if route=="vesperia":
			modeled_tree(p,0.85+(i%3)*0.12)
		else:
			painted_card(scenery_root,"ys-oak.png",p,7.3+(i%3)*0.5)
			contact_shadow(p,Vector2(5.8,4.5),0.22)
	well()
	garden_edges()
	grass_and_flowers()
	boundary()

func terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(140):
		for x in range(140):
			var a := Vector3(x-70,0,z-90)
			for v in [a,a+Vector3.RIGHT,a+Vector3.BACK,a+Vector3.RIGHT,a+Vector3(1,0,1),a+Vector3.BACK]:
				v.y = height_at(v.x,v.z)
				st.add_vertex(v)
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.name = "Terrain"
	node.mesh = st.commit()
	var m := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = GROUND
	m.shader = shader
	m.set_shader_parameter("retro",route=="ys")
	m.set_shader_parameter("meadow",load(ART+"grass.png"))
	node.material_override = m
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	node.create_trimesh_collision()
	solids += 1

func triangle_mesh(parent: Node3D,points: Array,m: Material,uvs: Array = []) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size()):
		if not uvs.is_empty():
			st.set_uv(uvs[i])
		st.add_vertex(points[i])
	st.generate_normals()
	return Craft.mesh(parent,st.commit(),Vector3.ZERO,m)

func modeled_house(root_: Node3D,index: int) -> void:
	var wall := mat("wall",Color("e5d5ae"))
	var wood := mat("wood",Color("756044"))
	var trim := mat("trim",Color("b49b6e"))
	var stone := mat("stone",Color.WHITE,ART+"stone.png")
	var roof := mat("roof",Color("d6deef"),ART+"slate.png")
	var roof_edge := mat("roofedge",Color("59697d"))
	var glass := mat("glass",Color("7395a4"))
	box(root_,Vector3(0,0.48,0),Vector3(4.9,0.9,4.6),stone)
	box(root_,Vector3(0,2.0,0),Vector3(4.6,2.3,4.3),wall)
	# Slightly projecting upper structure and deep eaves establish a distinct JRPG building silhouette.
	box(root_,Vector3(0,3.18,0),Vector3(4.85,0.3,4.5),wood)
	for z in [-2.16,2.16]:
		var vertices := [Vector3(-2.3,3.3,z),Vector3(2.3,3.3,z),Vector3(0,5.65,z)]
		if z>0:
			vertices.reverse()
		triangle_mesh(root_,vertices,wall)
	for x in [-2.27,0,2.27]:
		for z in [-2.18,2.18]:
			box(root_,Vector3(x,2.0,z),Vector3(0.16,2.55,0.18),wood)
	for side in [-1,1]:
		# The bowed roof is a textured mesh, not an image facing the camera.
		for row in range(10):
			var t0 := row/10.0
			var t1 := (row+1)/10.0
			var x0: float = side*t0*2.95
			var x1: float = side*t1*2.95
			var y0 := 5.72-t0*3.0+t0*t0*0.4
			var y1 := 5.72-t1*3.0+t1*t1*0.4
			var vs := [Vector3(x0,y0,-2.65),Vector3(x1,y1,-2.65),Vector3(x0,y0,2.65),Vector3(x0,y0,2.65),Vector3(x1,y1,-2.65),Vector3(x1,y1,2.65)]
			var uv := [Vector2(0,t0*1.5),Vector2(0,t1*1.5),Vector2(1.6,t0*1.5),Vector2(1.6,t0*1.5),Vector2(0,t1*1.5),Vector2(1.6,t1*1.5)]
			if side<0:
				vs.reverse()
				uv.reverse()
			triangle_mesh(root_,vs,roof,uv)
		for z in [-2.66,2.66]:
			beam(root_,Vector3(0,5.75,z),Vector3(side*2.95,3.12,z),0.17,roof_edge)
		beam(root_,Vector3(side*2.95,3.1,-2.7),Vector3(side*2.95,3.1,2.7),0.17,roof_edge)
		for z in [-1.5,0,1.5]:
			beam(root_,Vector3(side*2.28,2.55,z),Vector3(side*2.85,3.15,z),0.12,wood)
		# Side windows expose depth when approaching the cottage from the road.
		for z in [-1,1]:
			box(root_,Vector3(side*2.34,2.05,z),Vector3(0.1,1.0,0.7),glass)
			for dz in [-0.4,0,0.4]:
				box(root_,Vector3(side*2.41,2.05,z+dz),Vector3(0.12,1.14,0.07),wood)
	beam(root_,Vector3(0,5.8,-2.8),Vector3(0,5.8,2.8),0.2,roof_edge)
	for x in [-1.55,1.55]:
		window(root_,Vector3(x,2.13,2.22),glass,wood,trim)
	# A recessed arched entrance, threshold and carved frame.
	box(root_,Vector3(0,1.36,2.22),Vector3(1.13,2.0,0.1),mat("door",Color("876448")))
	for x in [-0.67,0.67]:
		box(root_,Vector3(x,1.45,2.29),Vector3(0.16,2.2,0.23),stone)
	for i in range(9):
		var a := i*PI/8
		var block_ := box(root_,Vector3(cos(a)*0.65,2.42+sin(a)*0.47,2.3),Vector3(0.24,0.22,0.25),stone)
		block_.rotation.z = a-PI/2
	Craft.ball(root_,Vector3(0.35,1.4,2.34),Vector3.ONE*0.13,mat("brass",Color("d5b46b")))
	for row in range(3):
		box(root_,Vector3(0,0.12+row*0.1,3.05-row*0.3),Vector3(1.6,0.24,1.0-row*0.18),stone)
	window(root_,Vector3(0,4.12,2.23),glass,wood,trim,0.7)
	for side in [-1,1]:
		beam(root_,Vector3(side*2.2,3.4,2.24),Vector3(side*0.5,5.1,2.24),0.13,wood)
	box(root_,Vector3(1.35,5.5,-0.65),Vector3(0.6,1.65,0.65),stone)
	box(root_,Vector3(1.35,6.34,-0.65),Vector3(0.82,0.14,0.84),trim)
	awning(root_,index)
	lantern(root_,Vector3(0.95,2.35,2.65))
	# A hanging painted shop plaque supplies a readable landmark without screen UI.
	beam(root_,Vector3(-2.3,2.6,1.4),Vector3(-3.0,2.6,1.4),0.09,wood)
	box(root_,Vector3(-2.95,2.20,1.4),Vector3(0.12,0.6,0.66),mat("sign%d"%index,[Color("b47d69"),Color("7d96a5"),Color("a4a572")][index]))

func window(parent: Node3D,p: Vector3,glass: Material,wood: Material,trim: Material,factor := 1.0) -> void:
	box(parent,p,Vector3(0.85,1.15,0.12)*factor,glass)
	for dx in [-0.48,0,0.48]:
		box(parent,p+Vector3(dx*factor,0,0.1),Vector3(0.07,1.3,0.1)*factor,wood)
	for dy in [-0.6,0,0.6]:
		box(parent,p+Vector3(0,dy*factor,0.1),Vector3(1.08,0.07,0.1)*factor,wood)
	box(parent,p+Vector3(0,-0.69*factor,0.2),Vector3(1.2,0.15,0.36)*factor,trim)

func awning(parent: Node3D,index: int) -> void:
	var cloth := mat("cloth%d"%index,[Color("d5bc8b"),Color("acbac3"),Color("bac398")][index])
	for i in range(12):
		var z0 := 2.2+i/12.0*1.4
		var z1 := 2.2+(i+1)/12.0*1.4
		var y0 := 2.95-(z0-2.2)*0.24-sin((z0-2.2)/1.4*PI)*0.12
		var y1 := 2.95-(z1-2.2)*0.24-sin((z1-2.2)/1.4*PI)*0.12
		triangle_mesh(parent,[Vector3(-1.15,y0,z0),Vector3(1.15,y0,z0),Vector3(-1.15,y1,z1),Vector3(1.15,y0,z0),Vector3(1.15,y1,z1),Vector3(-1.15,y1,z1)],cloth)
	for x in [-1.18,1.18]:
		beam(parent,Vector3(x,0.15,3.6),Vector3(x,2.65,3.6),0.09,mat("wood",Color.WHITE))

func lantern(parent: Node3D,p: Vector3) -> void:
	var metal := mat("iron",Color("53636b"))
	beam(parent,p+Vector3(0,0.3,-0.2),p+Vector3(0,0.3,0.1),0.06,metal)
	box(parent,p,Vector3(0.21,0.35,0.2),mat("lamp",Color("e4c079")))
	for x in [-0.13,0.13]:
		for z in [-0.13,0.13]:
			beam(parent,p+Vector3(x,-0.22,z),p+Vector3(x,0.22,z),0.035,metal)
	for y in [-0.24,0.24]:
		box(parent,p+Vector3(0,y,0),Vector3(0.32,0.07,0.32),metal)

func tapered_branch(parent: Node3D,points: Array,radii: Array,m: Material) -> void:
	var rings: Array = []
	for i in range(points.size()):
		var d: Vector3 = (points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)]).normalized()
		var right := d.cross(Vector3.FORWARD).normalized()
		var forward := d.cross(right).normalized()
		var ring: Array = []
		for j in range(10):
			var a := j*TAU/10
			ring.append(points[i]+(right*cos(a)+forward*sin(a))*radii[i])
		rings.append(ring)
	Craft.mesh(parent,Craft.ring_mesh(rings),Vector3.ZERO,m)

func modeled_tree(p: Vector3,factor: float) -> void:
	var root_ := Node3D.new()
	root_.position = p
	root_.scale = Vector3.ONE*factor
	scenery_root.add_child(root_)
	var bark := mat("bark",Color("807054"))
	tapered_branch(root_,[Vector3.ZERO,Vector3(0.15,0.8,0),Vector3(-0.3,2,0.1),Vector3(0.25,3.4,0),Vector3(1.7,4.8,0)],[0.48,0.35,0.28,0.20,0.02],bark)
	tapered_branch(root_,[Vector3(-0.2,1.8,0.1),Vector3(-0.8,3.0,0),Vector3(-1.7,4.4,0.5)],[0.24,0.15,0.02],bark)
	tapered_branch(root_,[Vector3(0.1,2.8,0),Vector3(0.1,4.0,-0.9),Vector3(0,5,-1.5)],[0.19,0.12,0.02],bark)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2(1.7,1.7)
	multi.mesh = quad
	multi.instance_count = 480
	var centers := [Vector3(-1.7,4.6,0.5),Vector3(1.5,4.9,0),Vector3(0,5.3,-1.3),Vector3(0.3,4.6,1.3)]
	for i in range(multi.instance_count):
		var a := rng.randf()*TAU
		var radius := sqrt(rng.randf())*1.75
		var center: Vector3 = centers[i%4]+Vector3(cos(a)*radius,rng.randf_range(-0.5,0.7),sin(a)*radius)
		var basis_ := Basis.from_euler(Vector3(rng.randf()*PI,rng.randf()*TAU,rng.randf()*TAU)).scaled(Vector3.ONE*rng.randf_range(0.7,1.1))
		multi.set_instance_transform(i,Transform3D(basis_,center))
		multi.set_instance_color(i,Color.from_hsv(0.23,0.25,rng.randf_range(0.8,1.0)))
	var leaves := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """shader_type spatial;render_mode cull_disabled;
uniform sampler2D leaf_texture:source_color,filter_linear_mipmap;
uniform float base_height=3.0;
uniform float crown_height=2.5;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;VERTEX.x+=sin(TIME*1.2+world.x*0.4)*0.025;}
void fragment(){vec4 tex=texture(leaf_texture,UV);ALPHA=tex.a;ALPHA_SCISSOR_THRESHOLD=0.4;float h=clamp((world.y-base_height)/crown_height,0.0,1.0);ALBEDO=mix(vec3(0.23,0.36,0.15),vec3(0.45,0.58,0.28),h)*(0.88+tex.r*0.20);NORMAL=normalize((VIEW_MATRIX*vec4(0,1,0,0)).xyz);ROUGHNESS=1.0;SPECULAR=0.0;}
"""
	leaves.shader = shader
	leaves.set_shader_parameter("leaf_texture",load("res://assets/style-volume-v2/foliage-card.png"))
	leaves.set_shader_parameter("base_height",p.y+3.5*factor)
	leaves.set_shader_parameter("crown_height",2.3*factor)
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.material_override = leaves
	root_.add_child(node)

func painted_card(parent: Node3D,filename: String,p: Vector3,height_: float) -> void:
	var sprite := Sprite3D.new()
	sprite.texture = load(ART+filename)
	var used := sprite.texture.get_image().get_used_rect()
	sprite.pixel_size = height_/used.size.y
	sprite.offset = Vector2(sprite.texture.get_width()*0.5-used.get_center().x,used.end.y-sprite.texture.get_height()*0.5)
	sprite.position = p
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.35
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(sprite)
	painted_cards.append(sprite)

func contact_shadow(p: Vector3,size_: Vector2,opacity: float) -> void:
	var shader := Shader.new()
	shader.code = """shader_type spatial;render_mode unshaded,depth_draw_never,cull_disabled;uniform float opacity=0.3;void fragment(){float d=length((UV-0.5)*2.0);ALBEDO=vec3(0.12,0.18,0.12);ALPHA=(1.0-smoothstep(0.3,1.0,d))*opacity;}"""
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("opacity",opacity)
	var mesh := PlaneMesh.new()
	mesh.size = size_
	var node := Craft.mesh(self,mesh,p+Vector3.UP*0.03,m)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func water_and_bridge() -> void:
	var points: Array = []
	for z in range(-30,24):
		var x0 := 11.5+sin(z*0.13)*0.7
		var x1 := 11.5+sin((z+1)*0.13)*0.7
		points.append_array([Vector3(x0-1.2,-0.15,z),Vector3(x0+1.2,-0.15,z),Vector3(x1-1.2,-0.15,z+1),Vector3(x0+1.2,-0.15,z),Vector3(x1+1.2,-0.15,z+1),Vector3(x1-1.2,-0.15,z+1)])
	var shader := Shader.new()
	shader.code = """shader_type spatial;render_mode unshaded,cull_disabled;varying vec3 world;void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}void fragment(){float wave=smoothstep(0.88,0.98,sin(world.z*9.0+sin(world.x*7.0)+TIME*1.8));ALBEDO=mix(vec3(0.18,0.42,0.48),vec3(0.67,0.83,0.82),wave*0.6);}"""
	var water := ShaderMaterial.new()
	water.shader = shader
	triangle_mesh(scenery_root,points,water)
	var wood := mat("bridge",Color("a58c63"))
	for i in range(14):
		box(scenery_root,Vector3(8.3+i*0.46,0.12,9),Vector3(0.44,0.16,2.1),wood,true)
	for z in [7.9,10.1]:
		for x in [8.5,10.4,12.3,14.3]:
			box(scenery_root,Vector3(x,0.6,z),Vector3(0.12,1.15,0.12),wood)
		beam(scenery_root,Vector3(8.5,0.95,z),Vector3(14.3,0.95,z),0.10,wood)

func well() -> void:
	var p := ground_point(Vector3(-0.5,0,2.8))
	var root_ := Node3D.new()
	root_.name = "Well"
	root_.position = p
	scenery_root.add_child(root_)
	var stone := mat("stone",Color.WHITE,ART+"stone.png")
	var wood := mat("wood",Color("756044"))
	for row in range(3):
		for i in range(12):
			var a := (i+row*0.5)*TAU/12
			var piece := box(root_,Vector3(cos(a)*0.7,0.14+row*0.25,sin(a)*0.7),Vector3(0.38,0.24,0.25),stone)
			piece.rotation.y = -a+PI/2
	for x in [-0.9,0.9]:
		beam(root_,Vector3(x,0,0),Vector3(x,2.5,0),0.15,wood)
	for side in [-1,1]:
		var roof := box(root_,Vector3(side*0.48,2.53,0),Vector3(1.2,0.12,1.9),mat("wellroof",Color("7d8999")))
		roof.rotation.z = -side*0.45
	var axle := Craft.cylinder(root_,Vector3(0,1.9,0),0.07,0.07,1.9,wood,10)
	axle.rotation.z = PI/2
	beam(root_,Vector3(0,1.9,0),Vector3(0,0.5,0),0.025,mat("rope",Color("bea67c")))
	collider(root_,Vector3(0,0.5,0),Vector3(1.7,1,1.7))

func garden_edges() -> void:
	var stone := mat("stone",Color.WHITE,ART+"stone.png")
	var wood := mat("wood",Color("756044"))
	for i in range(10):
		var p := ground_point(Vector3(-11+i*0.6,0,5.5))
		box(scenery_root,p+Vector3.UP*0.3,Vector3(0.58,0.6,0.45),stone,true)
	for p in [Vector3(3,0,0),Vector3(-3,0,-7),Vector3(6,0,7)]:
		for i in range(4):
			var v := ground_point(p+Vector3(i*0.9,0,0))
			box(scenery_root,v+Vector3.UP*0.45,Vector3(0.12,0.9,0.12),wood)
		for y in [0.3,0.7]:
			beam(scenery_root,ground_point(p)+Vector3(0,y,0),ground_point(p+Vector3(2.7,0,0))+Vector3(0,y,0),0.07,wood)

func road_distance(p: Vector2) -> float:
	var lines := [[Vector2(0,19),Vector2(0,2)],[Vector2(0,2),Vector2(-0.5,-22)],[Vector2(0,5),Vector2(-6.5,4)],[Vector2(0,-4),Vector2(6,-3)],[Vector2(0,-9),Vector2(-5.8,-9)],[Vector2(0,9),Vector2(11,9)]]
	var result := 1000.0
	for line in lines:
		result = minf(result,Geometry2D.get_closest_point_to_segment(p,line[0],line[1]).distance_to(p))
	return result

func grass_and_flowers() -> void:
	var blade := SurfaceTool.new()
	blade.begin(Mesh.PRIMITIVE_TRIANGLES)
	for a in [0.0,PI/2]:
		var right := Vector3(cos(a),0,sin(a))*0.05
		for v in [-right,Vector3(0.04,0.34,0),right]:
			blade.set_uv(Vector2(0,clampf(v.y/0.34,0,1)))
			blade.add_vertex(v)
	blade.generate_normals()
	var positions: Array = []
	for i in range(15000):
		var p := Vector2(rng.randf_range(-19,19),rng.randf_range(-25,19))
		if road_distance(p)<1.7 or absf(p.x-11.5-sin(p.y*0.13)*0.7)<2.2 or p.distance_to(Vector2(-0.5,2.8))<3:
			continue
		var clear := true
		for house in HOUSES:
			if absf(p.x-house.x)<3.2 and absf(p.y-house.z)<3.6:
				clear = false
		if clear and sin(p.x*0.4)*cos(p.y*0.4)>-0.3:
			positions.append(ground_point(Vector3(p.x,0,p.y)))
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = blade.commit()
	multi.instance_count = positions.size()
	for i in range(positions.size()):
		multi.set_instance_transform(i,Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*rng.randf_range(0.65,1.2)),positions[i]))
	var shader := Shader.new()
	shader.code = """shader_type spatial;render_mode cull_disabled;varying vec3 world;void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;VERTEX.x+=sin(TIME*1.8+world.x*0.6+world.z*0.5)*UV.y*0.08;}void fragment(){NORMAL=normalize((VIEW_MATRIX*vec4(0,1,0,0)).xyz);ALBEDO=mix(vec3(0.27,0.43,0.15),vec3(0.47,0.61,0.24),UV.y);SPECULAR=0.0;ROUGHNESS=1.0;}"""
	var m := ShaderMaterial.new()
	m.shader = shader
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.material_override = m
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scenery_root.add_child(node)
	var flower := mat("flower",Color("e7dfbd"))
	for i in range(70):
		var p := ground_point(Vector3(rng.randf_range(-11,-7),0,rng.randf_range(6,11)))
		for k in range(4):
			var a := k*TAU/4
			Craft.ball(scenery_root,p+Vector3(cos(a)*0.045,0.23,sin(a)*0.045),Vector3(0.09,0.03,0.09),flower)

func boundary() -> void:
	var stone := mat("stone",Color.WHITE,ART+"stone.png")
	for i in range(20):
		var x := -22+i*2.1
		box(scenery_root,ground_point(Vector3(x,0,-27))+Vector3.UP*0.65,Vector3(2,1.3,0.7),stone,true)
