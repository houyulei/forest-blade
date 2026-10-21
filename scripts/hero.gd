class_name Hero
extends CharacterBody3D

var hp: int = 5
var max_hp: int = 5
var speed: float = 4.8
var facing := Vector3(0, 0, 1)
var visual: Dictionary
var sprite_view: HeroSprite
var clock: float = 0
var attack_time: float = 0
var attack_duration: float = 0.42
var combo: int = 0
var combo_window: float = 0
var buffered_attack: bool = false
var dash_time: float = 0
var dash_cooldown: float = 0
var invulnerable: float = 0
var hit_targets: Array[int] = []
var arena: Node3D
var slash: MeshInstance3D
var alive: bool = true
var did_jump: bool = false
var did_hit: bool = false
var did_land: bool = false
var was_airborne: bool = false
var run_blend: float = 0
var air_blend: float = 0
var stride_phase: float = 0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.23
	capsule.height = 1.28
	collider.shape = capsule
	collider.position.y = 0.68
	add_child(collider)
	sprite_view = HeroSprite.new()
	add_child(sprite_view)
	visual = {"root": sprite_view}
	slash = MeshInstance3D.new()
	slash.material_override = Craft.material(Color(0.65, 1.0, 0.91, 0.65), 0.3, 1.5)
	(slash.material_override as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	slash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(slash)

func _physics_process(delta: float) -> void:
	clock += delta
	invulnerable = maxf(0, invulnerable - delta)
	dash_cooldown = maxf(0, dash_cooldown - delta)
	combo_window = maxf(0, combo_window - delta)
	if not alive:
		velocity.x = move_toward(velocity.x, 0, delta * 20)
		velocity.z = move_toward(velocity.z, 0, delta * 20)
		velocity.y -= 20 * delta
		move_and_slide()
		sprite_view.update_state(self, delta)
		return
	var axis := Input.get_vector("left", "right", "up", "down")
	var camera_right: Vector3 = arena.camera.global_basis.x
	var camera_away: Vector3 = -arena.camera.global_basis.z
	camera_right.y = 0
	camera_away.y = 0
	var direction := (camera_right.normalized() * axis.x - camera_away.normalized() * axis.y).normalized() * axis.length()
	var moving := direction.length() > 0.1
	if moving and attack_time <= 0 and dash_time <= 0:
		facing = direction.normalized()
	if Input.is_action_just_pressed("attack"):
		if attack_time > 0:
			buffered_attack = true
		else:
			begin_attack()
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = 7.2
		did_jump = true
		arena.burst(global_position + Vector3.UP * 0.06, Color("d5dbc1"), 7)
	if Input.is_action_just_pressed("dash") and dash_cooldown <= 0 and attack_time <= 0:
		dash_time = 0.18
		dash_cooldown = 0.85
		invulnerable = maxf(invulnerable, 0.22)
		arena.burst(global_position + Vector3.UP * 0.2, Color("97ded1"), 6)
	var move_speed := speed
	var lean := 0.0
	if attack_time > 0:
		move_speed *= 0.28 if combo < 3 else 0.45
		attack_time -= delta
		var progress := clampf(1.0 - attack_time / attack_duration, 0, 1)
		pose_attack(progress)
		lean = sin(progress * PI) * 0.14
		if progress >= 0.22 and progress <= 0.78:
			for target in get_tree().get_nodes_in_group("enemy"):
				if not target.alive or hit_targets.has(target.get_instance_id()):
					continue
				var offset: Vector3 = target.global_position - global_position
				var flat := Vector3(offset.x, 0, offset.z)
				# The spinning finisher hits all around; the first two swings hit in front.
				var in_arc := combo == 3 or flat.length() < 0.5 or facing.dot(flat.normalized()) > -0.05
				if flat.length() < (2.25 if combo == 3 else 2.05) and absf(offset.y) < 1.3 and in_arc:
					hit_targets.append(target.get_instance_id())
					target.take_hit(1, facing, combo == 3)
					did_hit = true
		if attack_time <= 0:
			slash.visible = false
			combo_window = 0.48
			if buffered_attack:
				buffered_attack = false
				begin_attack()
	else:
		slash.visible = false

	if dash_time > 0:
		dash_time -= delta
		velocity.x = facing.x * 11
		velocity.z = facing.z * 11
	else:
		velocity.x = move_toward(velocity.x, direction.x * move_speed, delta * 35)
		velocity.z = move_toward(velocity.z, direction.z * move_speed, delta * 35)
	if not is_on_floor():
		velocity.y -= 20 * delta
		was_airborne = true
	elif was_airborne:
		was_airborne = false
		did_land = true
		arena.burst(global_position + Vector3.UP * 0.04, Color("d5dbc1"), 5)
	move_and_slide()
	if position.y < -5:
		take_hit(5, Vector3.ZERO)
	animate_locomotion(delta, lean)


func animate_locomotion(delta: float, _lean: float) -> void:
	sprite_view.update_state(self, delta)

func pose_attack(progress: float) -> void:
	var swing := smoothstep(0.08, 0.72, progress)
	var lead: float
	var trail: float
	if combo == 3:
		lead = swing * TAU + 1.35
		trail = maxf(1.35, lead - 2.6)
	else:
		var direction := 1.0 if combo == 1 else -1.0
		var sweep := lerpf(-1.5, 1.6, swing)
		lead = sweep * direction
		trail = maxf(-1.5, sweep - 1.4) * direction
	update_slash(progress, lead, trail)

func begin_attack() -> void:
	if not alive:
		return
	combo = combo % 3 + 1 if combo_window > 0 else 1
	attack_duration = 0.50 if combo == 3 else 0.36
	attack_time = attack_duration
	hit_targets.clear()
	arena.play_tone(530.0 + combo * 90, 0.10, 0.06)
	# Soft aim assistance preserves movement direction unless a nearby enemy is in front.
	for target in get_tree().get_nodes_in_group("enemy"):
		var offset: Vector3 = target.global_position - global_position
		offset.y = 0
		if target.alive and offset.length() < 2.7 and facing.dot(offset.normalized()) > 0.1:
			facing = offset.normalized()
			break

func update_slash(progress: float, lead: float, trail: float) -> void:
	slash.visible = progress > 0.12 and progress < 0.92
	var mesh_data := ImmediateMesh.new()
	mesh_data.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(16):
		var a := lerpf(trail, lead, float(i) / 16)
		var b := lerpf(trail, lead, float(i + 1) / 16)
		var points := [Vector3(sin(a) * 0.6, 0, cos(a) * 0.6), Vector3(sin(a) * 1.55, 0, cos(a) * 1.55), Vector3(sin(b) * 1.55, 0, cos(b) * 1.55), Vector3(sin(b) * 0.6, 0, cos(b) * 0.6)]
		for index in [0, 1, 2, 0, 2, 3]:
			mesh_data.surface_set_normal(Vector3.UP)
			mesh_data.surface_add_vertex(points[index])
	mesh_data.surface_end()
	slash.mesh = mesh_data
	slash.position.y = 1.2
	slash.rotation.y = atan2(facing.x, facing.z)

func take_hit(amount: int, direction: Vector3) -> void:
	if invulnerable > 0 or not alive:
		return
	hp = maxi(0, hp - amount)
	invulnerable = 1.05
	velocity += direction * 4
	arena.burst(global_position + Vector3.UP, Color("f2ad8b"), 12)
	arena.shake = 0.15
	arena.play_tone(150, 0.18, 0.10)
	if hp <= 0:
		alive = false
		attack_time = 0
		slash.visible = false
