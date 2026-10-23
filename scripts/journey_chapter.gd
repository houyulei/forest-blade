extends "res://scripts/chapter_one.gd"
## Production chapter on the chosen VillagePreview scenery route.
var journal: JourneyProgress
var world_objects: Array[JourneyObject]=[]
var villagers: Array[JourneyNPC]=[]
var potion_cooldown:=0.0
var sun: DirectionalLight3D
var capture_journey:=false
func _ready() -> void:
 ThemeDB.fallback_font=preload("res://assets/fonts/ChineseMedium.tres")
 rng.seed=71824
 var args:=OS.get_cmdline_user_args()
 capture_journey="--journey-capture" in args
 muted="--mute" in args or "--verify" in args
 if get_tree().has_meta("adventure_progress"):
  var existing: AdventureProgress=get_tree().get_meta("adventure_progress")
  journal=JourneyProgress.new();journal.persistence_enabled=existing.persistence_enabled;journal.save_path=existing.save_path;journal.restore(existing.snapshot())
 else:
  journal=JourneyProgress.new()
  journal.persistence_enabled=not (get_tree().has_meta("isolated_adventure") or "--verify" in args or capture_journey)
  journal.load_save()
 progress=journal
 get_tree().set_meta("adventure_progress",journal)
 chapter_finished=journal.chapter_one_completed
 setup_inputs();build_environment()
 hero=Hero.new();hero.name="Hero";hero.arena=self
 add_child(hero)
 setup_ui()
 adventure_ui=JourneyUI.new();adventure_ui.arena=self;add_child(adventure_ui)
 for i in range(6):
  var player:=AudioStreamPlayer.new();player.volume_db=-12;add_child(player);audio_players.append(player)
 var cp: Dictionary=journal.journey.checkpoint
 load_room(cp.zone,Vector3(float(cp.p[0]),0,float(cp.p[2])))
 apply_equipment();rest_hero()
 update_pixel_camera(0)
 if capture_journey:capture_finished_game.call_deferred()
 elif not get_tree().has_meta("isolated_adventure") and "--verify" not in args:set_menu("title")
func build_environment() -> void:
 super.build_environment()
 camera.projection=Camera3D.PROJECTION_PERSPECTIVE
 camera.fov=48;camera.far=240;camera.near=0.15
 var env:=get_node_environment()
 env.background_mode=Environment.BG_SKY
 var sky:=Sky.new();var paint:=ProceduralSkyMaterial.new()
 paint.sky_top_color=Color("659dc1");paint.sky_horizon_color=Color("c2d8df");paint.ground_horizon_color=Color("c2d8df")
 sky.sky_material=paint;env.sky=sky
 env.ambient_light_color=Color("b0bec9");env.ambient_light_energy=0.42
 env.fog_enabled=true;env.fog_density=0.0018;env.fog_light_color=Color("adcad2");env.fog_sky_affect=0.0
 for child in get_children():
  if child is DirectionalLight3D:sun=child
 sun.shadow_bias=0.12;sun.shadow_normal_bias=1.2;sun.directional_shadow_max_distance=38
 sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
func setup_ui() -> void:
 var layer:=CanvasLayer.new();add_child(layer)
 var root:=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(root)
 var top:=panel(root,Rect2(24,24,338,198));var col:=VBoxContainer.new();col.add_theme_constant_override("separation",5);top.add_child(col)
 text_label(col,"森之刃 / 第一章",12,Color("d1b782"))
 zone_label=text_label(col,"青芽村",27,Color("f1e4c4"))
 hp_label=text_label(col,"",20,Color("edb4a0"))
 dash_bar=ProgressBar.new();dash_bar.max_value=0.85;dash_bar.custom_minimum_size=Vector2(280,4);dash_bar.show_percentage=false;col.add_child(dash_bar)
 objective_label=text_label(col,"",15,Color("e9d5a7"));objective_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;objective_label.custom_minimum_size.x=290
 status_label=text_label(col,"",12,Color("b7c7b5"))
 route_label=text_label(root,"青芽村 → 波克布林森林 → 幽根洞穴",14,Color("e2d1a5"));route_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);route_label.offset_left=-355;route_label.offset_right=-24;route_label.offset_top=24;route_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
 chapter_map=JourneyMap.new();chapter_map.arena=self;chapter_map.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);chapter_map.offset_left=-215;chapter_map.offset_right=-24;chapter_map.offset_top=56;chapter_map.offset_bottom=247;root.add_child(chapter_map)
 var legend:=text_label(root,"Tab 地图 · T 委托 · B 背包 · I 装备",12,Color("d7ccad"));legend.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);legend.offset_left=-280;legend.offset_right=-24;legend.offset_top=253;legend.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
 var footer:=panel(root,Rect2());footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);footer.offset_left=24;footer.offset_right=-24;footer.offset_top=-68;footer.offset_bottom=-22
 var controls:=text_label(footer,"WASD 移动 · J 攻击 · K 武器技 · Q 魔法 · 空格 跳跃 · Shift 冲刺 · E 交互 · 4/5 药品 · Esc 暂停 · R 重返营火",13,Color("e7d9b5"));controls.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 message=text_label(root,"",27,Color("f4e6c7"));message.set_anchors_and_offsets_preset(Control.PRESET_CENTER);message.offset_left=-420;message.offset_right=420;message.offset_top=-65;message.offset_bottom=65;message.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 interaction_label=text_label(root,"",1,Color.TRANSPARENT)
 boss_panel=panel(root,Rect2());boss_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM);boss_panel.offset_left=-290;boss_panel.offset_right=290;boss_panel.offset_top=-260;boss_panel.offset_bottom=-183
 var boss_col:=VBoxContainer.new();boss_panel.add_child(boss_col)
 boss_label=text_label(boss_col,"黄金波克布林",18,Color("efc979"));boss_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 boss_bar=ProgressBar.new();boss_bar.custom_minimum_size=Vector2(540,9);boss_bar.show_percentage=false;boss_col.add_child(boss_bar);boss_panel.hide()
 screen_shade=ColorRect.new();screen_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);screen_shade.color=Color(0.02,0.04,0.03,0);screen_shade.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(screen_shade)
func create_landscape() -> ChapterLandscape:
 return JourneyLandscape.new()
func load_room(id: String,spawn: Vector3) -> void:
 for effect in get_tree().get_nodes_in_group("sword_effect"):effect.free()
 for effect in get_children():
  if effect is BladeFX:effect.free()
 for pickup in get_tree().get_nodes_in_group("loot"):pickup.free()
 for actor in room_actors:
  if is_instance_valid(actor):actor.free()
 room_actors.clear();bokoblins.clear();portals.clear();world_objects.clear();villagers.clear();dropped_enemy_ids.clear()
 boss=null;forge=null;boss_started=false;won=false;zone=id
 hero.cancel_attack();hero.blades.interrupt();hero.velocity=Vector3.ZERO;focus=Vector3.INF
 landscape=create_landscape();landscape.zone=id;landscape.camera=camera;add_child(landscape);landscape.build();room_actors.append(landscape);forest=landscape
 var env:=get_node_environment()
 env.background_mode=Environment.BG_COLOR if zone=="cave" else Environment.BG_SKY
 env.background_color=Color("18262f");env.ambient_light_energy=0.5 if zone=="cave" else 0.42
 env.fog_light_color=Color("243840") if zone=="cave" else Color("adcad2")
 sun.light_energy=0.28 if zone=="cave" else 0.70
 hero.position=(landscape as JourneyLandscape).ground_at(spawn)+Vector3.UP*0.08
 hero.facing=Vector3.FORWARD;hero.invulnerable=maxf(hero.invulnerable,1.0)
 checkpoint_zone=id;checkpoint_spawn=hero.position
 if zone=="village":
  forge=ForestForge.new();forge.position=(landscape as JourneyLandscape).ground_at(Vector3(4,0,0));add_child(forge);room_actors.append(forge)
  for data in JourneyData.NPCS:
   var npc:=JourneyNPC.new();npc.arena=self;npc.data=data;npc.position=(landscape as JourneyLandscape).ground_at(data.p);add_child(npc);room_actors.append(npc);villagers.append(npc)
  add_portal(Vector3(0,0,-36),"forest",Vector3(0,0,34),"前往波克布林森林")
 elif zone=="forest":
  add_portal(Vector3(0,0,36),"village",Vector3(0,0,-34),"返回青芽村")
  add_portal(Vector3(0,0,-36),"cave",Vector3(0,0,34),"进入幽根洞穴",true)
  var positions:=JourneyData.enemy_spawns(zone)
  for i in range(positions.size()):spawn_goblin("forest_%d"%i,(landscape as JourneyLandscape).ground_at(positions[i])+Vector3.UP*0.08)
 else:
  add_portal(Vector3(0,0,36),"forest",Vector3(0,0,-34),"返回波克布林森林")
  var positions:=JourneyData.enemy_spawns(zone)
  for i in range(positions.size()):spawn_goblin("cave_%d"%i,positions[i]+Vector3.UP*0.08)
  if not journal.chapter_one_completed:spawn_goblin("golden_boss",Vector3(0,0.08,-27),true)
 for data in JourneyData.points(zone):
  var object:=JourneyObject.new();object.arena=self;object.data=data;object.position=(landscape as JourneyLandscape).ground_at(data.p);add_child(object);world_objects.append(object);room_actors.append(object)
 for portal in portals:
  var label:=Label3D.new();label.text=portal.title+" [E]";label.position=portal.position+Vector3.UP*1.7;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.font_size=30;label.pixel_size=0.008;label.modulate=Color("e3d8a1");landscape.add_child(label)
 zone_label.text=ZONE_NAMES[zone];portal_cooldown=1.1;changing_room=false
 show_banner(ZONE_NAMES[zone],{"village":"营火、委托与归途。","forest":"循着林道，清理三处哨点。","cave":"点亮营火，深入黄金獠牙的巢穴。"}[zone])
func add_portal(p: Vector3,destination: String,spawn: Vector3,title: String,locked: bool=false) -> void:
 super.add_portal((landscape as JourneyLandscape).ground_at(p),destination,spawn,title,locked)
func transition_room(destination: String,spawn: Vector3) -> void:
 await super.transition_room(destination,spawn)
 if not journal.activate_camp("entrance/"+destination,destination,hero.position):adventure_ui.notify(journal.last_error)
func nearest_interaction() -> Dictionary:
 var best:=2.1
 var result: Dictionary={}
 var entries: Array=[]
 for npc in villagers:entries.append({"kind":"npc","node":npc,"p":npc.position})
 for point in world_objects:
  if not (point.opened and point.data.kind=="gather"):entries.append({"kind":"point","node":point,"p":point.position})
 if is_instance_valid(forge):entries.append({"kind":"smith","node":forge,"p":forge.smith_position()})
 for portal in portals:entries.append({"kind":"portal","portal":portal,"p":portal.position})
 for entry in entries:
  var distance: float=hero.position.distance_to(entry.p)
  if distance<best and interaction_visible(entry):best=distance;result=entry
 return result
func interaction_visible(entry: Dictionary) -> bool:
 var query:=PhysicsRayQueryParameters3D.create(hero.position+Vector3.UP*0.9,entry.p+Vector3.UP*0.55,1)
 query.exclude=[hero.get_rid()]
 var hit:=get_world_3d().direct_space_state.intersect_ray(query)
 return hit.is_empty() or (entry.has("node") and entry.node.is_ancestor_of(hit.collider))
func world_prompt() -> String:
 if not hero.alive:return "R · 从当前营火重新出发"
 var entry:=nearest_interaction()
 if entry.is_empty():return ""
 match entry.kind:
  "npc":return "E · 与%s交谈"%entry.node.data.name
  "smith":return "E · 与铁匠阿伦交谈"
  "point":return "E · "+("休整并记录归途" if entry.node.data.kind=="camp" else ("已开启" if entry.node.opened else entry.node.data.name))
  "portal":return "清理森林三处哨点后可进入洞穴" if entry.portal.locked and living_enemy_count()>0 else "E · "+entry.portal.title
 return ""
func interaction_allowed() -> bool:
 if menu_open or changing_room or not hero.alive or not hero.is_on_floor() or hero.blades.busy() or hero.attack_time>0 or hero.dash_time>0:return false
 for enemy_ in bokoblins:
  if enemy_.alive and enemy_.position.distance_to(hero.position)<3.5:
   adventure_ui.notify("附近有敌人，先脱离战斗再交互。")
   return false
 return true
func handle_world_interaction() -> void:
 if not interaction_allowed():return
 if zone=="cave" and is_instance_valid(boss) and not boss.alive and not journal.chapter_one_completed:
  finish_chapter();return
 var entry:=nearest_interaction()
 if entry.is_empty():return
 match entry.kind:
  "npc":
   if entry.node.data.id=="scout" and not journal.mark_scout():adventure_ui.notify(journal.last_error);return
   (adventure_ui as JourneyUI).npc_id=entry.node.data.id;set_menu("npc")
  "smith":set_menu("smith")
  "point":interact_point(entry.node)
  "portal":
   if portal_cooldown<=0:travel(entry.portal)
func interact_point(point: JourneyObject) -> bool:
 if not interaction_allowed() or not is_instance_valid(point) or point not in world_objects or hero.position.distance_to(point.position)>=2.1:return false
 if not interaction_visible({"node":point,"p":point.position}):return false
 if point.data.kind=="camp":
  if zone=="cave" and boss_started and is_instance_valid(boss) and boss.alive:adventure_ui.notify("首领战中无法休整。");return false
  if not journal.activate_camp(point.data.id,zone,point.position+Vector3(1.3,0,0)):
   adventure_ui.notify(journal.last_error);return false
  checkpoint_zone=zone;checkpoint_spawn=point.position+Vector3(1.3,0.08,0);point.refresh();rest_hero();adventure_ui.notify("已休整，归途记录在这处营火。");return true
 if not journal.claim_point(point.data.id,point.data.reward):adventure_ui.notify(journal.last_error);return false
 point.refresh();adventure_ui.notify("获得："+reward_text(point.data.reward));play_tone(680,0.08,0.05)
 burst(point.position+Vector3.UP*0.3,Color("d9c492"),8)
 return true
func reward_text(reward: Dictionary) -> String:
 var parts:=PackedStringArray()
 for item in reward:
  parts.append(JourneyData.GEAR[reward[item]].name if item=="gear" else "%s ×%d"%[journal.item_name(item),reward[item]])
 return "、".join(parts)
func set_menu(mode: String="") -> void:
 if changing_room:return
 super.set_menu(mode)
func apply_equipment() -> void:
 var values:=journal.stats()
 hero.max_hp=int(values.hp);hero.hp=mini(hero.hp,hero.max_hp);hero.speed=float(values.speed)
func incoming_damage(amount: int,kind: String="physical") -> int:
 var values:=journal.stats()
 if kind=="physical":return maxi(1,roundi(amount*100.0/maxf(25,100+float(values.defense))))
 return maxi(1,roundi(amount*(1-clampf(float(values.get(kind,0)),-100,75)/100.0)))
func use_potion(id: String) -> bool:
 if not hero.alive or changing_room or potion_cooldown>0 or menu_mode not in ["","bag"]:return false
 var meter: float=hero.blades.magic_meters[journal.equipped_sword]
 if (id=="potion" and hero.hp>=hero.max_hp) or (id=="ether" and meter>=100):adventure_ui.notify("当前已恢复至上限，未消耗药品。");return false
 if not journal.consume(id):adventure_ui.notify(journal.last_error);return false
 if id=="potion":hero.hp=mini(hero.max_hp,hero.hp+3)
 else:hero.blades.magic_meters[journal.equipped_sword]=minf(100,meter+50)
 potion_cooldown=1.0;adventure_ui.notify("已使用"+journal.item_name(id));return true
func _process(delta: float) -> void:
 if not is_instance_valid(hero) or not is_instance_valid(landscape):return
 if Input.is_action_just_pressed("mute"):muted=not muted
 elapsed+=delta;portal_cooldown=maxf(0,portal_cooldown-delta);potion_cooldown=maxf(0,potion_cooldown-delta)
 if not menu_open and not changing_room:
  if Input.is_action_just_pressed("restart"):respawn_at_checkpoint.call_deferred()
  if hero.position.y < -4:respawn_at_checkpoint.call_deferred()
  if zone=="cave" and is_instance_valid(boss) and boss.alive and not boss_started:
   var guards_alive:=false
   for actor in bokoblins:guards_alive=guards_alive or (actor!=boss and actor.alive)
   landscape.set_gate(guards_alive)
   if not guards_alive and hero.position.z< -14.5:
    boss_started=true;landscape.set_gate(true);boss.engage();show_banner("黄金波克布林","观察预警，在收招时反击。")
 hp_label.text="生命  "+"● ".repeat(hero.hp)+"○ ".repeat(hero.max_hp-hero.hp)
 dash_bar.value=0.85-hero.dash_cooldown
 boss_panel.visible=zone=="cave" and is_instance_valid(boss) and boss.alive and boss_started and not menu_open
 if boss_panel.visible:boss_bar.max_value=boss.max_hp;boss_bar.value=boss.hp;boss_label.text="黄金波克布林"+(" · 震怒" if boss.enraged else " · 洞穴霸主")+"  %d / %d"%[boss.hp,boss.max_hp]
 update_objective()
 if not hero.alive:message.modulate.a=1;message.text="暂歇片刻，再踏旅途。\nR · 从当前营火重新出发"
 shake=maxf(0,shake-delta);update_pixel_camera(delta)
func update_objective() -> void:
 var id: String=journal.journey.tracked
 var state:=journal.quest_state(id)
 objective_label.text=(JourneyData.QUESTS[id].name+"\n"+journal.quest_detail(id)) if state=="active" else ("与村长榆伯交谈，了解林道。" if journal.quest_state("main")=="available" else "自由探索 · 还有村民在等你。")
 status_label.text="林道哨兵剩余 %d / 12"%living_enemy_count() if zone=="forest" else ("洞口守卫与首领" if zone=="cave" else "安全区域 · 营火可休整")
func update_pixel_camera(delta: float) -> void:
 if not is_instance_valid(hero):return
 var window:=Vector2(DisplayServer.window_get_size()) if DisplayServer.get_name()!="headless" else Vector2(1280,800)
 pixel_world.size=Vector2i(ceili(window.x),ceili(window.y))
 var goal:=hero.position+Vector3(0,0,-3.5)
 focus=goal if focus==Vector3.INF else focus.lerp(goal,minf(1,delta*6))
 var offset:=Vector3(4.5,7,14)
 camera.global_position=focus+offset
 camera.look_at(camera.global_position-offset+Vector3.UP*0.6)
 pixel_display.position=Vector2.ZERO;pixel_display.size=get_viewport().get_visible_rect().size
func enemy_defeated(target: Node3D) -> void:
 if target is GoldenBokoblin:
  if target.get_instance_id() in dropped_enemy_ids:return
  dropped_enemy_ids.append(target.get_instance_id());defeated.cave.append("golden_boss");landscape.set_gate(false);finish_chapter();return
 var id:=str(target.get_meta("chapter_id",""))
 if not journal.record_kill(id):adventure_ui.notify(journal.last_error)
 super.enemy_defeated(target)
func finish_chapter() -> void:
 if not journal.boss_reward():adventure_ui.notify(journal.last_error+" 通关奖励未入账，按 E 重试。");return
 chapter_finished=true;completion_pending=false;won=true
 show_banner("深林重归宁静","战利品已收好。返回青芽村，向榆伯报告。")
 adventure_ui.notify("黄金波克布林已击败。村长正在等你的消息。")
func victory() -> void:
 if zone=="forest":show_banner("三处哨点已清理","北端通往幽根洞穴的道路已打开。")
func respawn_at_checkpoint() -> void:
 if changing_room:return
 if menu_open:set_menu()
 hero.alive=true;hero.hurt_time=0;hero.hurt_flash=0;hero.hit_pause=0;hero.sprite_view.death_time=0;hero.sprite_view.sprite.scale=Vector3.ONE;hero.dash_time=0;hero.dash_cooldown=0
 var destination:=checkpoint_zone;var p:=checkpoint_spawn
 defeated[destination]=[]
 load_room(destination,p);rest_hero();hero.set_physics_process(true)
func capture_finished_game() -> void:
 var captures: Array=[]
 for area in ["village","forest","cave"]:
  load_room(area,Vector3(0,0,14) if area=="village" else Vector3(0,0,24))
  for actor in bokoblins:actor.set_physics_process(false)
  for i in range(20):await get_tree().physics_frame
  hero.set_physics_process(false);message.modulate.a=0;update_pixel_camera(0)
  RenderingServer.force_draw()
  var path: String="res://artifacts/journey-"+area+".png"
  print("JOURNEY_CAPTURE ",path)
  captures.append({"area":area,"saved":get_viewport().get_texture().get_image().save_png(path)==OK,"extent":[40,40],"objects":world_objects.size(),"npcs":villagers.size(),"persistent":journal.persistence_enabled})
 # Capture the actual boss arena in a deterministic, isolated review state.
 hero.position=Vector3(0,0.08,-20);hero.velocity=Vector3.ZERO;focus=Vector3.INF
 for actor in bokoblins:
  if actor!=boss:actor.hide()
 boss_started=true
 if is_instance_valid(boss):boss.engage();boss.set_physics_process(false)
 landscape.set_gate(true)
 update_pixel_camera(0);message.modulate.a=0
 for i in range(5):await get_tree().process_frame
 RenderingServer.force_draw()
 captures.append({"path":"journey-boss.png","saved":get_viewport().get_texture().get_image().save_png("res://artifacts/journey-boss.png")==OK})
 load_room("village",Vector3(0,0,14))
 # Demonstrate the dialogue using real quest state, without writing player saves.
 var ui: JourneyUI=adventure_ui
 ui.npc_id="chief";set_menu("npc")
 for i in range(4):await get_tree().process_frame
 RenderingServer.force_draw()
 captures.append({"path":"journey-dialogue.png","saved":get_viewport().get_texture().get_image().save_png("res://artifacts/journey-dialogue.png")==OK})
 set_menu()
 for mode in ["equipment","bag","quests","map"]:
  set_menu(mode)
  for i in range(4):await get_tree().process_frame
  RenderingServer.force_draw()
  captures.append({"path":"journey-ui-"+mode+".png","saved":get_viewport().get_texture().get_image().save_png("res://artifacts/journey-ui-"+mode+".png")==OK})
 set_menu()
 var file:=FileAccess.open("res://artifacts/journey-captures.json",FileAccess.WRITE);file.store_string(JSON.stringify(captures,"\t"))
 var success:=true
 for entry in captures:success=success and entry.saved
 print("JOURNEY_CAPTURE_COMPLETE ",success," ",captures.size())
 get_tree().quit(0 if success else 1)
