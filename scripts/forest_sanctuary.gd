class_name ForestSanctuary
extends Node3D
## Painted scenery is anchored in real 3D space; walkable structures have real collision.
const ART := "res://assets/environment/"
var camera: Camera3D
var anchors: Dictionary
var rng := RandomNumberGenerator.new()
var artwork: Dictionary = {}
var scenery_count: int = 0
var collision_count: int = 0
var tall_cards: Array[Sprite3D] = []

func build() -> void:
	rng.seed = 8721
	anchors = JSON.parse_string(FileAccess.get_file_as_string(ART+"anchors.json"))
	for name in anchors:
		artwork[name] = load(ART+name+".png")
	ground()
	structures()
	woodland()
	details()
	atmosphere()

func ground() -> void:
	var body := StaticBody3D.new()
	body.name = "ForestGround"
	body.position = Vector3(0,-0.17,0)
	add_child(body)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30,0.4,30)
	collision.shape = box
	body.add_child(collision)
	collision_count += 1
	var plane := PlaneMesh.new()
	plane.size = Vector2(26,26)
	var mesh := MeshInstance3D.new()
	mesh.name = "PaintedGround"
	mesh.mesh = plane
	mesh.position.y = 0.032
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded;
uniform sampler2D ground_art : source_color, filter_linear_mipmap_anisotropic;
float hash(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p){ vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y); }
void fragment(){
 vec3 paint=texture(ground_art,UV).rgb;
 float foliage=noise(UV*13.0+vec2(TIME*0.009,0.0))*0.7+noise(UV*29.0-vec2(0.0,TIME*0.006))*0.3;
 float edges=smoothstep(0.17,0.5,length(UV-vec2(0.5)));
 float shadows=smoothstep(0.40,0.72,foliage)*(0.17+edges*0.22);
 vec3 tint=mix(vec3(1.02,0.99,0.88),vec3(0.59,0.73,0.73),shadows);
 ALBEDO=paint*tint;
 ROUGHNESS=1.0;
}
"""
	material.shader = shader
	material.set_shader_parameter("ground_art",load(ART+"ground.png"))
	mesh.material_override = material
	add_child(mesh)
	# Continue the forest floor beyond the playable footprint so camera travel never
	# reveals the clear color. This underlay reuses an all-grass corner of the painting.
	var backdrop := MeshInstance3D.new()
	var backdrop_plane := PlaneMesh.new()
	backdrop_plane.size = Vector2(80,80)
	backdrop.mesh = backdrop_plane
	backdrop.position.y = 0.025
	var backdrop_shader := Shader.new()
	backdrop_shader.code = "shader_type spatial; render_mode unshaded; uniform sampler2D grass : source_color,filter_linear_mipmap; void fragment(){vec2 uv=fract(UV*30.0)*0.15+vec2(0.82); ALBEDO=texture(grass,uv).rgb*vec3(0.82,0.88,0.80); ROUGHNESS=1.0;}"
	var backdrop_material := ShaderMaterial.new()
	backdrop_material.shader = backdrop_shader
	backdrop_material.set_shader_parameter("grass",load(ART+"ground.png"))
	backdrop.material_override = backdrop_material
	add_child(backdrop)
	# Contained woodland footprint; invisible boundaries sit well outside the combat clearing.
	for p in [Vector3(10,1.5,0),Vector3(-10,1.5,0),Vector3(0,1.5,9),Vector3(0,1.5,-9)]:
		var size := Vector3(0.3,4,20) if absf(p.x)>0 else Vector3(20,4,0.3)
		collider(p,size)

func masonry() -> StandardMaterial3D:
	var material := Craft.material(Color("d0d1bb"))
	material.albedo_texture = load(ART+"masonry.png")
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE * 0.65
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material

func structures() -> void:
	var stone := masonry()
	# Compact climbable sanctuary terrace, approached by three broad weathered steps.
	for i in range(3):
		var h := 0.18 + i*0.19
		var p := Vector3(-2.7,h*0.5+0.03,-0.6-i*0.6)
		Craft.solid_box(self,p,Vector3(2.0,h,0.65),stone)
		collision_count += 1
	Craft.solid_box(self,Vector3(-2.7,0.36,-2.45),Vector3(3.3,0.66,2.0),stone)
	collision_count += 1
	# The focal arch and shrine share the elevated platform; front and back remain readable.
	card("arch",Vector3(-2.1,0.70,-2.65),2.8)
	card("shrine",Vector3(-3.6,0.70,-2.3),1.45)
	# Narrow colliders follow arch jambs, leaving the opening unobstructed.
	collider(Vector3(-2.82,1.55,-2.65),Vector3(0.35,1.7,0.45))
	collider(Vector3(-1.37,1.55,-2.65),Vector3(0.35,1.7,0.45))
	# Side ruins create landmarks without a visually perfect arena ring.
	card("wall",Vector3(4.9,0.035,-2.6),2.0)
	collider(Vector3(4.9,0.68,-2.6),Vector3(2.3,1.3,0.65))
	card("pillar",Vector3(-5.5,0.035,1.2),2.25)
	collider(Vector3(-5.5,0.95,1.2),Vector3(0.62,1.85,0.62))
	card("fallen",Vector3(3.8,0.035,3.1),0.82)
	Craft.solid_box(self,Vector3(3.8,0.18,3.1),Vector3(1.4,0.30,0.65),stone).get_child(0).visible = false
	collision_count += 1
	card("rocks",Vector3(4.5,0.035,4.0),0.85)
	collider(Vector3(4.5,0.30,4.0),Vector3(0.8,0.53,0.75))
	card("lantern",Vector3(-4.5,0.035,-0.85),1.1)
	card("lantern",Vector3(3.0,0.035,-3.0),1.05)
	for p in [Vector3(-4.5,0.8,-0.85),Vector3(3.0,0.8,-3.0)]:
		var light := OmniLight3D.new()
		light.position = p
		light.light_color = Color("ffc77a")
		light.light_energy = 0.45
		light.omni_range = 2.2
		add_child(light)

func woodland() -> void:
	# Deliberate framing: trunks sit beyond travel routes, crowns frame the screen edges.
	var trees := [
		["oak",Vector3(-7.8,0.035,0.1),5.3],
		["birch",Vector3(-6.6,0.035,-3.8),4.7],
		["crooked",Vector3(-2.9,0.035,-6.8),4.1],
		["sapling",Vector3(1.0,0.035,-7.1),4.6],
		["oak",Vector3(7.6,0.035,-2.6),4.5],
		["birch",Vector3(8.2,0.035,1.3),5.4],
		["crooked",Vector3(-5.5,0.035,7.4),4.8],
		["sapling",Vector3(5.7,0.035,7.4),4.0],
		["birch",Vector3(-9.0,0.035,5.0),5.2]
	]
	for item in trees:
		var tree := card(item[0],item[1],item[2])
		tree.set_meta("tree",true)
		tree.set_meta("painted_height",float(item[2]))
		tall_cards.append(tree)
		collider(item[1]+Vector3.UP*1.0,Vector3(0.65,2.0,0.65))
		contact_shadow(item[1],Vector2(2.1,1.3),0.27)
		for j in range(3):
			var p: Vector3 = item[1]+Vector3(rng.randf_range(-0.65,0.65),0,rng.randf_range(-0.4,0.5))
			card("ferns" if j%2==0 else "bramble",p,rng.randf_range(0.45,0.85))

func details() -> void:
	# Plants grow in groups around walls, tree roots and path shoulders.
	var clusters := [Vector3(-5.7,0.04,0),Vector3(-5.7,0.04,3.3),Vector3(-4.8,0.04,4.5),Vector3(-2.2,0.04,5.7),Vector3(0.6,0.04,5.8),Vector3(3.4,0.04,5.5),Vector3(5.5,0.04,2.1),Vector3(5.3,0.04,-1.0),Vector3(2.8,0.04,-4.3),Vector3(-0.6,0.04,-4.8),Vector3(-5.8,0.04,-2.5)]
	var kinds := ["ferns","flowers","bramble","mushrooms"]
	for i in range(clusters.size()):
		for j in range(3):
			var p: Vector3 = clusters[i]+Vector3(rng.randf_range(-0.55,0.55),0,rng.randf_range(-0.4,0.4))
			var height := rng.randf_range(0.45,0.85)
			if kinds[(i+j)%4]=="mushrooms":
				height *= 0.6
			card(kinds[(i+j)%4],p,height)
	for item in [["log",Vector3(-4.8,0.04,3.9),0.8],["rocks",Vector3(6.1,0.04,0.3),1.1],["rocks",Vector3(-6.2,0.04,-1.8),0.8],["fallen",Vector3(1.9,0.04,-5.2),0.65],["flowers",Vector3(-3.3,0.71,-1.75),0.43],["ferns",Vector3(-3.9,0.71,-2.7),0.55]]:
		card(item[0],item[1],item[2])

func card(name: String,p: Vector3,height: float) -> Sprite3D:
	var texture: Texture2D = artwork[name]
	var sprite := Sprite3D.new()
	sprite.name = name.capitalize()+"_"+str(scenery_count)
	sprite.texture = texture
	sprite.position = p
	sprite.pixel_size = height/texture.get_height()
	sprite.offset = Vector2(texture.get_width()*0.5-float(anchors[name].anchor),texture.get_height()*0.5-2)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.25
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite)
	scenery_count += 1
	return sprite

func collider(p: Vector3,size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = p
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	collision_count += 1
	return body

func contact_shadow(p: Vector3,size: Vector2,opacity: float) -> void:
	var plane := PlaneMesh.new()
	plane.size = size
	var node := MeshInstance3D.new()
	node.mesh = plane
	node.position = p+Vector3.UP*0.006
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded,depth_draw_never,cull_disabled; uniform float opacity=0.25; void fragment(){ALBEDO=vec3(0.025,0.075,0.065); ALPHA=(1.0-smoothstep(0.15,1.0,length((UV-vec2(0.5))*2.0)))*opacity;}"
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("opacity",opacity)
	node.material_override = material
	add_child(node)

func atmosphere() -> void:
	# Light shafts are deliberately restrained so attacks and ground warnings remain clear.
	for i in range(3):
		var beam := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.75+i*0.35,7.0)
		beam.mesh = quad
		beam.position = Vector3(-3.5+i*2.0,2.2,-2.0+i*0.5)
		beam.basis = camera.global_basis*Basis(Vector3.FORWARD,-0.38)
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var shader := Shader.new()
		shader.code = "shader_type spatial; render_mode unshaded,depth_draw_never,cull_disabled; void fragment(){float edge=1.0-smoothstep(0.0,0.5,abs(UV.x-0.5)); float fade=smoothstep(0.0,0.18,UV.y)*(1.0-smoothstep(0.55,1.0,UV.y)); ALBEDO=vec3(1.0,0.90,0.64); ALPHA=edge*edge*fade*0.045;}"
		var material := ShaderMaterial.new()
		material.shader = shader
		beam.material_override = material
		add_child(beam)
	for i in range(22):
		var mote := Craft.ball(self,Vector3(rng.randf_range(-6,6),rng.randf_range(0.35,2.6),rng.randf_range(-5,5)),Vector3.ONE*rng.randf_range(0.018,0.032),Craft.material(Color("eddda0"),0.5,0.8))
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var tween := create_tween().set_loops()
		tween.tween_property(mote,"position:y",mote.position.y+0.5,rng.randf_range(3,5)).set_trans(Tween.TRANS_SINE)
		tween.tween_property(mote,"position:y",mote.position.y,rng.randf_range(3,5)).set_trans(Tween.TRANS_SINE)

func _process(delta: float) -> void:
	var actor := get_parent().get("hero") as CharacterBody3D
	if not is_instance_valid(actor) or not is_instance_valid(camera):
		return
	var viewport_height := float(camera.get_viewport().get_visible_rect().size.y)
	var pixels_per_unit := viewport_height/maxf(0.1,camera.size)
	var actor_point := camera.unproject_position(actor.global_position+Vector3.UP*0.85)
	for tree in tall_cards:
		var feet := camera.unproject_position(tree.global_position)
		var h := float(tree.get_meta("painted_height"))*pixels_per_unit
		var w := h*tree.texture.get_width()/tree.texture.get_height()
		var rectangle := Rect2(feet-Vector2(w*0.5,h),Vector2(w,h))
		var behind := camera.global_basis.z.dot(actor.global_position+Vector3.UP*0.8-tree.global_position)<0.15
		var alpha := 0.30 if behind and rectangle.has_point(actor_point) else 1.0
		tree.modulate.a = move_toward(tree.modulate.a,alpha,delta*3.5)
		# Only a fading tree needs alpha blending. Solid trees use a single depth-writing pass.
		var cut := SpriteBase3D.ALPHA_CUT_DISABLED if tree.modulate.a < 0.999 else SpriteBase3D.ALPHA_CUT_DISCARD
		if tree.alpha_cut != cut:
			tree.alpha_cut = cut
