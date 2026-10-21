extends SceneTree
## Renders a hero turnaround to artifacts/hero-model.png for comparison with the concept art.
## ../tools/godot --path . --script res://scripts/model_sheet.gd
## Add `-- --poses` to render the three combo swings at mid-swing to artifacts/hero-poses.png.

var frames: int = 0
var poses: bool = false
var heroes: Array[Hero] = []

func _initialize() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("f3ecdc")
	world.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	scene.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_color = Color("ffe8c7")
	sun.light_energy = 0.88
	sun.shadow_enabled = true
	scene.add_child(sun)
	var floor := Craft.box(scene, Vector3(0, -0.02, 0), Vector3(8, 0.04, 3), Craft.material(Color("e9e0cc")))
	floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	poses = "--poses" in OS.get_cmdline_user_args()
	var yaws := [0.45, 0.0, -PI / 2, PI]
	for i in range(yaws.size()):
		if poses:
			# Combo 1, 2 and 3 at mid-swing, then the finisher a little later in its spin.
			var hero := Hero.new()
			hero.position.x = (i - 1.5) * 1.3
			hero.process_mode = Node.PROCESS_MODE_DISABLED
			scene.add_child(hero)
			heroes.append(hero)
			continue
		var holder := Node3D.new()
		holder.position.x = (i - 1.5) * 0.95
		scene.add_child(holder)
		var boy := BoyModel.build(holder)
		boy.root.rotation.y = yaws[i]
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.2 if poses else 2.3
	scene.add_child(camera)
	camera.look_at_from_position(Vector3(0, 4.5, 8) if poses else Vector3(0, 1.4, 8), Vector3(0, 0.98, 0))
	camera.current = true

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 3:
		for i in range(heroes.size()):
			var hero := heroes[i]
			hero.combo = mini(i + 1, 3)
			hero.pose_attack(0.45 if i < 3 else 0.7)
			hero.visual.root.rotation.y = 0.6
			hero.slash.rotation.y = 0.6
	if frames == 20:
		var path := ProjectSettings.globalize_path("res://artifacts/hero-poses.png" if poses else "res://artifacts/hero-model.png")
		root.get_texture().get_image().save_png(path)
		print("MODEL_SHEET_SAVED: " + path)
		return true
	return false
