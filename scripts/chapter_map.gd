class_name ChapterMap
extends Control
var arena: Node3D
func _process(_delta: float) -> void:
	queue_redraw()
func point(p: Vector3) -> Vector2:
	var e: Vector2 = arena.landscape.extent
	return Vector2(12,12)+(Vector2(p.x,p.z)/e*0.5+Vector2(0.5,0.5))*(size-Vector2(24,24))
func _draw() -> void:
	if not is_instance_valid(arena.landscape):
		return
	var line := Color("52705c") if arena.zone!="cave" else Color("55656c")
	draw_style_box(style(),Rect2(Vector2.ZERO,size))
	var points := PackedVector2Array()
	for p in arena.landscape.route:
		points.append(point(p))
	if points.size()>1:
		draw_polyline(points,line,9,true)
		draw_polyline(points,Color("b5a479"),2,true)
	for target in arena.bokoblins:
		if is_instance_valid(target) and target.alive:
			draw_circle(point(target.position),4.5 if target is GoldenBokoblin else 2.8,Color("eac269") if target is GoldenBokoblin else Color("d58f6d"))
	for portal in arena.portals:
		draw_rect(Rect2(point(portal.position)-Vector2(4,3),Vector2(8,6)),Color("8fcbb7"))
	draw_circle(point(arena.hero.position),4,Color("f9eed0"))
	draw_arc(point(arena.hero.position),6.5,0,TAU,20,Color("f9eed0"),1,true)
func style() -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = Color(0.025,0.05,0.045,0.85)
	result.border_color = Color(0.6,0.56,0.37,0.5)
	result.set_border_width_all(1)
	result.set_corner_radius_all(7)
	return result
