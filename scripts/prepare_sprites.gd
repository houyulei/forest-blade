extends SceneTree
## Technical atlas assembly: detected alpha islands -> equal cells and shared foot baseline.
## Artwork remains unchanged; original AI atlases are retained alongside the output.
const CELL := 320
const BASELINE := 280
const SCALE := 0.86

func _initialize() -> void:
	var regions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/hero/frame-regions.json"))
	for action in regions:
		var source := Image.load_from_file("res://assets/hero/%s-source.png" % action)
		var atlas := Image.create(CELL * 6, CELL * 4, false, Image.FORMAT_RGBA8)
		atlas.fill(Color.TRANSPARENT)
		var index := 0
		for region in regions[action]:
			var rectangle := Rect2i(int(region[0]), int(region[1]), int(region[2]), int(region[3]))
			var frame := isolate_sprite(source.get_region(rectangle))
			var histogram := PackedInt32Array()
			histogram.resize(frame.get_width())
			var total := 0
			# Lower-body mass locates the feet, avoiding a trailing scarf or extended sword.
			for y in range(int(frame.get_height() * 0.65), frame.get_height()):
				for x in range(frame.get_width()):
					if frame.get_pixel(x, y).a > 0.55:
						histogram[x] += 1
						total += 1
			var anchor := float(frame.get_width()) * 0.5
			var cumulative := 0
			for x in range(histogram.size()):
				cumulative += histogram[x]
				if cumulative >= total / 2:
					anchor = x
					break
			frame.resize(roundi(frame.get_width() * SCALE), roundi(frame.get_height() * SCALE), Image.INTERPOLATE_LANCZOS)
			var cell := Vector2i(index % 6 * CELL, index / 6 * CELL)
			var offset := Vector2i(roundi(CELL * 0.5 - anchor * SCALE), BASELINE - frame.get_height())
			atlas.blit_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), cell + offset)
			index += 1
		atlas.save_png("res://assets/hero/%s.png" % action)
		print("ATLAS_READY: ", action, " / ", index, " frames")
	quit()

func isolate_sprite(image: Image) -> Image:
	# Cropping rectangles can overlap a neighbor's sword tip. Keep only the main
	# connected alpha island, retaining its antialiased edge pixels.
	var width := image.get_width()
	var height := image.get_height()
	var data := image.get_data()
	var visited := PackedByteArray()
	visited.resize(width * height)
	var largest := PackedInt32Array()
	for seed in range(width * height):
		if visited[seed] != 0 or data[seed * 4 + 3] <= 90:
			continue
		var queue := PackedInt32Array([seed])
		visited[seed] = 1
		var cursor := 0
		while cursor < queue.size():
			var pixel := queue[cursor]
			cursor += 1
			var x := pixel % width
			for next in [pixel - 1, pixel + 1, pixel - width, pixel + width]:
				if next < 0 or next >= visited.size():
					continue
				if (next == pixel - 1 and x == 0) or (next == pixel + 1 and x == width - 1):
					continue
				if visited[next] == 0 and data[next * 4 + 3] > 90:
					visited[next] = 1
					queue.append(next)
		if queue.size() > largest.size():
			largest = queue
	var keep := PackedByteArray()
	keep.resize(width * height)
	for pixel in largest:
		var x := pixel % width
		var y := pixel / width
		for dy in range(-1,2):
			for dx in range(-1,2):
				var nx := x + dx
				var ny := y + dy
				if nx >= 0 and nx < width and ny >= 0 and ny < height:
					keep[ny * width + nx] = 1
	for pixel in range(keep.size()):
		if keep[pixel] == 0:
			data[pixel * 4 + 3] = 0
	return Image.create_from_data(width,height,false,Image.FORMAT_RGBA8,data)
