extends SceneTree
## Real hero / enemies / collision, with an isolated save and physics-driven stepping.
class FixedStep:
	extends Node
	signal advanced
	var hero: Hero
	var pending := false
	func _physics_process(delta: float) -> void:
		if pending:
			pending = false
			hero._physics_process(delta)
			advanced.emit()
var game
var hero: Hero
var driver: FixedStep
var right := Vector3.RIGHT
var checks: Array = []
var failed := false
var recording := false
var frame_index := 0
var caption: Label
var measurements := {}
func _initialize() -> void:
	set_meta("isolated_adventure",true)
	recording = "--record" in OS.get_cmdline_user_args() and DisplayServer.get_name()!="headless"
	run.call_deferred()
func check(ok: bool, title: String) -> void:
	checks.append({"check":title,"passed":ok})
	failed = failed or not ok
	print("PASS: " if ok else "FAIL: ",title)
func tick(n: int = 1) -> void:
	for i in range(n):
		driver.pending = true
		await driver.advanced
		await process_frame
func reset(id: String, combo: int = 1) -> void:
	hero.blades.interrupt()
	hero.blades.skill_cooldown = 0
	hero.blades.thunder_charge = 0
	hero.cancel_attack()
	hero.hit_pause = 0
	hero.hurt_time = 0
	hero.hurt_flash = 0
	hero.dash_time = 0
	hero.dash_cooldown = 0
	hero.invulnerable = 0
	hero.hp = 5
	hero.position = Vector3(-1.5,0.035,3)
	hero.velocity = Vector3.ZERO
	hero.facing = right
	hero.blades.switch_sword(id)
	hero.combo = combo-1
	hero.combo_window = 1 if combo>1 else 0
	for target in get_nodes_in_group("enemy"):
		target.hp = 1000
		target.max_hp = 1000
		target.alive = true
		target.position = Vector3(-8,0.035,-7)
func attack() -> int:
	hero.begin_attack()
	var frames := 0
	while hero.attack_time>0 or hero.hit_pause>0:
		await tick()
		frames += 1
		if frames>90:
			check(false,"attack must finish within 90 physics steps")
			break
	return frames
func capture_frame() -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().get_region(Rect2i(360,170,850,530)).save_png("res://artifacts/elemental-normal-frames/%04d.png" % frame_index)
	frame_index += 1
func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.muted = true
	for target in get_nodes_in_group("enemy"):
		target.set_physics_process(false)
	for i in range(20):
		await physics_frame
		await process_frame
	hero = game.hero
	hero.set_physics_process(false)
	driver = FixedStep.new()
	driver.hero = hero
	root.add_child(driver)
	right = game.camera.global_basis.x
	right.y = 0
	right = right.normalized()
	var side := right.cross(Vector3.UP).normalized()
	var mob: Bokoblin = game.bokoblins[0]
	var second: Bokoblin = game.bokoblins[1]
	# Exact intended damage, timing, foot travel and hit pose for every normal hit.
	for id in ["fire","thunder"]:
		var total_frames := 0
		for combo in range(1,4):
			reset(id,combo)
			await tick(3)
			mob.position = hero.position+right*1.4
			var start: Vector3 = hero.position
			hero.begin_attack()
			var frames := 0
			var hits := 0
			var aligned := true
			var stable := true
			var proper_atlas := true
			var max_pause := 0.0
			while hero.attack_time>0 or hero.hit_pause>0:
				var hp_before := mob.hp
				await tick()
				frames += 1
				if mob.hp<hp_before:
					hits += 1
					aligned = aligned and hero.sprite_view.current_column==3 and hero.slash.visible
					proper_atlas = proper_atlas and hero.sprite_view.current_atlas==HeroSprite.normal_atlas(id,combo)
				max_pause = maxf(max_pause,hero.hit_pause)
				if hero.attack_time>0 and 1.0-hero.attack_time/hero.attack_duration>0.70:
					stable = stable and Vector2(hero.velocity.x,hero.velocity.z).length()<0.001
				if frames>90: break
			var expected: int = ([18,22,30] if id=="fire" else [8,8,11])[combo-1]
			check(mob.hp==1000-expected and hits==1,"%s hit %d deals %d damage exactly once" % [id,combo,expected])
			check(proper_atlas,"%s hit %d has its own combo motion atlas" % [id,combo])
			check(aligned,"%s hit %d damage and trail coincide with the extended blade pose" % [id,combo])
			check(stable and hero.position.distance_to(start)>0.04 and hero.position.distance_to(start)<0.36,"%s hit %d has a grounded step and stationary recovery" % [id,combo])
			check(max_pause>0.04 if id=="fire" else max_pause<0.025,"%s hit %d has weapon-appropriate hit stop" % [id,combo])
			total_frames += frames
		measurements[id] = {"three_hit_frames":total_frames,"seconds":total_frames/60.0}
	check(int(measurements.fire.three_hit_frames)>int(measurements.thunder.three_hit_frames)*1.7,"fire three-hit combo remains substantially weightier than lightning including actual hit stop")
	for id in ["fire","thunder"]:
		reset(id)
		await tick(2)
		# Same lateral target: fire can sweep it; lightning cannot.
		mob.position = hero.position+right*0.8+side*1.15
		await attack()
		check((mob.hp==982) if id=="fire" else (mob.hp==1000),"%s has the intended lateral coverage" % id)
		reset(id)
		await tick(2)
		mob.position = hero.position+right*2.7
		await attack()
		check((mob.hp==1000) if id=="fire" else (mob.hp==992),"%s has the intended forward reach" % id)
		reset(id)
		await tick(2)
		mob.position = hero.position-right*0.2
		await attack()
		check(mob.hp==1000,"%s never hits a target immediately behind the boy" % id)
		reset(id)
		await tick(2)
		mob.position = hero.position+right*1.4
		second.position = hero.position+right*1.65
		await attack()
		check(mob.hp==second.hp and mob.hp<1000,"%s hits each target only once, even with overlapping hit windows" % id)
		reset(id)
		await tick(2)
		mob.position = hero.position+right*1.5
		var wall := StaticBody3D.new()
		wall.collision_layer = 1
		var collider := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.12,2,4)
		collider.shape = box
		wall.add_child(collider)
		game.add_child(wall)
		wall.global_position = hero.position+right*0.8+Vector3.UP
		wall.rotation.y = atan2(-right.z,right.x)
		await tick(2)
		await attack()
		check(mob.hp==1000,"%s normal cannot damage through solid scenery" % id)
		wall.queue_free()
		await tick(2)
	# Fire side poses must never turn backwards in the middle of the cut.
	reset("fire")
	for progress in [0.1,0.32,0.42,0.65,0.9]:
		hero.facing = -right
		hero.begin_attack()
		hero.attack_time = hero.attack_duration*(1.0-progress)
		hero.sprite_view.update_state(hero,0)
		check(hero.sprite_view.sprite.flip_h and hero.sprite_view.sprite.frame_coords.y==2,"fire left-facing pose %.2f uses the consistent mirrored side strip" % progress)
		hero.cancel_attack()
	# Late buffered inputs must chain; early inputs must not accidentally survive.
	for id in ["fire","thunder"]:
		reset(id)
		await tick(2)
		hero.begin_attack()
		while hero.attack_time>hero.attack_duration*0.2: await tick()
		Input.action_press("attack")
		await tick()
		Input.action_release("attack")
		await tick(6)
		check(hero.combo==2 and hero.attack_time>0,"%s late physical attack input chains to normal hit two" % id)
		reset(id)
		await tick(2)
		hero.begin_attack()
		hero.invulnerable = 0
		hero.take_hit(1,-right)
		await tick(45)
		check(hero.attack_time<=0 and not hero.buffered_attack,"%s interrupted normal never produces delayed damage" % id)
	# Equipped weapons remain visually consistent outside attacks, including movement.
	for id in ["fire","thunder"]:
		reset(id)
		await tick(12)
		var expected: Texture2D = HeroSprite.FIRE_RUN if id=="fire" else HeroSprite.SPEAR_RUN
		check(SwordArsenal.data(id).name==("焰锋大剑" if id=="fire" else "鸣雷长枪"),"%s equipment names its actual weapon type" % id)
		for direction in [right,-right,side,-side]:
			hero.facing = direction
			hero.velocity = direction*3.0
			hero.position += direction*0.05
			hero.sprite_view.last_position = hero.position-direction*0.05
			hero.sprite_view.has_last_position = true
			hero.sprite_view.update_state(hero,1.0/60.0)
			check(hero.sprite_view.current_atlas==expected and is_equal_approx(hero.sprite_view.sprite.offset.y,expected.get_width()/6.0*0.375),"%s running direction %s keeps its two-hand weapon and feet anchor" % [id,direction])
		hero.velocity = Vector3.ZERO
		hero.position.y += 1.0
		await tick()
		hero.velocity.y = 3
		hero.sprite_view.update_state(hero,1.0/60.0)
		check(hero.sprite_view.current_atlas==HeroSprite.state_atlas(id) and hero.sprite_view.current_column==2,"%s jumping uses its dedicated held-weapon pose" % id)
	# Chaining keeps the previous final guard, and each next start is the same painted pose.
	for id in ["fire","thunder"]:
		for combo in range(1,3):
			reset(id,combo)
			await tick(12)
			await attack()
			check(hero.sprite_view.current_atlas==HeroSprite.normal_atlas(id,combo) and hero.sprite_view.current_column==5,"%s combo %d holds its final guard during the follow-up window" % [id,combo])
			var cell := HeroSprite.normal_atlas(id,combo).get_width()/6
			var previous := HeroSprite.normal_atlas(id,combo).get_image().get_region(Rect2i(5*cell,2*cell,cell,cell))
			var next := HeroSprite.normal_atlas(id,combo+1).get_image().get_region(Rect2i(0,2*cell,cell,cell))
			check(previous.get_data()==next.get_data(),"%s combo %d links into the next identical guard without a pose reset" % [id,combo])
	reset("thunder")
	await tick(12)
	mob.position = hero.position+right*1.4
	second.position = hero.position+right*1.6
	await attack()
	check(hero.blades.thunder_charge==1,"one spear strike hitting multiple enemies grants only one electric charge")
	hero.blades.thunder_charge = 3
	hero.combo = 3
	hero.combo_window = 1
	check(not hero.blades.attack_input(),"full spear charge never hijacks the next normal attack into an automatic dash")
	check(hero.blades.begin_skill() and hero.blades.powered,"K deliberately releases the fully charged spear thrust")
	# A deliberate click after recovery must still continue the combo (not re-enter charge).
	for id in ["fire","thunder"]:
		reset(id)
		await tick(12)
		hero.begin_attack()
		for expected_combo in [2,3]:
			while hero.attack_time>0 or hero.hit_pause>0: await tick()
			await tick(3)
			Input.action_press("attack")
			await tick()
			Input.action_release("attack")
			await tick()
			check(hero.combo==expected_combo and hero.attack_time>0 and not hero.blades.busy(),"%s physical click after recovery continues normal combo %d" % [id,expected_combo])
	# Short fire tap counts toward the normal windup and doesn't incur double startup.
	reset("fire")
	await tick(3)
	Input.action_press("attack")
	await tick(6)
	Input.action_release("attack")
	await tick(1)
	check(hero.attack_time>0 and 1.0-hero.attack_time/hero.attack_duration>=0.20,"short fire tap carries its elapsed windup into the ordinary slash")
	if recording:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/elemental-normal-frames"))
		game.set_process(false)
		for node in game.get_children():
			if node is CanvasLayer and node.layer>=0: node.hide()
		var layer := CanvasLayer.new()
		layer.layer = 20
		root.add_child(layer)
		caption = Label.new()
		caption.position = Vector2(400,210)
		caption.add_theme_font_size_override("font_size",22)
		caption.add_theme_color_override("font_color",Color("fff0c8"))
		caption.add_theme_constant_override("outline_size",6)
		caption.add_theme_color_override("font_outline_color",Color("183527"))
		layer.add_child(caption)
		for id in ["fire","thunder"]:
			for facing in [right,-right,-side,side]:
				reset(id)
				hero.facing = facing
				game.focus = Vector3.INF
				game.update_pixel_camera(1)
				caption.text = ("焰锋大剑｜双手重斩｜伤害 18 / 22 / 30" if id=="fire" else "鸣雷长枪｜双手连刺｜伤害 8 / 8 / 11")
				await tick(4)
				for combo in range(1,4):
					mob.position = hero.position+facing*1.6
					mob.change_state("idle")
					mob.facing = -facing
					mob.update_visual(0)
					hero.begin_attack()
					var count := 0
					while hero.attack_time>0 or hero.hit_pause>0:
						await tick()
						if count%2==0: await capture_frame()
						count += 1
					await tick(2)
				for i in range(12):
					await tick(2)
					await capture_frame()
		reset("fire")
		caption.hide()
		game.adventure_ui.show()
		game.set_menu("equipment")
		await tick(2)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/elemental-normal-equipment.png")
	var file := FileAccess.open("res://artifacts/elemental-normal-verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"measurements":measurements},"\t"))
	print("ELEMENTAL_NORMALS_FAILED" if failed else "ELEMENTAL_NORMALS_OK")
	quit(1 if failed else 0)
