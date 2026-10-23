extends SceneTree
## Controlled review poses in the production village. Never touches player progress.
var game
func _initialize() -> void:
	set_meta("isolated_adventure",true)
	run.call_deferred()
func run() -> void:
	game = load("res://journey_chapter.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.muted = true
	game.load_room("village",Vector3(0,0,14))
	for i in range(20): await physics_frame
	var hero: Hero = game.hero
	hero.set_physics_process(false)
	game.set_process(false)
	game.message.modulate.a = 0
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var caption := Label.new()
	caption.position = Vector2(420,32)
	caption.add_theme_font_size_override("font_size",23)
	caption.add_theme_color_override("font_color",Color("ffe7aa"))
	caption.add_theme_color_override("font_outline_color",Color("172c27"))
	caption.add_theme_constant_override("outline_size",6)
	layer.add_child(caption)
	var right: Vector3 = game.camera.global_basis.x
	right.y = 0
	var away: Vector3 = -game.camera.global_basis.z
	away.y = 0
	for weapon in SwordArsenal.ORDER:
		for mode in ["run","attack"]:
			hero.blades.interrupt()
			hero.cancel_attack()
			hero.blades.switch_sword(weapon)
			hero.hurt_time = 0
			hero.dash_time = 0
			hero.landing_time = 0
			var direction := 1 if mode=="run" else 5
			hero.facing = -right.normalized()*sin(direction*PI/4)-away.normalized()*cos(direction*PI/4)
			hero.sprite_view.direction8 = direction
			hero.velocity = hero.facing*3 if mode=="run" else Vector3.ZERO
			hero.sprite_view.run_phase = 0.55
			hero.sprite_view.last_position = hero.position-hero.facing*0.04
			hero.sprite_view.has_last_position = true
			if mode=="attack":
				hero.combo = 0
				hero.combo_window = 0
				hero.begin_attack()
				hero.attack_time = hero.attack_duration*0.58
			hero.sprite_view.update_state(hero,0)
			caption.text = SwordArsenal.data(weapon).name+" · "+HeroDirections.NAMES[direction]+("移动" if mode=="run" else "普攻")+"（受控姿势审阅）"
			game.focus = Vector3.INF
			game.update_pixel_camera(0)
			for i in range(4): await process_frame
			RenderingServer.force_draw()
			var path: String = "res://artifacts/eight-game-"+weapon+"-"+mode+".png"
			root.get_texture().get_image().save_png(path)
			print("EIGHT_CAPTURE ",path)
	print("EIGHT_CAPTURE_COMPLETE")
	quit()
