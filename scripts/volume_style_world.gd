class_name VolumeStyleWorld
extends Node3D
## Walkable village art implementation; isolated from chapter progress.
var rng := RandomNumberGenerator.new()
var materials := {}
var houses := [Vector3(-9.5,0,3),Vector3(6.2,0,-7),Vector3(-5,0,-14)]
var grass_count := 0
var solid_count := 0
var tree_count := 0
var static_batches := 0
var windmill_sails: Node3D
const SURFACE := """shader_type spatial;
render_mode cull_disabled;
uniform vec4 paint : source_color = vec4(0.5,0.7,0.25,1.0);
uniform bool grass=false;
uniform bool terrain=false;
varying vec3 world;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;if(grass){NORMAL=vec3(0.0,1.0,0.0);VERTEX.x+=sin(TIME*1.8+world.x*0.55+world.z*0.23)*0.13*UV.y;VERTEX.z+=cos(TIME*1.4+world.x*0.31)*0.05*UV.y;}}
void fragment(){
 vec3 c=paint.rgb;
 if(terrain){float n=noise(world.xz*0.13)*0.6+noise(world.xz*0.49)*0.4;c=mix(vec3(0.30,0.43,0.12),vec3(0.53,0.63,0.21),n);float center=sin(world.z*0.095)*1.8;float width=1.5+sin(world.z*0.24)*0.22;float path=1.0-smoothstep(width,width+0.85,abs(world.x-center)+noise(world.xz*2.8)*0.22);float grain=noise(world.xz*6.0)*0.5+noise(world.xz*1.1)*0.5;c=mix(c,mix(vec3(0.53,0.44,0.28),vec3(0.74,0.64,0.43),n*0.5+grain*0.5),path);}
 if(grass){NORMAL=normalize((VIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz);c=mix(paint.rgb*0.80,paint.rgb*1.05,UV.y);c*=0.91+COLOR.r*0.17;}
 ALBEDO=c;ROUGHNESS=0.95;SPECULAR=0.06;
}
"""

func material(id: String,color: Color) -> Material:
	if materials.has(id):
		return materials[id]
	if id not in ["grass","terrain"]:
		var standard := StandardMaterial3D.new()
		standard.albedo_color = color
		standard.roughness = 1.0
		standard.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		standard.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		standard.cull_mode = BaseMaterial3D.CULL_DISABLED
		materials[id] = standard
		return standard
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SURFACE
	mat.shader = shader
	mat.set_shader_parameter("paint",color)
	materials[id] = mat
	return mat

func path_x(z: float) -> float:
	return sin(z*0.095)*1.8

func height_at(x: float,z: float) -> float:
	var h := 0.35*sin(x*0.12)*cos(z*0.10)
	h += 4.8*exp(-((x+19)*(x+19)+(z+27)*(z+27))/340.0)
	h += 3.0*exp(-((x-22)*(x-22)+(z+25)*(z+25))/320.0)
	h += 0.7*exp(-((x+1)*(x+1)+(z-16)*(z-16))/190.0)
	var creek := absf(x-(13.0+sin(z*0.10)*1.8))
	h = lerpf(-0.72,h,smoothstep(1.3,3.1,creek))
	return h

func build() -> void:
	rng.seed = 20261024
	terrain()
	creek()
	for i in range(houses.size()):
		cottage(houses[i],i)
	for item in [[-10,13,1.65],[18,12,1.1],[-13,-4,1.5],[-1,-21,1.25],[17,-14,1.35],[-17,-22,1.3],[8,-29,1.2],[23,-35,1.4],[-25,-35,1.3]]:
		tree(Vector3(item[0],0,item[1]),item[2])
	for i in range(14):
		var angle := rng.randf()*TAU
		var radius := rng.randf_range(0.35,0.95)
		var p := Vector3(-10+cos(angle)*radius,0,-2+sin(angle)*radius)
		bush(p,0.6)
	for p in [Vector3(-3,0,8),Vector3(3.5,0,-3),Vector3(-3,0,-13)]:
		fence(p)
	well(Vector3(-2.6,0,9.5))
	village_details()
	rocks_and_ridges()
	distant_woodland()
	grass()
	flowers()
	batch_static_geometry()

func terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 150
	for z in range(count):
		for x in range(count):
			var a := Vector3(x-75,0,z-90)
			var b := a+Vector3.RIGHT
			var c := a+Vector3.BACK
			var d := a+Vector3(1,0,1)
			for p in [a,b,c,b,d,c]:
				p.y = height_at(p.x,p.z)
				st.add_vertex(p)
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.name = "RollingTerrain"
	node.mesh = st.commit()
	var mat := material("terrain",Color.WHITE)
	mat.set_shader_parameter("terrain",true)
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	node.create_trimesh_collision()
	solid_count += 1

func block(p: Vector3,size_: Vector3,mat: Material,solid: bool = false) -> MeshInstance3D:
	if solid:
		var body := Craft.solid_box(self,p,size_,mat)
		solid_count += 1
		return body.get_child(0)
	return Craft.box(self,p,size_,mat)

func organic(parent: Node3D,p: Vector3,radii: Vector3,mat: Material,seed_: float = 0) -> MeshInstance3D:
	var deform := func(v: Vector3) -> Vector3:
		var n := sin(v.x*3.2+seed_)*cos(v.y*4.3-seed_)*sin(v.z*3.8+1.4)
		return v*(1.0+n*0.10)
	return Craft.mesh(parent,Craft.blob(radii,deform,12,18),p,mat)

func beam(parent: Node3D,a: Vector3,b: Vector3,radius: float,mat: Material) -> void:
	var item := Craft.cylinder(parent,(a+b)*0.5,radius,radius*0.68,a.distance_to(b),mat,9)
	Craft.orient(item,(a+b)*0.5,b-a,Vector3.FORWARD)

func tree(p: Vector3,factor: float) -> void:
	p.y = height_at(p.x,p.z)
	var root_ := Node3D.new()
	root_.position = p
	add_child(root_)
	var bark := material("bark",Color("786950"))
	beam(root_,Vector3.ZERO,Vector3(0.15,4.5,0.05)*factor,0.30*factor,bark)
	for k in range(5):
		var angle := k*TAU/5+0.3
		var end := Vector3(cos(angle)*1.9,4.3+k*0.18,sin(angle)*1.7)*factor
		beam(root_,Vector3(0,2.4,0)*factor,end,0.13*factor,bark)
		beam(root_,Vector3(cos(angle)*0.75,0.04,sin(angle)*0.65)*factor,Vector3(0,0.5,0)*factor,0.11*factor,bark)
	leaf_canopy(root_,factor)
	var body := StaticBody3D.new()
	body.position = Vector3(0,2,0)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.30*factor
	capsule.height = 4.0
	shape.shape = capsule
	body.add_child(shape)
	root_.add_child(body)
	tree_count += 1
	solid_count += 1

func leaf_canopy(parent: Node3D,factor: float) -> void:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1.7,1.7)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = 560
	for i in range(multi.instance_count):
		var azimuth := rng.randf()*TAU
		var elevation := rng.randf_range(-0.65,1.0)
		var radius := pow(rng.randf(),0.25)*2.9
		var horizontal := sqrt(1.0-elevation*elevation)
		var p := Vector3(cos(azimuth)*horizontal*radius,4.8+elevation*radius*0.62,sin(azimuth)*horizontal*radius)*factor
		var basis_ := Basis.from_euler(Vector3(rng.randf_range(-PI,PI),rng.randf()*TAU,rng.randf()*TAU))
		basis_ = basis_.scaled(Vector3.ONE*factor*rng.randf_range(0.65,1.10))
		multi.set_instance_transform(i,Transform3D(basis_,p))
		multi.set_instance_color(i,Color.from_hsv(0.22+rng.randf_range(-0.015,0.015),0.50,rng.randf_range(0.65,0.96)))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/style-volume-v2/foliage-card.png")
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.45
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.backlight_enabled = true
	mat.backlight = Color(0.2,0.26,0.07)
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.material_override = mat
	parent.add_child(node)

func bush(p: Vector3,size_: float) -> void:
	p.y = height_at(p.x,p.z)+size_*0.45
	organic(self,p,Vector3(size_,size_*0.65,size_*0.8),material("bush",Color("688141")),p.x)

func cottage(p: Vector3,index: int) -> void:
	p.y = height_at(p.x,p.z)
	var root_ := Node3D.new()
	root_.name = "VillageHouse%d"%index
	root_.position = p
	add_child(root_)
	var cream := material("plaster",Color("e0d2ac"))
	cream.albedo_texture = load("res://assets/style-volume-v2/plaster.png")
	cream.uv1_scale = Vector3(1.3,1.0,1.0)
	var wood := material("timber",Color("69563b"))
	var stone := material("stone",Color("8b927d"))
	var dark := material("window",Color("354f52"))
	var door := material("door",Color("8c7752"))
	Craft.solid_box(root_,Vector3(0,1.45,0),Vector3(4.6,2.8,3.9),cream)
	solid_count += 1
	for side in [-1,1]:
		for depth in [-1,1]:
			Craft.box(root_,Vector3(side*2.28,1.4,depth*1.94),Vector3(0.16,2.8,0.16),wood)
		Craft.box(root_,Vector3(side*2.30,2.6,0),Vector3(0.15,0.18,4.0),wood)
	for y in [0.18,0.46]:
		for i in range(8):
			var rock := organic(root_,Vector3(-2.05+i*0.59,y,1.98),Vector3(0.31,0.17,0.17),stone,i)
			rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Gable plaster faces and pitched tiles are actual geometry, not camera-facing art.
	var gables := SurfaceTool.new()
	gables.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in [-1.96,1.96]:
		var points := [Vector3(-2.3,2.8,z),Vector3(2.3,2.8,z),Vector3(0,4.35,z)]
		if z>0:
			points.reverse()
		for point in points:
			gables.add_vertex(point)
	gables.generate_normals()
	Craft.mesh(root_,gables.commit(),Vector3.ZERO,cream)
	var roof_colors := [Color("ae744b"),Color("b57b51"),Color("a96e49"),Color("b47a4d")]
	for side in [-1,1]:
		for row in range(9):
			for column in range(13):
				var t0 := row/9.0
				var t1 := (row+1)/9.0
				var z0 := -2.25+column*4.5/13.0
				var z1 := z0+4.5/13.0+0.018
				var x0: float = side*t0*2.65
				var x1: float = side*t1*2.65
				var y0 := 4.40-t0*1.72
				var y1 := 4.40-t1*1.72
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				for strip in range(4):
					var za := lerpf(z0,z1,strip/4.0)
					var zb := lerpf(z0,z1,(strip+1)/4.0)
					var bump_a := sin(strip*PI/4.0)*0.045+0.018
					var bump_b := sin((strip+1)*PI/4.0)*0.045+0.018
					var points := [Vector3(x0,y0+bump_a,za),Vector3(x1,y1+bump_a,za),Vector3(x0,y0+bump_b,zb),Vector3(x0,y0+bump_b,zb),Vector3(x1,y1+bump_a,za),Vector3(x1,y1+bump_b,zb)]
					if side<0:
						points.reverse()
					for v in points:
						st.add_vertex(v)
				st.generate_normals()
				var mat := material("roof%d"%((row+column*3+index)%4),roof_colors[(row+column*3+index)%4])
				Craft.mesh(root_,st.commit(),Vector3.ZERO,mat)
		beam(root_,Vector3(0,4.4,2.28),Vector3(side*2.65,2.67,2.28),0.10,wood)
		beam(root_,Vector3(side*2.65,2.67,-2.28),Vector3(side*2.65,2.67,2.28),0.08,wood)
	beam(root_,Vector3(0,4.42,-2.4),Vector3(0,4.42,2.4),0.12,wood)
	Craft.box(root_,Vector3(-0.55,1.15,2.01),Vector3(1.0,1.80,0.10),door)
	for x in [-1.08,-0.02]:
		Craft.box(root_,Vector3(x,1.2,2.10),Vector3(0.11,2.0,0.13),wood)
	Craft.box(root_,Vector3(-0.55,2.15,2.10),Vector3(1.2,0.12,0.13),wood)
	for x in [-0.90,-0.68,-0.46,-0.24]:
		Craft.box(root_,Vector3(x,1.15,2.08),Vector3(0.025,1.7,0.02),wood)
	Craft.ball(root_,Vector3(-0.22,1.20,2.16),Vector3.ONE*0.10,material("metal",Color("7e6c45")))
	for x in [-1.65,1.25]:
		Craft.box(root_,Vector3(x,1.8,2.01),Vector3(0.8,0.82,0.10),dark)
		for dx in [-0.43,0,0.43]:
			Craft.box(root_,Vector3(x+dx,1.8,2.09),Vector3(0.055,0.95,0.08),wood)
		for y in [1.35,1.80,2.25]:
			Craft.box(root_,Vector3(x,y,2.09),Vector3(0.93,0.055,0.08),wood)
	Craft.box(root_,Vector3(1.25,1.23,2.22),Vector3(1.05,0.20,0.35),wood)
	for k in range(8):
		organic(root_,Vector3(0.85+k*0.11,1.39,2.20),Vector3(0.14,0.14,0.18),material("flowerleaf",Color("6c8849")),k)
	var chimney := Craft.cylinder(root_,Vector3(1.3,4.0,-0.7),0.30,0.28,1.7,stone,8)
	Craft.cylinder(root_,chimney.position+Vector3.UP*0.85,0.36,0.36,0.14,stone,8)
	Craft.solid_box(root_,Vector3(-0.55,0.13,2.35),Vector3(1.5,0.26,0.70),stone)
	solid_count += 1
	side_windows(root_)
	cottage_porch(root_)
	root_.scale = Vector3.ONE*1.30
	root_.rotation_degrees.y = [-18.0,12.0,-8.0][index]

func fence(p: Vector3) -> void:
	var wood := material("fence",Color("817453"))
	for i in range(4):
		var point := p+Vector3(0,0,i*0.8)
		point.y = height_at(point.x,point.z)
		block(point+Vector3.UP*0.5,Vector3(0.12,1.0,0.12),wood,true)
		if i<3:
			for y in [0.35,0.75]:
				block(point+Vector3(0,y,0.4),Vector3(0.08,0.10,0.8),wood)

func creek() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-50,44):
		var a := 13.0+sin(z*0.10)*1.8
		var b := 13.0+sin((z+1)*0.10)*1.8
		for point in [Vector3(a-1.4,-0.10,z),Vector3(a-1.4,-0.10,z+1),Vector3(b+1.4,-0.10,z),Vector3(b+1.4,-0.10,z),Vector3(a-1.4,-0.10,z+1),Vector3(b+1.4,-0.10,z+1)]:
			st.add_vertex(point)
	st.generate_normals()
	var water := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """shader_type spatial;render_mode cull_disabled;
varying vec3 world;void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){float wave=sin(world.z*3.0+TIME*1.4+sin(world.x*4.0))*0.5+0.5;ALBEDO=mix(vec3(0.13,0.38,0.41),vec3(0.29,0.58,0.58),wave*0.35);ROUGHNESS=0.25;SPECULAR=0.5;}
"""
	water.shader = shader
	Craft.mesh(self,st.commit(),Vector3.ZERO,water)
	var wood := material("bridge",Color("8e7850"))
	for i in range(16):
		block(Vector3(8.5+i*0.47,0.08,10),Vector3(0.44,0.13,1.65),wood,true)
	for x in [8.7,11,13.3,15.4]:
		for z in [9.1,10.9]:
			block(Vector3(x,0.5,z),Vector3(0.10,1.0,0.10),wood)

	for z in [9.1,10.9]:
		beam(self,Vector3(8.7,0.85,z),Vector3(15.4,0.85,z),0.055,wood)

func windmill(p: Vector3) -> void:
	p.y = height_at(p.x,p.z)
	var root_ := Node3D.new()
	root_.position = p
	add_child(root_)
	Craft.cylinder(root_,Vector3.UP*3.2,1.3,0.8,6.4,material("mill",Color("c8c1a8")),16)
	Craft.cylinder(root_,Vector3.UP*7.1,1.5,0.0,1.8,material("millroof",Color("8d6750")),16)
	windmill_sails = Node3D.new()
	windmill_sails.position = Vector3(0,5.6,1.1)
	root_.add_child(windmill_sails)
	var cloth := material("canvas",Color("e1ddbd"))
	var wood := material("fence",Color("817453"))
	for i in range(4):
		var arm := Node3D.new()
		arm.rotation.z = i*PI/2
		windmill_sails.add_child(arm)
		Craft.box(arm,Vector3(0,1.5,0),Vector3(0.13,3.3,0.15),wood)
		Craft.box(arm,Vector3(0.35,2.1,0.02),Vector3(0.75,2.1,0.035),cloth)
		for k in range(5):
			Craft.box(arm,Vector3(0.35,1.2+k*0.45,0.06),Vector3(0.85,0.04,0.05),wood)

func rocks_and_ridges() -> void:
	# Uneven rock shelves, grass ledges, then increasingly blue distant ridges.
	for layer in range(3):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var z := -52.0-layer*28
		var tops: Array[Vector3] = []
		for i in range(41):
			var x := -120.0+i*6
			var y := 9.0+layer*5+sin(i*0.73+layer*2)*4+sin(i*1.9)*2
			tops.append(Vector3(x,y,z-rng.randf()*8))
		for i in range(40):
			var a := tops[i]
			var b := tops[i+1]
			for point in [a,b,Vector3(a.x,-2,a.z+5),b,Vector3(b.x,-2,b.z+5),Vector3(a.x,-2,a.z+5)]:
				st.add_vertex(point)
		st.generate_normals()
		var colors := [Color("798e7f"),Color("698f9b"),Color("759faa")]
		var ridge_mat := material("ridge%d"%layer,colors[layer])
		if layer>0:
			ridge_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		Craft.mesh(self,st.commit(),Vector3.ZERO,ridge_mat)
		if layer==0:
			var shelf := SurfaceTool.new()
			shelf.begin(Mesh.PRIMITIVE_TRIANGLES)
			for j in range(40):
				var a := tops[j]
				var b := tops[j+1]
				for point in [a,a+Vector3(0,0,-15),b,b,a+Vector3(0,0,-15),b+Vector3(0,0,-15)]:
					shelf.add_vertex(point+Vector3.UP*0.03)
			shelf.generate_normals()
			Craft.mesh(self,shelf.commit(),Vector3.ZERO,material("cliffgrass",Color("6e8852")))
	var rock := material("riverrock",Color("717c67"))
	for i in range(160):
		var z := rng.randf_range(-36,24)
		var side := -1.0 if i%2==0 else 1.0
		var x := 13+sin(z*0.10)*1.8+side*rng.randf_range(1.5,2.7)
		var size_ := rng.randf_range(0.35,1.0)
		organic(self,Vector3(x,height_at(x,z)+size_*0.18,z),Vector3(size_,size_*0.65,size_*0.9),rock,i)
	for i in range(20):
		var x := rng.randf_range(-16,-5)
		var z := rng.randf_range(9,18)
		organic(self,Vector3(x,height_at(x,z)+0.15,z),Vector3(0.65,0.4,0.6),rock,i)

func distant_woodland() -> void:
	var bark := material("distantbark",Color("617464"))
	var leaves := material("distantneedles",Color("5b796a"))
	for i in range(100):
		var x := rng.randf_range(-39,37)
		var z := rng.randf_range(-48,-33)
		var p := Vector3(x,height_at(x,z),z)
		var height := rng.randf_range(2.8,5.3)
		Craft.cylinder(self,p+Vector3.UP*height*0.35,0.09,0.04,height*0.7,bark,6)
		for layer in range(3):
			var y := height*(0.45+layer*0.17)
			Craft.cylinder(self,p+Vector3.UP*y,height*(0.23-layer*0.047),0.0,height*0.52,leaves,8)

func grass_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in range(3):
		var angle := blade*TAU/3
		var right := Vector3(cos(angle),0,sin(angle))*0.055
		var lean := Vector3(sin(angle),0,cos(angle))*0.05
		var points := [-right,right,Vector3.UP*0.36+lean,Vector3.UP*0.36+lean,right,Vector3.UP*0.18+right*0.5+lean*0.4]
		for j in range(points.size()):
			st.set_uv(Vector2(0.5,clampf(points[j].y/0.36,0,1)))
			st.set_color(Color(0.7,0.7,0.7))
			st.add_vertex(points[j])
	st.generate_normals()
	return st.commit()

func grass() -> void:
	var positions: Array[Vector3] = []
	for i in range(56000):
		var x := rng.randf_range(-25,25)
		var z := rng.randf_range(-33,28)
		if Vector2(x+2.6,z-9.5).length()<1.5 or absf(x-path_x(z))<1.7 or absf(x-(13+sin(z*0.10)*1.8))<2:
			continue
		var clear := true
		for house in houses:
			if absf(x-house.x)<3.7 and absf(z-house.z)<3.5:
				clear = false
		if clear:
			positions.append(Vector3(x,height_at(x,z),z))
	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_3D
	mesh.mesh = grass_mesh()
	mesh.instance_count = positions.size()
	for i in range(positions.size()):
		var scale_ := Vector3.ONE*rng.randf_range(0.45,1.0)
		mesh.set_instance_transform(i,Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(scale_),positions[i]))
	var node := MultiMeshInstance3D.new()
	node.name = "WindblownGrass"
	node.multimesh = mesh
	var mat := material("grass",Color("718f36"))
	mat.set_shader_parameter("grass",true)
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	grass_count = positions.size()

func flowers() -> void:
	var stem := material("stem",Color("668044"))
	var petal := material("petal",Color("dddac2"))
	for i in range(100):
		var x := rng.randf_range(-15,-9)
		var z := rng.randf_range(6,13)
		var p := Vector3(x,height_at(x,z),z)
		Craft.cylinder(self,p+Vector3.UP*0.15,0.012,0.008,0.3,stem,4)
		for k in range(4):
			var a := k*TAU/4
			organic(self,p+Vector3(cos(a)*0.05,0.30,sin(a)*0.05),Vector3(0.055,0.018,0.055),petal,k)

func _process(delta: float) -> void:
	if is_instance_valid(windmill_sails):
		windmill_sails.rotation.z += delta*0.13

func cottage_porch(root_: Node3D) -> void:
	var wood := material("timber",Color("69563b"))
	var roof := material("porchroof",Color("a9744e"))
	for x in [-1.45,0.35]:
		Craft.cylinder(root_,Vector3(x,1.08,3.0),0.075,0.08,2.15,wood,8)
		beam(root_,Vector3(x,2.1,3.0),Vector3(x,2.4,2.6),0.055,wood)
	var top := Craft.box(root_,Vector3(-0.55,2.42,2.6),Vector3(2.3,0.12,1.6),roof)
	top.rotation.x = 0.22
	for x in [-1.55,-1.1,-0.65,-0.2,0.25,0.5]:
		beam(root_,Vector3(x,2.64,1.85),Vector3(x,2.25,3.35),0.035,wood)

func well(p: Vector3) -> void:
	p.y = height_at(p.x,p.z)
	var root_ := Node3D.new()
	root_.name = "VillageWell"
	root_.position = p
	add_child(root_)
	var stone := material("wellstone",Color("777f6c"))
	var wood := material("timber",Color("69563b"))
	for row in range(3):
		for i in range(12):
			var angle := (i+row*0.5)*TAU/12
			var point := Vector3(cos(angle)*0.76,0.17+row*0.26,sin(angle)*0.76)
			var piece := Craft.box(root_,point,Vector3(0.39,0.25,0.27),stone)
			piece.rotation.y = -angle+PI/2
	for x in [-0.83,0.83]:
		Craft.solid_box(root_,Vector3(x,1.15,0),Vector3(0.15,2.3,0.15),wood)
	var axle := Craft.cylinder(root_,Vector3(0,1.8,0),0.08,0.08,1.8,wood,10)
	axle.rotation.z = PI/2
	beam(root_,Vector3(0,1.8,0.02),Vector3(0,0.45,0.02),0.018,material("rope",Color("a19067")))
	for side in [-1,1]:
		var roof := Craft.box(root_,Vector3(side*0.5,2.42,0),Vector3(1.2,0.12,1.8),material("wellroof",Color("ad774e")))
		roof.rotation.z = side*-0.45
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.95
	cylinder.height = 0.95
	shape.shape = cylinder
	shape.position.y = 0.475
	body.add_child(shape)
	root_.add_child(body)
	solid_count += 3

func village_details() -> void:
	var stone := material("gardenstone",Color("939983"))
	for i in range(22):
		var p := Vector3(-12+i*0.39,0,7.8)
		p.y = height_at(p.x,p.z)
		for j in range(2):
			organic(self,p+Vector3(0,0.16+j*0.28,0),Vector3(0.25,0.17,0.21),stone,i+j)
	var wood := material("barrel",Color("8b7951"))
	var iron := material("barrelband",Color("545e52"))
	for p in [Vector3(-10,0,6.1),Vector3(-9,0,6.5),Vector3(8.5,0,-3.5)]:
		p.y = height_at(p.x,p.z)
		Craft.cylinder(self,p+Vector3.UP*0.5,0.37,0.32,1,wood,12)
		for y in [0.15,0.80]:
			Craft.cylinder(self,p+Vector3.UP*y,0.38,0.38,0.055,iron,12)

func side_windows(root_: Node3D) -> void:
	var wood := material("timber",Color("69563b"))
	var glass := material("window",Color("354f52"))
	for z in [-0.9,0.9]:
		Craft.box(root_,Vector3(2.32,1.8,z),Vector3(0.07,0.80,0.7),glass)
		for dz in [-0.39,0,0.39]:
			Craft.box(root_,Vector3(2.39,1.8,z+dz),Vector3(0.1,0.90,0.06),wood)
		for y in [1.36,1.8,2.24]:
			Craft.box(root_,Vector3(2.39,y,z),Vector3(0.10,0.06,0.84),wood)
		Craft.box(root_,Vector3(2.44,1.3,z),Vector3(0.25,0.12,0.95),wood)

func collect_meshes(parent: Node,found: Array[MeshInstance3D]) -> void:
	for child in parent.get_children():
		if child is MeshInstance3D and child.visible and child.name!="RollingTerrain":
			found.append(child)
		collect_meshes(child,found)

func batch_static_geometry() -> void:
	# Preserve physics bodies; only combine static rendered surfaces sharing material/shadow settings.
	var found: Array[MeshInstance3D] = []
	collect_meshes(self,found)
	var groups := {}
	for node in found:
		if not node.material_override or node.mesh.get_surface_count()!=1:
			continue
		var arrays := node.mesh.surface_get_arrays(0)
		var format_mask := 0
		for slot in range(arrays.size()):
			if arrays[slot]!=null and arrays[slot].size()>0:
				format_mask |= 1<<slot
		var key := "%d:%d:%d"%[node.material_override.get_instance_id(),node.cast_shadow,format_mask]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(node)
	for key in groups:
		var nodes: Array = groups[key]
		if nodes.size()<2:
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for node in nodes:
			st.append_from(node.mesh,0,global_transform.affine_inverse()*node.global_transform)
		var merged := MeshInstance3D.new()
		merged.name = "StaticVillageBatch%d"%static_batches
		merged.mesh = st.commit()
		merged.material_override = nodes[0].material_override
		merged.cast_shadow = nodes[0].cast_shadow
		add_child(merged)
		for node in nodes:
			node.queue_free()
		static_batches += 1
