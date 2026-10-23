class_name HeroSprite
extends Node3D
## A camera-facing painted sprite; collision and elevation still belong to CharacterBody3D.
const RUN := preload("res://assets/hero/run.png")
const RUN_SIDE := preload("res://assets/hero/run-side.png")
const FIRE := preload("res://assets/hero/weapon-redesign/greatsword-cut.png")
const THRUST := preload("res://assets/hero/motion-audit-v3/spear-guard-v3.png")
const FIRE_SWEEP := preload("res://assets/hero/weapon-redesign/greatsword-sweep.png")
const FIRE_HEAVY := preload("res://assets/hero/weapon-redesign/greatsword-cleave.png")
const SPEAR_LOW := preload("res://assets/hero/motion-audit-v3/spear-low-v3.png")
const SPEAR_LUNGE := preload("res://assets/hero/motion-audit-v3/spear-lunge-v3.png")
const FIRE_RUN := preload("res://assets/hero/weapon-redesign/greatsword-run.png")
const SPEAR_RUN := preload("res://assets/hero/motion-audit-v3/spear-run-v3.png")
const SPEAR_POSES := preload("res://assets/hero/motion-audit-v3/spear-poses-v3.png")
const FIRE_POSES := preload("res://assets/hero/motion-audit-v3/greatsword-poses-v3.png")
const SPEAR_CARRY := preload("res://assets/hero/motion-audit-v3/spear-carry-upper.png")
const FIRE_CARRY := preload("res://assets/hero/motion-audit-v3/greatsword-carry-upper.png")
const LEGS_SIDE := preload("res://assets/hero/motion-audit-v3/run-legs-side.png")
const LEGS_FRONT := preload("res://assets/hero/motion-audit-v3/run-legs-front.png")
const LEGS_BACK := preload("res://assets/hero/motion-audit-v3/run-legs-back.png")
const SPIN := preload("res://assets/hero/three-swords/wind-spin.png")
const RETURN := preload("res://assets/hero/attack-return.png")
const CLEAVE := preload("res://assets/hero/attack-cleave.png")
const ATTACK := preload("res://assets/hero/attack.png")
const POSES := preload("res://assets/hero/poses.png")
var sprite: Sprite3D
var lightning_body: Sprite3D
var shadow: MeshInstance3D
var time: float = 0
var direction_row: int = 0
var direction8: int = 0
var action_name: String = "idle"
var current_column: int = 0
static func normal_atlas(weapon: String, combo: int) -> Texture2D:
	if weapon=="fire": return [FIRE,FIRE_SWEEP,FIRE_HEAVY][clampi(combo-1,0,2)]
	if weapon=="thunder": return [THRUST,SPEAR_LOW,SPEAR_LUNGE][clampi(combo-1,0,2)]
	return [ATTACK,RETURN,CLEAVE][clampi(combo-1,0,2)]

static func state_atlas(weapon: String) -> Texture2D:
	return FIRE_POSES if weapon=="fire" else (SPEAR_POSES if weapon=="thunder" else POSES)

static func display_frame(atlas: Texture2D, column: int, direction: int) -> Dictionary:
	var row := direction
	var flip := false
	var columns := 6
	if atlas==SPIN:
		columns = 4
		column = (column+[0,4,12,8][direction])%16
		row = column/4
		column %= 4
	elif atlas==RUN_SIDE:
		columns = 16
		row = 0
		flip = direction==2
	elif atlas in [FIRE,FIRE_SWEEP,FIRE_HEAVY,FIRE_POSES,THRUST,SPEAR_LOW,SPEAR_LUNGE,SPEAR_RUN,SPEAR_POSES] and direction==1:
		row = 2
		flip = true
	var cell := atlas.get_width()/columns
	return {"row":row,"column":column,"flip":flip,"cell":cell,"baseline":cell*0.875,"columns":columns}

static func run_parts(weapon: String, direction: int, phase: float) -> Array:
	var top: Texture2D = FIRE_CARRY if weapon=="fire" else SPEAR_CARRY
	var side := direction in [1,2]
	var legs: Texture2D = LEGS_SIDE if side else (LEGS_FRONT if direction==0 else LEGS_BACK)
	var column := int(fposmod(phase,1.0)*(16 if side else 6))
	var torso_direction := 2 if direction==1 else direction
	# A clean waist-up cutout keeps the grip fixed; independently animate both legs.
	return [
		{"texture":legs,"rect":Rect2i(column*320,0,320,150),"position":Vector2(-160,-110),"flip":side and direction==2,"fade":"top"},
		{"texture":top,"rect":Rect2i(torso_direction*768,0,768,768),"position":Vector2(-384,-672-float(ActorSizes.PROFILES.hero.reference_pixels[direction])*0.36+sin(phase*TAU*2)*1.5),"flip":direction==1,"fade":"none"}]

var run_visuals: Array[Sprite3D] = []
var run_regions := {}
var run_materials := {}
const RUN_LAYER_SHADER := "shader_type spatial; render_mode unshaded,cull_disabled,depth_draw_never; uniform sampler2D image_texture : source_color,filter_linear_mipmap; uniform vec4 region; uniform float fade_pixels; uniform float source_height; uniform bool fade_top; void vertex(){MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);} void fragment(){vec4 c=texture(image_texture,UV);float local_y=(UV.y-region.y)/region.w;float edge=fade_pixels/source_height;float a=fade_top?smoothstep(0.0,edge,local_y):(1.0-smoothstep(1.0-edge,1.0,local_y));ALBEDO=c.rgb;ALPHA=c.a*a;ALPHA_SCISSOR_THRESHOLD=0.04;}"

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
	sprite.pixel_size = ActorSizes.pixel_size("hero")
	sprite.offset = Vector2(0, 120)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.12
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite)
	lightning_body = Sprite3D.new()
	lightning_body.texture = POSES
	lightning_body.hframes = 6
	lightning_body.vframes = 4
	lightning_body.offset = Vector2(0,120)
	lightning_body.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lightning_body.shaded = false
	lightning_body.no_depth_test = true
	lightning_body.render_priority = 3
	lightning_body.modulate = Color(1.35,1.25,0.8,0.60)
	lightning_body.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	lightning_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lightning_body.visible = false
	add_child(lightning_body)
	for i in range(2):
		var part := Sprite3D.new()
		part.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		part.shaded = false
		part.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		part.alpha_scissor_threshold = 0.12
		part.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		part.visible = false
		add_child(part)
		run_visuals.append(part)
	current_atlas = POSES
	shadow = MeshInstance3D.new()
	shadow.name = "GroundContactShadow"
	shadow.top_level = true
	var plane := PlaneMesh.new()
	plane.size = ActorSizes.shadow_size("hero")
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
	if actor.is_on_floor() and actor.attack_time <= 0 and not actor.blades.busy() and actor.hurt_time<=0 and actor.dash_time<=0 and travel < maxf(0.5, delta * 25):
		run_phase = fposmod(run_phase + travel / ActorSizes.stride_distance("hero"), 1.0)
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
	direction8 = HeroDirections.from_world(actor.facing,camera,direction8)
	if HeroDirections.cardinal_row(direction8)>=0:
		direction_row = HeroDirections.cardinal_row(direction8)
	sprite.pixel_size = ActorSizes.pixel_size("hero",direction_row)
	var atlas: Texture2D = POSES
	current_column = int(state_time * 2) % 2
	var heavy_weapon: bool = actor.arena.progress.equipped_sword=="fire"
	var long_weapon: bool = actor.arena.progress.equipped_sword=="thunder"
	var weapon_run: Texture2D = FIRE_RUN if heavy_weapon else SPEAR_RUN
	if actor.arena.progress.equipped_sword in ["fire","thunder"]:
		atlas = FIRE if actor.arena.progress.equipped_sword=="fire" else THRUST
		current_column = 0
	action_name = "idle"
	if actor.combo_window>0 and actor.attack_weapon==actor.arena.progress.equipped_sword and (heavy_weapon or long_weapon):
		atlas = normal_atlas(actor.attack_weapon,actor.combo)
		current_column = 5
	if not actor.alive:
		atlas = state_atlas(actor.arena.progress.equipped_sword)
		death_time += delta
		current_column = 5
		sprite.scale = Vector3.ONE if heavy_weapon or long_weapon or direction8%2==1 else Vector3(1, maxf(0.2, 1 - death_time * 2), 1)
		sprite.modulate = Color(0.65,0.65,0.7,1)
		action_name = "defeat"
	elif actor.hurt_time>0:
		atlas = state_atlas(actor.arena.progress.equipped_sword)
		current_column = 1 if heavy_weapon or long_weapon else 2
		action_name = "hurt"
	elif actor.blades.busy():
		var pose: Dictionary = actor.blades.pose()
		atlas = {"spin":SPIN,"fire":FIRE,"fire_heavy":FIRE_HEAVY,"thrust":THRUST,"spear_lunge":SPEAR_LUNGE}[pose.atlas]
		current_column = pose.frame
		if atlas==SPIN:
			sprite.pixel_size = ActorSizes.pixel_size("hero",0)
		action_name = actor.blades.state
	elif actor.attack_time > 0:
		atlas = normal_atlas(actor.attack_weapon,actor.combo)
		var progress: float = 1.0 - actor.attack_time / actor.attack_duration
		current_column = SwordMotion.frame(actor.combo,progress,actor.attack_weapon)
		# Side-view final source frame has an ambiguous blade overlap; hold clean recovery.
		if actor.attack_weapon=="wind" and actor.combo==2 and current_column==5 and direction_row in [1,2] and direction8%2==0:
			current_column = 4
		action_name = "attack"
	elif actor.dash_time>0:
		atlas = weapon_run if heavy_weapon or long_weapon else POSES
		current_column = 2
		action_name = "dash"
	elif not actor.is_on_floor():
		atlas = state_atlas(actor.arena.progress.equipped_sword)
		current_column = (2 if actor.velocity.y>0 else 3) if heavy_weapon or long_weapon else (3 if actor.velocity.y > 0 else 4)
		action_name = "jump"
	elif actor.landing_time>0:
		atlas = state_atlas(actor.arena.progress.equipped_sword)
		current_column = 4 if heavy_weapon or long_weapon else 2
		action_name = "land"
	elif travel > 0.0001 and Vector2(actor.velocity.x, actor.velocity.z).length() > 0.3:
		atlas = weapon_run if heavy_weapon or long_weapon else RUN
		current_column = int(run_phase * 6) % 6
		if not (heavy_weapon or long_weapon) and (direction_row == 1 or direction_row == 2) and direction8%2==0:
			atlas = RUN_SIDE
			current_column = int(run_phase * 16) % 16
		action_name = "run"
	if action_name != previous_action:
		state_time = 0
	var display := HeroEightArt.resolve(atlas,current_column,direction8,actor.arena.progress.equipped_sword,action_name)
	var rendered_atlas: Texture2D = display.texture
	if current_atlas != rendered_atlas:
		sprite.frame = 0
		sprite.hframes = 1
		sprite.vframes = 1
		sprite.texture = rendered_atlas
		sprite.hframes = display.columns
		sprite.vframes = display.rows
		current_atlas = rendered_atlas
	sprite.pixel_size = display.pixel_size
	sprite.offset = Vector2(0,float(display.cell)*0.375)
	sprite.flip_h = display.flip
	sprite.frame_coords = Vector2i(display.column,display.row)
	# Billboards are rooted at their feet. Never rotate their parent toward movement.
	rotation = Vector3.ZERO
	position = Vector3.ZERO
	if actor.alive:
		sprite.scale = Vector3.ONE
		sprite.modulate = Color(1,0.74,0.63) if actor.hurt_time>0 else Color.WHITE
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
	sprite.visible = actor.hurt_flash <= 0 or actor.dash_time>0 or actor.blades.state=="thunder" or sin(actor.clock * 45) > -0.35

	var layered := action_name=="run" and (heavy_weapon or long_weapon) and direction8%2==0
	var primary_visible := sprite.visible
	for i in range(run_visuals.size()):
		run_visuals[i].visible = layered and primary_visible
	if layered:
		var parts := run_parts(actor.arena.progress.equipped_sword,direction_row,run_phase)
		for i in range(2):
			var part: Dictionary = parts[i]
			var key: String = part.texture.resource_path+str(part.rect)
			if not run_regions.has(key):
				var region := AtlasTexture.new()
				region.atlas = part.texture
				region.region = part.rect
				run_regions[key] = region
				var shader := Shader.new()
				shader.code = RUN_LAYER_SHADER
				var material := ShaderMaterial.new()
				material.shader = shader
				material.set_shader_parameter("image_texture",part.texture)
				var texture_size := Vector2(part.texture.get_size())
				material.set_shader_parameter("region",Vector4(part.rect.position.x/texture_size.x,part.rect.position.y/texture_size.y,part.rect.size.x/texture_size.x,part.rect.size.y/texture_size.y))
				material.set_shader_parameter("fade_pixels",16.0 if i==0 else 0.001)
				material.set_shader_parameter("source_height",float(part.rect.size.y))
				material.set_shader_parameter("fade_top",i==0)
				material.render_priority = i
				run_materials[key] = material
			var view: Sprite3D = run_visuals[i]
			view.texture = run_regions[key]
			view.material_override = run_materials[key]
			view.pixel_size = sprite.pixel_size
			view.offset = Vector2(part.position.x+part.rect.size.x/2.0,-part.position.y-part.rect.size.y/2.0)
			view.flip_h = part.flip
			# Place the torso just in front of the overlapping waist seam.
			view.position = camera.global_basis.z*(0.002 if i==1 else 0.0)
		sprite.visible = false

	# A short electric afterimage keeps the lightning form readable inside large enemies.
	# The ordinary sprite still obeys world depth and never grants wall traversal.
	lightning_body.visible = actor.alive and actor.blades.lightning_glow>0 and not layered
	if lightning_body.visible:
		if lightning_body.texture!=sprite.texture:
			lightning_body.frame = 0
			lightning_body.hframes = 1
			lightning_body.vframes = 1
			lightning_body.texture = sprite.texture
		lightning_body.hframes = sprite.hframes
		lightning_body.vframes = sprite.vframes
		lightning_body.frame_coords = sprite.frame_coords
		lightning_body.pixel_size = sprite.pixel_size
		lightning_body.offset = sprite.offset
		lightning_body.flip_h = sprite.flip_h
		lightning_body.modulate.a = 0.60*minf(1,actor.blades.lightning_glow/0.18)
