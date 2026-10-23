extends "res://scripts/main.gd"
## A spatial rendering study, isolated from the playable chapter and its saves.
var world: VolumeStyleWorld
var capture_prefix := "style-v2"
var sun: DirectionalLight3D
var overlay: CanvasLayer
var view := 0
var camera_fixed := false
var late_light := false
var follow := true
var follow_offset := Vector3(3.5,5.8,13.0)
const SHOTS := [
	{"name":"村口与远山","camera":Vector3(3.5,6.5,26),"target":Vector3(-0.5,3,-1)},
	{"name":"草地与林坡","camera":Vector3(14,5.5,18),"target":Vector3(-4,2.8,0)},
	{"name":"屋檐与树荫","camera":Vector3(1,4.5,12),"target":Vector3(-6,2.7,3)}]

func _ready() -> void:
	ThemeDB.fallback_font = preload("res://assets/fonts/ChineseMedium.tres")
	progress = AdventureProgress.new()
	progress.persistence_enabled = false
	rng.seed = 71824
	muted = true
	setup_inputs()
	build_light()
	world = create_world()
	add_child(world)
	world.build()
	hero = Hero.new()
	hero.arena = self
	hero.position = Vector3(0,world.height_at(0,13)+0.1,13)
	add_child(hero)
	hero.invulnerable = 99999
	make_ui()
	set_view(0)
	follow = true
	if "--volume-capture" in OS.get_cmdline_user_args():
		camera_fixed = true
		capture_study.call_deferred()

func create_world() -> VolumeStyleWorld:
	return VolumeStyleWorld.new()

func build_light() -> void:
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ShaderMaterial.new()
	var sky_shader := Shader.new()
	sky_shader.code = """shader_type sky;
uniform vec4 zenith:source_color=vec4(0.29,0.57,0.78,1.0);
uniform vec4 horizon:source_color=vec4(0.70,0.83,0.86,1.0);
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void sky(){
 float altitude=max(EYEDIR.y,0.0);
 vec3 base=mix(horizon.rgb,zenith.rgb,smoothstep(0.0,0.25,altitude));
 vec2 p=EYEDIR.xz/max(0.10,altitude)*2.3;
 float cloud=noise(p)*0.60+noise(p*2.2)*0.27+noise(p*4.5)*0.13;
 float mask=smoothstep(0.48,0.65,cloud)*smoothstep(0.02,0.12,altitude);
 COLOR=mix(base,vec3(0.95,0.95,0.89),mask*0.88);
}
"""
	sky_material.shader = sky_shader
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b6c6bb")
	env.ambient_light_energy = 0.40
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color("a5c7d7")
	env.fog_density = 0.0025
	world_env.environment = env
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42,-32,0)
	sun.light_color = Color("fff0cc")
	sun.light_energy = 0.70
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80
	sun.shadow_bias = 0.035
	sun.shadow_normal_bias = 0.25
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 48
	camera.far = 300
	camera.near = 0.15
	add_child(camera)
	camera.current = true

func make_ui() -> void:
	overlay = CanvasLayer.new()
	add_child(overlay)
	var root_ := Control.new()
	root_.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(root_)
	var column := VBoxContainer.new()
	column.position = Vector2(30,24)
	column.add_theme_constant_override("separation",5)
	root_.add_child(column)
	text_label(column,"青芽村 · 目标画风实机版",14,Color("f1e4bf"))
	text_label(column,"风过青芽，溪流入林。",24,Color("fff5dc"))
	text_label(column,"地形 · 自然光 · 树荫 · 风吹草地 · 远景空气感",14,Color("e4e9d7"))
	var footer := text_label(root_,"WASD 走动 · 空格跳跃 · Shift 冲刺 · F 跟随镜头 · F1/F2/F3 观景 · F4 日光 · R 回村口 · H 隐藏说明",14,Color("f0e7cc"))
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 30
	footer.offset_right = -30
	footer.offset_top = -45
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func set_view(index: int) -> void:
	follow = false
	view = index
	camera.look_at_from_position(SHOTS[view].camera,SHOTS[view].target)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_F1: set_view(0)
		KEY_F2: set_view(1)
		KEY_F3: set_view(2)
		KEY_F4:
			late_light = not late_light
			sun.rotation_degrees = Vector3(-24,-72,0) if late_light else Vector3(-42,-32,0)
			sun.light_color = Color("ffd7a0") if late_light else Color("fff0cc")
		KEY_F: follow = not follow
		KEY_R: reset_village_position()
		KEY_H: overlay.visible = not overlay.visible

func _process(delta: float) -> void:
	if is_instance_valid(hero):
		hero.invulnerable = 99999
		if hero.position.y < -3 or absf(hero.position.x)>30 or hero.position.z < -36 or hero.position.z>28:
			reset_village_position()
		if follow and not camera_fixed:
			var target_position := hero.global_position+follow_offset
			camera.position = camera.position.lerp(target_position,1.0-exp(-delta*5.0))
			camera.look_at(hero.global_position+Vector3(0,1.3,-7))

func reset_village_position() -> void:
	hero.position = Vector3(0,world.height_at(0,13)+0.1,13)
	hero.velocity = Vector3.ZERO

func capture_study() -> void:
	overlay.hide()
	for i in range(20):
		await get_tree().physics_frame
	hero.set_physics_process(false)
	hero.facing = Vector3(0,0,-1)
	hero.sprite_view.update_state(hero,0)
	var captures := []
	for i in range(SHOTS.size()):
		set_view(i)
		for j in range(4):
			await get_tree().process_frame
		RenderingServer.force_draw()
		await RenderingServer.frame_post_draw
		var path := "res://artifacts/%s-%d.png"%[capture_prefix,i+1]
		var result := get_viewport().get_texture().get_image().save_png(path)
		captures.append({"view":SHOTS[i].name,"saved":result==OK,"path":path})
		print("VOLUME_CAPTURE: ",path)
	var file := FileAccess.open("res://artifacts/%s-report.json"%capture_prefix,FileAccess.WRITE)
	file.store_string(JSON.stringify({"persistent":false,"grass_instances":world.grass_count,"trees":world.tree_count,"solids":world.solid_count,"static_batches":world.static_batches,"captures":captures},"\t"))
	get_tree().quit()
