extends SceneTree
## In-engine, fixed-60-fps presentation. Only captions/camera framing are demonstration-specific.
var game
var hero: Hero
var caption: Label
var right := Vector3.RIGHT
func _initialize() -> void:
	set_meta("isolated_adventure",true)
	run.call_deferred()
func step(n: int) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func reset(id: String) -> void:
	hero.blades.interrupt()
	hero.cancel_attack()
	hero.hurt_time = 0
	hero.hurt_flash = 0
	hero.hit_pause = 0
	hero.dash_time = 0
	hero.invulnerable = 0
	hero.velocity = Vector3.ZERO
	hero.position = Vector3(-1.5,0.035,3)
	hero.facing = right
	hero.blades.skill_cooldown = 0
	hero.blades.wind_window = 0
	hero.blades.wind_count = 0
	hero.blades.thunder_charge = 0
	hero.blades.magic_meters[id] = 100.0
	hero.blades.switch_sword(id)
	for node in get_nodes_in_group("sword_effect")+get_nodes_in_group("blade_fx"):
		node.queue_free()
	var actors := [game.bokoblins[0],game.bokoblins[1],game.enemy]
	for i in range(3):
		actors[i].position = hero.position+right*(1.5+i*1.25)
		actors[i].hp = 10000
		actors[i].max_hp = 10000
		if actors[i] is Bokoblin:
			actors[i].facing = -right
			actors[i].change_state("idle")
			actors[i].update_visual(0)
	game.shake = 0
	game.focus = Vector3.INF
	game.update_pixel_camera(1)
func run() -> void:
	if DisplayServer.get_name()=="headless":
		quit(1)
		return
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.muted = true
	for actor in get_nodes_in_group("enemy"):
		actor.set_physics_process(false)
	await step(20)
	hero = game.hero
	right = game.camera.global_basis.x
	right.y = 0
	right = right.normalized()
	game.set_process(false)
	for node in game.get_children():
		if node is CanvasLayer and node.layer>=0:
			node.hide()
	var layer := CanvasLayer.new()
	layer.layer = 20
	root.add_child(layer)
	caption = Label.new()
	caption.position = Vector2(440,220)
	caption.add_theme_font_size_override("font_size",25)
	caption.add_theme_color_override("font_color",Color("fff0c8"))
	caption.add_theme_constant_override("outline_size",6)
	caption.add_theme_color_override("font_outline_color",Color("183527"))
	layer.add_child(caption)
	for id in SwordArsenal.ORDER:
		reset(id)
		var folder: String = "res://artifacts/three-swords-demo/"+id
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
		var count := 290 if id=="wind" else (270 if id=="fire" else 190)
		for frame in range(count):
			await physics_frame
			match id:
				"wind":
					if frame==0: caption.text = "苍岚剑｜三连斩"
					if frame in [9,36,65]: hero.begin_attack()
					if frame==108:
						caption.text = "苍岚剑｜旋身连舞"
						hero.blades.begin_wind(true)
					if frame in [135,162]: hero.blades.begin_wind(true)
					if frame==203:
						caption.text = "苍岚剑｜苍岚龙卷"
						hero.blades.cast_magic()
				"fire":
					if frame==0: caption.text = "焰锋剑｜重斩"
					if frame in [9,43,78]: hero.begin_attack()
					if frame==127:
						caption.text = "焰锋剑｜蓄力→向前释放"
						hero.blades.begin_charge()
					if frame==187: hero.blades.release_charge()
					if frame==218:
						caption.text = "焰锋剑｜贯焰火球"
						hero.blades.cast_magic()
				"thunder":
					if frame==0: caption.text = "鸣雷剑｜连刺积电"
					if frame in [9,31,54]: hero.begin_attack()
					if frame==83:
						caption.text = "鸣雷剑｜满电雷光突进"
						hero.blades.begin_thunder()
					if frame==117:
						caption.text = "鸣雷剑｜跃雷连锁"
						hero.blades.cast_magic()
			await process_frame
			if frame%3==0:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().get_region(Rect2i(360,170,850,530)).save_png(folder+"/%04d.png" % frame)
		print("RECORDED ",id," frames ",count)
	print("THREE_SWORDS_RECORDING_OK")
	quit()
