extends SceneTree
## Integration verification uses isolated progress and real room/NPC/input/physics code.
var game
var checks: Array = []
var failed := false

func _initialize() -> void:
	set_meta("isolated_adventure",true)
	run.call_deferred()

func step(frames: int = 3) -> void:
	for i in range(frames):
		await physics_frame
		await process_frame

func check(ok: bool,title: String) -> void:
	checks.append({"check":title,"passed":ok})
	print("PASS: " if ok else "FAIL: ",title)
	failed = failed or not ok

func freeze_enemies() -> void:
	for actor in game.bokoblins:
		actor.set_physics_process(false)

func place_hero(p: Vector3) -> void:
	game.hero.set_physics_process(true)
	game.hero.position = p
	game.hero.velocity = Vector3.ZERO
	game.hero.hurt_time = 0
	game.hero.dash_time = 0
	game.hero.cancel_attack()
	game.hero.blades.interrupt()
	await step(12)
	game.hero.set_physics_process(false)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await step(2)
	event = InputEventKey.new()
	event.physical_keycode = code
	Input.parse_input_event(event)
	await step(36)

func walk_route(points: Array) -> bool:
	game.hero.set_physics_process(true)
	for waypoint in points:
		var arrived := false
		for frame in range(220):
			var offset: Vector3 = waypoint-game.hero.position
			offset.y = 0
			if offset.length()<0.35:
				arrived = true
				break
			var direction := offset.normalized()
			var right: Vector3 = game.camera.global_basis.x
			var away: Vector3 = -game.camera.global_basis.z
			away.y = 0
			away = away.normalized()
			var x := direction.dot(right)
			var y := direction.dot(away)
			Input.action_press("right",maxf(0,x))
			Input.action_press("left",maxf(0,-x))
			Input.action_press("up",maxf(0,y))
			Input.action_press("down",maxf(0,-y))
			await step(1)
		for action in ["right","left","up","down"]:
			Input.action_release(action)
		if not arrived:
			game.hero.set_physics_process(false)
			return false
	game.hero.set_physics_process(false)
	return true

func portal_to(destination: String) -> Dictionary:
	for portal in game.portals:
		if portal.destination==destination:
			return portal
	return {}

func use_portal(destination: String) -> void:
	var portal := portal_to(destination)
	if portal.is_empty():
		check(false,"missing portal to "+destination+" from "+game.zone)
		return
	await place_hero(portal.position+Vector3(0,0.1,0))
	game.portal_cooldown = 0
	await key(KEY_E)
	freeze_enemies()
	await step(3)
	check(game.zone==destination,"real E transition reaches "+destination)

func run() -> void:
	game = load("res://chapter_one.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.muted = true
	await step(12)
	check(game.zone=="village" and game.living_enemy_count()==0,"chapter starts in a safe village")
	check(not game.progress.persistence_enabled and not game.chapter_finished,"test never reads or writes player progress")
	check(game.landscape.scenery_count>=25 and game.landscape.collision_count>=10,"village has painted buildings and solid boundaries")
	await place_hero(game.forge.smith_position()+Vector3(0,0.1,1))
	await key(KEY_E)
	check(game.menu_mode=="smith" and game.menu_open,"real E input opens the village blacksmith")
	game.hero.hp = 1
	game.adventure_ui.choices.get_child(3).pressed.emit()
	check(not game.menu_open and game.hero.hp==5,"village blacksmith rest restores life")
	await use_portal("forest")
	check(game.zone=="forest" and game.living_enemy_count()==6,"village exit enters the six-enemy forest")
	check(not is_instance_valid(game.forge),"forest does not retain the village blacksmith")
	check(await walk_route([Vector3(-2,0,11),Vector3(2,0,4),Vector3(-2,0,-3),Vector3(2,0,-10),Vector3(0,0,-16)]),"camera-relative movement traverses the entire authored forest route")
	var cave_portal := portal_to("cave")
	await place_hero(cave_portal.position+Vector3.UP*0.1)
	check(not game.travel(cave_portal) and game.zone=="forest","cave entrance is locked until fixed forest enemies are cleared")
	var first: Bokoblin = game.bokoblins[0]
	first.take_hit(999,Vector3.ZERO,true)
	var drop_count := get_nodes_in_group("loot").size()
	game.enemy_defeated(first)
	check(drop_count==3 and get_nodes_in_group("loot").size()==3,"one forest enemy drops its reward once")
	for actor in game.bokoblins:
		actor.take_hit(999,Vector3.ZERO,true)
	check(game.living_enemy_count()==0 and not game.chapter_finished,"forest clearance unlocks travel without ending the chapter")
	await use_portal("village")
	check(game.zone=="village" and game.progress.gold==48 and game.progress.materials.ore==6 and game.progress.materials.fang==6,"leaving collects forest materials exactly once and returns to village")
	await use_portal("forest")
	check(game.zone=="forest" and game.living_enemy_count()==0,"in-session revisit retains cleared forest camps")
	await use_portal("cave")
	check(game.zone=="cave" and game.living_enemy_count()==3,"deep forest exit enters cave guards and golden boss")
	var boss: GoldenBokoblin = game.boss
	var health := boss.hp
	boss.take_hit(100,Vector3.ZERO,true)
	check(not boss.engaged and boss.hp==health,"inactive boss cannot be sniped through the entry route")
	for actor in game.bokoblins:
		if actor!=boss:
			actor.take_hit(999,Vector3.ZERO,true)
	await place_hero(Vector3(0,0.1,-1))
	await step()
	check(game.boss_started and boss.engaged and game.landscape.gate_art.visible,"entering the cleared lair starts boss combat and closes visible seal")
	await key(KEY_I)
	check(game.menu_open and not boss.is_physics_processing(),"equipment pauses boss combat")
	await key(KEY_ESCAPE)
	check(not game.menu_open and not boss.is_physics_processing(),"closing equipment restores the boss previous processing state")
	game.hero.set_physics_process(false)
	game.hero.position = boss.position+Vector3(0,0.1,1)
	game.hero.invulnerable = 0
	boss.move_kind = "slam"
	boss.change_state("strike",0.2)
	boss.attack_has_hit = false
	var before: int = game.hero.hp
	boss.resolve_attack()
	boss.resolve_attack()
	check(game.hero.hp==before-1,"boss ground slam hits once per attack")
	game.hero.invulnerable = 0
	game.hero.position = boss.position+Vector3(0,1.2,1)
	boss.attack_has_hit = false
	before = game.hero.hp
	boss.resolve_attack()
	check(game.hero.hp==before,"jumping avoids the boss ground slam")
	for kind in ["club","slam","rush"]:
		boss.move_index = ["club","slam","rush"].find(kind)
		boss.choose_attack()
		check(boss.move_kind==kind and boss.state=="windup" and boss.timer>=0.75,"boss %s has explicit anticipation"%kind)
	boss.change_state("windup",0.6)
	boss.move_kind = "rush"
	boss.take_hit(20,Vector3.RIGHT,true)
	check(boss.state=="windup" and boss.hp==health-20,"boss takes damage but attack windup resists permanent stagger")
	boss.hp = 150
	boss._physics_process(0.016)
	check(boss.enraged and boss.state=="alert","half-health boss enters a telegraphed second phase")
	game.hero.hp = 5
	game.hero.alive = true
	# Real collision blocks a rush, not just its visual.
	boss.position = Vector3(8.05,0.05,-5)
	boss.attack_direction = Vector3.RIGHT
	boss.move_kind = "rush"
	boss.change_state("strike",0.48)
	boss.attack_has_hit = true
	boss.set_physics_process(true)
	await step(20)
	boss.set_physics_process(false)
	check(boss.position.x<8.55,"boss rush obeys the solid cave wall")
	boss.position = Vector3(0,0.05,-6)
	boss.take_hit(999,Vector3.ZERO,true)
	await step(4)
	check(not boss.alive and game.chapter_finished and game.progress.chapter_one_completed,"only golden boss defeat completes and persists the chapter")
	check(not game.landscape.gate_art.visible,"boss defeat opens the return route")
	var count := get_nodes_in_group("loot").size()
	game.enemy_defeated(boss)
	check(get_nodes_in_group("loot").size()==count,"boss reward is protected against duplicate defeat callbacks")
	await use_portal("forest")
	await use_portal("village")
	check(game.zone=="village" and game.hero.hp==5 and game.hero.blades.magic_meters.fire==100,"completed chapter supports a full return to village and recovery")
	check(game.progress.gold==144 and game.progress.materials.ore==13 and game.progress.materials.fang==11 and game.progress.materials.stone==2,"full chapter yields configured fixed rewards without revisit duplication")
	var data := AdventureProgress.new()
	data.save_path = "user://chapter-one-verification-only.json"
	data.restore(game.progress.snapshot())
	check(data.save(),"chapter completion can be saved atomically")
	var loaded := AdventureProgress.new()
	loaded.save_path = data.save_path
	loaded.load_save()
	check(loaded.snapshot()==data.snapshot() and loaded.chapter_one_completed,"completion and original inventory survive disk reload")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(data.save_path))
	data = AdventureProgress.new()
	data.save_path = "user://missing-chapter-test-%d/save.json"%Time.get_ticks_usec()
	check(not data.complete_chapter_one() and not data.chapter_one_completed,"failed completion save rolls back the permanent flag")
	loaded.restore({"version":2,"gold":19,"sword_levels":{"wind":2}})
	check(not loaded.chapter_one_completed and loaded.gold==19 and loaded.sword_levels.wind==2,"old version-two saves default the optional chapter flag without losing growth")
	game.checkpoint_zone = "forest"
	game.checkpoint_spawn = Vector3(0,0.1,16)
	game.hero.alive = false
	game.hero.hp = 0
	var saved_gold: int = game.progress.gold
	game.respawn_at_checkpoint()
	await step(4)
	freeze_enemies()
	check(game.zone=="forest" and game.hero.alive and game.hero.hp==5 and game.living_enemy_count()==6 and game.progress.gold==saved_gold,"checkpoint retry restores actors and preserves permanent inventory")
	var file := FileAccess.open("res://artifacts/chapter-one-verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"passed":not failed},"\t"))
	print("CHAPTER_ONE_VERIFICATION_FAILED" if failed else "CHAPTER_ONE_VERIFICATION_OK")
	quit(1 if failed else 0)
