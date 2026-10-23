extends SceneTree
## Actual actors, shared motion timeline and real collision world; isolated player progress.
class FixedStep:
	extends Node
	signal advanced
	var actor: Hero
	var pending := false
	func _physics_process(delta: float) -> void:
		if pending:
			pending = false
			actor._physics_process(delta)
			advanced.emit()
var driver: FixedStep
var game
var checks: Array = []
var failed := false
var frame_number := 0
var record := false
func _initialize() -> void:
	set_meta("isolated_adventure",true)
	record = "--record" in OS.get_cmdline_user_args()
	run.call_deferred()
func step(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func check(ok: bool, title: String) -> void:
	checks.append({"check":title,"passed":ok})
	print("PASS: " if ok else "FAIL: ",title)
	failed = failed or not ok
func capture(title: String) -> void:
	if DisplayServer.get_name()=="headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/action-%s.png" % title)
func tick() -> void:
	driver.pending = true
	await driver.advanced
	await process_frame
	if record and DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/action-frames/%04d.png" % frame_number)
		frame_number += 1
func text_nodes(node: Node) -> Array:
	var strings: Array = []
	if node is Label or node is Button or node is Label3D:
		strings.append(node.text)
	for child in node.get_children():
		strings.append_array(text_nodes(child))
	return strings
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/action-frames"))
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.muted = true
	for target in get_nodes_in_group("enemy"):
		target.set_physics_process(false)
		target.position = Vector3(-8,0.05,-7)
	await step(20)
	var hero: Hero = game.hero
	hero.set_physics_process(false)
	driver = FixedStep.new()
	driver.actor = hero
	root.add_child(driver)
	var mob: Bokoblin = game.bokoblins[0]
	var behind: Bokoblin = game.bokoblins[1]
	mob.hp = 500
	mob.max_hp = 500
	behind.hp = 500
	behind.max_hp = 500
	var right: Vector3 = game.camera.global_basis.x
	right.y = 0
	right = right.normalized()
	for combo in range(1,4):
		hero.position = Vector3(0,0.05,2)
		hero.velocity = Vector3.ZERO
		hero.facing = right
		hero.combo_window = 0 if combo==1 else 1
		mob.position = hero.position+right*1.4
		mob.state = "idle"
		mob.facing = -right
		mob.update_visual(0)
		behind.position = hero.position-right*1.4
		hero.begin_attack()
		check(hero.combo==combo,"combo %d begins in order" % combo)
		var start: Vector3 = hero.position
		var hp_before := mob.hp
		var behind_before := behind.hp
		var hit_phase := -1.0
		var shot := false
		var used_correct_atlas := false
		var recovery_stable := true
		for i in range(65):
			var before := mob.hp
			await tick()
			if mob.hp<before:
				hit_phase = 1.0-hero.attack_time/hero.attack_duration
			if hero.attack_time>0 and 1.0-hero.attack_time/hero.attack_duration>0.75:
				recovery_stable = recovery_stable and Vector2(hero.velocity.x,hero.velocity.z).length()<0.01
			if not shot and hero.attack_time>0 and 1.0-hero.attack_time/hero.attack_duration>0.5:
				used_correct_atlas = hero.sprite_view.current_atlas==[HeroSprite.ATTACK,HeroSprite.RETURN,HeroSprite.CLEAVE][combo-1]
				await capture("combo-%d" % combo)
				shot = true
			if hero.attack_time<=0 and hero.hit_pause<=0:
				break
		check(mob.hp==hp_before-(10+[0,1,4][combo-1]),"combo %d deals one hit with its intended damage" % combo)
		check(SwordMotion.active(combo,hit_phase),"combo %d damage aligns with the drawn release phase" % combo)
		check(behind.hp==behind_before,"combo %d does not hit a target behind the boy" % combo)
		print("MEASURED_STEP ",combo,": ",hero.position.distance_to(start)," pos ",hero.position," floor ",hero.is_on_floor())
		check(hero.position.distance_to(start)>0.04 and hero.position.distance_to(start)<0.5 and recovery_stable,"combo %d makes a short controlled step without recovery skating" % combo)
		check(used_correct_atlas,"combo %d uses its own forward-playing artwork" % combo)
		for i in range(4):
			await tick()
	# Windup cannot be evaded for free; recovery can be cancelled deliberately.
	hero.combo_window = 0
	hero.begin_attack()
	check(not hero.begin_dash(),"dash cannot cancel the attack windup")
	hero.attack_time = hero.attack_duration*0.25
	check(hero.begin_dash() and hero.attack_time==0 and not hero.buffered_attack,"dash cancels the recovery and clears the queued swing")
	hero.dash_time = 0
	hero.dash_cooldown = 0
	hero.invulnerable = 0
	hero.begin_attack()
	hero.buffered_attack = true
	hero.attack_buffer_time = 0.22
	hero.take_hit(1,-right)
	check(hero.attack_time==0 and not hero.buffered_attack and hero.hurt_time>0,"damage interrupts the sword and discards stale input")
	check(not hero.begin_dash() and not hero.begin_fire(),"hit reaction prevents contradictory actions")
	for i in range(15):
		await tick()
	check(hero.begin_dash(),"controls recover after the short hit reaction")
	hero.dash_time = 0
	hero.dash_cooldown = 0
	hero.hurt_time = 0
	mob.position = Vector3(-8,0.05,-7)
	behind.position = Vector3(-8,0.05,-7)
	hero.combo_window = 0
	hero.begin_attack()
	hero.buffered_attack = true
	hero.attack_buffer_time = 0.05
	for i in range(28):
		await tick()
	check(hero.combo==1 and hero.attack_time<=0 and not hero.buffered_attack,"expired early input does not trigger an unwanted follow-up")
	hero.combo_window = 0
	hero.begin_attack()
	while hero.attack_time>hero.attack_duration*0.24:
		await tick()
	hero.buffered_attack = true
	hero.attack_buffer_time = 0.22
	for i in range(8):
		await tick()
	check(hero.combo==2 and hero.attack_time>0,"late attack input chains naturally into the second swing")
	hero.cancel_attack()
	game.set_menu("equipment")
	await step(3)
	var all_text := text_nodes(game)
	var regex := RegEx.new()
	regex.compile("[A-Za-z]{3,}")
	var foreign: Array = []
	for text_ in all_text:
		for found in regex.search_all(text_):
			if found.get_string() not in ["WASD","Shift","Esc"]:
				foreign.append(found.get_string())
	check(foreign.is_empty(),"all visible game text is Simplified Chinese apart from keyboard names: "+str(foreign))
	var font: Font = preload("res://assets/fonts/NotoSansSC.ttf")
	check(font.has_char("锻".unicode_at(0)) and font.has_char("剑".unicode_at(0)),"bundled font includes Simplified Chinese glyphs")
	check(OS.get_user_data_dir().ends_with("Godot/app_userdata/Forest Blade — Painted Hero 2.5D"),"Chinese window title retains the existing save directory")
	await capture("equipment-zh")
	game.set_menu()
	hero.position = game.forge.smith_position()+Vector3(0,0,1)
	hero.invulnerable = 0
	hero.sprite_view.update_state(hero,0)
	game.set_menu("smith")
	await step(25)
	await capture("smith-zh")
	var file := FileAccess.open("res://artifacts/action-polish-verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks},"\t"))
	print("ACTION_POLISH_VERIFICATION_FAILED" if failed else "ACTION_POLISH_VERIFICATION_OK")
	quit(1 if failed else 0)
