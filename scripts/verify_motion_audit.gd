extends SceneTree
## Isolated real-game smoke check for the layered carry, jump, landing and hit state.
var game
var hero: Hero
var checks: Array = []
var failed := false
func _initialize() -> void:
	set_meta("isolated_adventure",true)
	run.call_deferred()
func step(n: int) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(ok: bool, title: String) -> void:
	checks.append({"passed":ok,"check":title})
	failed = failed or not ok
	print("PASS: " if ok else "FAIL: ",title)
func capture(id: String) -> void:
	if DisplayServer.get_name()=="headless": return
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/audit-game-%s.png" % id)
func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.muted = true
	for target in get_nodes_in_group("enemy"):
		target.set_physics_process(false)
		target.position = Vector3(-8,0.035,-7)
	await step(20)
	hero = game.hero
	for id in ["fire","thunder"]:
		hero.blades.switch_sword(id)
		for direction in ["right","left","up","down"]:
			hero.position = Vector3(0,0.035,2)
			hero.velocity = Vector3.ZERO
			await step(12)
			Input.action_press(direction)
			await step(18)
			check(hero.sprite_view.action_name=="run" and not hero.sprite_view.sprite.visible and hero.sprite_view.run_visuals.all(func(n):return n.visible),"%s %s uses visible torso and leg layers" % [id,direction])
			if direction in ["left","right"]:
				var regions := {}
				for phase in range(16):
					var parts := HeroSprite.run_parts(id,hero.sprite_view.direction_row,float(phase)/16.0)
					regions[str(parts[0].rect)] = true
				check(regions.size()==16,"%s %s side gait keeps all sixteen leg frames" % [id,direction])
			await capture(id+"-"+direction)
			Input.action_release(direction)
			await step(10)
		Input.action_press("jump")
		await step(8)
		Input.action_release("jump")
		check(hero.sprite_view.current_atlas==HeroSprite.state_atlas(id) and hero.sprite_view.current_column==2,"%s rises using its dedicated jump pose" % id)
		await capture(id+"-jump")
		await step(18)
		check(hero.sprite_view.current_atlas==HeroSprite.state_atlas(id) and hero.sprite_view.current_column==3,"%s falls using its dedicated descent pose" % id)
		await capture(id+"-fall")
		var landed := false
		for i in range(40):
			await step(1)
			if hero.landing_time>0 and not landed:
				landed = true
				check(hero.sprite_view.current_atlas==HeroSprite.state_atlas(id) and hero.sprite_view.current_column==4,"%s landing uses its dedicated two-knee recovery pose" % id)
				await capture(id+"-land")
		if not landed: check(false,"%s landing recovery must occur" % id)
		hero.invulnerable = 0
		hero.take_hit(1,Vector3.ZERO)
		await step(2)
		hero.hurt_flash = 0
		check(hero.sprite_view.current_atlas==HeroSprite.state_atlas(id) and hero.sprite_view.current_column==1,"%s hit response does not become a charge or running pose" % id)
		await capture(id+"-hurt")
		await step(15)
		hero.hp = 5
		hero.alive = false
		hero.sprite_view.update_state(hero,0)
		check(hero.sprite_view.current_atlas==HeroSprite.state_atlas(id) and hero.sprite_view.current_column==5 and hero.sprite_view.sprite.scale==Vector3.ONE,"%s defeat draws its dedicated kneeling pose without flattening the body" % id)
		await capture(id+"-defeat")
		hero.alive = true
		hero.sprite_view.death_time = 0
	var file := FileAccess.open("res://artifacts/motion-audit-verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks},"\t"))
	print("MOTION_AUDIT_FAILED" if failed else "MOTION_AUDIT_OK")
	quit(1 if failed else 0)
