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
var attack_buffer_time := 0.0
var hurt_time := 0.0
var hurt_flash := 0.0
var landing_time := 0.0
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
var mp := 100.0
var max_mp := 100.0
var hit_pause := 0.0
var stride_phase: float = 0
var blades: BladeCombat
var attack_weapon := "wind"
var attack_damage := 10

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var collider := CollisionShape3D.new()
	ActorSizes.configure_capsule(collider,"hero")
	add_child(collider)
	sprite_view = HeroSprite.new()
	add_child(sprite_view)
	blades = BladeCombat.new()
	blades.hero = self
	blades.arena = arena
	add_child(blades)
	visual = {"root": sprite_view}
	slash = MeshInstance3D.new()
	slash.material_override = Craft.material(Color(0.65, 1.0, 0.91, 0.65), 0.3, 1.5)
	(slash.material_override as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	slash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(slash)

func _physics_process(delta: float) -> void:
	if hit_pause>0:
		hit_pause = maxf(0,hit_pause-delta)
		return
	clock += delta
	attack_buffer_time = maxf(0,attack_buffer_time-delta)
	if attack_buffer_time<=0:
		buffered_attack = false
	hurt_time = maxf(0,hurt_time-delta)
	hurt_flash = maxf(0,hurt_flash-delta)
	landing_time = maxf(0,landing_time-delta)

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
	blades.tick(delta,direction)
	for index in range(3):
		if Input.is_action_just_pressed("sword_%d" % (index+1)):
			blades.switch_sword(SwordArsenal.ORDER[index])
	if moving and attack_time <= 0 and dash_time <= 0 and not blades.busy() and hurt_time<=0:
		facing = direction.normalized()
	if Input.is_action_just_pressed("fire_skill"):
		blades.cast_magic()
	if Input.is_action_just_pressed("sword_skill"):
		blades.begin_skill()
	if Input.is_action_just_pressed("attack") and hurt_time<=0 and dash_time<=0:
		if blades.attack_input():
			pass
		elif attack_time>0:
			buffered_attack = true
			attack_buffer_time = 0.22
		else:
			begin_attack()
	if Input.is_action_just_pressed("jump") and is_on_floor() and not blades.busy() and hurt_time<=0 and (attack_time<=0 or can_cancel_attack()):
		cancel_attack()
		velocity.y = 7.2
		did_jump = true
		arena.burst(global_position + Vector3.UP * 0.06, Color("d5dbc1"), 7)
	if Input.is_action_just_pressed("dash"):
		begin_dash(direction if moving else Vector3.ZERO)
	var move_speed := speed
	var lean := 0.0
	var attack_step := 0.0
	if hurt_time>0:
		move_speed = 0
	elif blades.busy():
		move_speed = 0
		slash.visible = false
	elif attack_time > 0:
		move_speed = 0
		attack_time -= delta
		var progress := clampf(1.0 - attack_time / attack_duration, 0, 1)
		pose_attack(progress)
		lean = sin(progress * PI) * 0.14
		attack_step = SwordMotion.step_speed(combo,progress,attack_weapon) if is_on_floor() else 0.0
		if SwordMotion.active(combo,progress,attack_weapon):
			for target in get_tree().get_nodes_in_group("enemy"):
				if not target.alive or hit_targets.has(target.get_instance_id()):
					continue
				var offset: Vector3 = target.global_position - global_position
				var flat := Vector3(offset.x, 0, offset.z)
				# Grounded slashes hit in front and respect scenery.
				if absf(offset.y)<1.3 and SwordMotion.in_range(combo,attack_weapon,flat,facing):
					var ray := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*0.75,target.global_position+Vector3.UP*0.75,1)
					if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
						continue
					var first_contact := hit_targets.is_empty()
					hit_targets.append(target.get_instance_id())
					target.take_hit(attack_damage, facing, combo == 3)
					blades.on_sword_hit(first_contact)
					var motion := SwordMotion.profile(combo,attack_weapon)
					if first_contact:
						hit_pause = float(motion.pause)
					arena.shake = maxf(arena.shake,float(motion.shake))
					did_hit = true
		if attack_time <= 0:
			slash.visible = false
			combo_window = 0.48
			blades.on_combo_finished(combo)
			if buffered_attack:
				buffered_attack = false
				attack_buffer_time = 0
				if attack_weapon=="fire" or not blades.attack_input():
					begin_attack()
	else:
		slash.visible = false

	if dash_time > 0:
		dash_time -= delta
		velocity.x = facing.x * 11
		velocity.z = facing.z * 11
	elif blades.busy():
		var skill_motion := blades.motion_velocity()
		velocity.x = skill_motion.x
		velocity.z = skill_motion.z
	elif attack_time>0:
		velocity.x = facing.x*attack_step
		velocity.z = facing.z*attack_step
	else:
		velocity.x = move_toward(velocity.x, direction.x * move_speed, delta * 35)
		velocity.z = move_toward(velocity.z, direction.z * move_speed, delta * 35)
	if not is_on_floor():
		velocity.y -= 20 * delta
		was_airborne = true
	elif was_airborne:
		was_airborne = false
		did_land = true
		landing_time = 0.09
		arena.burst(global_position + Vector3.UP * 0.04, Color("d5dbc1"), 5)
	move_and_slide()
	if position.y < -5:
		take_hit(5, Vector3.ZERO)
	animate_locomotion(delta, lean)


func animate_locomotion(delta: float, _lean: float) -> void:
	sprite_view.update_state(self, delta)

func can_cancel_attack() -> bool:
	return attack_time>0 and 1.0-attack_time/attack_duration>=float(SwordMotion.profile(combo,attack_weapon).cancel)

func cancel_attack() -> void:
	attack_time = 0
	combo_window = 0
	buffered_attack = false
	attack_buffer_time = 0
	slash.visible = false

func pose_attack(progress: float) -> void:
	var motion := SwordMotion.profile(combo,attack_weapon)
	var active: Vector2 = motion.active
	var swing := smoothstep(active.x-0.02,active.y+0.03,progress)
	if attack_weapon=="thunder":
		var mesh := ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		var tip := lerpf(float(motion.reach)*0.75,float(motion.reach),swing)
		var width := 0.035 if combo<3 else 0.055
		for point in [Vector3(-width,0,0.65),Vector3(width,0,0.65),Vector3(0.012,0,tip),Vector3(-width,0,0.65),Vector3(0.012,0,tip),Vector3(-0.012,0,tip)]:
			mesh.surface_add_vertex(point)
		mesh.surface_end()
		slash.mesh = mesh
		slash.position.y = [0.95,0.70,1.05][combo-1]
		slash.rotation.y = atan2(facing.x,facing.z)
	elif (combo==3 and attack_weapon=="wind") or (attack_weapon=="fire" and combo!=2):
		update_slash(progress,lerpf(0.15,2.85,swing),lerpf(0.05,1.8,swing),true)
	else:
		var sign_ := -1.0 if combo==2 else 1.0
		var lead := lerpf(-1.4,1.45,swing)
		update_slash(progress,lead*sign_,maxf(-1.4,lead-0.85)*sign_)
	if attack_weapon=="fire":
		slash.position.y = 0.9 if combo==2 else 1.2
	slash.visible = progress>=active.x and progress<=active.y+0.08

func begin_attack() -> void:
	if not alive or blades.busy() or hurt_time>0 or dash_time>0:
		return
	attack_weapon = arena.progress.equipped_sword
	var tint: Color = SwordArsenal.data(attack_weapon).color
	(slash.material_override as StandardMaterial3D).albedo_color = Color(tint,0.30)
	(slash.material_override as StandardMaterial3D).emission = tint*0.3
	combo = combo % 3 + 1 if combo_window > 0 else 1
	attack_duration = SwordMotion.profile(combo,attack_weapon).duration
	attack_damage = arena.progress.sword_damage()+int(SwordMotion.profile(combo,attack_weapon).bonus)
	attack_time = attack_duration
	hit_targets.clear()
	var pitch := (180.0+combo*35 if attack_weapon=="fire" else (820.0+combo*85 if attack_weapon=="thunder" else 530.0+combo*90))
	arena.play_tone(pitch,0.075 if attack_weapon=="thunder" else 0.10,0.06)
	# Select the nearest eligible enemy without changing the aim cone mid-search.
	var nearest_distance := 2.7
	var nearest_direction := Vector3.ZERO
	for target in get_tree().get_nodes_in_group("enemy"):
		var offset: Vector3 = target.global_position - global_position
		offset.y = 0
		if target.alive and offset.length() < nearest_distance and facing.dot(offset.normalized()) > 0.75:
			nearest_distance = offset.length()
			nearest_direction = offset.normalized()
	if nearest_direction != Vector3.ZERO:
		facing = facing.slerp(nearest_direction,0.35).normalized()

func begin_dash(direction: Vector3 = Vector3.ZERO) -> bool:
	if not alive or dash_cooldown>0 or blades.busy() or hurt_time>0 or (attack_time>0 and not can_cancel_attack()):
		return false
	cancel_attack()
	if direction.length()>0.1:
		facing = direction.normalized()
	dash_time = 0.18
	dash_cooldown = 0.85
	invulnerable = maxf(invulnerable,0.22)
	arena.burst(global_position+Vector3.UP*0.2,Color("97ded1"),6)
	return true

func begin_fire() -> bool:
	# Compatibility entry point; the old stationary explosion has been retired.
	return blades.begin_charge() if arena.progress.equipped_sword=="fire" else false

func release_fire() -> void:
	blades.release_charge()

func update_slash(progress: float, lead: float, trail: float, vertical: bool = false) -> void:
	slash.visible = progress > 0.12 and progress < 0.92
	var mesh_data := ImmediateMesh.new()
	mesh_data.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(16):
		var radius := float(SwordMotion.profile(combo,attack_weapon).reach) if attack_weapon=="fire" else 1.55
		var inner := radius*(0.78 if attack_weapon=="fire" else 1.28/1.55)
		var a := lerpf(trail, lead, float(i) / 16)
		var b := lerpf(trail, lead, float(i + 1) / 16)
		var points := [Vector3(sin(a) * inner, 0, cos(a) * inner), Vector3(sin(a) * radius, 0, cos(a) * radius), Vector3(sin(b) * radius, 0, cos(b) * radius), Vector3(sin(b) * inner, 0, cos(b) * inner)]
		if vertical:
			points = [Vector3(0,cos(a)*0.82,sin(a)*0.82),Vector3(0,cos(a)*1.16,sin(a)*1.16),Vector3(0,cos(b)*1.16,sin(b)*1.16),Vector3(0,cos(b)*0.82,sin(b)*0.82)]
			if attack_weapon=="fire":
				var tilt := 0.38 if combo==1 else 0.0
				points = [Vector3(cos(a)*tilt,cos(a)*0.85,sin(a)*radius*0.78),Vector3(cos(a)*tilt,cos(a)*1.10,sin(a)*radius),Vector3(cos(b)*tilt,cos(b)*1.10,sin(b)*radius),Vector3(cos(b)*tilt,cos(b)*0.85,sin(b)*radius*0.78)]
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
	if arena.has_method("incoming_damage"):
		amount = arena.incoming_damage(amount,"physical")
	cancel_attack()
	blades.interrupt()
	hurt_time = 0.16
	hurt_flash = 1.05
	slash.visible = false
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
