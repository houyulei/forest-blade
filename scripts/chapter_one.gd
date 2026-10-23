extends "res://scripts/main.gd"
## Playable first chapter; the original sanctuary remains a separate regression scene.
const ZONE_NAMES := {"village":"青芽村","forest":"波克布林森林","cave":"幽根洞穴"}
var zone := "village"
var landscape: ChapterLandscape
var room_actors: Array[Node] = []
var portals: Array[Dictionary] = []
var defeated := {"forest":[],"cave":[]}
var boss: GoldenBokoblin
var changing_room := false
var portal_cooldown := 0.0
var boss_started := false
var chapter_finished := false
var completion_pending := false
var zone_label: Label
var route_label: Label
var interaction_label: Label
var boss_panel: PanelContainer
var boss_bar: ProgressBar
var boss_label: Label
var chapter_map: ChapterMap
var screen_shade: ColorRect
var title_clock := 0.0
var checkpoint_zone := "village"
var checkpoint_spawn := Vector3(0,0.1,5)
var banner_tween: Tween

func _ready() -> void:
	ThemeDB.fallback_font = preload("res://assets/fonts/ChineseMedium.tres")
	rng.seed = 71824
	var args := OS.get_cmdline_user_args()
	muted = "--mute" in args
	if not get_tree().has_meta("adventure_progress"):
		var data := AdventureProgress.new()
		data.persistence_enabled = not (get_tree().has_meta("isolated_adventure") or "--verify" in args or "--capture" in args)
		data.load_save()
		get_tree().set_meta("adventure_progress",data)
	progress = get_tree().get_meta("adventure_progress")
	chapter_finished = progress.chapter_one_completed
	setup_inputs()
	build_environment()
	hero = Hero.new()
	hero.name = "Hero"
	hero.arena = self
	hero.position = Vector3(0,0.1,5)
	add_child(hero)
	setup_ui()
	adventure_ui = AdventureUI.new()
	adventure_ui.arena = self
	add_child(adventure_ui)
	for i in range(6):
		var player := AudioStreamPlayer.new()
		player.volume_db = -12
		add_child(player)
		audio_players.append(player)
	load_room("village",Vector3(0,0.1,5))
	if "--capture" in args:
		capture_chapter.call_deferred()

func panel(parent: Control,rect: Rect2) -> PanelContainer:
	var node := PanelContainer.new()
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035,0.075,0.06,0.90)
	style.border_color = Color(0.72,0.65,0.40,0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(18)
	node.add_theme_stylebox_override("panel",style)
	parent.add_child(node)
	return node

func setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var top := panel(root,Rect2(24,24,352,205))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",5)
	top.add_child(column)
	text_label(column,"第一大关  /  深林的金色獠牙",13,Color("d4b978"))
	zone_label = text_label(column,"青芽村",31,Color("f4e6c7"))
	objective_label = text_label(column,"",17,Color("f0dbab"))
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.custom_minimum_size.x = 300
	hp_label = text_label(column,"",23,Color("edb6a1"))
	dash_bar = ProgressBar.new()
	dash_bar.max_value = 0.85
	dash_bar.custom_minimum_size = Vector2(280,5)
	dash_bar.show_percentage = false
	column.add_child(dash_bar)
	status_label = text_label(column,"",13,Color("b2c9ba"))
	route_label = text_label(root,"青芽村  →  森林  →  深林洞穴",15,Color("e2d1a5"))
	route_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	route_label.offset_left = -315
	route_label.offset_right = -24
	route_label.offset_top = 27
	route_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	chapter_map = ChapterMap.new()
	chapter_map.arena = self
	chapter_map.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	chapter_map.offset_left = -215
	chapter_map.offset_right = -24
	chapter_map.offset_top = 62
	chapter_map.offset_bottom = 285
	chapter_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(chapter_map)
	var legend := text_label(root,"白：旅人  红：敌人  金：首领",12,Color("d7ccad"))
	legend.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	legend.offset_left = -240
	legend.offset_right = -24
	legend.offset_top = 294
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var footer := panel(root,Rect2(0,0,0,0))
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 24
	footer.offset_right = -24
	footer.offset_top = -67
	footer.offset_bottom = -22
	var controls := text_label(footer,"WASD 移动 · J 攻击 · K 武器技 · Q 魔法 · 1/2/3 切换 · 空格 跳跃 · Shift 冲刺 · E 交互 · I 装备 · R 重返入口",13,Color("e7d9b5"))
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_label = text_label(root,"",20,Color("ffe0a0"))
	interaction_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	interaction_label.offset_left = -450
	interaction_label.offset_right = 450
	interaction_label.offset_top = -160
	interaction_label.offset_bottom = -130
	interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message = text_label(root,"",29,Color("f4e6c7"))
	message.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	message.offset_left = -400
	message.offset_right = 400
	message.offset_top = -80
	message.offset_bottom = 50
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boss_panel = panel(root,Rect2(0,0,0,0))
	boss_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	boss_panel.offset_left = -300
	boss_panel.offset_right = 300
	boss_panel.offset_top = -250
	boss_panel.offset_bottom = -176
	var boss_column := VBoxContainer.new()
	boss_panel.add_child(boss_column)
	boss_label = text_label(boss_column,"黄金波克布林",18,Color("efc979"))
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_bar = ProgressBar.new()
	boss_bar.custom_minimum_size = Vector2(560,9)
	boss_bar.show_percentage = false
	boss_bar.add_theme_stylebox_override("fill",bar_style(Color("cf9b4d")))
	boss_bar.add_theme_stylebox_override("background",bar_style(Color("342b24")))
	boss_column.add_child(boss_bar)
	boss_panel.hide()
	screen_shade = ColorRect.new()
	screen_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_shade.color = Color(0.02,0.04,0.03,0)
	screen_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(screen_shade)

func bar_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(3)
	return style

func load_room(id: String,spawn: Vector3) -> void:
	# Called outside physics. Clear old group membership immediately before freeing.
	for effect in get_tree().get_nodes_in_group("sword_effect"):
		effect.free()
	for effect in get_children():
		if effect is BladeFX:
			effect.free()
	for pickup in get_tree().get_nodes_in_group("loot"):
		pickup.free()
	for actor in room_actors:
		if is_instance_valid(actor):
			actor.free()
	room_actors.clear()
	bokoblins.clear()
	dropped_enemy_ids.clear()
	portals.clear()
	boss = null
	forge = null
	boss_started = false
	won = false
	zone = id
	hero.cancel_attack()
	hero.blades.interrupt()
	hero.velocity = Vector3.ZERO
	hero.position = spawn
	hero.facing = Vector3(0,0,-1)
	hero.invulnerable = maxf(hero.invulnerable,1.0)
	focus = Vector3.INF
	landscape = create_landscape()
	landscape.name = "ChapterLandscape_"+id
	landscape.camera = camera
	landscape.zone = id
	add_child(landscape)
	landscape.build()
	room_actors.append(landscape)
	forest = landscape
	match zone:
		"village":
			forge = ForestForge.new()
			forge.position = Vector3(4.3,0,1)
			add_child(forge)
			room_actors.append(forge)
			add_portal(Vector3(0,0,-8.1),"forest",Vector3(0,0.1,16),"前往波克布林森林")
		"forest":
			add_portal(Vector3(0,0,17.8),"village",Vector3(0,0.1,-6),"返回青芽村")
			add_portal(Vector3(0,0,-17.1),"cave",Vector3(0,0.1,11.5),"进入幽根洞穴",true)
			var spawns := [Vector3(-2.8,0.1,11),Vector3(-0.5,0.1,9),Vector3(2.8,0.1,1),Vector3(0.3,0.1,-1),Vector3(-2.5,0.1,-9),Vector3(0.2,0.1,-11)]
			for i in range(spawns.size()):
				spawn_goblin("forest_%d"%i,spawns[i])
		"cave":
			add_portal(Vector3(0,0,13.7),"forest",Vector3(0,0.1,-14.5),"返回波克布林森林")
			spawn_goblin("cave_0",Vector3(-1.8,0.1,7))
			spawn_goblin("cave_1",Vector3(1.3,0.1,5))
			spawn_goblin("golden_boss",Vector3(0,0.1,-6),true)
	var environment: Environment = get_node_environment()
	environment.background_color = Color("151f25") if zone=="cave" else Color("9bb4ad")
	environment.ambient_light_energy = 0.32 if zone=="cave" else 0.42
	zone_label.text = ZONE_NAMES[zone]
	route_label.text = ("● 青芽村  →  森林  →  深林洞穴" if zone=="village" else ("青芽村  →  ● 森林  →  深林洞穴" if zone=="forest" else "青芽村  →  森林  →  ● 深林洞穴"))
	portal_cooldown = 1.1
	show_banner(ZONE_NAMES[zone], "休整后，从北门进入森林。" if zone=="village" else ("沿林道北行，寻找深林洞穴。" if zone=="forest" else "清除洞口守卫，深入巢穴。"))
	changing_room = false

func create_landscape() -> ChapterLandscape:
	return ChapterLandscape.new()

func get_node_environment() -> Environment:
	for child in get_children():
		if child is WorldEnvironment:
			return child.environment
	return null

func spawn_goblin(id: String,p: Vector3,golden: bool = false) -> void:
	if id in defeated.get(zone,[]):
		return
	var goblin: Bokoblin = GoldenBokoblin.new() if golden else Bokoblin.new()
	goblin.name = id
	goblin.set_meta("chapter_id",id)
	goblin.arena = self
	goblin.hero = hero
	goblin.position = p
	add_child(goblin)
	bokoblins.append(goblin)
	room_actors.append(goblin)
	if golden:
		boss = goblin

func add_portal(p: Vector3,destination: String,spawn: Vector3,title: String,locked: bool = false) -> void:
	portals.append({"position":p,"destination":destination,"spawn":spawn,"title":title,"locked":locked})
	var color := Color("dfca85") if destination=="cave" else Color("91cbb4")
	var mark := Craft.ring(landscape,p+Vector3.UP*0.045,0.72,0.055,Craft.material(color,0.6,0.45))
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func show_banner(title: String,subtitle: String) -> void:
	if banner_tween and banner_tween.is_running():
		banner_tween.kill()
	message.text = title+"\n"+subtitle
	message.modulate.a = 1
	banner_tween = create_tween()
	banner_tween.tween_interval(2.0)
	banner_tween.tween_property(message,"modulate:a",0.0,0.7)

func nearby_portal() -> Dictionary:
	for portal in portals:
		if hero.position.distance_to(portal.position+Vector3.UP*0.1)<1.55:
			return portal
	return {}

func can_travel() -> bool:
	return hero.alive and not menu_open and not changing_room and not hero.blades.busy() and hero.attack_time<=0 and hero.hurt_time<=0 and hero.dash_time<=0 and hero.is_on_floor()

func travel(portal: Dictionary) -> bool:
	if portal.is_empty() or portal not in portals or not can_travel():
		return false
	if hero.position.distance_to(portal.position+Vector3.UP*0.1)>=1.55:
		return false
	if zone=="cave" and boss_started and is_instance_valid(boss) and boss.alive:
		adventure_ui.notify("首领战中，洞口已被封锁。")
		return false
	if portal.locked and living_enemy_count()>0:
		adventure_ui.notify("先清理森林哨点，再进入深林洞穴。")
		return false
	for target in bokoblins:
		if target.alive and target.global_position.distance_to(hero.global_position)<3:
			adventure_ui.notify("附近还有敌人，先脱离战斗。")
			return false
	# Collect remaining room drops before leaving; a failed save cancels the transition.
	for pickup in get_tree().get_nodes_in_group("loot"):
		if not pickup.collected and not pickup.collect():
			return false
	changing_room = true
	hero.set_physics_process(false)
	for actor in bokoblins:
		actor.set_physics_process(false)
	transition_room.call_deferred(portal.destination,portal.spawn)
	return true

func transition_room(destination: String,spawn: Vector3) -> void:
	var tween := create_tween()
	tween.tween_property(screen_shade,"color:a",1.0,0.18)
	await tween.finished
	load_room(destination,spawn)
	checkpoint_zone = destination
	checkpoint_spawn = spawn
	if destination=="village":
		rest_hero()
	hero.set_physics_process(true)
	tween = create_tween()
	tween.tween_property(screen_shade,"color:a",0.0,0.25)

func rest_hero() -> void:
	hero.hp = hero.max_hp
	hero.blades.magic_meters = {"wind":100.0,"fire":100.0,"thunder":100.0}
	hero.mp = 100

func handle_world_interaction() -> void:
	if menu_open or changing_room or not hero.alive:
		return
	if zone=="cave" and "golden_boss" in defeated.cave and not progress.chapter_one_completed:
		finish_chapter()
		return
	var portal := nearby_portal()
	if not portal.is_empty():
		if portal_cooldown<=0:
			travel(portal)
		return
	adventure_ui.notify("沿林道寻找出口；铁匠阿伦在青芽村东侧。")

func _process(delta: float) -> void:
	if not is_instance_valid(hero) or not is_instance_valid(landscape):
		return
	elapsed += delta
	portal_cooldown = maxf(0,portal_cooldown-delta)
	if Input.is_action_just_pressed("mute"):
		muted = not muted
	if Input.is_action_just_pressed("restart") and not menu_open and not changing_room:
		respawn_at_checkpoint.call_deferred()
	if not menu_open and not changing_room and hero.alive:
		if zone=="cave" and is_instance_valid(boss) and boss.alive and not boss_started and hero.position.z<0.0:
			var guards_alive := false
			for actor in bokoblins:
				guards_alive = guards_alive or (actor!=boss and actor.alive)
			if not guards_alive:
				boss_started = true
				landscape.set_gate(true)
				boss.engage()
				show_banner("黄金波克布林","看清预警，抓住收招的空隙。")
	if completion_pending and not menu_open:
		finish_chapter()
	hp_label.text = "生命  "+"● ".repeat(hero.hp)+"○ ".repeat(hero.max_hp-hero.hp)
	dash_bar.value = 0.85-hero.dash_cooldown
	boss_panel.visible = zone=="cave" and is_instance_valid(boss) and boss.alive and boss_started and not menu_open
	if boss_panel.visible:
		boss_bar.max_value = boss.max_hp
		boss_bar.value = boss.hp
		boss_label.text = "黄金波克布林"+(" · 震怒" if boss.enraged else " · 洞穴霸主")+"  %d / %d"%[boss.hp,boss.max_hp]
	if not hero.alive:
		message.modulate.a = 1
		message.text = "暂歇片刻，再踏旅途。\nR · 从区域入口重新出发"
		objective_label.text = "整顿后再挑战"
	else:
		update_objective()
	var portal := nearby_portal()
	interaction_label.text = ("E · "+portal.title) if not portal.is_empty() and not menu_open else ""
	if not portal.is_empty() and portal.locked and living_enemy_count()>0:
		interaction_label.text = "清理森林哨点后可进入洞穴"
	shake = maxf(0,shake-delta)
	update_pixel_camera(delta)

func update_objective() -> void:
	match zone:
		"village":
			objective_label.text = "整备武器，从北门出发" if not chapter_finished else "第一大关已通关 · 可再次探索"
			status_label.text = "阿伦可强化武器、精炼与休息。"
		"forest":
			var remaining := living_enemy_count()
			objective_label.text = "清理森林哨点 · 剩余 %d / 6"%remaining if remaining>0 else "前往北端 · 深林洞穴"
			status_label.text = "闪开挥棒，利用空隙逐个击破。"
		"cave":
			objective_label.text = "击败黄金波克布林" if is_instance_valid(boss) and boss.alive else "首领已击败 · 可返回村庄"
			status_label.text = "震地可跳跃，冲锋向侧面躲。" if boss_started else "清理守卫，向北深入巢穴。"

func update_pixel_camera(delta: float) -> void:
	var window := Vector2(DisplayServer.window_get_size()) if DisplayServer.get_name()!="headless" else Vector2(1280,800)
	var low := Vector2i(ceili(window.x),ceili(window.y))
	pixel_world.size = low+Vector2i(PIXEL_MARGIN*2,PIXEL_MARGIN*2)
	var texel := VIEW_HEIGHT/low.y
	camera.size = texel*pixel_world.size.y
	var goal := Vector3(clampf(hero.position.x,-5,5),0,clampf(hero.position.z,-landscape.extent.y+5,landscape.extent.y-5))
	focus = goal if focus==Vector3.INF else focus.lerp(goal,minf(1,delta*6))
	camera.global_position = focus+camera_home-camera_target+Vector3(rng.randf_range(-shake,shake),rng.randf_range(-shake,shake),0)
	var unit := Vector2.ONE/get_viewport().get_final_transform().get_scale()
	pixel_display.position = -Vector2(PIXEL_MARGIN,PIXEL_MARGIN)*unit
	pixel_display.size = Vector2(pixel_world.size)*unit

func enemy_defeated(target: Node3D) -> void:
	if dropped_enemy_ids.has(target.get_instance_id()):
		return
	var id := str(target.get_meta("chapter_id",""))
	if id!="" and id not in defeated[zone]:
		defeated[zone].append(id)
	# Reuse guarded one-time material drops; the boss has its own reward table.
	if target is GoldenBokoblin:
		if not dropped_enemy_ids.has(target.get_instance_id()):
			dropped_enemy_ids.append(target.get_instance_id())
			for item in ["gold","ore","fang","stone"]:
				var pickup := LootPickup.new()
				pickup.arena = self
				pickup.item = item
				pickup.amount = {"gold":80,"ore":5,"fang":3,"stone":2}[item]
				pickup.position = target.position+Vector3(rng.randf_range(-0.5,0.5),0.03,rng.randf_range(-0.5,0.5))
				add_child(pickup)
		landscape.set_gate(false)
		completion_pending = true
		return
	super.enemy_defeated(target)

func victory() -> void:
	# Forest clearance unlocks the cave, never a chapter-wide victory.
	won = true
	if zone=="forest":
		show_banner("森林哨点已清理","北端的深林洞穴已经可以进入。")

func finish_chapter() -> void:
	if not progress.complete_chapter_one():
		# Retry only on an explicit interaction / checkpoint action after a disk failure.
		completion_pending = false
		adventure_ui.notify(progress.last_error+" 通关状态未保存，请按 E 重试。")
		return
	completion_pending = false
	chapter_finished = true
	won = true
	show_banner("第一大关 · 完成","黄金波克布林已被击败。拾取战利品，返回青芽村。")
	adventure_ui.notify("深林重归宁静。返回村庄可恢复生命与魔法。")

func respawn_at_checkpoint() -> void:
	if changing_room:
		return
	if not hero.alive or zone!="village":
		# Recreate this room's enemies only. Permanent inventory stays intact.
		defeated[checkpoint_zone] = []
	hero.alive = true
	hero.hurt_time = 0
	hero.hurt_flash = 0
	hero.sprite_view.death_time = 0
	hero.sprite_view.sprite.scale = Vector3.ONE
	hero.dash_time = 0
	hero.dash_cooldown = 0
	rest_hero()
	load_room(checkpoint_zone,checkpoint_spawn)
	hero.set_physics_process(true)

func capture_chapter() -> void:
	for id in ["village","forest","cave"]:
		load_room(id,Vector3(0,0.1,1.8) if id=="village" else (Vector3(0,0.1,6) if id=="forest" else Vector3(0,0.1,-3)))
		for actor in bokoblins:
			actor.set_physics_process(false)
		hero.set_physics_process(true)
		for frame in range(15):
			await get_tree().physics_frame
		hero.set_physics_process(false)
		if id=="cave":
			for actor in bokoblins:
				if actor!=boss:
					actor.take_hit(999,Vector3.ZERO,true)
			boss_started = true
			boss.engage()
			landscape.set_gate(true)
			for frame in range(95):
				for actor in bokoblins:
					if actor!=boss:
						actor.update_visual(1.0/60.0)
						actor.death_time += 1.0/60.0
				await get_tree().process_frame
		for frame in range(12):
			await get_tree().process_frame
		message.modulate.a = 0
		RenderingServer.force_draw()
		await save_capture("chapter-one-"+id)
	get_tree().quit()
