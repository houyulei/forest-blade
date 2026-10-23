class_name Sentinel
extends CharacterBody3D

var hp: int = 90
var max_hp: int = 90
var alive: bool = true
var arena: Node3D
var hero: Hero
var visual: Node3D
var core: MeshInstance3D
var warning: MeshInstance3D
var hp_fill: Sprite3D
var health: Sprite3D
var sprite: Sprite3D
const SPRITES := preload("res://assets/sentinel/sentinel.png")
var clock: float = 0
var state: String = "idle"
var timer: float = 0
var stun: float = 0
var knock := Vector3.ZERO
var attack_direction := Vector3.FORWARD
var attack_count: int = 0

func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 4
	collision_mask = 1
	var c := CollisionShape3D.new()
	ActorSizes.configure_capsule(c,"sentinel")
	add_child(c)
	visual = Node3D.new()
	add_child(visual)
	sprite = Sprite3D.new()
	sprite.name = "PaintedSentinel"
	sprite.texture = SPRITES
	sprite.hframes = 4
	sprite.vframes = 4
	sprite.pixel_size = ActorSizes.pixel_size("sentinel")
	sprite.offset = Vector2(0,112)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.12
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(sprite)
	var footprint := ActorSizes.shadow_size("sentinel")
	var contact := Craft.cylinder(self,Vector3(0,0.015,0),footprint.x*0.5,footprint.x*0.5,0.006,Craft.material(Color(0.06,0.10,0.09,0.22)),32)
	contact.scale.z = footprint.y/footprint.x
	contact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	warning = Craft.ring(arena, Vector3(position.x, 0.04, position.z), 1.7, 0.07, Craft.material(Color(1, 0.38, 0.20, 0.7), 0.4, 0.8))
	warning.visible = false
	health = ActorSizes.make_health_bar(self,Color("263e41"),Vector2i(120,7))
	hp_fill = ActorSizes.make_health_bar(self,Color("f0bc72"),Vector2i(114,3))
	hp_fill.render_priority = 1
	update_health_position()

func update_health_position() -> void:
	health.position = ActorSizes.health_position("sentinel",arena.camera)
	hp_fill.position = health.position-arena.camera.global_basis.x*(1.0-float(hp)/max_hp)*0.456

func _physics_process(delta: float) -> void:
	clock += delta
	if not alive:
		visual.scale = visual.scale.lerp(Vector3.ZERO, delta * 5)
		return
	timer -= delta
	stun = maxf(0, stun - delta)
	knock = knock.move_toward(Vector3.ZERO, delta * 15)
	var offset := hero.global_position - global_position
	offset.y = 0
	var distance := offset.length()
	var direction := offset.normalized()
	velocity.x = knock.x
	velocity.z = knock.z
	if not is_on_floor():
		velocity.y -= delta * 20
	if not hero.alive:
		state = "idle"
		warning.visible = false
	elif stun <= 0:
		match state:
			"idle", "chase":
				state = "chase"
				if distance > 1.65:
					velocity.x += direction.x * 1.65
					velocity.z += direction.z * 1.65
				elif arena.can_enemy_attack(self):
					state = "windup"
					timer = 0.85
					attack_direction = direction
					warning.position = Vector3(position.x, 0.055, position.z)
					warning.visible = true
				visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), delta * 7)
			"windup":
				warning.scale = Vector3.ONE * (1 + sin(clock * 24) * 0.04)
				visual.scale.y = 0.90 + sin(clock * 30) * 0.02
				if timer <= 0:
					state = "recover"
					timer = 1.15
					attack_count += 1
					warning.visible = false
					arena.burst(global_position + Vector3.UP * 0.10, Color("f1b16c"), 15)
					arena.shockwave(global_position)
					arena.play_tone(90, 0.15, 0.10)
					if distance < 1.95 and hero.global_position.y - position.y < 0.65:
						hero.take_hit(1, direction)
			"recover":
				visual.scale.y = lerpf(visual.scale.y, 1.0, delta * 8)
				if timer <= 0:
					state = "chase"
	visual.position.y = sin(clock * 4) * 0.035
	move_and_slide()
	update_visual(direction)

func update_visual(direction: Vector3) -> void:
	update_health_position()
	hp_fill.scale.x = float(hp) / max_hp
	var camera: Camera3D = arena.camera
	var screen_x := direction.dot(camera.global_basis.x)
	var camera_away := -camera.global_basis.z
	camera_away.y = 0
	var screen_y := direction.dot(camera_away.normalized())
	var row := (2 if screen_x > 0 else 1) if absf(screen_x) > absf(screen_y) else (0 if screen_y < 0 else 3)
	var column := int(clock * 5) % 2
	if state == "windup":
		column = 1
	elif state == "recover":
		column = 2 if timer > 0.95 else 3
	sprite.pixel_size = ActorSizes.pixel_size("sentinel",row)
	sprite.frame_coords = Vector2i(column,row)
	visual.rotation.y = 0

func take_hit(amount: int, direction: Vector3, heavy: bool = false) -> void:
	if not alive:
		return
	hp = maxi(0, hp - amount)
	knock = direction * (5 if heavy else 2.4)
	if heavy:
		stun = 0.5
		state = "recover"
		timer = 0.8
		warning.visible = false
	arena.burst(global_position + Vector3.UP * 0.9, Color("ffdf9a"), 12)
	arena.damage_number(global_position + Vector3.UP * 1.6, amount)
	arena.shake = 0.10 if heavy else 0.05
	arena.play_tone(260 if heavy else 350, 0.08, 0.08)
	visual.scale = Vector3(1.10, 0.88, 1.10)
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector3.ONE, 0.14)
	if hp <= 0:
		alive = false
		warning.visible = false
		health.visible = false
		hp_fill.visible = false
		disable_collider()
		arena.burst(global_position + Vector3.UP * 0.7, Color("a2e1ca"), 24)
		arena.enemy_defeated(self)

func disable_collider() -> void:
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)
