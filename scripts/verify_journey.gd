extends SceneTree
var game
var checks: Array=[]
var failed:=false
func _initialize() -> void:
 run.call_deferred()
func check(ok: bool,text_: String) -> void:
 checks.append({"check":text_,"passed":ok});failed=failed or not ok
 print("PASS: " if ok else "FAIL: ",text_)
func step(count:=6) -> void:
 for i in range(count):await physics_frame;await process_frame
func key(code: Key) -> void:
 var e:=InputEventKey.new();e.physical_keycode=code;e.pressed=true;Input.parse_input_event(e);await step(2)
 e=InputEventKey.new();e.physical_keycode=code;Input.parse_input_event(e);await step(2)
func buttons(parent: Node) -> Array[Button]:
 var result: Array[Button]=[]
 for child in parent.get_children():
  if child is Button:result.append(child)
  result.append_array(buttons(child))
 return result
func press_text(text_: String) -> bool:
 for b in buttons(game.adventure_ui):
  if b.text==text_ and not b.disabled:b.pressed.emit();return true
 return false
func near(p: Vector3) -> void:
 game.hero.position=Vector3(p.x+1.25,game.landscape.volume.height_at(p.x+1.25,p.z)+0.05,p.z)
 game.hero.velocity=Vector3.ZERO;game.hero.invulnerable=9999
 await step(12)
func point(id: String) -> JourneyObject:
 for actor in game.world_objects:
  if actor.data.id==id:return actor
 return null
func npc(id: String) -> JourneyNPC:
 for actor in game.villagers:
  if actor.data.id==id:return actor
 return null
func accept_from(id: String) -> void:
 if id=="smith":await near(game.forge.smith_position())
 else:await near(npc(id).position)
 game.handle_world_interaction();await step(2)
 check(game.menu_mode in ["npc","smith"],"与委托人交互："+id)
 check(press_text("接取委托"),"通过界面接取委托："+id)
 game.set_menu();await step(2)
func unit_progress() -> void:
 var p:=JourneyProgress.new();p.persistence_enabled=false
 p.restore({"version":2,"gold":47,"equipped_sword":"thunder","sword_levels":{"wind":1,"fire":2,"thunder":3},"materials":{"ore":7,"fang":4,"stone":2}})
 check(p.gold==47 and p.sword_levels.thunder==3 and p.materials.ore==7,"旧版存档保留金币、材料和三武器强化")
 check(p.quantity("potion")==3 and p.journey.gear.head=="","旧存档获得合理的新增系统默认值")
 p.claim_point("unit/chest",{"gold":15,"gear":"linen_cap","potion":1})
 check(p.quantity("potion")==4 and "linen_cap" in p.journey.owned,"宝箱原子发放物品与装备")
 var before:=p.snapshot()
 check(not p.claim_point("unit/chest",{"gold":15}) and p.snapshot()==before,"重复开启宝箱不会重复领奖")
 check(p.equip_gear("linen_cap","head") and p.stats().hp==6,"装备实际提高生命上限")
 check(not p.equip_gear("linen_cap","body"),"阻止装备放入错误位置")
 p.claim_point("unit/ring",{"gear":"wind_leaf"});p.equip_gear("wind_leaf","accessory_1")
 check(not p.equip_gear("wind_leaf","accessory_2"),"同一饰品不能在两个位置重复装备")
 p.claim_point("unit/coat",{"gear":"ember_coat"});p.equip_gear("ember_coat","body")
 check(p.stats().fire==20 and p.stats().wind==10 and p.stats().thunder==0,"风火雷抗性独立累加，允许负抗性装备")
 p.equip_gear("","accessory_1")
 check(p.stats().wind==-10 and p.stats().fire==20 and p.stats().thunder==0,"独立负风抗真实表达弱风")
 before=p.snapshot()
 p.persistence_enabled=true;p.save_path="user://missing-journey-%d/save.json"%Time.get_ticks_usec()
 check(not p.claim_point("unit/fail",{"gold":30,"potion":2}) and p.snapshot()==before,"宝箱保存失败回滚资源和领取标记")
 check(not p.consume("potion") and p.snapshot()==before,"药品保存失败不扣数量")
 check(not p.boss_reward() and p.snapshot()==before,"首领奖励保存失败时回滚资源和通关标记")
 check(not p.equip_gear("","head") and p.snapshot()==before,"装备保存失败回滚")
 p.persistence_enabled=false;p.accept_quest("herbs");p.apply_reward({"herb":3})
 before=p.snapshot();p.persistence_enabled=true
 check(not p.turn_in("herbs") and p.snapshot()==before,"任务保存失败回滚材料、奖励和完成状态")
 p.persistence_enabled=false
 check(p.turn_in("herbs") and p.quantity("herb")==0 and p.quest_state("herbs")=="done","委托交付扣除材料并一次发放奖励")
 before=p.snapshot()
 check(not p.turn_in("herbs") and p.snapshot()==before,"任务不可重复领奖")
 var path:="user://verify-journey-%d.json"%Time.get_ticks_usec()
 p.persistence_enabled=true;p.save_path=path
 check(p.save(),"新增进度写入隔离存档")
 var loaded:=JourneyProgress.new();loaded.save_path=path;loaded.load_save()
 check(loaded.snapshot()==p.snapshot(),"重载保留装备、药品、宝箱和任务")
 var legacy:=AdventureProgress.new();legacy.restore(p.snapshot())
 check(legacy.snapshot().journey==p.snapshot().journey,"旧场景存档不会丢弃新增旅程数据")
 DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
func run() -> void:
 unit_progress()
 set_meta("isolated_adventure",true)
 game=load("res://journey_chapter.tscn").instantiate();root.add_child(game);current_scene=game
 await step(30)
 check(not game.journal.persistence_enabled and game.hero.is_on_floor(),"正式场景隔离测试且主角落地")
 check(JourneyData.TOTAL_AREA/JourneyData.PREVIEW_AREA==5.0 and game.landscape.extent==Vector2(40,40),"三张区域总地表面积为所选预览可探索范围的五倍")
 check(game.villagers.size()==7 and is_instance_valid(game.forge),"村庄有七位新增村民与铁匠")
 check(game.world_objects.size()==12,"村庄布置采集、宝箱和营火")
 var before_position: Vector3=game.hero.position
 Input.action_press("up");await step(35);Input.action_release("up")
 check(game.hero.position.distance_to(before_position)>1,"真实地形行走")
 await key(KEY_I)
 check(game.menu_mode=="equipment" and not game.hero.is_physics_processing(),"装备界面打开并暂停角色")
 await key(KEY_ESCAPE)
 check(not game.menu_open and game.hero.is_physics_processing(),"关闭界面恢复角色")
 await key(KEY_B);check(game.menu_mode=="bag","背包快捷键")
 await key(KEY_T);check(game.menu_mode=="quests","委托快捷键")
 await key(KEY_TAB);check(game.menu_mode=="map","地图快捷键")
 game.set_menu()
 await accept_from("chief")
 check(game.journal.quest_state("main")=="active","主线委托已接取")
 await accept_from("herbalist")
 var herb:=point("village/gather/0")
 await near(herb.position)
 check(herb.interact() and game.journal.quantity("herb")==1,"靠近并采集青芽草")
 check(not herb.interact() and game.journal.quantity("herb")==1,"同一采集点只结算一次")
 var wood_point:=point("village/gather/1")
 await near(wood_point.position)
 var wall:=Craft.solid_box(game,wood_point.position+Vector3(0.65,0.75,0),Vector3(0.15,1.5,0.8),Craft.material(Color.GRAY))
 await step(3)
 check(not wood_point.interact(),"实体障碍阻止穿墙采集")
 wall.free()
 var chest:=point("village/chest/0")
 game.hero.position=Vector3(0,0.1,14);await step(10)
 check(not chest.interact(),"不能远程开启宝箱")
 await near(chest.position)
 check(chest.interact() and chest.opened and "linen_cap" in game.journal.journey.owned,"宝箱交互获得可装备物品")
 game.journal.equip_gear("linen_cap","head");game.apply_equipment()
 check(game.hero.max_hp==6,"装备属性应用到实际角色")
 game.hero.hp=2
 var count: int=game.journal.quantity("potion")
 game.potion_cooldown=0
 check(game.use_potion("potion") and game.hero.hp==5 and game.journal.quantity("potion")==count-1,"药品真实恢复生命并扣除数量")
 game.hero.hp=game.hero.max_hp;game.potion_cooldown=0;count=game.journal.quantity("potion")
 check(not game.use_potion("potion") and game.journal.quantity("potion")==count,"满生命不消耗药品")
 game.hero.blades.magic_meters[game.journal.equipped_sword]=20;game.potion_cooldown=0
 check(game.use_potion("ether") and game.hero.blades.magic_meters[game.journal.equipped_sword]>=70,"魔力药恢复当前武器魔法")
 game.journal.apply_reward({"herb":2,"wood":2,"ore":3,"fang":4})
 for pair in [["herbalist","herbs"],["smith","forge"],["hunter","hunt"]]:
  if game.journal.quest_state(pair[1])=="available":await accept_from(pair[0])
  await near(game.forge.smith_position() if pair[0]=="smith" else npc(pair[0]).position)
  game.handle_world_interaction();await step(2)
  check(press_text("交付委托并领取奖励"),"通过委托人界面交付："+pair[1]);game.set_menu()
 await accept_from("scout");await accept_from("farmer");await accept_from("innkeeper")
 check(game.journal.journey.scout_met,"与侦察员交谈推进主线")
 var camp:=point("village/camp/0");await near(camp.position)
 check(camp.interact(),"营火设置检查点并恢复")
 var checkpoint: Vector3=game.checkpoint_spawn
 game.hero.position+=Vector3(7,0,0);game.hero.hp=1;game.respawn_at_checkpoint();await step(20)
 check(game.hero.hp==game.hero.max_hp and game.hero.position.distance_to(checkpoint)<0.2,"重返营火保留成长并恢复生命")
 check(point("village/chest/0").opened and point("village/gather/0").opened,"重建区域不刷新已领取的宝箱和采集点")
 await near(Vector3(0,0,-36));game.portal_cooldown=0
 check(game.travel(game.portals[0]),"村庄入口可进入森林")
 await step(55)
 check(game.zone=="forest" and game.bokoblins.size()==12,"跨区到达扩大后的森林并生成三处哨点")
 for enemy in game.bokoblins:enemy.set_physics_process(false)
 await near(Vector3(0,0,-36));game.portal_cooldown=0
 check(not game.travel(game.portals[1]),"哨点未清理时洞穴入口保持锁定")
 for object in game.world_objects.duplicate():
  if object.data.kind in ["cargo","camp"]:
   await near(object.position);object.interact()
 check(game.journal.quest_ready("cargo") and game.journal.quest_ready("camps"),"找回三箱货物并点亮两处森林营火")
 for enemy in game.bokoblins.duplicate():enemy.take_hit(999,Vector3.ZERO,true)
 await step(5)
 check(game.journal.journey.kills.size()==12 and game.journal.quest_ready("patrol"),"森林战斗推进不同哨兵击败计数")
 var kills: int=game.journal.journey.kills.size();game.journal.record_kill("forest_0")
 check(game.journal.journey.kills.size()==kills,"重复击败同一哨兵不刷委托进度")
 await near(Vector3(0,0,-36));game.portal_cooldown=0
 check(game.travel(game.portals[1]),"清理后洞穴入口开放")
 await step(55)
 check(game.zone=="cave" and is_instance_valid(game.boss),"进入洞穴与黄金首领场景")
 for enemy in game.bokoblins.duplicate():
  enemy.set_physics_process(false)
  if enemy!=game.boss:enemy.take_hit(999,Vector3.ZERO,true)
 await near(Vector3(0,0,-18));await step(5)
 check(game.boss_started and game.boss.engaged,"清理守卫并深入后触发首领战")
 var gold: int=game.journal.gold
 game.boss.take_hit(999,Vector3.ZERO,true);await step(5)
 check(game.journal.chapter_one_completed and game.journal.gold==gold+80,"首领完成与战利品同一事务保存")
 game.finish_chapter()
 check(game.journal.gold==gold+80,"重试通关不重复发放首领奖励")
 await near(Vector3(0,0,36));game.portal_cooldown=0
 check(game.travel(game.portals[0]),"首领战后可以离开洞穴")
 await step(55)
 check(game.zone=="forest" and game.living_enemy_count()==0,"回访森林保留本次已清理哨点")
 await near(Vector3(0,0,36));game.portal_cooldown=0
 check(game.travel(game.portals[0]),"从森林实际返回村庄")
 await step(55)
 check(game.zone=="village","返回村庄后可以交付主线")
 for pair in [["chief","main"],["scout","patrol"],["farmer","cargo"],["innkeeper","camps"]]:
  await near(npc(pair[0]).position);game.handle_world_interaction();await step(2)
  check(press_text("交付委托并领取奖励"),"回村交付："+pair[1]);game.set_menu()
 check(game.journal.quest_state("main")=="done" and "gold_fang" in game.journal.journey.owned,"主线闭环获得金色獠牙装备")
 game.journal.equip_gear("guard_vest","body");game.apply_equipment()
 check(game.incoming_damage(4,"physical")<4 and game.incoming_damage(4,"fire")==4,"防御只降低物理伤害")
 game.set_menu("pause");check(not game.hero.is_physics_processing(),"暂停菜单冻结角色")
 game.set_menu()
 game.set_menu("title");check(not game.hero.is_physics_processing(),"标题页暂停角色")
 await key(KEY_ENTER);check(not game.menu_open and game.hero.is_physics_processing(),"Enter 从标题继续旅程")
 var path:="user://verify-journey-run-%d.json"%Time.get_ticks_usec()
 game.journal.save_path=path;game.journal.persistence_enabled=true
 check(game.journal.save(),"完整旅程保存到隔离文件")
 var loaded:=JourneyProgress.new();loaded.save_path=path;loaded.load_save()
 check(loaded.chapter_one_completed and loaded.journey.quests==game.journal.journey.quests and loaded.journey.claimed==game.journal.journey.claimed and loaded.journey.checkpoint.zone=="village","完整流程重载保留任务、探索、装备和归途")
 DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 var file:=FileAccess.open("res://artifacts/journey-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify({"passed":not failed,"checks":checks},"\t"))
 print("JOURNEY_OK" if not failed else "JOURNEY_FAILED")
 quit(1 if failed else 0)
