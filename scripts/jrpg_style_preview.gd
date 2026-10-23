extends "res://scripts/main.gd"
## Two original visual interpretations, with real player physics and isolated progress.
var world: JRPGVillageWorld
var route := "vesperia"
var overlay: CanvasLayer
var title: Label
var description: Label
var follow := true
var overview := false
var capturing := false
const NAMES := {"vesperia":"A · 薄暮方向 / 立体手绘村庄","ys":"B · 伊苏方向 / 固定俯视 2.5D"}
const DESCRIPTIONS := {"vesperia":"立体建筑 · 手绘石墙与板岩屋顶 · 卡通明暗与细描边","ys":"绘制房屋与树木 · 正交俯视 · 清楚的道路与行走空间"}
func _ready() -> void:
	ThemeDB.fallback_font = preload("res://assets/fonts/ChineseMedium.tres")
	progress = AdventureProgress.new()
	progress.persistence_enabled = false
	muted = true
	setup_inputs()
	if "--ys" in OS.get_cmdline_user_args():
		route = "ys"
	build_review_light()
	build_world()
	hero = Hero.new()
	hero.arena = self
	hero.position = Vector3(0,world.height_at(0,8)+0.1,8)
	add_child(hero)
	hero.invulnerable = 99999
	make_review_ui()
	configure_camera(true)
	if "--jrpg-capture" in OS.get_cmdline_user_args():
		capturing = true
		capture_comparison.call_deferred()
func build_world() -> void:
	world = JRPGVillageWorld.new()
	world.route = route
	add_child(world)
	world.build()
func build_review_light() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("a7c4cf")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b5beca")
	env.ambient_light_energy = 0.48
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env_node.environment = env
	add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55,-28,0)
	sun.light_color = Color("fff4df")
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	sun.shadow_bias = 0.12
	sun.shadow_normal_bias = 1.5
	sun.directional_shadow_max_distance = 65
	add_child(sun)
	camera = Camera3D.new()
	camera.far = 160
	camera.near = 0.1
	camera.current = true
	add_child(camera)
func camera_focus() -> Vector3:
	return Vector3(0,0,-1) if overview else hero.position+Vector3(0,0,-3.3)
func configure_camera(snap: bool = false,delta: float = 0.016) -> void:
	if route=="ys":
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 34 if overview else 22
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 42
	var focus_point := camera_focus()
	var offset := Vector3(19,25,19) if route=="ys" else Vector3(6,8.5,18)
	if overview and route=="vesperia":
		offset = Vector3(14,19,34)
	var next := focus_point+offset
	camera.position = next if snap else camera.position.lerp(next,1-exp(-delta*7))
	camera.look_at(camera.position-offset+Vector3.UP*0.5)
func change_route(next: String) -> void:
	if next==route:
		return
	var old := world
	remove_child(old)
	old.queue_free()
	route = next
	build_world()
	configure_camera(true)
	title.text = NAMES[route]
	description.text = DESCRIPTIONS[route]
func make_review_ui() -> void:
	overlay = CanvasLayer.new()
	add_child(overlay)
	var root_ := Control.new()
	root_.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(root_)
	var column := VBoxContainer.new()
	column.position = Vector2(24,20)
	column.add_theme_constant_override("separation",6)
	root_.add_child(column)
	title = text_label(column,NAMES[route],23,Color("fff0cb"))
	description = text_label(column,DESCRIPTIONS[route],14,Color("e6e8d6"))
	text_label(column,"原创实机试作 · 视觉参考方向，不是原作资源或复刻",13,Color("cbd5ca"))
	var footer := text_label(root_,"Tab 切换方案 · F1 薄暮方向 · F2 伊苏方向 · F3 全村／近景 · WASD 走动 · 空格跳跃 · Shift 冲刺 · R 回入口 · H 隐藏说明",14,Color("f7edda"))
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 20
	footer.offset_right = -20
	footer.offset_top = -44
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
func _input(event: InputEvent) -> void:
	if capturing or not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_TAB: change_route("ys" if route=="vesperia" else "vesperia")
		KEY_F1: change_route("vesperia")
		KEY_F2: change_route("ys")
		KEY_F3:
			overview = not overview
			configure_camera(true)
		KEY_R: reset_review()
		KEY_H: overlay.visible = not overlay.visible
func reset_review() -> void:
	hero.position = Vector3(0,world.height_at(0,8)+0.1,8)
	hero.velocity = Vector3.ZERO
func _process(delta: float) -> void:
	if not is_instance_valid(hero):
		return
	hero.invulnerable = 99999
	if hero.position.y < -3 or absf(hero.position.x)>23 or hero.position.z>22 or hero.position.z < -25:
		reset_review()
	if not capturing:
		configure_camera(false,delta)
func capture_comparison() -> void:
	overlay.hide()
	for i in range(25):
		await get_tree().physics_frame
	hero.set_physics_process(false)
	hero.facing = Vector3.FORWARD
	hero.sprite_view.update_state(hero,0)
	var report := {}
	for variant in ["vesperia","ys"]:
		change_route(variant)
		report[variant] = []
		for shot in ["overview","street"]:
			overview = shot=="overview"
			configure_camera(true)
			for j in range(5):
				await get_tree().process_frame
			RenderingServer.force_draw()
			await RenderingServer.frame_post_draw
			var path := "res://artifacts/jrpg-%s-%s.png"%[variant,shot]
			var result := get_viewport().get_texture().get_image().save_png(path)
			report[variant].append({"path":path,"saved":result==OK,"houses":world.house_roots.size(),"solids":world.solids,"painted_cards":world.painted_cards.size(),"persistent":progress.persistence_enabled})
			print("JRPG_CAPTURE ",path)
	var file := FileAccess.open("res://artifacts/jrpg-comparison-report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	get_tree().quit()
