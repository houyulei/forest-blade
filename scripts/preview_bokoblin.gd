extends SceneTree
## Render the shipped sprite states for animated art review, without altering art.
var viewport: SubViewport
var sprite: Sprite2D
var label: Label
var index := 0
var ticks := 0
var ready := false
func _initialize() -> void:
	build.call_deferred()
func build() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/bokoblin-preview"))
	viewport = SubViewport.new()
	viewport.size = Vector2i(320,320)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("20352e")
	background.size = Vector2(320,320)
	viewport.add_child(background)
	sprite = Sprite2D.new()
	sprite.position = Vector2(160,160)
	viewport.add_child(sprite)
	label = Label.new()
	label.position = Vector2(12,10)
	label.add_theme_font_size_override("font_size",14)
	label.modulate = Color("f1d3a4")
	viewport.add_child(label)
	pose()
	ready = true
func pose() -> void:
	var atlas: Texture2D = Bokoblin.COMBAT
	var column := 0
	var action := "GUARD"
	if index>=6 and index<30:
		atlas = Bokoblin.WALK
		column = ((index-6)/2)%6
		action = "WALK"
	elif index>=30 and index<36:
		column = 1
		action = "WINDUP"
	elif index>=36 and index<43:
		column = 2
		action = "WINDUP"
	elif index>=43 and index<47:
		column = 3
		action = "STRIKE"
	elif index>=47 and index<54:
		column = 4
		action = "FOLLOW THROUGH"
	elif index>=54 and index<64:
		column = 5
		action = "RECOVER"
	elif index>=64:
		atlas = Bokoblin.DAMAGE
		column = 0 if index<69 else (1 if index<74 else 2)
		action = "HURT" if index<69 else "DEFEATED"
	sprite.frame = 0
	sprite.hframes = 1
	sprite.vframes = 1
	sprite.texture = atlas
	sprite.hframes = 3 if atlas==Bokoblin.DAMAGE else 6
	sprite.vframes = 3
	sprite.frame_coords = Vector2i(column,1)
	label.text = "RED BOKOBLIN  /  "+action
func _process(_delta: float) -> bool:
	if not ready:
		return false
	ticks += 1
	if ticks<2:
		return false
	ticks = 0
	viewport.get_texture().get_image().save_png("res://artifacts/bokoblin-preview/%03d.png" % index)
	index += 1
	if index==84:
		print("BOKOBLIN_PREVIEW_READY: 84 frames")
		quit()
		return true
	pose()
	return false
