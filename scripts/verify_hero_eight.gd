extends SceneTree
## Real eight-way input, three-weapon damage and runtime sprite selection; isolated save.
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
var checks: Array = []
var failed := false
func _initialize() -> void:
	set_meta("isolated_adventure",true)
	run.call_deferred()
func check(ok: bool,title: String) -> void:
	checks.append({"passed":ok,"check":title})
	failed = failed or not ok
	print("PASS " if ok else "FAIL ",title)
func tick(n: int = 1) -> void:
	for i in range(n):
		driver.pending = true
		await driver.advanced
		await process_frame
func reset(weapon: String,direction: int) -> void:
	hero.blades.interrupt()
	hero.blades.skill_cooldown = 0
	hero.cancel_attack()
	hero.hit_pause = 0
	hero.hurt_time = 0
	hero.hurt_flash = 0
	hero.dash_time = 0
	hero.dash_cooldown = 0
	hero.invulnerable = 0
	hero.landing_time = 0
	hero.alive = true
	hero.hp = 5
	hero.position = Vector3(-1.5,0.035,3)
	hero.velocity = Vector3.ZERO
	hero.blades.switch_sword(weapon)
	var right: Vector3 = game.camera.global_basis.x
	right.y = 0
	var away: Vector3 = -game.camera.global_basis.z
	away.y = 0
	hero.facing = -right.normalized()*sin(direction*PI/4)-away.normalized()*cos(direction*PI/4)
	hero.sprite_view.direction8 = direction
	for target in get_nodes_in_group("enemy"):
		target.hp = 1000
		target.max_hp = 1000
		target.alive = true
		target.position = Vector3(-8,0.035,-7)
func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.muted = true
	for target in get_nodes_in_group("enemy"): target.set_physics_process(false)
	for i in range(20):
		await physics_frame
		await process_frame
	hero = game.hero
	hero.set_physics_process(false)
	driver = FixedStep.new()
	driver.hero = hero
	root.add_child(driver)
	var input_pairs := [["down"],["down","left"],["left"],["up","left"],["up"],["up","right"],["right"],["down","right"]]
	for weapon in SwordArsenal.ORDER:
		for direction in range(8):
			reset(weapon,direction)
			await tick(8)
			hero.sprite_view.update_state(hero,0)
			check(hero.sprite_view.direction8==direction,"%s %s idle direction" % [weapon,HeroDirections.NAMES[direction]])
			for key in input_pairs[direction]: Input.action_press(key)
			await tick(10)
			check(hero.sprite_view.action_name=="run" and hero.sprite_view.direction8==direction,"%s %s actual movement" % [weapon,HeroDirections.NAMES[direction]])
			check((hero.sprite_view.sprite.visible and not hero.sprite_view.sprite.flip_h) if direction%2==1 else true,"%s %s distinct diagonal painted gait" % [weapon,HeroDirections.NAMES[direction]])
			for key in input_pairs[direction]: Input.action_release(key)
			for combo in range(1,4):
				reset(weapon,direction)
				await tick(3)
				hero.combo = combo-1
				hero.combo_window = 1 if combo>1 else 0
				var mob: Bokoblin = game.bokoblins[0]
				mob.position = hero.position+hero.facing*1.3
				hero.begin_attack()
				var valid := true
				var steps := 0
				while hero.attack_time>0 or hero.hit_pause>0:
					await tick()
					steps += 1
					if hero.attack_time>0:
						var expected := HeroEightArt.resolve(HeroSprite.normal_atlas(weapon,combo),hero.sprite_view.current_column,direction,weapon,"attack")
						valid = valid and hero.sprite_view.current_atlas==expected.texture and hero.sprite_view.sprite.frame_coords==Vector2i(expected.column,expected.row)
					if steps>100: break
				var damage: int = {"wind":[10,11,14],"fire":[18,22,30],"thunder":[8,8,11]}[weapon][combo-1]
				check(valid and steps<=100,"%s %s combo %d real atlas and timing" % [weapon,HeroDirections.NAMES[direction],combo])
				check(mob.hp==1000-damage,"%s %s combo %d damage once" % [weapon,HeroDirections.NAMES[direction],combo])
			reset(weapon,direction)
			await tick(3)
			Input.action_press("jump")
			await tick(1)
			Input.action_release("jump")
			await tick(5)
			check(hero.sprite_view.action_name=="jump" and hero.sprite_view.direction8==direction,"%s %s actual jump" % [weapon,HeroDirections.NAMES[direction]])
			var landed := false
			for step in range(70):
				await tick()
				if hero.sprite_view.action_name=="land":
					landed = true
					break
			check(landed,"%s %s actual landing" % [weapon,HeroDirections.NAMES[direction]])
			for state in ["hurt","dash","defeat"]:
				hero.hurt_time = 0.1 if state=="hurt" else 0.0
				hero.dash_time = 0.1 if state=="dash" else 0.0
				hero.alive = state!="defeat"
				hero.sprite_view.update_state(hero,0)
				check(hero.sprite_view.action_name==state and hero.sprite_view.sprite.frame_coords.y in range(4),"%s %s %s runtime state" % [weapon,HeroDirections.NAMES[direction],state])
			reset(weapon,direction)
			await tick(3)
			hero.blades.begin_skill()
			hero.sprite_view.update_state(hero,0)
			check(hero.blades.busy() and hero.sprite_view.direction8==direction,"%s %s K skill" % [weapon,HeroDirections.NAMES[direction]])
			hero.blades.interrupt()
			hero.blades.magic_meters[weapon] = 100
			hero.blades.skill_cooldown = 0
			hero.blades.cast_magic()
			hero.sprite_view.update_state(hero,0)
			check(hero.blades.state=="magic" and hero.sprite_view.direction8==direction,"%s %s Q magic" % [weapon,HeroDirections.NAMES[direction]])
	var file := FileAccess.open("res://artifacts/hero-eight-verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":not failed,"checks":checks},"\t"))
	print("HERO_EIGHT_FAILED" if failed else "HERO_EIGHT_OK", " checks=",checks.size())
	quit(1 if failed else 0)
