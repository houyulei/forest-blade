extends SceneTree
func _initialize() -> void:
	var raw := Image.load_from_file("res://assets/hero/three-swords/effects-source.png")
	var atlas := Image.create(1280,960,false,Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	var rows := [Vector2i(0,390),Vector2i(390,710),Vector2i(710,1024)]
	for row in range(3):
		for col in range(4):
			var cell := raw.get_region(Rect2i(col*384,rows[row].x,384,rows[row].y-rows[row].x))
			var bounds := cell.get_used_rect()
			cell = cell.get_region(bounds)
			var scale_ := minf(300.0/cell.get_width(),295.0/cell.get_height())
			cell.resize(roundi(cell.get_width()*scale_),roundi(cell.get_height()*scale_),Image.INTERPOLATE_LANCZOS)
			var position := Vector2i(col*320+(320-cell.get_width())/2,row*320+300-cell.get_height())
			atlas.blit_rect(cell,Rect2i(Vector2i.ZERO,cell.get_size()),position)
	atlas.save_png("res://assets/hero/three-swords/effects.png")
	print("SWORD_FX_READY")
	quit()
