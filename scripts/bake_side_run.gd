extends SceneTree
## Reproducible cutout animation bake. Each foot has its own ground/contact arc.
const COUNT := 16
var viewport: SubViewport
var stage: Node2D
var parts := {}
var atlas := Image.create(320 * COUNT, 320, false, Image.FORMAT_RGBA8)
var sheet := Image.create(320 * 8, 640, false, Image.FORMAT_RGBA8)
var samples: Array = []
var frame := 0
var ticks := 0
var ready := false
var source: Image

func _initialize() -> void:
	build.call_deferred()

func piece(name_: String, rect: Rect2i, pivot: Vector2, size_scale: float, layer: int) -> Sprite2D:
	var node := Sprite2D.new()
	node.texture = ImageTexture.create_from_image(source.get_region(rect))
	node.centered = false
	node.offset = -pivot
	node.scale = Vector2.ONE * size_scale
	node.z_index = layer
	stage.add_child(node)
	parts[name_] = node
	return node

func build() -> void:
	source = Image.load_from_file("res://assets/hero/run-rig/parts-source.png")
	viewport = SubViewport.new()
	viewport.size = Vector2i(320,320)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	stage = Node2D.new()
	viewport.add_child(stage)
	piece("body",Rect2i(165,3,510,397),Vector2(205,322),0.32,4)
	piece("near_thigh",Rect2i(1150,430,185,245),Vector2(108,39),0.24,3)
	piece("far_thigh",Rect2i(720,708,180,244),Vector2(75,31),0.24,0)
	piece("near_shin",Rect2i(295,704,139,157),Vector2(58,27),0.27,3)
	piece("far_shin",Rect2i(1213,706,124,158),Vector2(51,28),0.27,0)
	piece("near_boot",Rect2i(225,820,210,170),Vector2(145,34),0.20,3)
	piece("far_boot",Rect2i(1155,818,194,164),Vector2(131,34),0.20,0)
	piece("near_arm",Rect2i(818,110,148,225),Vector2(72,40),0.18,6)
	piece("far_arm",Rect2i(274,436,145,220),Vector2(73,39),0.18,1)
	piece("near_hand",Rect2i(1201,133,124,255),Vector2(69,33),0.15,7)
	piece("far_hand",Rect2i(747,445,101,241),Vector2(48,36),0.15,2)
	for side in ["near","far"]:
		parts[side+"_thigh"].scale.x *= 0.83
		parts[side+"_shin"].scale.x *= 0.92
	pose(0)
	ready = true

# Contact, compression, drive, toe-off, heel recovery, knee drive, extension, reach.
# Angles describe an athletic run. The lower leg folds behind the thigh in recovery.
const LEG_KEYS := [Vector2(0.65,0.40), Vector2(0.25,0.75),
	Vector2(-0.40,0.65), Vector2(-0.85,0.85), Vector2(-0.60,1.80),
	Vector2(0.25,2.00), Vector2(0.85,1.20), Vector2(0.85,0.55)]
const BOOT_KEYS := [0.08,0.0,-0.35,-0.65,-0.65,-0.25,0.24,0.16]

func leg(prefix: String, phase: float, hip: Vector2) -> Vector2:
	var sample := fposmod(phase / TAU, 1.0)*8.0
	var key := int(sample)
	var fraction := smoothstep(0.0,1.0,sample-key)
	var angles: Vector2 = LEG_KEYS[key].lerp(LEG_KEYS[(key+1)%8],fraction)
	var thigh_angle := angles.x
	var calf_angle := thigh_angle - angles.y
	var knee := hip + Vector2(-sin(thigh_angle),cos(thigh_angle))*43
	var foot := knee + Vector2(-sin(calf_angle),cos(calf_angle))*37
	parts[prefix+"_thigh"].position = hip
	parts[prefix+"_thigh"].rotation = thigh_angle
	parts[prefix+"_shin"].position = knee
	parts[prefix+"_shin"].rotation = calf_angle
	parts[prefix+"_boot"].position = foot
	parts[prefix+"_boot"].rotation = lerpf(BOOT_KEYS[key],BOOT_KEYS[(key+1)%8],fraction)
	return foot

func arm(prefix: String, phase: float, shoulder: Vector2, lean: float) -> void:
	# Opposite arm accompanies the leading leg; elbows stay loose rather than boxing.
	var swing := -cos(phase)
	var angle := swing*0.72 + lean
	parts[prefix+"_arm"].position = shoulder
	parts[prefix+"_arm"].rotation = angle
	var elbow := shoulder + Vector2(-sin(angle),cos(angle))*28
	parts[prefix+"_hand"].position = elbow
	parts[prefix+"_hand"].rotation = angle + 0.95 + swing*0.15

func pose(index: int) -> void:
	var phase := float(index)/COUNT*TAU
	var bob := 4.0*cos(phase*2)
	var hip := Vector2(160,177+bob)
	var lean := -0.16 + 0.018*sin(phase*2)
	parts.body.position = hip
	parts.body.rotation = lean
	var far_foot := leg("far",phase+PI,hip+Vector2(2,0))
	var near_foot := leg("near",phase,hip)
	arm("far",phase+PI,hip+Vector2(-1,-33).rotated(lean),lean)
	arm("near",phase,hip+Vector2(-7,-33).rotated(lean),lean)
	samples.append({"frame":index,"near_foot":[near_foot.x,near_foot.y],"far_foot":[far_foot.x,far_foot.y]})

func _process(_delta: float) -> bool:
	if not ready:
		return false
	ticks += 1
	if ticks < 3:
		return false
	ticks = 0
	var image := viewport.get_texture().get_image()
	atlas.blit_rect(image,Rect2i(0,0,320,320),Vector2i(frame*320,0))
	sheet.blit_rect(image,Rect2i(0,0,320,320),Vector2i(frame%8*320,frame/8*320))
	image.save_png("res://artifacts/side-run-%02d.png" % frame)
	frame += 1
	if frame == COUNT:
		atlas.save_png("res://assets/hero/run-side.png")
		sheet.save_png("res://artifacts/side-run-contact.png")
		var file := FileAccess.open("res://artifacts/side-run-joints.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(samples,"\t"))
		print("SIDE_RUN_BAKED: 16 frames, independently articulated legs")
		quit()
		return true
	pose(frame)
	return false
