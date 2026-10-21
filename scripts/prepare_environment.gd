extends SceneTree
## Technical extraction of isolated transparent scenery cards; originals are retained.
const BASE := "res://assets/environment/"

func _initialize() -> void:
	var trees := Image.load_from_file(BASE + "trees-source.png")
	var items := {
		"oak": [trees,Rect2i(0,0,810,651)],
		"birch": [trees,Rect2i(810,0,452,651)],
		"crooked": [trees,Rect2i(0,651,690,595)],
		"sapling": [trees,Rect2i(690,651,572,595)]
	}
	for group in [["plants",["ferns","flowers","rocks","log","mushrooms","bramble"]],["ruins",["arch","pillar","wall","shrine","fallen","lantern"]]]:
		var source := Image.load_from_file(BASE + group[0] + "-source.png")
		for i in range(6):
			items[group[1][i]] = [source,Rect2i(i % 3 * 512,i / 3 * 512,512,512)]
	var manifest := {}
	for name in items:
		var image: Image = items[name][0].get_region(items[name][1])
		var min_x := image.get_width()
		var min_y := image.get_height()
		var max_x := 0
		var max_y := 0
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				if image.get_pixel(x,y).a > 0.3:
					min_x = mini(min_x,x)
					min_y = mini(min_y,y)
					max_x = maxi(max_x,x)
					max_y = maxi(max_y,y)
		var rectangle := Rect2i(Vector2i(maxi(0,min_x-2),maxi(0,min_y-2)),Vector2i(mini(image.get_width(),max_x+3)-maxi(0,min_x-2),mini(image.get_height(),max_y+3)-maxi(0,min_y-2)))
		image = image.get_region(rectangle)
		var histogram := PackedInt32Array()
		histogram.resize(image.get_width())
		var total := 0
		for y in range(int(image.get_height()*0.82),image.get_height()):
			for x in range(image.get_width()):
				if image.get_pixel(x,y).a > 0.5:
					histogram[x] += 1
					total += 1
		var anchor := image.get_width()/2
		var count := 0
		for x in range(histogram.size()):
			count += histogram[x]
			if count >= total/2:
				anchor = x
				break
		image.save_png(BASE+name+".png")
		manifest[name] = {"width":image.get_width(),"height":image.get_height(),"anchor":anchor}
		print("SCENERY_READY: ",name)
	var file := FileAccess.open(BASE+"anchors.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"\t"))
	quit()
