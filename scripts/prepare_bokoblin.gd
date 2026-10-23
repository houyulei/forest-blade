extends SceneTree
## Technical assembly only: crop alpha islands, normalize pivots and direction.
const Tools = preload("res://scripts/prepare_sprites.gd")
const ROOT_X := {
	"walk":[[151,398,652,910,1153,1416],[156,421,661,909,1154,1414],[148,412,658,913,1169,1425]],
	"combat":[[150,408,660,915,1179,1419],[157,423,665,939,1165,1417],[157,418,665,907,1166,1416]],
	"damage":[[260,800,1270],[270,800,1270],[280,805,1280]]}
const ROOT_Y := {"walk":[305,611,958],"combat":[333,645,964],"damage":[349,670,993]}
const SCALES := {"walk":[0.85,0.82,0.70],"combat":[0.81,0.83,0.79],"damage":[0.61,0.61,0.61]}
func _initialize() -> void:
	var regions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/bokoblin/frame-regions.json"))
	for action in ["walk","combat","damage"]:
		var filename := "walk-source-v2.png" if action=="walk" else "%s-source.png" % action
		var source := Image.load_from_file("res://assets/bokoblin/"+filename)
		var columns := 3 if action=="damage" else 6
		var atlas := Image.create(columns*320,960,false,Image.FORMAT_RGBA8)
		atlas.fill(Color.TRANSPARENT)
		for index in range(regions[action].size()):
			var record: Dictionary = regions[action][index]
			var r: Array = record.rect
			var rectangle := Rect2i(r[0],r[1],r[2],r[3])
			var image := Image.create(rectangle.size.x,rectangle.size.y,false,Image.FORMAT_RGBA8)
			# Keep each connected component assigned to this sprite, including a dropped club.
			for component in record.components:
				var bounds := Rect2i(component[0],component[1],component[2],component[3]).grow(1)
				bounds = bounds.intersection(Rect2i(Vector2i.ZERO,source.get_size()))
				var part := Tools.isolate_sprite(source.get_region(bounds))
				image.blit_rect(part,Rect2i(Vector2i.ZERO,part.get_size()),bounds.position-rectangle.position)
			var row := index/columns
			var column := index%columns
			var pivot := Vector2(ROOT_X[action][row][column]-rectangle.position.x,ROOT_Y[action][row]-rectangle.position.y)
			# Generated side windup and damage face right; canonical side sprites face left.
			if row==1 and (action=="damage" or (action=="combat" and column==2)):
				image.flip_x()
				pivot.x = image.get_width()-pivot.x
			var ratio: float = SCALES[action][row]
			image.resize(roundi(image.get_width()*ratio),roundi(image.get_height()*ratio),Image.INTERPOLATE_LANCZOS)
			var offset := Vector2i(Vector2(160,280)-pivot*ratio)
			atlas.blit_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i(column*320,row*320)+offset)
		atlas.save_png("res://assets/bokoblin/%s.png" % action)
		print("BOKOBLIN_ATLAS_READY: ",action," ",columns*3," frames")
	quit()
