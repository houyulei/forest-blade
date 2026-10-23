extends SceneTree
## Actual game motion, explicitly rendered; --minimized --disable-render-loop is supported.
var game
var hero: Hero
var right := Vector3.RIGHT
var caption: Label
var frames := 0
var clock := 0
func _initialize() -> void:
	set_meta("isolated_adventure",true)
	run.call_deferred()
func step(count: int, record: bool = false) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
		clock += 1
		if record and clock%3==0:
			RenderingServer.force_draw()
			root.get_texture().get_image().get_region(Rect2i(320,130,900,620)).save_png("res://artifacts/weapon-combo-frames/%04d.png" % frames)
			frames += 1
func reset(id: String, direction: Vector3) -> void:
	hero.blades.interrupt()
	hero.blades.skill_cooldown = 0
	hero.cancel_attack()
	hero.hit_pause = 0
	hero.hurt_time = 0
	hero.hurt_flash = 0
	hero.dash_time = 0
	hero.velocity = Vector3.ZERO
	hero.position = Vector3(-1.5,0.035,3)
	hero.facing = direction
	hero.blades.switch_sword(id)
	for target in get_nodes_in_group("enemy"):
		target.position = Vector3(-8,0.035,-7)
	game.focus = Vector3.INF
	game.update_pixel_camera(1)
func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.muted = true
	for target in get_nodes_in_group("enemy"):
		target.set_physics_process(false)
	await step(15)
	hero = game.hero
	right = game.camera.global_basis.x
	right.y = 0
	right = right.normalized()
	game.set_process(false)
	for node in game.get_children():
		if node is CanvasLayer and node.layer>=0: node.hide()
	var layer := CanvasLayer.new()
	layer.layer = 20
	root.add_child(layer)
	caption = Label.new()
	caption.position = Vector2(500,205)
	caption.add_theme_font_size_override("font_size",24)
	caption.add_theme_color_override("font_color",Color("fff0c8"))
	caption.add_theme_constant_override("outline_size",6)
	caption.add_theme_color_override("font_outline_color",Color("183527"))
	layer.add_child(caption)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/weapon-combo-frames"))
	var side := right.cross(Vector3.UP)
	for id in ["fire","thunder"]:
		for direction in [right,-right,side,-side]:
			reset(id,direction)
			await step(10)
			for combo in range(1,4):
				caption.text = (["焰锋大剑 · 肩上斜劈","焰锋大剑 · 反向横斩","焰锋大剑 · 过顶重劈"] if id=="fire" else ["鸣雷长枪 · 平刺","鸣雷长枪 · 低刺","鸣雷长枪 · 踏步贯刺"])[combo-1]
				hero.begin_attack()
				while hero.attack_time>0 or hero.hit_pause>0:
					await step(1,true)
				await step(3,true)
			await step(12,true)
		reset(id,right)
		await step(10)
		if id=="fire":
			caption.text = "焰锋大剑 · 双手过顶蓄力"
			hero.blades.begin_charge()
			await step(48,true)
			hero.blades.release_charge()
			await step(35,true)
		else:
			caption.text = "鸣雷长枪 · 满电雷光贯突"
			hero.blades.thunder_charge = 3
			hero.blades.begin_skill()
			await step(35,true)
		print("RECORDED ",id," total frames ",frames)
	caption.hide()
	game.adventure_ui.show()
	game.set_menu("equipment")
	await step(2)
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/weapon-combo-equipment.png")
	print("WEAPON_COMBO_RECORDING_OK ",frames)
	quit()
