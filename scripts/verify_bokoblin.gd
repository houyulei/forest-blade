extends SceneTree
## Integration checks using actual game actors, attack timing and collision world.
var game
var goblin: Bokoblin
var checks: Array = []
var failed := false
func _initialize() -> void:
	set_meta("isolated_adventure",true)
	run.call_deferred()
func step(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func check(value: bool, label: String) -> void:
	checks.append({"check":label,"passed":value})
	print("PASS: " if value else "FAIL: ",label)
	failed = failed or not value
func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/bokoblin-%s.png" % label)
func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.muted = true
	game.enemy.set_physics_process(false)
	for target in game.bokoblins:
		target.set_physics_process(false)
	await step(25)
	await capture("encounter")
	game.hero.set_physics_process(false)
	goblin = game.bokoblins[0]
	game.enemy.position = Vector3(-8,0.05,-6)
	game.bokoblins[1].position = Vector3(8,0.05,6)
	goblin.position = Vector3(0,0.05,2)
	goblin.home = goblin.position
	game.hero.position = goblin.position+Vector3(0,0,3)
	check(game.living_enemy_count()==3 and goblin.hp==40 and goblin.tier=="base","base red variant joins a three-enemy encounter")
	var right: Vector3 = game.camera.global_basis.x
	var away: Vector3 = -game.camera.global_basis.z
	away.y = 0
	away = away.normalized()
	var facings := [-away,-right,right,away]
	var rows := [0,1,1,2]
	for i in range(4):
		goblin.facing = facings[i]
		goblin.update_visual(0)
		check(goblin.direction_row==rows[i] and goblin.sprite.flip_h==(i==2),"direction %d uses the correct sprite orientation" % i)
	goblin.change_state("idle")
	goblin.set_physics_process(true)
	await step(2)
	check(goblin.state=="alert" and goblin.alert.visible,"proximity and line of sight trigger visible alert")
	await step(30)
	var start: Vector3 = goblin.position
	var columns := {}
	for i in range(20):
		await step(1)
		columns[goblin.current_column] = true
	check(goblin.position.distance_to(start)>0.4 and goblin.animation_name=="walk" and columns.size()>=3,"chase uses moving, distance-driven walk frames")
	goblin.set_physics_process(false)
	goblin.position = Vector3(0,0.05,2)
	game.hero.position = goblin.position+Vector3(0,0,1.15)
	game.hero.hp = 5
	game.hero.invulnerable = 0
	goblin.facing = Vector3.BACK
	goblin.velocity = Vector3.ZERO
	goblin.begin_windup()
	goblin.set_physics_process(true)
	await step(25)
	check(goblin.state=="windup" and goblin.current_column==2 and goblin.warning.visible,"club windup shows raised weapon and attack sector")
	await capture("windup")
	await step(18)
	check(goblin.attack_count==1 and game.hero.hp==4,"club strike connects at its active phase")
	await capture("strike")
	game.hero.invulnerable = 0
	await step(12)
	check(game.hero.hp==4 and goblin.state=="recover","one swing cannot damage twice even after invulnerability is cleared")
	goblin.position = Vector3(0,0.05,2)
	goblin.velocity = Vector3.ZERO
	game.hero.position = goblin.position+Vector3.BACK*1.15
	goblin.facing = Vector3.BACK
	goblin.begin_windup()
	var locked: Vector3 = goblin.attack_direction
	game.hero.position = goblin.position+Vector3.RIGHT*1.15
	await step(52)
	check(goblin.attack_direction.is_equal_approx(locked) and game.hero.hp==4,"sidestepping evades a direction-locked attack")
	goblin.set_physics_process(false)
	goblin.change_state("strike",Bokoblin.ACTIVE)
	goblin.attack_has_hit = false
	goblin.attack_direction = Vector3.BACK
	game.hero.position = goblin.position+Vector3.FORWARD*1.15
	goblin.resolve_attack()
	check(game.hero.hp==4,"club cone does not hit behind the attacker")
	game.hero.position = goblin.position+Vector3.BACK*1.15+Vector3.UP*1.2
	goblin.resolve_attack()
	check(game.hero.hp==4,"club attack respects target height")
	game.hero.position = goblin.position+Vector3.BACK*1.15
	var wall := Craft.solid_box(game,goblin.position+Vector3(0,0.8,0.6),Vector3(1.2,1.5,0.15),Craft.material(Color.GRAY))
	await step(2)
	goblin.resolve_attack()
	check(not goblin.has_line_of_sight() and game.hero.hp==4,"solid obstacle blocks detection and club damage")
	wall.queue_free()
	await step(2)
	goblin.begin_windup()
	goblin.take_hit(1,Vector3.FORWARD)
	goblin.update_visual(0)
	goblin.resolve_attack()
	check(goblin.state=="hurt" and not goblin.warning.visible and game.hero.hp==4 and goblin.current_atlas==Bokoblin.DAMAGE,"receiving a hit cancels the pending club attack")
	await capture("hurt")
	goblin.hp = 40
	goblin.change_state("idle")
	goblin.position = Vector3(0,0.05,2)
	game.hero.position = Vector3(0,0.05,3.2)
	game.hero.velocity = Vector3.ZERO
	game.hero.facing = Vector3.FORWARD
	game.enemy.position = Vector3(-1.2,0.05,1.1)
	goblin.position = Vector3(0.5,0.05,2)
	game.hero.hurt_time = 0
	game.hero.begin_attack()
	var nearest: Vector3 = goblin.position-game.hero.position
	nearest.y = 0
	check(game.hero.facing.x>0 and game.hero.facing.dot(Vector3.FORWARD)>0.98,"sword aim gently follows the nearest eligible enemy without a sudden turn")
	game.hero.attack_time = 0
	game.hero.combo = 0
	game.enemy.position = Vector3(-8,0.05,-6)
	goblin.position = Vector3(0,0.05,2)
	game.hero.facing = Vector3.FORWARD
	game.hero.combo_window = 0
	game.hero.set_physics_process(true)
	Input.action_press("attack")
	await step(2)
	Input.action_release("attack")
	await step(26)
	check(goblin.hp==30,"hero sword damages the new enemy once per swing")
	game.hero.set_physics_process(false)
	goblin.take_hit(1,Vector3.FORWARD,true)
	check(goblin.state=="hurt" and goblin.timer>=0.47,"heavy finisher produces a longer stagger")
	goblin.change_state("idle")
	goblin.position = goblin.home+Vector3.RIGHT*9
	goblin.knock = Vector3.ZERO
	goblin.velocity = Vector3.ZERO
	goblin.set_physics_process(true)
	await step(3)
	check(goblin.state=="return","leaving the territory triggers return instead of endless pursuit")
	goblin.set_physics_process(false)
	game.enemy.state = "windup"
	game.bokoblins[1].change_state("windup",1)
	goblin.position = Vector3(0,0.05,2)
	check(not game.can_enemy_attack(goblin),"two active attackers block a third attack slot")
	game.enemy.state = "idle"
	game.bokoblins[1].change_state("idle")
	goblin.position = Vector3(100,0,100)
	check(not game.can_enemy_attack(goblin),"off-screen enemy cannot start an unannounced attack")
	goblin.position = Vector3(0,0.05,2)
	goblin.take_hit(99,Vector3.FORWARD)
	goblin.set_physics_process(true)
	await step(20)
	check(not goblin.alive and goblin.animation_name=="dead" and goblin.current_column==2 and not goblin.warning.visible,"lethal hit uses drawn fall and defeated poses and cancels warning")
	check(not game.won and game.living_enemy_count()==2,"defeating a Bokoblin keeps the remaining encounter active")
	await capture("defeated")
	game.enemy.take_hit(99,Vector3.ZERO)
	check(not game.won and game.living_enemy_count()==1,"defeating the sentinel still leaves the last Bokoblin")
	game.bokoblins[1].take_hit(99,Vector3.ZERO)
	check(game.won and game.living_enemy_count()==0,"defeating the last enemy completes the encounter")
	reload_current_scene()
	await step(15)
	check(current_scene.bokoblins.size()==2 and current_scene.living_enemy_count()==3 and not current_scene.won,"restart restores both Bokoblins and the sentinel")
	var file := FileAccess.open("res://artifacts/bokoblin-verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(checks,"\t"))
	print("BOKOBLIN_VERIFICATION_FAILED" if failed else "BOKOBLIN_VERIFICATION_OK")
	quit(1 if failed else 0)
