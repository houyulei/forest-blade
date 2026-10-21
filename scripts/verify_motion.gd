extends SceneTree
## Run with a real renderer; exercises input, atlas switching and motion playback.
var game
var checks: Array = []
func _initialize() -> void:
	run.call_deferred()
func wait_physics(count: int) -> void:
	for i in range(count):
		await physics_frame
func check(value: bool, label: String) -> void:
	checks.append({"check":label,"passed":value})
	print("PASS: " if value else "FAIL: ",label)
	if not value:
		finish(1)
func finish(code: int) -> void:
	var file := FileAccess.open("res://artifacts/motion-verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(checks,"\t"))
	quit(code)
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/motion-%s.png" % label)
func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.muted = true
	game.enemy.set_physics_process(false)
	await wait_physics(30)
	game.hero.position = Vector3(0,0.05,2)
	await wait_physics(15)
	var right: Vector3 = game.camera.global_basis.x
	var away: Vector3 = -game.camera.global_basis.z
	away.y = 0
	away = away.normalized()
	for action in ["left","right"]:
		var start: Vector3 = game.hero.position
		var frames := {}
		Input.action_press(action)
		for i in range(45):
			await wait_physics(1)
			frames[game.hero.sprite_view.current_column] = true
			if i == 12 or i == 28:
				await capture("%s-%d" % [action,i])
		Input.action_release(action)
		var movement: Vector3 = game.hero.position-start
		check(absf(movement.dot(away)) < 0.05,"%s follows camera horizontal" % action)
		check(game.hero.sprite_view.sprite.texture == game.hero.sprite_view.RUN_SIDE,"%s uses articulated side atlas" % action)
		check(game.hero.sprite_view.sprite.flip_h == (action == "right"),"%s sprite faces travel" % action)
		check(frames.size() >= 12,"%s advances through both leg strides" % action)
		await wait_physics(25)
		check(game.hero.sprite_view.action_name == "idle","%s stops into idle" % action)
	var phase: float = game.hero.sprite_view.run_phase
	await wait_physics(20)
	check(is_equal_approx(phase,game.hero.sprite_view.run_phase),"standing still does not advance stride")
	Input.action_press("jump")
	await wait_physics(4)
	Input.action_release("jump")
	check(game.hero.sprite_view.sprite.hframes == 6 and not game.hero.sprite_view.sprite.flip_h,"jump restores directional pose atlas")
	await wait_physics(65)
	Input.action_press("attack")
	await wait_physics(4)
	Input.action_release("attack")
	check(game.hero.sprite_view.action_name == "attack" and game.hero.sprite_view.sprite.hframes == 6,"attack atlas survives side run")
	var data: Array = JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/side-run-joints.json"))
	for leg in ["near_foot","far_foot"]:
		var min_x := 999.0
		var max_x := -999.0
		var min_y := 999.0
		for sample in data:
			min_x = minf(min_x,sample[leg][0])
			max_x = maxf(max_x,sample[leg][0])
			min_y = minf(min_y,sample[leg][1])
		check(max_x-min_x >= 60 and min_y < 225,"%s travels and lifts independently" % leg)
	check(data[0].near_foot[0] < data[0].far_foot[0] and data[8].near_foot[0] > data[8].far_foot[0],"legs exchange leading position halfway through cycle")
	finish(0)
