class_name GoldenBokoblin
extends Bokoblin
## Same body proportions as the species. Gold skin, authored two-phase boss behavior.
var engaged := false
var enraged := false
var move_index := 0
var move_kind := "club"
var attack_cooldown := 0.5
var phase_roar := 0.0
var crown: Label3D
var slam_warning: MeshInstance3D
var boss_title := "黄金波克布林"
var moves_used := {"club":0,"slam":0,"rush":0}

func _ready() -> void:
	max_hp = 300
	hp = max_hp
	tier = "gold"
	super._ready()
	sprite.name = "GoldenBokoblin"
	var shader := Shader.new()
	shader.code = """shader_type spatial; render_mode unshaded,cull_disabled;
uniform float flash=0.0; uniform float opacity=1.0;
void vertex(){MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);}
void fragment(){vec4 c=texture(TEXTURE,UV);float skin=smoothstep(0.08,0.32,c.r-c.g)*smoothstep(0.04,0.18,c.r-c.b);float l=dot(c.rgb,vec3(0.3,0.5,0.2));vec3 gold=vec3(1.15,0.82,0.22)*l;ALBEDO=mix(mix(c.rgb,gold,skin),vec3(1.0,0.9,0.65),flash);ALPHA=c.a*opacity;ALPHA_SCISSOR_THRESHOLD=0.15;}
"""
	# Sprite3D custom shaders bind the current atlas explicitly.
	shader.code = shader.code.replace("uniform float flash","uniform sampler2D atlas : source_color,filter_linear_mipmap; uniform float flash").replace("texture(TEXTURE,UV)","texture(atlas,UV)")
	var mat := ShaderMaterial.new()
	mat.shader = shader
	sprite.material_override = mat
	crown = Label3D.new()
	crown.text = "◆ 首领"
	crown.font_size = 26
	crown.pixel_size = 0.006
	crown.modulate = Color("f4cc67")
	crown.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(crown)
	slam_warning = Craft.ring(self,Vector3(0,0.055,0),2.5,0.13,Craft.material(Color(1,0.45,0.12,0.65),0.8,0.5))
	slam_warning.visible = false
	slam_warning.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	health.visible = false
	hp_fill.visible = false
	update_visual(0)

func engage() -> void:
	if engaged or not alive:
		return
	engaged = true
	facing = (hero.global_position-global_position).normalized()
	change_state("alert",1.0)

func choose_attack() -> void:
	move_kind = ["club","slam","rush"][move_index%3]
	move_index += 1
	attack_direction = (hero.global_position-global_position)
	attack_direction.y = 0
	attack_direction = attack_direction.normalized()
	facing = attack_direction
	attack_has_hit = false
	warning.rotation.y = atan2(facing.x,facing.z)
	var anticipation := 0.75 if move_kind=="club" else (1.05 if move_kind=="slam" else 0.90)
	change_state("windup",anticipation)
	warning.visible = move_kind!="slam"
	slam_warning.visible = move_kind=="slam"
	if move_kind=="rush":
		warning.scale.z = 2.8
	else:
		warning.scale.z = 1.0

func _physics_process(delta: float) -> void:
	if not alive:
		super._physics_process(delta)
		return
	clock += delta
	state_elapsed += delta
	timer = maxf(0,timer-delta)
	hit_flash = maxf(0,hit_flash-delta)
	attack_cooldown = maxf(0,attack_cooldown-delta)
	knock = knock.move_toward(Vector3.ZERO,delta*16)
	velocity.x = 0
	velocity.z = 0
	if not engaged or not hero.alive:
		warning.visible = false
		slam_warning.visible = false
		change_state("idle")
		update_visual(delta)
		return
	if not enraged and hp<=max_hp/2:
		enraged = true
		phase_roar = 1.0
		change_state("alert",1.0)
		slam_warning.visible = false
		arena.adventure_ui.notify("黄金波克布林震怒！留意冲锋后的重击。")
	phase_roar = maxf(0,phase_roar-delta)
	var offset := hero.global_position-global_position
	offset.y = 0
	var distance := offset.length()
	match state:
		"idle","alert":
			if timer<=0: change_state("chase")
		"chase":
			facing = offset.normalized()
			var trigger := 4.5 if move_index%3==2 else 1.5
			if distance>trigger:
				velocity = facing*(2.6 if not enraged else 2.95)
				velocity.y = 0
			elif attack_cooldown<=0 and arena.can_enemy_attack(self):
				choose_attack()
		"windup":
			facing = attack_direction
			if timer<=0:
				moves_used[move_kind] += 1
				attack_count += 1
				change_state("strike",0.48 if move_kind=="rush" else 0.20)
				slam_warning.visible = false
				if move_kind=="slam":
					arena.shockwave(global_position)
					arena.shake = 0.18
				arena.play_tone(95,0.16,0.10)
		"strike":
			if move_kind=="rush":
				velocity = attack_direction*8.0
			resolve_attack()
			if timer<=0:
				change_state("recover",1.05 if not enraged else 0.85)
				attack_cooldown = 0.25
		"recover","hurt":
			if timer<=0:
				# Phase two follows a charge with a separately telegraphed ground slam.
				if enraged and move_kind=="rush" and state=="recover":
					move_index = 1
				change_state("chase")
	velocity.x += knock.x
	velocity.z += knock.z
	velocity.y = -1.0 if is_on_floor() else velocity.y-delta*20
	var before := global_position
	move_and_slide()
	var moved := Vector2(global_position.x-before.x,global_position.z-before.z).length()
	walk_phase = fposmod(walk_phase+moved/ActorSizes.stride_distance("bokoblin"),1.0)
	update_visual(delta)

func resolve_attack() -> void:
	if state!="strike" or attack_has_hit or not hero.alive:
		return
	var offset := hero.global_position-global_position
	var flat := Vector3(offset.x,0,offset.z)
	var valid := false
	if move_kind=="slam":
		valid = flat.length()<=2.5 and offset.y<0.65 and offset.y> -0.7
	elif move_kind=="rush":
		valid = flat.length()<1.05 and absf(offset.y)<0.9
	else:
		valid = flat.length()<=REACH and absf(offset.y)<0.9 and attack_direction.dot(flat.normalized())>=cos(HALF_ARC)
	if valid and has_line_of_sight():
		attack_has_hit = true
		hero.take_hit(1,attack_direction)

func update_visual(delta: float) -> void:
	super.update_visual(delta)
	if sprite.material_override is ShaderMaterial:
		sprite.material_override.set_shader_parameter("atlas",sprite.texture)
		sprite.material_override.set_shader_parameter("flash",0.75 if hit_flash>0 else 0.0)
		sprite.material_override.set_shader_parameter("opacity",sprite.modulate.a)
	health.visible = false
	hp_fill.visible = false
	if is_instance_valid(crown):
		crown.position = ActorSizes.alert_position("bokoblin",arena.camera)
		crown.visible = alive
		crown.text = "◆ 震怒" if enraged else "◆ 首领"

func take_hit(amount: int,direction: Vector3,heavy: bool = false) -> void:
	if not alive or not engaged:
		return
	# Boss can be damaged during every attack, but only recovery accepts stagger.
	var previous_state := state
	var previous_timer := timer
	super.take_hit(amount,direction,heavy)
	if alive and previous_state not in ["recover","hurt"]:
		change_state(previous_state,previous_timer)
		warning.visible = previous_state=="windup" and move_kind!="slam"
		slam_warning.visible = previous_state=="windup" and move_kind=="slam"
		knock = Vector3.ZERO
	if not alive:
		slam_warning.visible = false
