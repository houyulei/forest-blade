extends SceneTree
## Persistent ARPG loop with three independent swords and blacksmith dialogue.
var game
var checks: Array = []
var failed := false
func _initialize() -> void:
	set_meta("isolated_adventure",true)
	run.call_deferred()
func step(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func press_menu(key: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = key
	down.pressed = true
	Input.parse_input_event(down)
	await step(2)
	var up := InputEventKey.new()
	up.physical_keycode = key
	Input.parse_input_event(up)
	await step(2)
func check(ok: bool, title: String) -> void:
	checks.append({"check":title,"passed":ok})
	print("PASS: " if ok else "FAIL: ",title)
	failed = failed or not ok
func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.muted = true
	for actor in get_nodes_in_group("enemy"):
		actor.set_physics_process(false)
	await step(20)
	game.hero.set_physics_process(false)
	var data: AdventureProgress = game.progress
	check(not data.persistence_enabled and data.equipped_sword=="wind","new adventure isolates the player save and equips the wind sword")
	var before := data.snapshot()
	check(not data.craft("sword") and data.snapshot()==before,"insufficient crafting cannot consume currency")
	game.set_menu("smith")
	check(not game.menu_open,"blacksmith conversation requires proximity")
	await press_menu(KEY_I)
	check(game.menu_mode=="equipment" and game.adventure_ui.equipment.visible and not game.adventure_ui.dialogue.visible,"I opens equipment without a forge panel")
	check(game.adventure_ui.sword_buttons.size()==3,"equipment lists all three swords")
	game.adventure_ui.sword_buttons.fire.pressed.emit()
	check(data.equipped_sword=="fire" and data.sword_damage()==18,"equipment selects the fire sword and refreshes its real stats")
	game.adventure_ui.sword_buttons.thunder.pressed.emit()
	check(data.equipped_sword=="thunder" and data.sword_damage()==8,"equipment selects the lightning sword")
	game.adventure_ui.sword_buttons.fire.pressed.emit()
	await press_menu(KEY_ESCAPE)
	check(not game.menu_open and not game.hero.is_physics_processing(),"Esc closes equipment and restores the previous actor processing state")
	var mob: Bokoblin = game.bokoblins[0]
	mob.take_hit(999,Vector3.ZERO,true)
	game.enemy_defeated(mob)
	check(get_nodes_in_group("loot").size()==3,"one monster drops three reward pickups exactly once")
	for pickup in get_nodes_in_group("loot"):
		check(pickup.collect() and not pickup.collect(),"each %s pickup can only be collected once" % pickup.item)
	await step(2)
	check(data.gold==8 and data.materials.ore==1 and data.materials.fang==1,"loot enters persistent inventory")
	for actor in [game.enemy,game.bokoblins[1]]:
		actor.take_hit(999,Vector3.ZERO,true)
	for pickup in get_nodes_in_group("loot"):
		pickup.collect()
	await step(2)
	check(data.gold==46 and data.materials.ore==5 and data.materials.fang==2 and data.materials.stone==1,"the fixed encounter retains its configured material and gold rewards")
	game.hero.position = game.forge.smith_position()+Vector3(0,0,1)
	game.set_menu("smith")
	check(game.menu_mode=="smith" and game.adventure_ui.dialogue.visible,"forge choices are available through the nearby NPC")
	game.adventure_ui.choices.get_child(0).pressed.emit()
	check(data.sword_levels.fire==1 and data.sword_levels.wind==0 and data.gold==34 and data.materials.ore==3,"blacksmith tempers only the equipped sword and deducts its exact recipe")
	game.adventure_ui.choices.get_child(1).pressed.emit()
	check(data.fire_core and data.gold==9 and data.materials.ore==1 and data.materials.stone==0,"blacksmith refines the fire sword crystal using the configured materials")
	check(not data.craft("fire_core"),"the same fire crystal cannot be crafted twice")
	game.adventure_ui.dialogue_page = "sell"
	game.adventure_ui.build_dialogue()
	game.adventure_ui.choices.get_child(0).pressed.emit()
	check(data.materials.ore==0 and data.gold==13,"blacksmith buys a material for its configured price")
	before = data.snapshot()
	check(not data.sell("ore") and not data.sell("fang",-1) and data.snapshot()==before,"invalid sales cannot create currency")
	game.adventure_ui.dialogue_page = "main"
	game.adventure_ui.build_dialogue()
	game.hero.hp = 1
	game.hero.blades.magic_meters = {"wind":0.0,"fire":0.0,"thunder":0.0}
	game.adventure_ui.choices.get_child(3).pressed.emit()
	check(not game.menu_open and game.hero.hp==5 and game.hero.blades.magic_meters.wind==100 and game.hero.blades.magic_meters.fire==100 and game.hero.blades.magic_meters.thunder==100,"resting with the blacksmith restores life and all three magic gauges")
	var disk := AdventureProgress.new()
	disk.save_path = "user://adventure-verification-only.json"
	disk.restore(data.snapshot())
	check(disk.save(),"permanent progression is saved atomically")
	var loaded := AdventureProgress.new()
	loaded.save_path = disk.save_path
	loaded.load_save()
	check(loaded.snapshot()==data.snapshot(),"saved materials, all sword levels, selected sword and crystal survive reload")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(disk.save_path))
	disk.save_path = "user://nonexistent-verification-folder/%d/save.json" % Time.get_ticks_usec()
	before = disk.snapshot()
	check(not disk.add_gold(10) and disk.snapshot()==before,"save failure rolls back a reward instead of reporting a false success")
	var snapshot := data.snapshot()
	game.queue_free()
	await step(2)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for actor in get_nodes_in_group("enemy"):
		actor.set_physics_process(false)
	await step(3)
	check(game.progress.snapshot()==snapshot and game.living_enemy_count()==3,"map revisit respawns enemies while retaining permanent sword and inventory progression")
	var file := FileAccess.open("res://artifacts/adventure-verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks},"\t"))
	print("ADVENTURE_VERIFICATION_FAILED" if failed else "ADVENTURE_VERIFICATION_OK")
	quit(1 if failed else 0)
