extends SceneTree
## Integration checks use the real scene and physical world, with isolated progress.
var game
var checks: Array = []
var failed := false
func _initialize() -> void:
	run.call_deferred()
func step(count: int = 3) -> void:
	for frame in range(count):
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
	game = load("res://style_volume_preview.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await step(30)
	check(not game.progress.persistence_enabled,"预览不读写正式玩家存档")
	check(game.hero.is_on_floor(),"主角落在真实地形碰撞上")
	var start: Vector3 = game.hero.position
	var camera_start: Vector3 = game.camera.position
	Input.action_press("up")
	await step(60)
	Input.action_release("up")
	await step(10)
	check(game.hero.position.distance_to(start)>3,"道路支持实际行走")
	check(game.camera.position.distance_to(camera_start)>2,"固定朝向镜头跟随主角移动")
	var height: float = game.hero.position.y
	Input.action_press("jump")
	await step(10)
	Input.action_release("jump")
	check(game.hero.position.y>height+0.2,"真实地形上能够跳跃")
	await step(70)
	check(game.hero.is_on_floor(),"跳跃后回到地形表面")
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var house: Node3D = game.world.get_node("VillageHouse0")
	var wall_query := PhysicsRayQueryParameters3D.create(house.to_global(Vector3(0,1.4,5)),house.to_global(Vector3(0,1.4,0)))
	check(not space.intersect_ray(wall_query).is_empty(),"旋转缩放后的房屋仍保留实体墙面")
	var well: Node3D = game.world.get_node("VillageWell")
	var well_query := PhysicsRayQueryParameters3D.create(well.global_position+Vector3(0,0.5,2),well.global_position+Vector3(0,0.5,0))
	check(not space.intersect_ray(well_query).is_empty(),"水井具有实体碰撞")
	var bridge_query := PhysicsRayQueryParameters3D.create(Vector3(12,2,10),Vector3(12,-0.5,10))
	check(not space.intersect_ray(bridge_query).is_empty(),"木桥桥面可承载角色")
	await key(KEY_F2)
	check(not game.follow and game.view==1,"观景快捷键固定镜头")
	await key(KEY_F)
	check(game.follow,"F 恢复跟随镜头")
	await key(KEY_H)
	check(not game.overlay.visible,"H 隐藏说明")
	await key(KEY_F4)
	check(game.late_light,"F4 可以切换光照")
	await key(KEY_R)
	check(game.hero.position.distance_to(start)<0.1,"R 返回村口")
	game.hero.position.y = -10
	await step(5)
	check(game.hero.position.y>-2,"离开地形时自动返回安全点")
	var file := FileAccess.open("res://artifacts/volume-village-verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":not failed,"checks":checks},"\t"))
	print("VOLUME_VILLAGE_OK" if not failed else "VOLUME_VILLAGE_FAILED")
	quit(1 if failed else 0)
