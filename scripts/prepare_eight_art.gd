extends SceneTree
## Mechanical alpha isolation, resampling and atlas registration; source paintings stay intact.
const Tools = preload("res://scripts/prepare_sprites.gd")
const BASE := "res://assets/hero/eight-directions/"
const CELL := 640
const BASELINE := 560
func _initialize() -> void:
	var records: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE+"regions.json"))
	for name_ in records:
		var source := Image.load_from_file(ProjectSettings.globalize_path(BASE+name_+"-source.png"))
		var atlas := Image.create(CELL*6,CELL*4,false,Image.FORMAT_RGBA8)
		atlas.fill(Color.TRANSPARENT)
		for index in range(24):
			var record: Dictionary = records[name_][index]
			var r: Array = record.rect
			if record.has("reuse"):
				var link: Array = record.reuse
				record = records[link[0]][int(link[1])]
				r = record.rect
			var frame_source := Image.load_from_file(ProjectSettings.globalize_path(BASE+str(record.source_file)))
			var clean := Tools.isolate_sprite(frame_source.get_region(Rect2i(r[0],r[1],r[2],r[3])))
			var factor: float = record.scale
			var pivot := Vector2(record.pivot[0],record.pivot[1])
			clean.resize(maxi(1,roundi(clean.get_width()*factor)),maxi(1,roundi(clean.get_height()*factor)),Image.INTERPOLATE_LANCZOS)
			var offset := Vector2i(Vector2(CELL*0.5,BASELINE)-pivot*factor)
			var used := clean.get_used_rect()
			if offset.x+used.position.x<1 or offset.x+used.end.x>=CELL or offset.y+used.position.y<1 or offset.y+used.end.y>=CELL:
				push_error("Eight-way art clipped: %s frame %d" % [name_,index])
				quit(1)
				return
			var cell := Image.create(CELL,CELL,false,Image.FORMAT_RGBA8)
			cell.fill(Color.TRANSPARENT)
			cell.blit_rect(clean,Rect2i(Vector2i.ZERO,clean.get_size()),offset)
			atlas.blit_rect(cell,Rect2i(0,0,CELL,CELL),Vector2i(index%6*CELL,index/6*CELL))
		atlas.save_png(BASE+name_+".png")
		print("EIGHT_ATLAS_READY ",name_)
	# Continue each combo from the exact final pose of the preceding strike.
	for weapon in ["wind","fire","thunder"]:
		for combo in [2,3]:
			var previous_path: String = BASE+weapon+"-attack-"+str(combo-1)+"-diagonal.png"
			if not FileAccess.file_exists(previous_path): continue
			var previous := Image.load_from_file(ProjectSettings.globalize_path(previous_path))
			var path: String = BASE+weapon+"-attack-"+str(combo)+"-diagonal.png"
			if not FileAccess.file_exists(path) or previous==null: continue
			var atlas := Image.load_from_file(ProjectSettings.globalize_path(path))
			for row in range(4): atlas.blit_rect(previous,Rect2i(5*CELL,row*CELL,CELL,CELL),Vector2i(0,row*CELL))
			atlas.save_png(path)
	print("EIGHT_ART_READY")
	quit()
