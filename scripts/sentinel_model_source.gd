extends CharacterBody3D

var hp: int = 9
var max_hp: int = 9
var alive: bool = true
var arena: Node3D
var hero: Hero
var visual: Node3D
var core: MeshInstance3D
var warning: MeshInstance3D
var hp_fill: MeshInstance3D
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
	var s := CapsuleShape3D.new()
	s.radius = 0.46
	s.height = 1.4
	c.position.y = 0.7
	c.shape = s
	add_child(c)
	visual = Node3D.new()
	add_child(visual)
	var stone := Craft.material(Color("6b8280"))
	var edge := Craft.material(Color("8ea49a"))
	Craft.ball(visual, Vector3(0, 0.70, 0), Vector3(0.97, 1.12, 0.82), stone)
	Craft.box(visual, Vector3(0, 1.27, 0.03), Vector3(0.79, 0.43, 0.63), edge)
	Craft.box(visual, Vector3(0, 1.26, 0.36), Vector3(0.58, 0.09, 0.035), Craft.material(Color("203f42")))
	for side in [-1.0, 1.0]:
		Craft.box(visual, Vector3(side * 0.16, 1.27, 0.39), Vector3(0.11, 0.055, 0.025), Craft.material(Color("f5c86e"), 0.4, 2))
		Craft.ball(visual, Vector3(side * 0.62, 0.76, 0), Vector3(0.44, 0.75, 0.46), stone)
		Craft.ball(visual, Vector3(side * 0.29, 0.19, 0.06), Vector3(0.45, 0.38, 0.55), edge)
		Craft.cylinder(visual, Vector3(side * 0.29, 1.59, 0), 0.13, 0, 0.37, Craft.material(Color("4b766b")), 5)
	core = Craft.ball(visual, Vector3(0, 0.82, 0.42), Vector3(0.25, 0.31, 0.12), Craft.material(Color("f5c86e"), 0.3, 1.3))
	warning = Craft.ring(arena, Vector3(position.x, 0.04, position.z), 1.7, 0.07, Craft.material(Color(1, 0.38, 0.20, 0.7), 0.4, 0.8))
	warning.visible = false
	Craft.box(self, Vector3(0, 1.97, 0), Vector3(1.02, 0.06, 0.07), Craft.material(Color("263e41")))
	hp_fill = Craft.box(self, Vector3(0, 1.98, 0.015), Vector3(0.96, 0.045, 0.07), Craft.material(Color("f0bc72"), 0.5, 0.4))

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
				else:
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
	hp_fill.scale.x = float(hp) / max_hp

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
		hp_fill.get_parent().get_child(hp_fill.get_index() - 1).visible = false
		hp_fill.visible = false
		disable_collider()
		arena.burst(global_position + Vector3.UP * 0.7, Color("a2e1ca"), 24)
		arena.victory()

func disable_collider() -> void:
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)
