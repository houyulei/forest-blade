class_name HeroSprite
extends Node3D
## A camera-facing painted sprite; collision and elevation still belong to CharacterBody3D.
const RUN := preload("res://assets/hero/run.png")
const RUN_SIDE := preload("res://assets/hero/run-side.png")
const ATTACK := preload("res://assets/hero/attack.png")
const POSES := preload("res://assets/hero/poses.png")
const PIXEL_SIZE := 0.009
var sprite: Sprite3D
var shadow: MeshInstance3D
var time: float = 0
var direction_row: int = 0
var action_name: String = "idle"
var current_column: int = 0
var death_time: float = 0
var current_atlas: Texture2D
var run_phase: float = 0.0
var last_position := Vector3.ZERO
var has_last_position := false
var state_time: float = 0.0

func _ready() -> void:
	sprite = Sprite3D.new()
	sprite.name = "PaintedHero"
	sprite.texture = POSES
	sprite.hframes = 6
	sprite.vframes = 4
	sprite.pixel_size = PIXEL_SIZE
	sprite.offset = Vector2(0, 120)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.12
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite)
	current_atlas = POSES
	shadow = MeshInstance3D.new()
	shadow.name = "GroundContactShadow"
	shadow.top_level = true
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.85, 0.55)
	shadow.mesh = plane
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded, depth_draw_never, cull_disabled; void fragment(){ float r=length((UV-vec2(0.5))*2.0); ALBEDO=vec3(0.08,0.12,0.11); ALPHA=(1.0-smoothstep(0.3,1.0,r))*0.30; }"
	material.shader = shader
	shadow.material_override = material
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)

func update_state(actor: CharacterBody3D, delta: float) -> void:
	time += delta
	state_time += delta
	var travel := 0.0
	if has_last_position:
		travel = Vector2(actor.global_position.x-last_position.x, actor.global_position.z-last_position.z).length()
	last_position = actor.global_position
	has_last_position = true
	# Advance from real travel, including acceleration/dash, never from the global clock.
	# Teleports and standing against a wall must not advance the gait.
	if actor.is_on_floor() and actor.attack_time <= 0 and travel < maxf(0.5, delta * 25):
		run_phase = fposmod(run_phase + travel / 2.15, 1.0)
	var previous_action := action_name
	var camera: Camera3D = actor.arena.camera
	var right := camera.global_basis.x
	var up := -camera.global_basis.z
	up.y = 0
	up = up.normalized()
	var horizontal: float = actor.facing.dot(right)
	var vertical: float = actor.facing.dot(up)
	# Match screen-relative movement: row 0 front/down, 1 left, 2 right, 3 back/up.
	var was_side := direction_row == 1 or direction_row == 2
	var side_bias := 0.08 if was_side else -0.08
	if absf(horizontal) + side_bias > absf(vertical):
		direction_row = 2 if horizontal > 0 else 1
	else:
		direction_row = 0 if vertical < 0 else 3
	var atlas: Texture2D = POSES
	current_column = int(state_time * 2) % 2
	action_name = "idle"
	if not actor.alive:
		death_time += delta
		current_column = 5
		sprite.scale = Vector3(1, maxf(0.2, 1 - death_time * 2), 1)
		sprite.modulate = Color(0.65,0.65,0.7,1)
		action_name = "defeat"
	elif actor.attack_time > 0:
		atlas = ATTACK
		var progress: float = 1.0 - actor.attack_time / actor.attack_duration
		current_column = clampi(int(progress * 6), 0, 5)
		# Alternate a returning slash; the third swing keeps its circular 3D effect.
		if actor.combo == 2:
			current_column = 5 - current_column
		action_name = "attack"
	elif not actor.is_on_floor():
		current_column = 3 if actor.velocity.y > 0 else 4
		action_name = "jump"
	elif travel > 0.0001 and Vector2(actor.velocity.x, actor.velocity.z).length() > 0.3:
		atlas = RUN
		current_column = int(run_phase * 6) % 6
		if direction_row == 1 or direction_row == 2:
			atlas = RUN_SIDE
			current_column = int(run_phase * 16) % 16
		action_name = "run"
	if action_name != previous_action:
		state_time = 0
	if current_atlas != atlas:
		sprite.frame = 0
		sprite.hframes = 1
		sprite.vframes = 1
		sprite.texture = atlas
		sprite.hframes = 16 if atlas == RUN_SIDE else 6
		sprite.vframes = 1 if atlas == RUN_SIDE else 4
		current_atlas = atlas
	sprite.flip_h = atlas == RUN_SIDE and direction_row == 2
	sprite.frame_coords = Vector2i(current_column, 0 if atlas == RUN_SIDE else direction_row)
	# Billboards are rooted at their feet. Never rotate their parent toward movement.
	rotation = Vector3.ZERO
	position = Vector3.ZERO
	if actor.alive:
		sprite.scale = Vector3.ONE
		sprite.modulate = Color.WHITE
	var query := PhysicsRayQueryParameters3D.create(actor.global_position + Vector3.UP * 0.15, actor.global_position + Vector3.DOWN * 6, 1)
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		shadow.global_position = hit.position + Vector3.UP * 0.018
		var altitude: float = maxf(0, actor.global_position.y - hit.position.y)
		shadow.scale = Vector3.ONE * clampf(1.0 - altitude * 0.18, 0.5, 1.0)
		shadow.visible = true
	else:
		shadow.visible = false
	# Shadow remains visible while damage invulnerability flashes the character.
	sprite.visible = actor.invulnerable <= 0 or sin(actor.clock * 45) > -0.35
