class_name SwordEffect
extends Node3D
## Every cast owns a damage snapshot. Swept travel/LOS prevents wall piercing and tunnelling.
var arena: Node3D
var kind := "wind_cut"
var direction := Vector3.FORWARD
var damage := 10
var speed := 9.0
var radius := 0.6
var reach := 5.0
var age := 0.0
var travel := 0.0
var timer := 0.0
var hits := {}
var hit_total := 0
var pulses := 0
var chain_last: Node3D
var chain_origin := Vector3.ZERO
var visual: BladeFX
func _ready() -> void:
	add_to_group("sword_effect")
	visual = BladeFX.new()
	visual.arena = arena
	visual.direction = direction
	visual.radius = radius
	visual.life = 2.5
	match kind:
		"wind_cut": visual.kind = "wind"
		"fire_wave": visual.kind = "fire"
		"fire_ball": visual.kind = "fireball"
		"tornado":
			visual.kind = "tornado"
			visual.radius = radius
		"chain":
			visual.kind = "thunder"
			visual.color = Color("ffe879")
			visual.radius = 0.35
			chain_origin = global_position+Vector3.UP*0.8
	add_child(visual)
func clear_path(a: Vector3, b: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(a,b,1)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
func target_radius(target: Node3D) -> float:
	return 0.5 if target is Sentinel else 0.23
func deal(target: Node3D, push: Vector3, heavy: bool = false) -> void:
	target.take_hit(damage,push,heavy)
	hits[target.get_instance_id()] = int(hits.get(target.get_instance_id(),0))+1
	hit_total += 1
func segment_distance(point: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := Vector2(b.x-a.x,b.z-a.z)
	var ap := Vector2(point.x-a.x,point.z-a.z)
	var t := clampf(ap.dot(ab)/maxf(ab.length_squared(),0.00001),0,1)
	return ap.distance_to(ab*t)
func _physics_process(delta: float) -> void:
	if arena.menu_open:
		return
	age += delta
	if kind=="tornado":
		timer -= delta
		if timer<=0 and pulses<6:
			timer += 0.38
			pulses += 1
			for target in get_tree().get_nodes_in_group("enemy"):
				if target.alive and absf(target.global_position.y-global_position.y)<1.6 and segment_distance(target.global_position,global_position,global_position)<radius+target_radius(target) and clear_path(global_position+Vector3.UP*0.7,target.global_position+Vector3.UP*0.7):
					deal(target,(global_position-target.global_position).normalized())
		if age>=2.35:
			queue_free()
		return
	if kind=="chain":
		timer -= delta
		if timer<=0:
			timer = 0.13
			var nearest: Node3D
			var max_distance := 5.5 if pulses==0 else 3.4
			var best_score := INF
			for target in get_tree().get_nodes_in_group("enemy"):
				if not target.alive or target==chain_last or int(hits.get(target.get_instance_id(),0))>=2:
					continue
				var point: Vector3 = target.global_position+Vector3.UP*0.8
				var distance := point.distance_to(chain_origin)
				var score := distance+float(hits.get(target.get_instance_id(),0))*5.0
				if distance<max_distance and score<best_score and clear_path(chain_origin,point):
					best_score = score
					nearest = target
			if nearest==null or pulses>=6:
				queue_free()
				return
			var point: Vector3 = nearest.global_position+Vector3.UP*0.8
			var arc := BladeFX.new()
			arc.arena = arena
			arc.kind = "arc"
			arc.color = Color("ffe778")
			arc.life = 0.18
			arc.position = chain_origin
			arc.end_point = point-chain_origin
			arena.add_child(arc)
			deal(nearest,direction)
			chain_origin = point
			chain_last = nearest
			pulses += 1
		return
	var previous := global_position
	var next := previous+direction*speed*delta
	var right := Vector3(-direction.z,0,direction.x)
	for offset in [Vector3.ZERO,right*radius*0.65,-right*radius*0.65]:
		if not clear_path(previous+Vector3.UP*0.6+offset,next+Vector3.UP*0.6+offset):
			queue_free()
			return
	if kind=="fire_wave":
		var ray := PhysicsRayQueryParameters3D.create(next+Vector3.UP*0.9,next+Vector3.DOWN*1.3,1)
		var floor_ := get_world_3d().direct_space_state.intersect_ray(ray)
		if floor_.is_empty():
			queue_free()
			return
		next.y = floor_.position.y+0.035
	global_position = next
	travel += speed*delta
	for target in get_tree().get_nodes_in_group("enemy"):
		if not target.alive or hits.has(target.get_instance_id()) or absf(target.global_position.y-next.y)>1.5:
			continue
		if segment_distance(target.global_position,previous,next)<radius+target_radius(target) and clear_path(previous+Vector3.UP*0.6,target.global_position+Vector3.UP*0.6):
			deal(target,direction,kind in ["fire_wave","fire_ball"])
	if travel>=reach or age>2.5:
		queue_free()
