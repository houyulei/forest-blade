extends Node3D

var hero: Hero
var enemy: Sentinel
var bokoblins: Array[Bokoblin] = []
var camera: Camera3D
var shake: float = 0
var rng := RandomNumberGenerator.new()
var hp_label: Label
var status_label: Label
var objective_label: Label
var dash_bar: ProgressBar
var message: Label
var progress: AdventureProgress
var adventure_ui: AdventureUI
var forge: ForestForge
var menu_open := false
var menu_mode := ""
var paused_actors: Array = []
var dropped_enemy_ids: Array[int] = []
var won: bool = false
var elapsed: float = 0
var camera_home := Vector3(11, 14, 13)
var camera_target := Vector3(0, 0.4, 0)
var audio_players: Array[AudioStreamPlayer] = []
var audio_index: int = 0
var capture_mode: bool = false
var verify_mode: bool = false
var capture_frame: int = 0
var muted: bool = false
var benchmark_mode: bool = false
var benchmark_elapsed: float = 0
var benchmark_frames: Array[float] = []
## Full-resolution offscreen world, composited underneath the interface.
const PIXEL_SCALE := 1
const PIXEL_MARGIN := 2
## World units visible vertically, framing the sanctuary and the combat clearing.
const VIEW_HEIGHT := 10.6
var pixel_world: SubViewport
var pixel_display: TextureRect
var focus := Vector3.INF
var forest: ForestSanctuary

func _ready() -> void:
	ThemeDB.fallback_font = preload("res://assets/fonts/ChineseMedium.tres")
	rng.seed = 71824
	var args := OS.get_cmdline_user_args()
	capture_mode = "--capture" in args
	benchmark_mode = "--benchmark" in args
	verify_mode = "--verify" in args
	muted = "--mute" in args or verify_mode
	if not get_tree().has_meta("adventure_progress"):
		var data := AdventureProgress.new()
		data.persistence_enabled = not (verify_mode or capture_mode or benchmark_mode or get_tree().has_meta("isolated_adventure"))
		data.load_save()
		get_tree().set_meta("adventure_progress",data)
	progress = get_tree().get_meta("adventure_progress")
	setup_inputs()
	build_environment()
	build_level()
	hero = Hero.new()
	hero.name = "Hero"
	hero.arena = self
	hero.position = Vector3(-2.0, 0.1, 1.7)
	add_child(hero)
	enemy = Sentinel.new()
	enemy.name = "MossSentinel"
	enemy.arena = self
	enemy.hero = hero
	enemy.position = Vector3(2.1, 0.1, -1.5)
	add_child(enemy)
	for spawn in [Vector3(-4.0,0.1,3.6),Vector3(3.5,0.1,2.7)]:
		var goblin := Bokoblin.new()
		goblin.name = "RedBokoblin%d" % (bokoblins.size()+1)
		goblin.arena = self
		goblin.hero = hero
		goblin.position = spawn
		goblin.facing = (hero.position-spawn).normalized()
		add_child(goblin)
		bokoblins.append(goblin)
	forge = ForestForge.new()
	forge.position = Vector3(3.6,0.035,-0.35)
	add_child(forge)
	setup_ui()
	adventure_ui = AdventureUI.new()
	adventure_ui.arena = self
	add_child(adventure_ui)
	for i in range(6):
		var player := AudioStreamPlayer.new()
		player.volume_db = -12
		add_child(player)
		audio_players.append(player)
	if capture_mode or benchmark_mode or verify_mode:
		for goblin in bokoblins:
			goblin.set_physics_process(false)
	if capture_mode:
		enemy.set_physics_process(false)
		hero.facing = Vector3(1,0,1).normalized()
		enemy.visual.rotation.y = 0.4
	if benchmark_mode:
		enemy.set_physics_process(false)
		hero.set_physics_process(false)
		hero.position = Vector3(5.2,0.03,6.8)
	if verify_mode:
		if get_tree().has_meta("verify_restart_pending"):
			verify_restart.call_deferred()
		else:
			verify_game.call_deferred()

func setup_inputs() -> void:
	var keys := {"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "up": [KEY_W, KEY_UP], "down": [KEY_S, KEY_DOWN], "jump": [KEY_SPACE], "attack": [KEY_J], "dash": [KEY_SHIFT], "restart": [KEY_R], "mute": [KEY_M], "fire_skill":[KEY_Q], "sword_skill":[KEY_K], "sword_1":[KEY_1], "sword_2":[KEY_2], "sword_3":[KEY_3], "forge":[KEY_E], "equipment":[KEY_I], "forge_close":[KEY_ESCAPE]}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", mouse)

func build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("9bb4ad")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a9bfca")
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_color = Color("ffe8c7")
	sun.light_energy = 0.65
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45
	sun.shadow_bias = 0.035
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.far = 120
	setup_pixel_view()
	pixel_world.add_child(camera)
	camera.look_at_from_position(camera_home, camera_target)
	camera.current = true

func setup_pixel_view() -> void:
	get_viewport().disable_3d = true
	Craft.outline_scale = 1.0
	Craft.pixel_art = false
	pixel_world = SubViewport.new()
	pixel_world.world_3d = get_viewport().find_world_3d()
	pixel_world.msaa_3d = Viewport.MSAA_2X
	pixel_world.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(pixel_world)
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	pixel_display = TextureRect.new()
	pixel_display.texture = pixel_world.get_texture()
	pixel_display.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	pixel_display.stretch_mode = TextureRect.STRETCH_SCALE
	pixel_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pixel_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(pixel_display)

## Follows the hero, snapping the camera to whole low-res pixels so the world never
## shimmers; the sub-pixel remainder slides the upscaled image for smooth motion.
func update_pixel_camera(delta: float) -> void:
	var window := Vector2(DisplayServer.window_get_size()) if DisplayServer.get_name() != "headless" else Vector2(1280, 800)
	var low := Vector2i(ceili(window.x / PIXEL_SCALE), ceili(window.y / PIXEL_SCALE))
	pixel_world.size = low + Vector2i(PIXEL_MARGIN * 2, PIXEL_MARGIN * 2)
	var texel := VIEW_HEIGHT / low.y
	camera.size = texel * pixel_world.size.y
	var goal := Vector3(hero.position.x*0.5-0.35, 0, hero.position.z*0.5-0.35) if is_instance_valid(hero) else Vector3.ZERO
	focus = goal if focus == Vector3.INF else focus.lerp(goal, minf(1, delta * 6))
	var basis := camera.global_transform.basis
	var local := basis.inverse() * (focus + camera_home - camera_target)
	local += Vector3(rng.randf_range(-shake, shake), rng.randf_range(-shake, shake), 0)
	var snapped := Vector3(roundf(local.x / texel) * texel, roundf(local.y / texel) * texel, local.z)
	camera.global_position = basis * snapped
	var rest := (local - snapped) / texel
	var unit := Vector2(PIXEL_SCALE, PIXEL_SCALE) / get_viewport().get_final_transform().get_scale()
	var offset := Vector2(-rest.x, rest.y) - (Vector2(pixel_world.size) - window / PIXEL_SCALE) * 0.5
	pixel_display.position = offset * unit
	pixel_display.size = Vector2(pixel_world.size) * unit

func build_level() -> void:
	forest = ForestSanctuary.new()
	forest.name = "PaintedForestSanctuary"
	forest.camera = camera
	add_child(forest)
	forest.build()

func text_label(parent: Control, content: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = content
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.04,0.10,0.11,0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(label)
	return label

func setup_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)
	var cream := Color("fff0cc")
	var pale := Color("d0e1d7")
	var vignette := ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vignette_shader := Shader.new()
	vignette_shader.code = "shader_type canvas_item; void fragment(){float d=length((UV-vec2(0.5))*vec2(1.0,0.9));float a=smoothstep(0.26,0.73,d)*0.30;COLOR=vec4(0.015,0.05,0.035,a);}"
	var vignette_material := ShaderMaterial.new()
	vignette_material.shader = vignette_shader
	vignette.material = vignette_material
	root.add_child(vignette)
	var left_back := Panel.new()
	left_back.position = Vector2(24,19)
	left_back.size = Vector2(430,220)
	left_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glass := StyleBoxFlat.new()
	glass.bg_color = Color(0.025,0.075,0.065,0.73)
	glass.corner_radius_top_left = 10
	glass.corner_radius_top_right = 10
	glass.corner_radius_bottom_left = 10
	glass.corner_radius_bottom_right = 10
	glass.border_color = Color(0.72,0.65,0.40,0.22)
	glass.set_border_width_all(1)
	left_back.add_theme_stylebox_override("panel",glass)
	root.add_child(left_back)
	var right_back := Panel.new()
	right_back.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right_back.offset_left = -385
	right_back.offset_right = -24
	right_back.offset_top = 19
	right_back.offset_bottom = 121
	right_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_back.add_theme_stylebox_override("panel",glass)
	root.add_child(right_back)
	var top := VBoxContainer.new()
	top.position = Vector2(42, 30)
	top.add_theme_constant_override("separation", 2)
	root.add_child(top)
	text_label(top, "第一章 / 荒草中的圣所", 13, Color("e8cb89"))
	text_label(top, "森之刃", 34, cream)
	text_label(top, "穿过林荫，寻找遗忘的微光。", 16, pale)
	var health := VBoxContainer.new()
	health.position = Vector2(44, 143)
	root.add_child(health)
	text_label(health, "年少的旅人", 12, pale)
	hp_label = text_label(health, "", 28, Color("f0b197"))
	dash_bar = ProgressBar.new()
	dash_bar.custom_minimum_size = Vector2(178, 5)
	dash_bar.show_percentage = false
	dash_bar.max_value = 0.85
	health.add_child(dash_bar)
	var bar := StyleBoxFlat.new()
	bar.bg_color = Color("8cd5c2")
	dash_bar.add_theme_stylebox_override("fill", bar)
	text_label(health, "冲刺", 10, pale)
	var objective := VBoxContainer.new()
	objective.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	objective.offset_left = -365
	objective.offset_right = -35
	objective.offset_top = 36
	objective.offset_bottom = 145
	root.add_child(objective)
	text_label(objective, "古老圣所", 13, Color("e8cb89"))
	objective_label = text_label(objective, "清理圣所 · 3 名敌人", 19, cream)
	status_label = text_label(objective, "闪开挥棒，跳过震地。", 14, pale)
	var footer := PanelContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 30
	footer.offset_right = -30
	footer.offset_top = -78
	footer.offset_bottom = -26
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.07,0.14,0.15,0.88)
	panel.corner_radius_top_left = 9
	panel.corner_radius_top_right = 9
	panel.corner_radius_bottom_left = 9
	panel.corner_radius_bottom_right = 9
	panel.content_margin_left = 24
	panel.content_margin_right = 24
	footer.add_theme_stylebox_override("panel", panel)
	root.add_child(footer)
	var controls := text_label(footer, "WASD 移动　空格 跳跃　J 攻击　K 武器技　Q 元素魔法　1/2/3 切换　Shift 冲刺　E 对话　I 装备　R 重返", 14, cream)
	controls.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message = text_label(root, "", 34, cream)
	message.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	message.offset_left = -400
	message.offset_right = 400
	message.offset_top = -65
	message.offset_bottom = 65
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _process(delta: float) -> void:
	elapsed += delta
	if benchmark_mode:
		benchmark_elapsed += delta
		if benchmark_elapsed > 2.0:
			benchmark_frames.append(delta)
		if benchmark_elapsed > 7.0 and not benchmark_frames.is_empty():
			benchmark_frames.sort()
			var total := 0.0
			for frame_time in benchmark_frames:
				total += frame_time
			var report := {"average_fps":benchmark_frames.size()/total,"median_frame_ms":benchmark_frames[benchmark_frames.size()/2]*1000.0,"p95_frame_ms":benchmark_frames[int(benchmark_frames.size()*0.95)]*1000.0,"samples":benchmark_frames.size(),"location":"foreground canopy","render_scale":1.0,"msaa":"2x"}
			var file := FileAccess.open("res://artifacts/performance.json",FileAccess.WRITE)
			file.store_string(JSON.stringify(report,"\t"))
			print("PERFORMANCE: ",JSON.stringify(report))
			get_tree().quit()
	if Input.is_action_just_pressed("restart") and not menu_open:
		get_tree().reload_current_scene()
	if Input.is_action_just_pressed("mute"):
		muted = not muted
	if is_instance_valid(hero):
		hp_label.text = "● ".repeat(hero.hp) + "○ ".repeat(hero.max_hp - hero.hp)
		dash_bar.value = 0.85 - hero.dash_cooldown
		if not hero.alive:
			message.text = "暂歇片刻，再踏旅途。\nR · 重新出发"
			objective_label.text = "森林静候你的归来。"
		elif not won:
			objective_label.text = "清理圣所 · 剩余 %d 名" % living_enemy_count()
			var club_ready := false
			for goblin in bokoblins:
				club_ready = club_ready or (goblin.alive and goblin.state == "windup")
			status_label.text = "侧移闪开挥棒！" if club_ready else ("跳跃躲避震地！" if enemy.alive and enemy.state == "windup" else "保持移动，进攻后及时退开。")
	shake = maxf(0, shake - delta)
	update_pixel_camera(delta)
	if capture_mode:
		capture_frame += 1
		match capture_frame:
			20:
				hero.velocity = Vector3.ZERO
				hero.sprite_view.update_state(hero, 0.0)
				hero.set_physics_process(false)
			60:
				await save_capture("first-light")
			61:
				hero.set_physics_process(true)
				Input.action_press("attack")
			63:
				Input.action_release("attack")
			70:
				await save_capture("attack")
			100:
				Input.action_press("jump")
			102:
				Input.action_release("jump")
			113:
				await save_capture("jump")
			160:
				hero.set_physics_process(false)
				var back := camera.global_basis.z
				back.y = 0
				hero.position = Vector3(-5.5,0.03,1.2) - back.normalized() * 0.55
				hero.sprite_view.update_state(hero, 0.0)
			205:
				await save_capture("occlusion")
			230:
				hero.set_physics_process(true)
				var toward_camera := camera.global_basis.z
				toward_camera.y = 0
				hero.position = Vector3(5.7,0.08,7.4)-toward_camera.normalized()*0.8
				hero.velocity = Vector3.ZERO
			270:
				await save_capture("canopy-fade")
			300:
				print("CAPTURE_FPS: ",Engine.get_frames_per_second())
				get_tree().quit()

func save_capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://artifacts/%s.png" % filename)
	get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURE_SAVED: " + path)

func burst(p: Vector3, color: Color, count: int) -> void:
	for i in range(count):
		var particle := Craft.box(self, p, Vector3.ONE * rng.randf_range(0.035, 0.10), Craft.material(color, 0.5, 0.4))
		particle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var destination := p + Vector3(rng.randf_range(-0.6,0.6), rng.randf_range(0.2,0.9), rng.randf_range(-0.6,0.6))
		var tween := create_tween().set_parallel(true)
		tween.tween_property(particle, "position", destination, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "scale", Vector3.ZERO, 0.45)
		tween.chain().tween_callback(particle.queue_free)

func shockwave(p: Vector3) -> void:
	var wave := Craft.ring(self, Vector3(p.x, 0.08, p.z), 1.0, 0.06, Craft.material(Color(1,0.64,0.3,0.65), 0.4, 0.7))
	var tween := create_tween().set_parallel(true)
	tween.tween_property(wave, "scale", Vector3.ONE * 2.0, 0.32)
	tween.tween_property(wave, "transparency", 1.0, 0.32)
	tween.chain().tween_callback(wave.queue_free)

func damage_number(p: Vector3, amount: int) -> void:
	var label := Label3D.new()
	label.text = str(amount)
	label.font_size = 60
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("ffe2a0")
	label.outline_modulate = Color("374c48")
	label.position = p
	add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", p.y + 0.7, 0.65)
	tween.tween_property(label, "modulate:a", 0.0, 0.65)
	tween.chain().tween_callback(label.queue_free)

func living_enemy_count() -> int:
	var count := 0
	for target in get_tree().get_nodes_in_group("enemy"):
		if target.alive:
			count += 1
	return count

func can_enemy_attack(requester: Node3D) -> bool:
	if not hero.alive or not camera.is_position_in_frustum(requester.global_position+Vector3.UP*0.8):
		return false
	var active := 0
	for target in get_tree().get_nodes_in_group("enemy"):
		if target!=requester and target.alive and target.state in ["windup","strike"]:
			active += 1
	return active<2

func enemy_defeated(target: Node3D) -> void:
	if not dropped_enemy_ids.has(target.get_instance_id()):
		dropped_enemy_ids.append(target.get_instance_id())
		var rewards := {"gold":30,"ore":3,"stone":1} if target is Sentinel else {"gold":8,"ore":1,"fang":1}
		var index := 0
		for item in rewards:
			var pickup := LootPickup.new()
			pickup.arena = self
			pickup.item = item
			pickup.amount = rewards[item]
			pickup.position = target.global_position+Vector3(sin(index*2.4),0,cos(index*2.4))*0.26
			var ray := PhysicsRayQueryParameters3D.create(pickup.position+Vector3.UP*2,pickup.position+Vector3.DOWN*4,1)
			var hit := get_world_3d().direct_space_state.intersect_ray(ray)
			if not hit.is_empty():
				pickup.position.y = hit.position.y+0.015
			add_child(pickup)
			index += 1
	if not won and living_enemy_count()==0:
		victory()

func victory() -> void:
	won = true
	objective_label.text = "圣所重归宁静"
	status_label.text = "拾取素材，找铁匠阿伦强化装备。"
	message.modulate.a = 1
	message.text = "圣所重归宁静\n收好素材，磨砺锋刃。"
	var tween := create_tween()
	tween.tween_interval(3.2)
	tween.tween_property(message, "modulate:a", 0.0, 1.0)

func near_forge() -> bool:
	return is_instance_valid(forge) and hero.alive and hero.global_position.distance_to(forge.smith_position())<1.9

func set_menu(mode: String = "") -> void:
	if mode=="smith" and not near_forge():
		return
	if mode!="" and not hero.alive:
		return
	if mode=="smith":
		for target in get_tree().get_nodes_in_group("enemy"):
			if target.alive and target.global_position.distance_to(hero.global_position)<3.0:
				adventure_ui.notify("附近还有敌人，先脱离战斗再与阿伦交谈。")
				return
	if mode!="" and not menu_open:
		paused_actors.clear()
		var actors: Array = [hero]
		actors.append_array(get_tree().get_nodes_in_group("enemy"))
		for actor in actors:
			paused_actors.append([actor,actor.is_physics_processing()])
			actor.set_physics_process(false)
	elif mode=="" and menu_open:
		for pair in paused_actors:
			if is_instance_valid(pair[0]):
				pair[0].set_physics_process(pair[1])
		paused_actors.clear()
	menu_mode = mode
	menu_open = mode!=""
	adventure_ui.show_menu(mode)

func play_tone(frequency: float, duration: float, volume: float) -> void:
	if muted or audio_players.is_empty():
		return
	var sample := AudioStreamWAV.new()
	sample.format = AudioStreamWAV.FORMAT_16_BITS
	sample.mix_rate = 22050
	var frames := int(duration * sample.mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / sample.mix_rate
		var envelope := pow(1.0 - float(i) / frames, 2)
		var value := int(sin(TAU * frequency * t * (1.0 - t * 2)) * 32767 * volume * envelope)
		bytes.encode_s16(i * 2, value)
	sample.data = bytes
	var audio := audio_players[audio_index % audio_players.size()]
	audio_index += 1
	audio.stream = sample
	audio.play()

func wait_frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame

func require(condition: bool, description: String) -> bool:
	if not condition:
		push_error("VERIFY FAILED: " + description)
		get_tree().quit(1)
		return false
	print("PASS: " + description)
	return true

func verify_game() -> void:
	enemy.set_physics_process(false)
	await wait_frames(15)
	if not require(hero.sprite_view.sprite is Sprite3D, "hero uses a 2D billboard in 3D"):
		return
	var camera_right := camera.global_basis.x
	var camera_away := -camera.global_basis.z
	camera_away.y = 0
	camera_away = camera_away.normalized()
	var facings := [-camera_away, -camera_right, camera_right, camera_away]
	for row in range(4):
		hero.facing = facings[row]
		hero.sprite_view.update_state(hero, 0.0)
		if not require(hero.sprite_view.direction_row == row, "sprite facing row %d" % row):
			return
	if not require(hero.sprite_view.shadow.visible, "ground shadow finds the arena"):
		return
	if not require(enemy.sprite is Sprite3D, "enemy uses directional sprites"):
		return
	if not require(forest.scenery_count >= 60 and forest.collision_count >= 15, "painted scenery and solid environment loaded"):
		return
	var start := hero.position
	Input.action_press("right")
	await wait_frames(30)
	Input.action_release("right")
	if not require(hero.position.distance_to(start) > 1 and hero.sprite_view.action_name == "run", "camera-relative movement and run animation"):
		return
	Input.action_press("jump")
	await wait_frames(2)
	Input.action_release("jump")
	await wait_frames(12)
	if not require(hero.did_jump and hero.position.y > 0.6 and hero.sprite_view.action_name == "jump", "jump leaves ground"):
		return
	await wait_frames(55)
	if not require(hero.did_land and hero.is_on_floor(), "landing on arena collision"):
		return
	hero.position = Vector3(0,0.05,1)
	enemy.position = Vector3(0,0.05,-0.4)
	hero.facing = Vector3(0,0,-1)
	hero.velocity = Vector3.ZERO
	var before := enemy.hp
	Input.action_press("attack")
	await wait_frames(2)
	Input.action_release("attack")
	if not require(hero.sprite_view.action_name == "attack", "attack switches to drawn sword frames"):
		return
	await wait_frames(30)
	if not require(enemy.hp == before - progress.sword_damage(), "sword connects once per swing"):
		return
	before = hero.hp
	hero.invulnerable = 0
	hero.take_hit(1, Vector3.RIGHT)
	hero.take_hit(1, Vector3.RIGHT)
	if not require(hero.hp == before - 1, "damage and invulnerability"):
		return
	await wait_frames(12) # Finish the new hit reaction before accepting a dash.
	Input.action_press("dash")
	await wait_frames(2)
	Input.action_release("dash")
	if not require(hero.dash_cooldown > 0, "dash cooldown"):
		return
	# Verify a real enemy windup resolves into damage while grounded.
	await wait_frames(70)
	hero.position = Vector3(0,0.05,1)
	hero.velocity = Vector3.ZERO
	hero.invulnerable = 0
	enemy.position = Vector3(0,0.05,-0.4)
	enemy.state = "windup"
	enemy.timer = 0.1
	enemy.set_physics_process(true)
	before = hero.hp
	await wait_frames(20)
	if not require(enemy.attack_count > 0 and hero.hp == before - 1, "enemy telegraphed attack deals damage"):
		return
	# The same ground slam must miss when the player jumps over it.
	hero.invulnerable = 0
	hero.position = Vector3(0,1.3,1)
	hero.velocity = Vector3.ZERO
	enemy.state = "windup"
	enemy.timer = 0.08
	before = hero.hp
	await wait_frames(12)
	if not require(hero.hp == before and enemy.attack_count >= 2, "jump avoids enemy ground slam"):
		return
	enemy.take_hit(99, Vector3.FORWARD, true)
	await wait_frames(3)
	if not require(not won and not enemy.alive and living_enemy_count()==2, "sentinel defeat does not end a multi-enemy encounter"):
		return
	for goblin in bokoblins:
		goblin.take_hit(99,Vector3.FORWARD,true)
	if not require(won and living_enemy_count()==0, "all enemies defeated triggers victory"):
		return
	var toward_camera := camera.global_basis.z
	toward_camera.y = 0
	hero.position = Vector3(5.7,0.08,7.4)-toward_camera.normalized()*0.8
	hero.velocity = Vector3.ZERO
	await wait_frames(35)
	if not require(forest.tall_cards[7].modulate.a < 0.6, "foreground canopy fades to reveal the player"):
		return
	hero.position = Vector3(-2.7,1.5,-1.2)
	hero.velocity = Vector3.ZERO
	await wait_frames(60)
	if not require(hero.is_on_floor() and hero.position.y > 0.2, "landing on the real sanctuary steps"):
		return
	hero.invulnerable = 0
	hero.take_hit(99, Vector3.ZERO)
	if not require(not hero.alive and hero.hp == 0, "player defeat"):
		return
	get_tree().set_meta("verify_restart_pending", true)
	get_tree().reload_current_scene.call_deferred()

func verify_restart() -> void:
	await wait_frames(10)
	if not require(hero.alive and hero.hp == hero.max_hp and enemy.alive and enemy.hp == enemy.max_hp and living_enemy_count()==3 and not won, "restart resets actors and victory"):
		return
	print("GAMEPLAY_VERIFICATION_OK")
	get_tree().quit(0)
