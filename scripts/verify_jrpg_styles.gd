extends SceneTree
var game
var checks: Array = []
var failed := false
func _initialize() -> void:
	run.call_deferred()
func step(count := 3) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func check(ok: bool,title: String) -> void:
	checks.append({"check":title,"passed":ok})
	failed = failed or not ok
	print("PASS: " if ok else "FAIL: ",title)
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await step()
	event = InputEventKey.new()
	event.physical_keycode = code
	Input.parse_input_event(event)
	await step()
func run() -> void:
	game = load("res://jrpg_style_preview.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await step(35)
	check(not game.progress.persistence_enabled,"两版隔离正式存档")
	var original_position: Vector3 = game.hero.position
	var initial_solids: int = game.world.solids
	for variant in ["vesperia","ys"]:
		game.change_route(variant)
		game.reset_review()
		await step(15)
		check(game.hero.is_on_floor(),variant+"：角色稳定落地")
		check(game.world.house_roots.size()==3 and game.world.solids==initial_solids,variant+"：共享房屋布局及完整碰撞")
		check((game.world.painted_cards.size()==10) if variant=="ys" else game.world.painted_cards.is_empty(),variant+"：实际使用对应的绘制物件／立体网格管线")
		check(game.camera.projection==(Camera3D.PROJECTION_ORTHOGONAL if variant=="ys" else Camera3D.PROJECTION_PERSPECTIVE),variant+"：使用对应投影")
		var before: Vector3 = game.hero.position
		var camera_before: Vector3 = game.camera.position
		var basis_before: Basis = game.camera.basis
		Input.action_press("up")
		await step(60)
		Input.action_release("up")
		await step(10)
		check(game.hero.position.distance_to(before)>2.5,variant+"：实际行走")
		check(game.camera.position.distance_to(camera_before)>1.5 and game.camera.basis.is_equal_approx(basis_before),variant+"：镜头平移跟随并保持固定朝向")
		var y: float = game.hero.position.y
		Input.action_press("jump")
		await step(10)
		Input.action_release("jump")
		check(game.hero.position.y>y+0.2,variant+"：跳跃")
		await step(70)
		check(game.hero.is_on_floor(),variant+"：落地")
		var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
		var p: Vector3 = game.world.house_roots[0].global_position
		check(not space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3(0,1.3,4.5),p+Vector3(0,1.3,0))).is_empty(),variant+"：房屋墙面阻挡")
		check(not space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(11.5,2,9),Vector3(11.5,-0.5,9))).is_empty(),variant+"：木桥具有实体承载面")
		await key(KEY_R)
		check(game.hero.position.distance_to(original_position)<0.1,variant+"：R 返回入口")
		game.hero.position.y = -10
		await step(5)
		check(game.hero.position.y>-2,variant+"：跌落安全恢复")
	var p: Vector3 = game.hero.position
	await key(KEY_TAB)
	check(game.route=="vesperia" and game.hero.position.distance_to(p)<0.1,"Tab 切换方案并保留玩家位置")
	await key(KEY_F2)
	check(game.route=="ys","F2 打开伊苏方向")
	await key(KEY_F1)
	check(game.route=="vesperia","F1 打开薄暮方向")
	await key(KEY_F3)
	check(game.overview,"F3 切换全村机位")
	await key(KEY_H)
	check(not game.overlay.visible,"H 隐藏对比界面")
	check(not game.progress.persistence_enabled and game.hero.sprite_view is HeroSprite,"全程保留原精灵角色与存档隔离")
	check(not FileAccess.file_exists("res://cartoon_village_preview.tscn") and not FileAccess.file_exists("res://style_preview.tscn"),"已否定的几何卡通及旧换图入口已删除")
	var f := FileAccess.open("res://artifacts/jrpg-style-verification.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":not failed,"checks":checks},"\t"))
	print("JRPG_STYLE_OK" if not failed else "JRPG_STYLE_FAILED")
	quit(1 if failed else 0)
