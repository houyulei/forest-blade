extends SceneTree
## Bake the existing original stone sentinel into transparent directional sprites.
var viewport: SubViewport
const SourceSentinel = preload("res://scripts/sentinel_model_source.gd")
var model
var frame: int = 0
var atlas := Image.create(1024,1024,false,Image.FORMAT_RGBA8)
var job: int = 0
var ready: bool = false

func _initialize() -> void:
	build.call_deferred()

func build() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(256,256)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0,0,0,0)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("a9bfca")
	world.environment.ambient_light_energy = 0.38
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52,-35,0)
	sun.light_energy = 0.88
	sun.light_color = Color("ffe8c7")
	stage.add_child(sun)
	model = SourceSentinel.new()
	model.arena = stage
	stage.add_child(model)
	model.set_physics_process(false)
	for node in stage.get_children():
		if node is MeshInstance3D:
			node.visible = false
	for node in model.get_children():
		if node is MeshInstance3D:
			node.visible = false
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.25
	viewport.add_child(camera)
	camera.look_at_from_position(Vector3(0,5,6),Vector3(0,0.9,0))
	camera.current = true
	pose()
	ready = true

func pose() -> void:
	var row := job / 4
	var column := job % 4
	model.visual.rotation.y = [0.0,-PI/2,PI/2,PI][row]
	model.visual.scale = [Vector3.ONE,Vector3(1.04,0.93,1.04),Vector3(1.16,0.80,1.16),Vector3(1.04,1.04,1.04)][column]

func _process(_delta: float) -> bool:
	if not ready:
		return false
	frame += 1
	if frame < 5:
		return false
	frame = 0
	var source := viewport.get_texture().get_image()
	var rectangle := source.get_used_rect()
	var cell := source.get_region(rectangle)
	var location := Vector2i(job % 4 * 256 + (256 - cell.get_width()) / 2, job / 4 * 256 + 240 - cell.get_height())
	atlas.blit_rect(cell,Rect2i(Vector2i.ZERO,cell.get_size()),location)
	job += 1
	if job == 16:
		atlas.save_png("res://assets/sentinel/sentinel-legacy.png")
		print("SENTINEL_ATLAS_READY: 16 frames")
		quit()
		return true
	pose()
	return false
