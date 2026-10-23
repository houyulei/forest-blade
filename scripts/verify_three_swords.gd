extends SceneTree
## Use --fixed-fps 60 for deterministic renders and projectile timing.
class FixedStep:
	extends Node
	signal advanced
	var hero: Hero
	var pending := false
	func _physics_process(delta: float) -> void:
		if pending:
			pending = false
			if not hero.arena.menu_open:
				hero._physics_process(delta)
			advanced.emit()
var game
var hero: Hero
var combat: BladeCombat
var driver: FixedStep
var checks: Array = []
var failed := false
var right := Vector3.RIGHT
func _initialize() -> void:
	set_meta("isolated_adventure",true)
	run.call_deferred()
func wait_frames(n: int) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func tick(n: int = 1) -> void:
	for i in range(n):
		driver.pending = true
		await driver.advanced
		await process_frame
func check(ok: bool, title: String) -> void:
	checks.append({"check":title,"passed":ok})
	print("PASS: " if ok else "FAIL: ",title)
	failed = failed or not ok
func capture(title: String) -> void:
	if DisplayServer.get_name()=="headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/three-swords-%s.png" % title)
func clean_effects() -> void:
	for node in get_nodes_in_group("sword_effect")+get_nodes_in_group("blade_fx"):
		node.queue_free()
func reset(id: String) -> void:
	combat.interrupt()
	hero.cancel_attack()
	hero.hurt_time = 0
	hero.hurt_flash = 0
	hero.hit_pause = 0
	hero.dash_time = 0
	hero.dash_cooldown = 0
	hero.invulnerable = 0
	hero.hp = 5
	hero.position = Vector3(0,0.035,2)
	hero.velocity = Vector3.ZERO
	hero.facing = right
	combat.skill_cooldown = 0
	combat.wind_window = 0
	combat.wind_count = 0
	combat.thunder_charge = 0
	combat.switch_sword(id)
	clean_effects()
	for target in get_nodes_in_group("enemy"):
		target.position = Vector3(-8,0.035,-6)
		target.hp = 1000
		target.max_hp = 1000
		target.alive = true
func targets(distances: Array) -> void:
	var actors := [game.bokoblins[0],game.bokoblins[1],game.enemy]
	for i in range(distances.size()):
		actors[i].position = hero.position+right*float(distances[i])
		if actors[i] is Bokoblin:
			actors[i].change_state("idle")
			actors[i].facing = -right
			actors[i].update_visual(0)
func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.muted = true
	for target in get_nodes_in_group("enemy"):
		target.set_physics_process(false)
	await wait_frames(20)
	hero = game.hero
	hero.set_physics_process(false)
	combat = hero.blades
	driver = FixedStep.new()
	driver.hero = hero
	root.add_child(driver)
	right = game.camera.global_basis.x
	right.y = 0
	right = right.normalized()
	check(game.progress.equipped_sword=="wind" and combat.magic_meters.size()==3,"new adventure has three available swords and separate magic gauges")
	var durations: Array = []
	for id in SwordArsenal.ORDER:
		reset(id)
		await tick(5)
		hero.begin_attack()
		durations.append(hero.attack_duration)
		await tick(10)
		check(hero.sprite_view.current_atlas==({"wind":HeroSprite.ATTACK,"fire":HeroSprite.FIRE,"thunder":HeroSprite.THRUST}[id]) or hero.attack_time<=0,"%s has its own normal attack presentation" % id)
		await tick(50)
	check(durations[2]<durations[0] and durations[0]<durations[1],"lightning thrusts are fastest and fire slashes are slowest")
	reset("wind")
	await tick(4)
	hero.begin_attack()
	check(not combat.switch_sword("fire"),"switching swords cannot cancel an active attack")
	hero.cancel_attack()
	combat.on_combo_finished(3)
	check(combat.wind_window>0 and combat.attack_input(),"wind three-hit combo opens a timed cyclone follow-up")
	await tick(13)
	check(hero.sprite_view.current_atlas==HeroSprite.SPIN,"wind technique uses a full-body rotating animation")
	await capture("wind-technique")
	await tick(12)
	for i in range(4):
		check(combat.attack_input(),"wind follow-up %d can continue within its timing window" % (i+2))
		await tick(22)
	check(combat.wind_count==5 and combat.wind_window==0,"wind cyclone follow-ups stop after five")
	reset("fire")
	targets([2.2,3.8])
	await tick(4)
	check(combat.begin_charge(),"fire technique begins in a planted charge stance")
	var start: Vector3 = hero.position
	await tick(48)
	check(is_equal_approx(combat.charge,0.8) and hero.position.distance_to(start)<0.05,"fire builds power while staying grounded")
	check(hero.sprite_view.current_atlas==HeroSprite.FIRE_HEAVY and hero.sprite_view.current_column==1,"greatsword charges with both hands above the head")
	await capture("fire-charge")
	check(combat.release_charge(),"releasing charge enters the forward cleave")
	await tick(13)
	await capture("fire-technique")
	await tick(25)
	check(game.bokoblins[0].hp<1000 and game.bokoblins[1].hp<1000,"charged flame travels forward through multiple enemies")
	check(game.bokoblins[0].hp==game.bokoblins[1].hp,"the same flame wave hits each enemy once")
	var charged_damage: int = 1000-game.bokoblins[0].hp
	reset("fire")
	targets([1.8])
	await tick(4)
	combat.begin_charge()
	await tick(12)
	combat.release_charge()
	await tick(40)
	check(1000-game.bokoblins[0].hp<charged_damage,"partial fire charge deals less damage than a long charge")
	reset("fire")
	targets([2.2])
	await tick(4)
	combat.begin_charge()
	await tick(20)
	hero.take_hit(1,-right)
	await tick(60)
	check(not combat.busy() and game.bokoblins[0].hp==1000,"damage interrupts fire charging without producing a delayed attack")
	reset("thunder")
	targets([1.4])
	await tick(4)
	for i in range(3):
		hero.combo_window = 0 if i==0 else 1
		hero.begin_attack()
		await tick(23 if i<2 else 28)
	check(combat.thunder_charge==3,"three successful thrusts build full lightning charge")
	hero.cancel_attack()
	combat.skill_cooldown = 0
	var dash_start: Vector3 = hero.position
	check(combat.begin_thunder() and combat.powered,"full charge powers the lightning thrust")
	await tick(12)
	check(hero.sprite_view.sprite.visible and hero.sprite_view.lightning_body.visible,"lightning form retains a visible character and electric afterimage")
	await capture("thunder-technique")
	await tick(16)
	check(hero.position.distance_to(dash_start)>3 and hero.position.distance_to(dash_start)<4.3,"powered lightning thrust performs a real collision-aware dash")
	check(combat.thunder_charge==0,"lightning technique consumes its three charges")
	# Fire travel must stop at a wall, including its damage.
	reset("fire")
	targets([2.2])
	await tick(4)
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.18,2,3)
	col.shape = shape
	wall.add_child(col)
	wall.position = hero.position+right*1.15+Vector3.UP*0.8
	wall.rotation.y = atan2(right.x,right.z)-PI/2
	game.add_child(wall)
	await tick(2)
	combat.begin_charge()
	await tick(45)
	combat.release_charge()
	await tick(50)
	check(game.bokoblins[0].hp==1000,"solid scenery blocks travelling flame and prevents damage behind it")
	reset("thunder")
	await tick(4)
	combat.thunder_charge = 3
	combat.begin_thunder()
	await tick(28)
	check(hero.position.distance_to(Vector3(0,0.035,2))<1.2,"lightning dash stops at the same solid obstacle")
	wall.queue_free()
	await tick(3)
	# Distinct sword magic, with immutable cast snapshots and per-sword gauges.
	reset("wind")
	targets([0.9,1.5])
	await tick(4)
	combat.magic_meters.wind = 100
	check(combat.cast_magic(),"full wind gauge casts tornado magic")
	await tick(32)
	await capture("wind-magic")
	await tick(140)
	check(game.bokoblins[0].hp==958 and game.bokoblins[1].hp==958,"tornado hits nearby targets in six bounded pulses")
	check(float(combat.magic_meters.wind)<10 and not combat.cast_magic(),"spent wind gauge cannot immediately recast")
	reset("fire")
	targets([2.2,3.6])
	await tick(4)
	combat.magic_meters.fire = 100
	check(combat.cast_magic(),"fire uses its own unspent magic gauge")
	await tick(25)
	await capture("fire-magic")
	await tick(45)
	check(game.bokoblins[0].hp==962 and game.bokoblins[1].hp==962,"fire magic launches one piercing fireball down its path")
	reset("thunder")
	targets([1.4,2.5,3.7])
	await tick(4)
	combat.magic_meters.thunder = 100
	check(combat.cast_magic(),"lightning uses its own unspent magic gauge")
	await tick(30)
	await capture("thunder-magic")
	await tick(90)
	check(game.bokoblins[0].hp==972 and game.bokoblins[1].hp==972 and game.enemy.hp==972,"lightning magic chains across three enemies, at most twice per target")
	check(float(combat.magic_meters.fire)<10 and float(combat.magic_meters.wind)<15,"switching swords does not refill previously spent gauges")
	reset("fire")
	targets([2.2])
	await tick(4)
	combat.begin_charge()
	await tick(20)
	combat.release_charge()
	await tick(9)
	var before: int = game.bokoblins[0].hp
	var effect: SwordEffect
	for node in get_nodes_in_group("sword_effect"):
		effect = node
	var effect_position: Vector3 = effect.global_position
	game.set_menu("equipment")
	await tick(25)
	check(game.bokoblins[0].hp==before and effect.global_position.is_equal_approx(effect_position),"equipment pauses travelling attacks and their damage")
	await capture("equipment")
	game.set_menu()
	await tick(30)
	check(game.bokoblins[0].hp<before,"travelling attack resumes after closing equipment")
	# Input paths, rather than just direct technique calls.
	reset("fire")
	await tick(4)
	Input.action_press("attack")
	await tick(6)
	Input.action_release("attack")
	await tick(2)
	check(hero.attack_time>0 and not combat.busy(),"a short fire J press releases an ordinary slash")
	reset("fire")
	await tick(4)
	Input.action_press("sword_skill")
	await tick(30)
	check(combat.state=="charge" and combat.charge>0.4,"holding K actually charges the fire sword")
	Input.action_release("sword_skill")
	await tick(2)
	check(combat.state=="fire_release","releasing K actually fires the charged sword technique")
	reset("wind")
	await tick(4)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_3
	key.pressed = true
	Input.parse_input_event(key)
	await tick(2)
	var key_up := InputEventKey.new()
	key_up.physical_keycode = KEY_3
	Input.parse_input_event(key_up)
	await tick(2)
	check(game.progress.equipped_sword=="thunder","the physical 3 key selects the lightning sword")
	# In-flight damage belongs to the cast, even after a weapon switch.
	reset("fire")
	hero.position = Vector3(-3,0.035,3)
	targets([7.0])
	game.progress.sword_levels.fire = 2
	combat.magic_meters.fire = 100
	await tick(4)
	combat.cast_magic()
	await tick(40)
	check(combat.switch_sword("wind"),"a sword can be switched once its casting recovery ends")
	await tick(30)
	check(game.bokoblins[0].hp==952,"in-flight fireball retains the fire sword's original damage snapshot")
	game.progress.sword_levels.fire = 0
	# Transactional, independent upgrades and legacy migration.
	var progress := AdventureProgress.new()
	progress.persistence_enabled = false
	progress.gold = 200
	progress.materials = {"ore":20,"fang":20,"stone":10}
	progress.equip_sword("fire")
	check(progress.craft("sword") and progress.sword_levels.fire==1 and progress.sword_levels.wind==0,"blacksmith upgrades the equipped sword independently")
	progress.equip_sword("thunder")
	check(progress.sword_level==0 and progress.sword_damage()==8,"switching swords displays that sword's actual level and stats")
	var legacy := {"version":1,"gold":67,"materials":{"ore":4,"fang":3,"stone":2},"sword_level":2,"fire_core":true,"equipped_core":"refined_ember"}
	progress.restore(legacy)
	check(progress.equipped_sword=="fire" and progress.sword_levels.fire==2 and progress.fire_core and progress.gold==67 and progress.materials.ore==4,"legacy fire-core save migrates without losing equipment, materials or gold")
	var disk := AdventureProgress.new()
	disk.save_path = "user://three-swords-test-%d.json" % OS.get_process_id()
	disk.restore(progress.snapshot())
	check(disk.save(),"three-sword save writes atomically")
	var loaded := AdventureProgress.new()
	loaded.save_path = disk.save_path
	loaded.load_save()
	check(loaded.snapshot()==disk.snapshot(),"save reload retains all sword levels and equipped sword")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(disk.save_path))
	# A real v1 save is preserved before the first v2 transaction.
	var legacy_path := "user://three-swords-legacy-test-%d.json" % OS.get_process_id()
	var old_file := FileAccess.open(legacy_path,FileAccess.WRITE)
	old_file.store_string(JSON.stringify(legacy))
	old_file.close()
	var migrated := AdventureProgress.new()
	migrated.save_path = legacy_path
	migrated.load_save()
	check(migrated.needs_migration_backup and migrated.equip_sword("wind"),"first legacy-save transaction migrates through the normal save path")
	var backed_up: Variant = JSON.parse_string(FileAccess.get_file_as_string(legacy_path+".v1.bak"))
	check(backed_up is Dictionary and backed_up.get("version",0)==1 and backed_up.get("gold",0)==67,"legacy save backup retains its original version and rewards")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy_path+".v1.bak"))
	var file := FileAccess.open("res://artifacts/three-swords-verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks},"\t"))
	print("THREE_SWORDS_VERIFICATION_FAILED" if failed else "THREE_SWORDS_VERIFICATION_OK")
	quit(1 if failed else 0)
