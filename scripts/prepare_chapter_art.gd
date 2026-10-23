extends SceneTree
## Technical atlas extraction only. Preserve the generated source and its alpha.
func _initialize() -> void:
	var base := "res://assets/chapter-one/"
	var source := Image.load_from_file(base+"scenery-source.png")
	var names := ["cottage","inn","well","cave","cave_wall","stalagmites"]
	# Actual alpha components are not confined to the requested grid.
	var rectangles := [Rect2i(41,48,450,460),Rect2i(529,27,566,484),Rect2i(1159,119,331,402),Rect2i(17,554,507,440),Rect2i(540,550,570,444),Rect2i(1131,583,391,414)]
	var manifest := {}
	for i in range(names.size()):
		var region: Rect2i = rectangles[i]
		var cell := source.get_region(region)
		var bounds := Rect2i(Vector2i.ZERO,cell.get_size())
		var min_p := cell.get_size()
		var max_p := Vector2i.ZERO
		for y in range(cell.get_height()):
			for x in range(cell.get_width()):
				if cell.get_pixel(x,y).a>0.25:
					min_p = min_p.min(Vector2i(x,y))
					max_p = max_p.max(Vector2i(x,y))
		min_p = (min_p-Vector2i(2,2)).max(Vector2i.ZERO)
		max_p = (max_p+Vector2i(3,3)).min(cell.get_size())
		bounds = Rect2i(min_p,max_p-min_p)
		cell.get_region(bounds).save_png(base+names[i]+".png")
		manifest[names[i]] = {"source_rect":[region.position.x,region.position.y,region.size.x,region.size.y],"crop":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"anchor":bounds.size.x/2.0}
	var file := FileAccess.open(base+"regions.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"\t"))
	print("CHAPTER_ART_READY")
	quit()
