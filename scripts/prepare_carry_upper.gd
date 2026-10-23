extends SceneTree
const Tools = preload("res://scripts/prepare_sprites.gd")
func _initialize() -> void:
	var base := "res://assets/hero/motion-audit-v3/"
	var records: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base+"upper-regions.json"))
	for name_ in records:
		var source := Image.load_from_file(ProjectSettings.globalize_path(base+name_+"-source.png"))
		var atlas := Image.create(3072,768,false,Image.FORMAT_RGBA8)
		atlas.fill(Color.TRANSPARENT)
		for direction in range(4):
			var record: Dictionary = records[name_][direction]
			var r: Array = record.rect
			var part := Tools.isolate_sprite(source.get_region(Rect2i(r[0],r[1],r[2],r[3])))
			var factor := float(ActorSizes.PROFILES.hero.reference_pixels[direction])*0.64/float(record.body_height)
			part.resize(roundi(part.get_width()*factor),roundi(part.get_height()*factor),Image.INTERPOLATE_LANCZOS)
			var offset := Vector2i(Vector2(384,672)-Vector2(record.anchor,record.hem)*factor)
			var used := part.get_used_rect()
			if offset.x+used.position.x<0 or offset.x+used.end.x>768 or offset.y+used.position.y<0 or offset.y+used.end.y>768:
				push_error("Carry upper clipping: "+name_+str(direction))
				quit(1)
				return
			var cell := Image.create(768,768,false,Image.FORMAT_RGBA8)
			cell.fill(Color.TRANSPARENT)
			cell.blit_rect(part,Rect2i(Vector2i.ZERO,part.get_size()),offset)
			atlas.blit_rect(cell,Rect2i(0,0,768,768),Vector2i(direction*768,0))
		atlas.save_png(base+name_+".png")
	print("CARRY_UPPER_READY")
	quit()
