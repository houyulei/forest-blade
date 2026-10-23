extends SceneTree
const Tools = preload("res://scripts/prepare_sprites.gd")
# Constant body scale within a direction: raised weapons cannot resize the boy.
func _initialize() -> void:
	var records: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/hero/three-swords/regions.json"))
	for name_ in records:
		var source := Image.load_from_file("res://assets/hero/three-swords/%s-source.png" % name_)
		var cols := 4 if name_=="wind-spin" else 6
		var scales: Array = []
		for row in range(4):
			var first: Array = records[name_][0 if cols==4 else row*cols].rect
			var body := Tools.isolate_sprite(source.get_region(Rect2i(first[0],first[1],first[2],first[3])))
			scales.append((211.0 if cols==4 else ActorSizes.PROFILES.hero.reference_pixels[row])/body.get_used_rect().size.y)
		var atlas := Image.create(cols*320,1280,false,Image.FORMAT_RGBA8)
		atlas.fill(Color.TRANSPARENT)
		for index in range(cols*4):
			var record: Dictionary = records[name_][index]
			var r: Array = record.rect
			var rect := Rect2i(r[0],r[1],r[2],r[3])
			var clean := Tools.isolate_sprite(source.get_region(rect))
			var bottom := 0
			var left := 9999
			var right := 0
			# Brown boots, restricted to lower body, exclude blade tips and stray alpha.
			for y in range(int(clean.get_height()*0.72),clean.get_height()):
				for x in range(clean.get_width()):
					var c := clean.get_pixel(x,y)
					if c.a>0.75 and c.r>c.g*1.12 and c.r<c.g*1.95 and c.g>c.b*1.12 and c.r<0.65:
						bottom = maxi(bottom,y)
			for y in range(maxi(0,bottom-50),bottom+1):
				for x in range(clean.get_width()):
					var c := clean.get_pixel(x,y)
					if c.a>0.75 and c.r>c.g*1.12 and c.r<c.g*1.95 and c.g>c.b*1.12 and c.r<0.65:
						left = mini(left,x)
						right = maxi(right,x)
			var pivot := Vector2((left+right)*0.5,bottom+1)
			var scale_: float = scales[index/cols]
			clean.resize(roundi(clean.get_width()*scale_),roundi(clean.get_height()*scale_),Image.INTERPOLATE_LANCZOS)
			var offset := Vector2i(Vector2(160,280)-pivot*scale_)
			# Clip to own cell before atlas blit, never touch a neighbor.
			var cell := Image.create(320,320,false,Image.FORMAT_RGBA8)
			cell.fill(Color.TRANSPARENT)
			cell.blit_rect(clean,Rect2i(Vector2i.ZERO,clean.get_size()),offset)
			atlas.blit_rect(cell,Rect2i(0,0,320,320),Vector2i((index%cols)*320,(index/cols)*320))
			record["pivot"] = [pivot.x,pivot.y]
			record["scale"] = scale_
		atlas.save_png("res://assets/hero/three-swords/%s.png" % name_)
	var file := FileAccess.open("res://assets/hero/three-swords/regions.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(records,"\t"))
	print("THREE_SWORDS_ART_READY")
	quit()
