extends SceneTree
## Assemble AI guardian poses into the same 4x4 runtime format, with a shared foot pivot.
func _initialize() -> void:
	var source := Image.load_from_file("res://assets/sentinel/painted-source.png")
	var atlas := Image.create(1024,1024,false,Image.FORMAT_RGBA8)
	for row in range(4):
		for column in range(4):
			var left := roundi(column*source.get_width()/4.0)
			var top := roundi(row*source.get_height()/4.0)
			var right := roundi((column+1)*source.get_width()/4.0)
			var bottom := roundi((row+1)*source.get_height()/4.0)
			var image := source.get_region(Rect2i(left,top,right-left,bottom-top))
			var min_x := image.get_width()
			var max_x := 0
			var min_y := image.get_height()
			var max_y := 0
			for y in range(image.get_height()):
				for x in range(image.get_width()):
					if image.get_pixel(x,y).a > 0.4:
						min_x = mini(min_x,x)
						max_x = maxi(max_x,x)
						min_y = mini(min_y,y)
						max_y = maxi(max_y,y)
			image = image.get_region(Rect2i(min_x,min_y,max_x-min_x+1,max_y-min_y+1))
			image.resize(roundi(image.get_width()*0.78),roundi(image.get_height()*0.78),Image.INTERPOLATE_LANCZOS)
			atlas.blit_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i(column*256+(256-image.get_width())/2,row*256+240-image.get_height()))
	atlas.save_png("res://assets/sentinel/sentinel.png")
	print("PAINTED_GUARDIAN_READY: 16 frames")
	quit()
