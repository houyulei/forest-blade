extends SceneTree
## Alpha crop / feet registration only. Preserve the AI-painted source poses.
const Tools = preload("res://scripts/prepare_sprites.gd")
var CELL := 640
var BASELINE := 560
func _initialize() -> void:
	var base := "res://assets/hero/motion-audit-v3/" if "--audit" in OS.get_cmdline_user_args() else "res://assets/hero/weapon-redesign/"
	if "--audit" in OS.get_cmdline_user_args():
		CELL = 768
		BASELINE = 672
	var records: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base+"regions.json"))
	for name_ in records:
		var source := Image.load_from_file(ProjectSettings.globalize_path(base+name_+"-source.png"))
		var atlas := Image.create(CELL*6,CELL*4,false,Image.FORMAT_RGBA8)
		atlas.fill(Color.TRANSPARENT)
		var scales: Array[float] = []
		for row in range(4):
			var r: Array = records[name_][row*6].rect
			var first := Tools.isolate_sprite(source.get_region(Rect2i(r[0],r[1],r[2],r[3])))
			scales.append(float(ActorSizes.PROFILES.hero.reference_pixels[row])/float(records[name_][row*6].get("body_height",first.get_used_rect().size.y)))
		for index in range(24):
			var record: Dictionary = records[name_][index]
			var r: Array = record.rect
			var frame_source := source
			var factor: float = scales[index/6]
			if record.has("source"):
				frame_source = Image.load_from_file(ProjectSettings.globalize_path(base+str(record.source)+"-source.png"))
				factor = float(ActorSizes.PROFILES.hero.reference_pixels[index/6])/float(record.scale_body)
			var links := {"greatsword-sweep":"greatsword-cut","greatsword-cleave":"greatsword-sweep","spear-low":"spear-attack","spear-lunge":"spear-low","spear-low-v3":"spear-guard-v3","spear-lunge-v3":"spear-low-v3"}
			if index%6==0 and links.has(name_):
				var from_name: String = links[name_]
				var prior: Dictionary = records[from_name][index+5]
				r = prior.rect
				frame_source = Image.load_from_file(ProjectSettings.globalize_path(base+from_name+"-source.png"))
				factor = float(ActorSizes.PROFILES.hero.reference_pixels[index/6])/float(records[from_name][index].body_height)
				record["link_from"] = from_name+":"+str(index+5)
			var clean := Tools.isolate_sprite(frame_source.get_region(Rect2i(r[0],r[1],r[2],r[3])))
			var bottom := 0
			var left := 9999
			var right := 0
			for y in range(int(clean.get_height()*0.72),clean.get_height()):
				for x in range(clean.get_width()):
					var c := clean.get_pixel(x,y)
					if c.a>0.75 and c.r>c.g*1.12 and c.r<c.g*1.95 and c.g>c.b*1.12 and c.r<0.65:
						bottom = maxi(bottom,y)
			for y in range(maxi(0,bottom-40),bottom+1):
				for x in range(clean.get_width()):
					var c := clean.get_pixel(x,y)
					if c.a>0.75 and c.r>c.g*1.12 and c.r<c.g*1.95 and c.g>c.b*1.12 and c.r<0.65:
						left = mini(left,x)
						right = maxi(right,x)
			var pivot := Vector2((left+right)*0.5,bottom+1)
			clean.resize(roundi(clean.get_width()*factor),roundi(clean.get_height()*factor),Image.INTERPOLATE_LANCZOS)
			var offset := Vector2i(Vector2(CELL*0.5,BASELINE)-pivot*factor)
			var used := clean.get_used_rect()
			if offset.x+used.position.x<0 or offset.x+used.end.x>CELL or offset.y+used.position.y<0 or offset.y+used.end.y>CELL:
				push_error("Weapon clipped in %s frame %d offset %s used %s" % [name_,index,offset,used])
				quit(1)
				return
			var cell := Image.create(CELL,CELL,false,Image.FORMAT_RGBA8)
			cell.fill(Color.TRANSPARENT)
			cell.blit_rect(clean,Rect2i(Vector2i.ZERO,clean.get_size()),offset)
			atlas.blit_rect(cell,Rect2i(0,0,CELL,CELL),Vector2i(index%6*CELL,index/6*CELL))
			record["pivot"] = [pivot.x,pivot.y]
			record["scale"] = factor
		atlas.save_png(base+name_+".png")
	var file := FileAccess.open(base+"regions.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(records,"\t"))
	print("WEAPON_ART_READY")
	quit()
