extends SceneTree
## Measure opaque pixels in real idle frames, compare species and render a shared-baseline lineup.
var game
var checks: Array = []
var failed := false
var measured := {}
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
func opaque_bounds(sprite: Sprite3D) -> Rect2i:
	var image := sprite.texture.get_image()
	if image.is_compressed():
		image.decompress()
	var size_ := Vector2i(image.get_width()/sprite.hframes,image.get_height()/sprite.vframes)
	var source := image.get_region(Rect2i(sprite.frame_coords*size_,size_))
	var minimum := size_
	var maximum := Vector2i.ZERO
	for y in range(size_.y):
		for x in range(size_.x):
			if source.get_pixel(x,y).a>0.5:
				minimum.x = mini(minimum.x,x)
				minimum.y = mini(minimum.y,y)
				maximum.x = maxi(maximum.x,x)
				maximum.y = maxi(maximum.y,y)
	return Rect2i(minimum,maximum-minimum+Vector2i.ONE)
func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.muted = true
	game.enemy.set_physics_process(false)
	for actor in game.bokoblins:
		actor.set_physics_process(false)
	await step(20)
	game.hero.set_physics_process(false)
	game.hero.velocity = Vector3.ZERO
	var goblin: Bokoblin = game.bokoblins[0]
	goblin.change_state("chase")
	goblin.velocity = Vector3.ZERO
	game.enemy.clock = 0
	var right: Vector3 = game.camera.global_basis.x
	var away: Vector3 = -game.camera.global_basis.z
	away.y = 0
	away = away.normalized()
	var facings := [-away,-right,right,away]
	for i in range(4):
		game.hero.facing = facings[i]
		game.hero.sprite_view.update_state(game.hero,0)
		goblin.facing = facings[i]
		goblin.update_visual(0)
		game.enemy.update_visual(facings[i])
		for record in [["hero",game.hero.sprite_view.sprite],["bokoblin",goblin.sprite],["sentinel",game.enemy.sprite]]:
			var kind: String = record[0]
			var sprite: Sprite3D = record[1]
			var bounds := opaque_bounds(sprite)
			var height := bounds.size.y*sprite.pixel_size
			measured[kind+"_%d" % i] = height
			check(absf(height-ActorSizes.body_height(kind))<0.025,"%s direction %d has calibrated body height" % [kind,i])
	for record in [["hero",game.hero],["bokoblin",goblin],["sentinel",game.enemy]]:
		var collider: CollisionShape3D
		for child in record[1].get_children():
			if child is CollisionShape3D:
				collider = child
				break
		check(collider!=null and absf(collider.position.y-collider.shape.height*0.5)<0.001,"%s collider remains rooted at its feet" % record[0])
	check(absf(measured.bokoblin_0/measured.hero_0-0.8)<0.02,"Bokoblin is 80 percent of the boy's body height")
	check(absf(measured.sentinel_0/measured.hero_0-1.6)<0.02,"stone warden is 160 percent of the boy's body height")
	# Frame three actual game actors at equal depth, without changing scene zoom or artwork.
	game.set_process(false)
	game.bokoblins[1].visible = false
	var center := Vector3(0,0.04,3)
	game.camera.look_at_from_position(center+Vector3(11,14,13),center+Vector3.UP*0.6)
	right = game.camera.global_basis.x
	var toward: Vector3 = game.camera.global_basis.z
	toward.y = 0
	toward = toward.normalized()
	game.hero.position = center-right*3.0
	goblin.position = center
	game.enemy.position = center+right*3.2
	game.hero.facing = toward
	game.hero.sprite_view.update_state(game.hero,0)
	goblin.facing = toward
	goblin.update_visual(0)
	game.enemy.update_visual(toward)
	for actor in [goblin,game.enemy]:
		var bounds := opaque_bounds(actor.sprite)
		var top: Vector3 = actor.global_position+game.camera.global_basis.y*(actor.sprite.texture.get_height()/float(actor.sprite.vframes)*0.5+actor.sprite.offset.y-bounds.position.y)*actor.sprite.pixel_size
		check(game.camera.unproject_position(actor.health.global_position).y<game.camera.unproject_position(top).y,"%s health bar clears the drawn head" % actor.name)
	var left: Vector2 = game.camera.unproject_position(game.hero.global_position)
	var middle: Vector2 = game.camera.unproject_position(goblin.global_position)
	var last: Vector2 = game.camera.unproject_position(game.enemy.global_position)
	check(absf(left.y-middle.y)<0.5 and absf(last.y-middle.y)<0.5,"comparison actors share a screen baseline and depth")
	if DisplayServer.get_name()!="headless":
		for pair in [[game.hero,"BOY  1.00x"],[goblin,"BOKOBLIN  0.80x"],[game.enemy,"STONE WARDEN  1.60x"]]:
			var label := Label.new()
			label.text = pair[1]
			label.add_theme_font_size_override("font_size",16)
			label.add_theme_constant_override("outline_size",5)
			label.add_theme_color_override("font_outline_color",Color("173025"))
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.size.x = 220
			var uv: Vector2 = game.camera.unproject_position(pair[0].global_position)/Vector2(game.pixel_world.size)
			label.position = game.pixel_display.global_position+uv*game.pixel_display.size+Vector2(-110,22)
			root.add_child(label)
		await step(10)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/actor-size-lineup.png")
	var report := {"checks":checks,"measured_idle_heights":measured}
	var file := FileAccess.open("res://artifacts/actor-sizes-verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("ACTOR_SIZES_VERIFICATION_FAILED" if failed else "ACTOR_SIZES_VERIFICATION_OK")
	quit(1 if failed else 0)
