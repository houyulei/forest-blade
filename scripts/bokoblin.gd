class_name Bokoblin
extends CharacterBody3D
## Base red, wooden-club variant. Attacks lock facing and resolve once per swing.
const WALK := preload("res://assets/bokoblin/walk.png")
const COMBAT := preload("res://assets/bokoblin/combat.png")
const DAMAGE := preload("res://assets/bokoblin/damage.png")
const WINDUP := 0.68
const ACTIVE := 0.18
const RECOVERY := 0.90
const REACH := 1.85
const HALF_ARC := 0.70
var hp := 40
var max_hp := 40
var alive := true
var tier := "base"
var arena: Node3D
var hero: Hero
var state := "idle"
var timer := 0.0
var clock := 0.0
var facing := Vector3.FORWARD
var attack_direction := Vector3.FORWARD
var attack_has_hit := false
var attack_count := 0
var walk_phase := 0.0
var state_elapsed := 0.0
var home := Vector3.ZERO
var wander_target := Vector3.ZERO
var idle_timer := 0.0
var wander_step := 0
var knock := Vector3.ZERO
var hit_flash := 0.0
var death_time := 0.0
var sprite: Sprite3D
var warning: MeshInstance3D
var health: Sprite3D
var hp_fill: Sprite3D
var alert: Label3D
var shadow: MeshInstance3D
var direction_row := 0
var current_column := 0
var current_atlas: Texture2D
var animation_name := "idle"

func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 4
	collision_mask = 1
	home = global_position
	wander_target = home
	idle_timer = 0.7
	var collider := CollisionShape3D.new()
	ActorSizes.configure_capsule(collider,"bokoblin")
	add_child(collider)
	sprite = Sprite3D.new()
	sprite.name = "RedBokoblin"
	sprite.texture = COMBAT
	sprite.hframes = 6
	sprite.vframes = 3
	sprite.pixel_size = ActorSizes.pixel_size("bokoblin")
	sprite.offset = Vector2(0,120)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.15
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite)
	current_atlas = COMBAT
	var footprint := ActorSizes.shadow_size("bokoblin")
	shadow = Craft.cylinder(self,Vector3(0,0.02,0),footprint.x*0.5,footprint.x*0.5,0.005,Craft.material(Color(0.06,0.10,0.09,0.25)),32)
	shadow.scale.z = footprint.y/footprint.x
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	warning = MeshInstance3D.new()
	warning.name = "ClubAttackSector"
	warning.position.y = 0.04
	var mesh_ := ImmediateMesh.new()
	mesh_.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(20):
		var a := lerpf(-HALF_ARC,HALF_ARC,i/20.0)
		var b := lerpf(-HALF_ARC,HALF_ARC,(i+1)/20.0)
		for point in [Vector3.ZERO,Vector3(sin(a),0,cos(a))*REACH,Vector3(sin(b),0,cos(b))*REACH]:
			mesh_.surface_add_vertex(point)
	mesh_.surface_end()
	warning.mesh = mesh_
	var mat := Craft.material(Color(1.0,0.48,0.18,0.40))
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	warning.material_override = mat
	warning.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	warning.visible = false
	add_child(warning)
	health = ActorSizes.make_health_bar(self,Color("283b35"),Vector2i(80,7))
	hp_fill = ActorSizes.make_health_bar(self,Color("e9956d"),Vector2i(74,3))
	hp_fill.render_priority = 1
	alert = Label3D.new()
	alert.text = "!"
	alert.font_size = 48
	alert.pixel_size = 0.008
	alert.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	alert.modulate = Color("ffdd82")
	alert.outline_modulate = Color("623b28")
	alert.visible = false
	add_child(alert)
	update_visual(0)

func change_state(next: String, duration: float = 0) -> void:
	state = next
	timer = duration
	state_elapsed = 0
	warning.visible = next == "windup"
	alert.visible = next == "alert" or next == "windup"

func has_line_of_sight() -> bool:
	var from := global_position + Vector3.UP*0.7
	var to := hero.global_position + Vector3.UP*0.7
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,1)).is_empty()

func begin_windup() -> void:
	attack_direction = facing
	attack_has_hit = false
	warning.rotation.y = atan2(attack_direction.x,attack_direction.z)
	change_state("windup",WINDUP)

func _physics_process(delta: float) -> void:
	clock += delta
	state_elapsed += delta
	timer = maxf(0,timer-delta)
	hit_flash = maxf(0,hit_flash-delta)
	if not alive:
		death_time += delta
		update_visual(delta)
		return
	var flat := hero.global_position-global_position
	flat.y = 0
	var distance := flat.length()
	var toward := flat.normalized()
	var desired := Vector3.ZERO
	knock = knock.move_toward(Vector3.ZERO,delta*14)
	if not hero.alive:
		change_state("idle")
	elif state not in ["hurt","windup","strike","recover","return"] and global_position.distance_to(home)>8.5:
		change_state("return")
	match state:
		"idle", "wander":
			idle_timer -= delta
			if hero.alive and distance<5.8 and has_line_of_sight():
				facing = toward
				change_state("alert",0.42)
			elif idle_timer<=0:
				wander_step += 1
				var angle := wander_step*2.4 + float(get_index())
				wander_target = home + Vector3(sin(angle),0,cos(angle))*1.1
				idle_timer = 2.4
				change_state("wander" if state=="idle" else "idle")
			elif state=="wander":
				var offset := wander_target-global_position
				offset.y = 0
				if offset.length()>0.2:
					desired = offset.normalized()*0.85
					facing = offset.normalized()
		"alert":
			if timer<=0:
				change_state("chase")
		"chase":
			facing = toward
			if distance>7.8 or global_position.distance_to(home)>8.5:
				change_state("return")
			elif distance>1.42:
				desired = toward*2.35
			elif absf(hero.global_position.y-global_position.y)<1.0 and arena.can_enemy_attack(self):
				begin_windup()
		"windup":
			# Direction is fixed throughout anticipation; sidestepping can evade the club.
			facing = attack_direction
			if timer<=0:
				attack_count += 1
				change_state("strike",ACTIVE)
				arena.play_tone(145,0.09,0.07)
				arena.burst(global_position+attack_direction*1.0+Vector3.UP*0.1,Color("d5b57b"),4)
		"strike":
			resolve_attack()
			if timer<=0:
				change_state("recover",RECOVERY)
		"recover", "hurt":
			if timer<=0:
				change_state("chase" if distance<6.5 else "return")
		"return":
			var offset := home-global_position
			offset.y = 0
			if offset.length()>0.25:
				desired = offset.normalized()*1.8
				facing = offset.normalized()
			else:
				idle_timer = 1.0
				change_state("idle")
	# Soft separation prevents two sprites occupying exactly the same point.
	if desired.length()>0:
		for other in get_tree().get_nodes_in_group("enemy"):
			if other==self or not other.alive:
				continue
			var away: Vector3 = global_position-other.global_position
			away.y = 0
			if away.length()>0.01 and away.length()<0.85:
				desired += away.normalized()*(0.85-away.length())*2.5
	velocity.x = move_toward(velocity.x,desired.x+knock.x,delta*18)
	velocity.z = move_toward(velocity.z,desired.z+knock.z,delta*18)
	if not is_on_floor():
		velocity.y -= delta*20
	else:
		velocity.y = 0
	var previous := global_position
	move_and_slide()
	var traveled := Vector2(global_position.x-previous.x,global_position.z-previous.z).length()
	walk_phase = fposmod(walk_phase+traveled/ActorSizes.stride_distance("bokoblin"),1.0)
	if global_position.y < -5:
		take_hit(hp,Vector3.ZERO)
	update_visual(delta)

func resolve_attack() -> void:
	if state!="strike" or attack_has_hit or not alive or not hero.alive:
		return
	var offset := hero.global_position-global_position
	var flat := Vector3(offset.x,0,offset.z)
	if flat.length()<=REACH and absf(offset.y)<0.9 and attack_direction.dot(flat.normalized())>=cos(HALF_ARC) and has_line_of_sight():
		attack_has_hit = true
		hero.take_hit(1,attack_direction)

func update_visual(_delta: float) -> void:
	var camera: Camera3D = arena.camera
	var screen_x := facing.dot(camera.global_basis.x)
	var away := -camera.global_basis.z
	away.y = 0
	var screen_y := facing.dot(away.normalized())
	direction_row = 1 if absf(screen_x)>absf(screen_y) else (0 if screen_y<0 else 2)
	sprite.pixel_size = ActorSizes.pixel_size("bokoblin",direction_row)
	var atlas: Texture2D = COMBAT
	current_column = 0
	animation_name = "idle"
	match state:
		"wander","chase","return":
			if Vector2(velocity.x,velocity.z).length()>0.15:
				atlas = WALK
				current_column = int(walk_phase*6)%6
				animation_name = "walk"
		"alert":
			current_column = 1
			animation_name = "alert"
		"windup":
			current_column = 1 if timer>WINDUP*0.58 else 2
			animation_name = "windup"
		"strike":
			current_column = 3
			animation_name = "strike"
		"recover":
			current_column = 4 if timer>RECOVERY*0.6 else 5
			animation_name = "recover"
		"hurt":
			atlas = DAMAGE
			animation_name = "hurt"
		"dead":
			atlas = DAMAGE
			current_column = 1 if death_time<0.22 else 2
			animation_name = "dead"
	if current_atlas!=atlas:
		sprite.frame = 0
		sprite.hframes = 1
		sprite.texture = atlas
		sprite.hframes = 3 if atlas==DAMAGE else 6
		current_atlas = atlas
	sprite.frame_coords = Vector2i(current_column,direction_row)
	sprite.flip_h = direction_row==1 and screen_x>0
	sprite.modulate = Color(1.6,1.35,1.15,1) if hit_flash>0 else Color.WHITE
	if not alive:
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		sprite.modulate.a = 1.0-clampf((death_time-0.7)/0.8,0,1)
		var footprint := ActorSizes.shadow_size("bokoblin")
		shadow.scale = Vector3(1,1,footprint.y/footprint.x)*sprite.modulate.a
	var health_visible := alive and (hp<max_hp or state not in ["idle","wander","return"])
	health.visible = health_visible
	hp_fill.visible = health_visible
	hp_fill.scale.x = float(hp)/max_hp
	# Keep the left edge of the billboard health bar fixed as health decreases.
	health.position = ActorSizes.health_position("bokoblin",camera)
	hp_fill.position = health.position-camera.global_basis.x*(1.0-float(hp)/max_hp)*0.296
	alert.position = ActorSizes.alert_position("bokoblin",camera)

func take_hit(amount: int, direction: Vector3, heavy: bool = false) -> void:
	if not alive:
		return
	hp = maxi(0,hp-amount)
	knock = direction*(4.8 if heavy else 2.6)
	hit_flash = 0.10
	arena.burst(global_position+Vector3.UP*0.8,Color("ffcd83"),7)
	arena.damage_number(global_position+Vector3.UP*1.4,amount)
	arena.play_tone(280,0.07,0.06)
	arena.shake = 0.07 if heavy else 0.035
	if hp<=0:
		alive = false
		change_state("dead")
		for child in get_children():
			if child is CollisionShape3D:
				child.set_deferred("disabled",true)
		arena.enemy_defeated(self)
	else:
		change_state("hurt",0.48 if heavy else 0.28)
