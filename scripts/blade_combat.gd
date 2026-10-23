class_name BladeCombat
extends Node3D
## Sword techniques (K / weapon-specific J inputs) and full-gauge sword magic (Q).
var hero: Hero
var arena: Node3D
var state := ""
var elapsed := 0.0
var duration := 0.0
var released := false
var charge := 0.0
var charge_source := "sword_skill"
var skill_cooldown := 0.0
var wind_window := 0.0
var wind_count := 0
var wind_queued := false
var thunder_charge := 0
var powered := false
var lightning_glow := 0.0
var technique_hits := {}
var magic_meters := {"wind":100.0,"fire":100.0,"thunder":100.0}
var charge_fx: BladeFX
var dash_fx: BladeFX
var last_trail := Vector3.ZERO
var casts := {"wind":0,"fire":0,"thunder":0}
var skill_casts := {"wind":0,"fire":0,"thunder":0}
var lock_weapon := "wind"
func weapon() -> String:
	return arena.progress.equipped_sword
func busy() -> bool:
	return state!=""
func available() -> bool:
	return hero.alive and hero.hurt_time<=0 and hero.dash_time<=0 and hero.attack_time<=0 and not busy() and hero.is_on_floor()
func switch_sword(id: String) -> bool:
	if id not in SwordArsenal.ORDER or not hero.alive or busy() or hero.attack_time>0 or hero.dash_time>0 or hero.hurt_time>0:
		return false
	if not arena.progress.equip_sword(id):
		return false
	hero.combo_window = 0
	hero.combo = 0
	wind_window = 0
	wind_count = 0
	hero.mp = magic_meters[id]
	arena.play_tone(520+SwordArsenal.ORDER.find(id)*120,0.07,0.04)
	return true
func attack_input() -> bool:
	if busy():
		if state=="wind" and elapsed/duration>0.40 and wind_count<5:
			wind_queued = true
		return true
	if weapon()=="wind" and wind_window>0 and wind_count<5:
		return begin_wind(true)
	if weapon()=="fire" and hero.attack_time<=0 and hero.combo_window<=0:
		return begin_charge("attack")
	return false
func begin_skill() -> bool:
	match weapon():
		"wind": return begin_wind(false)
		"fire": return begin_charge("sword_skill")
		"thunder": return begin_thunder()
	return false
func enter(action: String, seconds: float) -> void:
	state = action
	duration = seconds
	elapsed = 0
	released = false
	lock_weapon = weapon()
	hero.cancel_attack()
	hero.velocity.x = 0
	hero.velocity.z = 0
func begin_wind(chain: bool) -> bool:
	if not available() or (not chain and skill_cooldown>0) or (chain and wind_count>=5):
		return false
	wind_count = wind_count+1 if chain else 1
	wind_window = 0
	wind_queued = false
	enter("wind",0.34)
	skill_casts.wind += 1
	var swirl := BladeFX.new()
	swirl.arena = arena
	swirl.kind = "wind"
	swirl.radius = 0.95
	swirl.life = duration
	add_child(swirl)
	return true
func begin_charge(source: String = "sword_skill") -> bool:
	if not available() or skill_cooldown>0:
		return false
	enter("charge",1.2)
	charge_source = source
	charge = 0
	charge_fx = BladeFX.new()
	charge_fx.arena = arena
	charge_fx.kind = "charge"
	charge_fx.life = 999
	charge_fx.radius = 0.34
	charge_fx.visible = source!="attack"
	charge_fx.position = -hero.facing*0.15+arena.camera.global_basis.y*1.85
	add_child(charge_fx)
	if Input.is_action_just_released(source):
		release_charge()
	return true
func release_charge() -> bool:
	if state!="charge":
		return false
	if is_instance_valid(charge_fx):
		charge_fx.queue_free()
	if charge<0.18 and charge_source=="attack":
		state = ""
		hero.begin_attack()
		hero.attack_time -= minf(charge,hero.attack_duration*0.27)
		return true
	enter("fire_release",0.40)
	skill_casts.fire += 1
	skill_cooldown = 0.32
	arena.play_tone(170,0.1,0.055)
	return true
func begin_thunder() -> bool:
	if not available() or skill_cooldown>0:
		return false
	powered = thunder_charge>=3
	thunder_charge = 0
	enter("thunder",0.38 if powered else 0.30)
	lightning_glow = duration+0.2
	technique_hits.clear()
	skill_cooldown = 1.1
	skill_casts.thunder += 1
	last_trail = hero.global_position
	dash_fx = BladeFX.new()
	dash_fx.arena = arena
	dash_fx.kind = "thunder"
	dash_fx.color = Color("ffe785")
	dash_fx.radius = 0.65
	dash_fx.life = duration
	add_child(dash_fx)
	return true
func cast_magic() -> bool:
	if not available() or float(magic_meters[weapon()])<100.0:
		return false
	magic_meters[weapon()] = 0.0
	hero.mp = 0
	casts[weapon()] += 1
	enter("magic",0.62)
	if weapon()=="thunder":
		lightning_glow = 1.3
	return true
func interrupt() -> void:
	lightning_glow = 0
	state = ""
	released = true
	wind_window = 0
	wind_queued = false
	if is_instance_valid(charge_fx):
		charge_fx.queue_free()
	if is_instance_valid(dash_fx):
		dash_fx.queue_free()
func on_sword_hit(first_contact: bool = true) -> void:
	magic_meters[weapon()] = minf(100,float(magic_meters[weapon()])+8)
	if weapon()=="thunder" and first_contact:
		thunder_charge = mini(3,thunder_charge+1)
func on_combo_finished(combo: int) -> void:
	if combo==3 and weapon()=="wind":
		wind_window = 0.38
		wind_count = 0
func spawn_effect(kind: String, damage: int, radius: float, reach: float = 5, speed: float = 9) -> SwordEffect:
	var effect := SwordEffect.new()
	effect.arena = arena
	effect.kind = kind
	effect.damage = damage
	effect.radius = radius
	effect.reach = reach
	effect.speed = speed
	effect.direction = hero.facing
	effect.position = hero.global_position+hero.facing*(0.25 if kind=="tornado" else 0.50)
	arena.add_child(effect)
	return effect
func release_magic() -> void:
	released = true
	var level := int(arena.progress.sword_levels[lock_weapon])
	match lock_weapon:
		"wind": spawn_effect("tornado",7+level,2.15)
		"fire": spawn_effect("fire_ball",38+level*5+(8 if arena.progress.fire_core else 0),0.72,9.0,10.5)
		"thunder": spawn_effect("chain",14+level*2,0.4)
	arena.shake = 0.07
	arena.play_tone(110 if lock_weapon=="fire" else 720,0.18,0.065)
func motion_velocity() -> Vector3:
	if state=="thunder" and elapsed>=0.07 and elapsed<=duration-0.07:
		return hero.facing*(15.5 if powered else 12.0)
	return Vector3.ZERO
func tick(delta: float, move_direction: Vector3) -> void:
	skill_cooldown = maxf(0,skill_cooldown-delta)
	lightning_glow = maxf(0,lightning_glow-delta)
	wind_window = maxf(0,wind_window-delta)
	magic_meters[weapon()] = minf(100,float(magic_meters[weapon()])+delta*2)
	hero.mp = float(magic_meters[weapon()])
	if not busy():
		return
	elapsed += delta
	if state=="charge":
		charge = minf(1.0,elapsed)
		if move_direction.length()>0.1:
			hero.facing = hero.facing.slerp(move_direction.normalized(),minf(1,delta*10)).normalized()
		if is_instance_valid(charge_fx):
			charge_fx.visible = charge_source!="attack" or elapsed>=0.18
			charge_fx.position = -hero.facing*0.15+arena.camera.global_basis.y*1.85
			charge_fx.scale = Vector3.ONE*(0.38+charge*0.8)
		if Input.is_action_just_released(charge_source) or elapsed>=1.2:
			release_charge()
		return
	var progress := elapsed/duration
	match state:
		"wind":
			if progress>=0.30 and not released:
				released = true
				var cut := spawn_effect("wind_cut",9+int(arena.progress.sword_levels.wind)*2,0.58,4.7,8.5)
				for target in get_tree().get_nodes_in_group("enemy"):
					var ray := PhysicsRayQueryParameters3D.create(hero.global_position+Vector3.UP*0.7,target.global_position+Vector3.UP*0.7,1)
					if target.alive and target.global_position.distance_to(hero.global_position)<1.3 and hero.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
						cut.deal(target,(target.global_position-hero.global_position).normalized())
				arena.play_tone(650+wind_count*35,0.07,0.035)
		"fire_release":
			if progress>=0.28 and not released:
				released = true
				var amount := roundi(lerpf(12,30,charge))+int(arena.progress.sword_levels.fire)*3+(6 if arena.progress.fire_core else 0)
				spawn_effect("fire_wave",amount,arena.progress.fire_radius(),lerpf(2.5,6.4,charge)+(0.8 if arena.progress.fire_core else 0.0),9.5)
				arena.shake = 0.035+charge*0.035
		"thunder":
			if elapsed>=0.07 and elapsed<=duration-0.05:
				hero.invulnerable = maxf(hero.invulnerable,0.05)
				if hero.global_position.distance_to(last_trail)>0.42:
					var arc := BladeFX.new()
					arc.arena = arena
					arc.kind = "arc"
					arc.color = Color("ffe987")
					arc.life = 0.16
					arc.position = last_trail+Vector3.UP*0.65
					arc.end_point = hero.global_position-last_trail
					arena.add_child(arc)
					last_trail = hero.global_position
				for target in get_tree().get_nodes_in_group("enemy"):
					if target.alive and not technique_hits.has(target.get_instance_id()):
						var offset: Vector3 = target.global_position-hero.global_position
						offset.y = 0
						var ray := PhysicsRayQueryParameters3D.create(hero.global_position+Vector3.UP*0.7,target.global_position+Vector3.UP*0.7,1)
						if offset.length()<1.35 and hero.facing.dot(offset.normalized())>0.35 and absf(target.global_position.y-hero.global_position.y)<1.4 and hero.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
							technique_hits[target.get_instance_id()] = true
							target.take_hit((28 if powered else 15)+int(arena.progress.sword_levels.thunder)*2,hero.facing,powered)
		"magic":
			if progress>=0.40 and not released:
				release_magic()
	if elapsed>=duration:
		var previous := state
		state = ""
		if previous=="wind":
			wind_window = 0.32 if wind_count<5 else 0
			skill_cooldown = 0.18 if wind_count<5 else 0.75
			if wind_queued and wind_count<5:
				begin_wind(true)
func pose() -> Dictionary:
	var progress := clampf(elapsed/maxf(0.001,duration),0,1)
	match state:
		"wind": return {"atlas":"spin","frame":clampi(int(progress*16),0,15)}
		"charge": return {"atlas":"fire","frame":0} if charge_source=="attack" and elapsed<0.18 else {"atlas":"fire_heavy","frame":1}
		"fire_release": return {"atlas":"fire_heavy","frame":2+clampi(int(progress*4),0,3)}
		"thunder": return {"atlas":"spear_lunge","frame":1 if progress<0.18 else (3 if progress<0.80 else 4)}
		"magic":
			if lock_weapon=="wind": return {"atlas":"spin","frame":clampi(int(progress*16),0,15)}
			return {"atlas":"fire_heavy" if lock_weapon=="fire" else "spear_lunge","frame":1 if progress<0.4 else (3 if progress<0.75 else 5)}
	return {"atlas":"fire","frame":0}
