class_name JourneyUI
extends AdventureUI
var modal: PanelContainer
var modal_content: VBoxContainer
var modal_status: Label
var npc_id:=""
var selected_slot:=""
var page_title: Label
var root_control: Control
var quick: Label
var start_button: Button
func _ready() -> void:
 layer=8
 root_control=Control.new()
 root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 root_control.mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_child(root_control)
 var hud_box:=PanelContainer.new()
 hud_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
 hud_box.offset_left=24;hud_box.offset_right=365;hud_box.offset_top=-174;hud_box.offset_bottom=-86
 hud_box.mouse_filter=Control.MOUSE_FILTER_IGNORE
 hud_box.add_theme_stylebox_override("panel",panel_style())
 root_control.add_child(hud_box)
 var col:=VBoxContainer.new();hud_box.add_child(col)
 hud=label(col,"",14)
 mp_bar=ProgressBar.new();mp_bar.max_value=100;mp_bar.show_percentage=false;mp_bar.custom_minimum_size.y=5
 col.add_child(mp_bar)
 quick=label(col,"",13,Color("c5cdb3"))
 prompt=label(root_control,"",19,Color("ffe1a2"))
 prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
 prompt.offset_left=-450;prompt.offset_right=450;prompt.offset_top=-125;prompt.offset_bottom=-95
 prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 toast=label(root_control,"",17,Color("ffe1a2"))
 toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
 toast.offset_left=-420;toast.offset_right=420;toast.offset_top=35
 toast.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 shade=ColorRect.new();shade.color=Color(0.025,0.04,0.035,0.80)
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 root_control.add_child(shade)
 modal=PanelContainer.new()
 modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
 modal.offset_left=-480;modal.offset_right=480;modal.offset_top=-355;modal.offset_bottom=355
 modal.add_theme_stylebox_override("panel",panel_style())
 root_control.add_child(modal)
 var outer:=VBoxContainer.new();outer.add_theme_constant_override("separation",10);modal.add_child(outer)
 var head:=HBoxContainer.new();outer.add_child(head)
 page_title=label(head,"",26,Color("f1d49a"));page_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 button(head,"关闭 [Esc]",func():arena.set_menu())
 var tabs:=HBoxContainer.new();outer.add_child(tabs)
 for pair in [["equipment","装备 [I]"],["bag","背包 [B]"],["quests","委托 [T]"],["map","地图 [Tab]"]]:
  var id: String=pair[0]
  button(tabs,pair[1],func():arena.set_menu(id))
 var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;outer.add_child(scroll)
 modal_content=VBoxContainer.new();modal_content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;modal_content.add_theme_constant_override("separation",10);scroll.add_child(modal_content)
 modal_status=label(outer,"进度会自动保存。",14,Color("bbc8b5"));modal_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 shade.hide();modal.hide()
 refresh()
func clear_content() -> void:
 for child in modal_content.get_children():
  modal_content.remove_child(child);child.queue_free()
func heading(text_: String) -> void:
 label(modal_content,text_,19,Color("eed8a7"))
func paragraph(text_: String) -> Label:
 var result:=label(modal_content,text_,16)
 result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 return result
func show_menu(mode: String) -> void:
 shade.visible=mode!="";modal.visible=mode!=""
 if mode=="":return
 clear_content()
 modal_status.text="进度自动保存 · 药品、装备、采集和委托会保留。"
 page_title.text={"title":"森之刃","pause":"旅途暂歇","equipment":"旅人装备","bag":"背包与药品","quests":"村民委托","map":"区域地图","npc":"村中交谈","smith":"阿伦 · 铁匠"}.get(mode,mode)
 match mode:
  "title":
   paragraph("第一章 · 深林的金色獠牙")
   heading("青芽村的营火还亮着，北边的林道却已久无人归。")
   paragraph("在村庄接取委托，备好药品；沿林道寻找营火、素材与宝箱，深入洞穴挑战黄金波克布林。")
   start_button=button(modal_content,"继续旅程" if FileAccess.file_exists(arena.progress.save_path) else "踏上旅途",func():arena.set_menu())
   controls()
  "pause":
   button(modal_content,"继续旅程",func():arena.set_menu())
   button(modal_content,"保存进度",func():notify("进度已保存。" if arena.progress.save() else arena.progress.last_error))
   button(modal_content,"音效："+("关闭" if arena.muted else "开启"),func():arena.muted=not arena.muted;show_menu("pause"))
   button(modal_content,"返回标题",func():arena.set_menu("title"))
   controls()
  "equipment":build_equipment()
  "bag":build_bag()
  "quests":build_quests()
  "map":
   var map_:=JourneyMap.new();map_.arena=arena;map_.custom_minimum_size=Vector2(780,420);modal_content.add_child(map_)
   paragraph("白：旅人　红：敌人　金：宝箱／首领　绿：采集　蓝：村民　橙：营火\n靠近地图边缘的路标按 E 切换区域。营火可休整并设置重返点。")
  "npc":build_npc()
  "smith":
   speech=paragraph("");choices=VBoxContainer.new();modal_content.add_child(choices)
   dialogue_page="main";build_dialogue()
 refresh()
func controls() -> void:
 paragraph("WASD／方向键　移动\nJ／左键　普攻　K　武器技　Q　满槽魔法\n1／2／3　切换武器　空格　跳跃　Shift　冲刺\nE　交谈／采集／开箱／营火／区域入口\nI　装备　B　背包　T　委托　Tab　地图\n4　回复药　5　魔力药　Esc　暂停／返回\nR　从当前营火或区域入口重新出发")
func build_equipment() -> void:
 var data: JourneyProgress=arena.progress
 var stats_: Dictionary=data.stats()
 paragraph("生命上限 %d　攻击 %d　物防 %d　移速 %.1f\n风抗 %+d%%　火抗 %+d%%　雷抗 %+d%%\n负抗性表示对应弱点；物防仅影响物理伤害。"%[stats_.hp,data.sword_damage(),stats_.defense,stats_.speed,stats_.wind,stats_.fire,stats_.thunder])
 heading("武器")
 for id in SwordArsenal.ORDER:
  var weapon_id: String=id
  var b:=button(modal_content,"%s +%d　%s"%[SwordArsenal.data(id).name,data.sword_levels[id],"已装备" if data.equipped_sword==id else "装备"],func():
   var ok: bool=arena.hero.blades.switch_sword(weapon_id)
   show_menu("equipment");notify("已切换武器。" if ok else "先结束当前动作再切换。"))
  b.disabled=data.equipped_sword==id
 heading("防具与饰品 · 共六个装备位置（含武器）")
 for slot in JourneyData.SLOT_NAMES:
  var slot_id: String=slot
  var id: String=data.journey.gear[slot]
  button(modal_content,JourneyData.SLOT_NAMES[slot]+"　"+(JourneyData.GEAR[id].name if id!="" else "未装备")+"　›",func():show_gear_picker(slot_id))
 paragraph("装备可从探索宝箱、村民委托与行商处获得。武器强化仍需与阿伦交谈。")
func show_gear_picker(slot: String) -> void:
 clear_content()
 var data: JourneyProgress=arena.progress
 heading("选择"+JourneyData.SLOT_NAMES[slot])
 var count:=0
 for id in data.journey.owned:
  if not data.valid_slot(id,slot):continue
  count+=1
  var gear_id: String=id
  button(modal_content,JourneyData.GEAR[id].name+"　"+JourneyData.GEAR[id].hint,func():
   var ok:=data.equip_gear(gear_id,slot)
   arena.apply_equipment();show_menu("equipment");notify("装备已更新。" if ok else data.last_error))
 if count==0:paragraph("暂未找到该位置的装备。探索宝箱或完成村民委托后再来看看。")
 button(modal_content,"卸下此位置的装备",func():
  if data.equip_gear("",slot):arena.apply_equipment();show_menu("equipment")
  else:notify(data.last_error))
 button(modal_content,"返回装备",func():show_menu("equipment"))
func build_bag() -> void:
 var data: JourneyProgress=arena.progress
 heading("药品")
 paragraph("当前生命 %d / %d　金币 %d"%[arena.hero.hp,arena.hero.max_hp,data.gold])
 for pair in [["potion","回复药","恢复 3 点生命"],["ether","魔力药","恢复当前武器 50 点魔法"]]:
  var id: String=pair[0]
  var b:=button(modal_content,"%s ×%d　%s　使用"%[pair[1],data.quantity(id),pair[2]],func():arena.use_potion(id);show_menu("bag"))
  b.disabled=data.quantity(id)<=0
 heading("材料")
 for id in ["ore","fang","stone","herb","wood","cargo"]:paragraph("%s　× %d"%[data.item_name(id),data.quantity(id)])
func build_quests() -> void:
 var data: JourneyProgress=arena.progress
 for id in JourneyData.QUESTS:
  var quest_id: String=id
  var q: Dictionary=JourneyData.QUESTS[id]
  var state:=data.quest_state(id)
  heading(q.name+"　"+{"available":"未接取","active":"进行中","done":"已完成"}[state])
  paragraph(q.text+"\n"+data.quest_detail(id))
  var giver: String="阿伦 · 铁匠" if q.giver=="smith" else ""
  for npc in JourneyData.NPCS:
   if npc.id==q.giver:giver=npc.name+" · "+npc.role
  paragraph("委托人："+giver+"（青芽村）\n奖励："+arena.reward_text(q.reward))
  var b:=button(modal_content,"正在追踪" if data.journey.tracked==id else "追踪此委托",func():
   if data.track(quest_id):show_menu("quests")
   else:notify(data.last_error))
  b.disabled=data.journey.tracked==id or state!="active"
func quest_choices(parent: VBoxContainer,npc: String) -> void:
 var id:=JourneyData.quest_for(npc)
 if id=="":return
 var data: JourneyProgress=arena.progress
 var q: Dictionary=JourneyData.QUESTS[id]
 label(parent,q.name+" · "+data.quest_detail(id),17,Color("e6cf9b"))
 var desc:=label(parent,q.text+"\n奖励："+arena.reward_text(q.reward),15)
 desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 if data.quest_state(id)=="available":
  button(parent,"接取委托",func():
   var ok:=data.accept_quest(id)
   show_menu(arena.menu_mode);notify("已接取："+q.name if ok else data.last_error))
 elif data.quest_state(id)=="active":
  var b:=button(parent,"交付委托并领取奖励",func():
   var ok:=data.turn_in(id)
   arena.apply_equipment();show_menu(arena.menu_mode);notify("委托完成："+q.name if ok else data.last_error))
  b.disabled=not data.quest_ready(id)
func build_npc() -> void:
 var npc: Dictionary={}
 for value in JourneyData.NPCS:
  if value.id==npc_id:npc=value
 if npc.is_empty():return
 page_title.text=npc.name+" · "+npc.role
 paragraph(npc.speech)
 quest_choices(modal_content,npc_id)
 if npc_id in ["merchant","herbalist"]:
  heading("补给")
  for pair in [["potion","回复药 · 8 金币"],["ether","魔力药 · 10 金币"],["linen_cap","旅人布帽 · 20 金币"],["trail_boots","林径短靴 · 35 金币"]]:
   if npc_id=="herbalist" and pair[0] not in ["potion","ether"]:continue
   var id: String=pair[0]
   button(modal_content,pair[1],func():
    var ok: bool=arena.progress.buy(id)
    show_menu("npc");notify("购买成功。" if ok else arena.progress.last_error))
 if npc_id=="innkeeper":button(modal_content,"休息片刻，恢复生命与魔法",func():arena.rest_hero();notify("已恢复生命与魔法。"))
 button(modal_content,"结束交谈",func():arena.set_menu())
func build_dialogue(message_: String="") -> void:
 super.build_dialogue(message_)
 if dialogue_page=="main":quest_choices(choices,"smith")
func notify(content_: String) -> void:
 super.notify(content_)
 if is_instance_valid(modal_status):modal_status.text=content_
func refresh() -> void:
 if not is_instance_valid(arena.hero):return
 var data: JourneyProgress=arena.progress
 var sword: Dictionary=SwordArsenal.data(data.equipped_sword)
 var mp:=int(arena.hero.blades.magic_meters[data.equipped_sword])
 hud.text="%s +%d　攻击 %d　魔法 %d/100"%[sword.name,data.sword_level,data.sword_damage(),mp]
 mp_bar.value=mp
 quick.text="[4] 回复药 %d　[5] 魔力药 %d　金币 %d"%[data.quantity("potion"),data.quantity("ether"),data.gold]
func _process(delta: float) -> void:
 refresh()
 toast_time=maxf(0,toast_time-delta)
 toast.visible=toast_time>0 and not arena.menu_open
 if toast_time<=0:notes.clear()
 prompt.text=arena.world_prompt() if not arena.menu_open else ""
func _input(event: InputEvent) -> void:
 if event.is_echo() or arena.changing_room:return
 if arena.menu_mode=="title":
  if event is InputEventKey and event.pressed and event.physical_keycode==KEY_ENTER:arena.set_menu();get_viewport().set_input_as_handled()
  return
 if event.is_action_pressed("equipment"):
  arena.set_menu("" if arena.menu_mode=="equipment" else "equipment")
 elif event.is_action_pressed("forge"):
  if not arena.menu_open:arena.handle_world_interaction()
  elif arena.menu_mode in ["npc","smith"]:arena.set_menu()
 elif event.is_action_pressed("forge_close"):
  arena.set_menu("" if arena.menu_open else "pause")
 elif event is InputEventKey and event.pressed:
  match event.physical_keycode:
   KEY_B:arena.set_menu("" if arena.menu_mode=="bag" else "bag")
   KEY_T:arena.set_menu("" if arena.menu_mode=="quests" else "quests")
   KEY_TAB:arena.set_menu("" if arena.menu_mode=="map" else "map")
   KEY_4:arena.use_potion("potion")
   KEY_5:arena.use_potion("ether")
   _:return
 else:return
 get_viewport().set_input_as_handled()
