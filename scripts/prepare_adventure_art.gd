extends SceneTree
const Tools = preload("res://scripts/prepare_sprites.gd")
const ROOT_X := [[230,580,950,1300],[240,585,960,1305],[245,590,960,1310],[240,590,960,1310]]
const ROOT_Y := [266,517,768,1007]
func _initialize() -> void:
	var source := Image.load_from_file("res://assets/hero/fire-source.png")
	var regions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/hero/fire-regions.json"))
	var atlas := Image.create(1280,1280,false,Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	for index in range(16):
		var record: Dictionary = regions.fire[index]
		var r: Array = record.rect
		var rect := Rect2i(r[0],r[1],r[2],r[3])
		var image := Tools.isolate_sprite(source.get_region(rect))
		var row := index/4
		var column := index%4
		var pivot := Vector2(ROOT_X[row][column]-rect.position.x,ROOT_Y[row]-rect.position.y)
		image.resize(roundi(image.get_width()*0.97),roundi(image.get_height()*0.97),Image.INTERPOLATE_LANCZOS)
		var offset := Vector2i(Vector2(160,280)-pivot*0.97)
		atlas.blit_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i(column*320,row*320)+offset)
	atlas.save_png("res://assets/hero/fire.png")
	for name_ in ["forge","smith"]:
		var raw := Image.load_from_file("res://assets/forge/%s-source.png" % name_)
		var clean := Tools.isolate_sprite(raw)
		var bounds := clean.get_used_rect()
		clean = clean.get_region(bounds)
		clean.resize(roundi(clean.get_width()*512.0/clean.get_height()),512,Image.INTERPOLATE_LANCZOS)
		clean.save_png("res://assets/forge/%s.png" % name_)
	print("ADVENTURE_ART_READY: fire 16 poses, forge and blacksmith cutouts")
	quit()
