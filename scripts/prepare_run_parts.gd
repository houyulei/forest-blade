extends SceneTree
## Extract the already-animated lower body. No repainting or invented gait poses.
func lower_only(source: Image) -> Image:
	var width := source.get_width()
	var height := source.get_height()
	var pixels := source.get_data()
	var visited := PackedByteArray()
	visited.resize(width*height)
	var keep := PackedByteArray()
	keep.resize(width*height)
	for seed in range(width*height):
		if visited[seed] or pixels[seed*4+3]<=90: continue
		var queue := PackedInt32Array([seed])
		visited[seed] = 1
		var cursor := 0
		var reaches_leg := false
		while cursor<queue.size():
			var p := queue[cursor]
			cursor += 1
			if p/width>=45: reaches_leg = true
			for next in [p-1,p+1,p-width,p+width]:
				if next<0 or next>=visited.size(): continue
				if abs(next%width-p%width)>1: continue
				if not visited[next] and pixels[next*4+3]>90:
					visited[next] = 1
					queue.append(next)
		if reaches_leg:
			for p in queue:
				for dy in range(-1,2):
					for dx in range(-1,2):
						var x := p%width+dx
						var y := p/width+dy
						if x>=0 and x<width and y>=0 and y<height: keep[y*width+x] = 1
	for p in range(keep.size()):
		if not keep[p]: pixels[p*4+3] = 0
		# The old run artwork contains hands next to the upper pelvis. Restrict
		# that hidden waist band, then widen to retain both complete swinging legs.
		var y := p/width
		var half_width := 28.0 if y<25 else minf(160,28.0+(y-25)*2.2)
		if absf(float(p%width)-160)>half_width: pixels[p*4+3] = 0
	return Image.create_from_data(width,height,false,Image.FORMAT_RGBA8,pixels)
func _initialize() -> void:
	for name_ in ["side","front","back"]:
		var side: bool = name_=="side"
		var source := Image.load_from_file(ProjectSettings.globalize_path("res://assets/hero/run-side.png" if side else "res://assets/hero/run.png"))
		var count := 16 if side else 6
		var row := 3 if name_=="back" else 0
		var atlas := Image.create(count*320,150,false,Image.FORMAT_RGBA8)
		atlas.fill(Color.TRANSPARENT)
		for column in range(count):
			var part := lower_only(source.get_region(Rect2i(column*320,row*320+170,320,150)))
			atlas.blit_rect(part,Rect2i(0,0,320,150),Vector2i(column*320,0))
		atlas.save_png("res://assets/hero/motion-audit-v3/run-legs-%s.png" % name_)
	print("RUN_PARTS_READY")
	quit()
