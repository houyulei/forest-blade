class_name AdventureUI
extends CanvasLayer
var arena: Node3D
var hud: Label
var mp_bar: ProgressBar
var prompt: Label
var toast: Label
var toast_time := 0.0
var notes := PackedStringArray()
var shade: ColorRect
var equipment: PanelContainer
var inventory: Label
var stats: Label
var gear: Label
var sword_buttons := {}
var sword_help: Label
var equipment_status: Label
var dialogue: PanelContainer
var speech: Label
var choices: VBoxContainer
var dialogue_page := "main"

func label(parent: Node, content: String, size_: int = 17, color: Color = Color("e8e4ca")) -> Label:
	var result := Label.new()
	result.text = content
	result.add_theme_font_size_override("font_size",size_)
	result.add_theme_color_override("font_color",color)
	parent.add_child(result)
	return result

func button(parent: Node, title: String, callback: Callable) -> Button:
	var result := Button.new()
	result.text = title
	result.custom_minimum_size.y = 38
	result.add_theme_font_size_override("font_size",16)
	result.pressed.connect(callback)
	parent.add_child(result)
	return result

func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("182b25")
	style.set_corner_radius_all(9)
	style.set_content_margin_all(22)
	style.border_color = Color(0.7,0.55,0.3,0.55)
	style.set_border_width_all(1)
	return style

func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var card := PanelContainer.new()
	card.position = Vector2(24,254)
	card.size = Vector2(352,108)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel",panel_style())
	root.add_child(card)
	var hud_column := VBoxContainer.new()
	card.add_child(hud_column)
	hud = label(hud_column,"",15)
	mp_bar = ProgressBar.new()
	mp_bar.max_value = 100
	mp_bar.show_percentage = false
	mp_bar.custom_minimum_size = Vector2(300,6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("f0a05e")
	mp_bar.add_theme_stylebox_override("fill",fill)
	hud_column.add_child(mp_bar)
	prompt = label(root,"",18,Color("ffdc9b"))
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left = -410
	prompt.offset_right = 410
	prompt.offset_top = -123
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast = label(root,"",18,Color("ffe2a5"))
	toast.position = Vector2(42,400)
	shade = ColorRect.new()
	shade.color = Color(0.015,0.035,0.025,0.74)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	equipment = PanelContainer.new()
	equipment.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	equipment.offset_left = -460
	equipment.offset_right = 460
	equipment.offset_top = -340
	equipment.offset_bottom = 340
	equipment.add_theme_stylebox_override("panel",panel_style())
	root.add_child(equipment)
	var eq_column := VBoxContainer.new()
	eq_column.add_theme_constant_override("separation",14)
	equipment.add_child(eq_column)
	label(eq_column,"装备",28,Color("f4d49a"))
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation",28)
	eq_column.add_child(content)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 210
	content.add_child(left)
	var portrait := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = HeroSprite.POSES
	atlas.region = Rect2(0,0,320,320)
	portrait.texture = atlas
	portrait.custom_minimum_size = Vector2(190,190)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	left.add_child(portrait)
	gear = label(left,"",17)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation",12)
	content.add_child(right)
	stats = label(right,"",20)
	label(right,"三种元素武器",14,Color("b7bda5"))
	for id in SwordArsenal.ORDER:
		var sword_id: String = id
		sword_buttons[id] = button(right,"",func(): equip(sword_id))
	sword_help = label(right,"",16,Color("d1c39e"))
	sword_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inventory = label(eq_column,"",17)
	equipment_status = label(eq_column,"带上素材，找铁匠阿伦强化装备。",15,Color("b4c6b5"))
	button(eq_column,"返回森林 [I / Esc]",func(): arena.set_menu())
	dialogue = PanelContainer.new()
	dialogue.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	dialogue.offset_left = -445
	dialogue.offset_right = 445
	dialogue.offset_top = -395
	dialogue.offset_bottom = -90
	dialogue.add_theme_stylebox_override("panel",panel_style())
	root.add_child(dialogue)
	var dialog_column := VBoxContainer.new()
	dialog_column.add_theme_constant_override("separation",8)
	dialogue.add_child(dialog_column)
	label(dialog_column,"阿伦 / 铁匠",20,Color("f4d49a"))
	speech = label(dialog_column,"",17)
	speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choices = VBoxContainer.new()
	choices.add_theme_constant_override("separation",5)
	dialog_column.add_child(choices)
	shade.hide()
	equipment.hide()
	dialogue.hide()
	refresh()

func notify(content: String) -> void:
	notes.append(content)
	while notes.size()>3:
		notes.remove_at(0)
	toast_time = 3.5
	toast.text = "\n".join(notes)

func equip(id: String) -> void:
	equipment_status.text = "已切换元素武器。" if arena.hero.blades.switch_sword(id) else (arena.progress.last_error if arena.progress.last_error!="" else "先完成当前动作，再切换武器。")
	refresh()

func show_menu(mode: String) -> void:
	shade.visible = mode!=""
	equipment.visible = mode=="equipment"
	dialogue.visible = mode=="smith"
	if mode=="smith":
		dialogue_page = "main"
		build_dialogue()
	refresh()

func build_dialogue(message_: String = "") -> void:
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()
	var data: AdventureProgress = arena.progress
	if dialogue_page=="sell":
		speech.text = message_ if message_!="" else "多余的素材我可以收下。你想卖些什么？"
		for item in AdventureProgress.ITEMS:
			var id: String = item
			var sale := button(choices,"出售 1 个%s / 持有 %d / 获得 %d 金币" % [AdventureProgress.ITEMS[id].name,data.materials[id],AdventureProgress.ITEMS[id].sell],func():
				var ok: bool = data.sell(id)
				build_dialogue("收下了。还需要什么？" if ok else data.last_error))
			sale.disabled = data.materials[id]<=0
		button(choices,"返回",func():
			dialogue_page = "main"
			build_dialogue())
		return
	speech.text = message_ if message_!="" else "武器也需要养护。带来铁矿和怪物素材，我来帮你锻造。"
	var sword := button(choices,"强化%s至 +%d / %s" % [SwordArsenal.data(data.equipped_sword).name,data.sword_level+1,data.cost_text("sword")],func(): craft("sword"))
	sword.disabled = not data.can_craft("sword")
	if data.sword_level>=3:
		sword.text = "这把剑已达到当前强化上限。"
	var core := button(choices,"精炼焰锋大剑结晶 / "+data.cost_text("fire_core"),func(): craft("fire_core"))
	core.disabled = not data.can_craft("fire_core")
	button(choices,"出售多余素材",func():
		dialogue_page = "sell"
		build_dialogue())
	button(choices,"休息片刻后离开",func():
		arena.hero.hp = arena.hero.max_hp
		arena.hero.blades.magic_meters = {"wind":100.0,"fire":100.0,"thunder":100.0}
		arena.hero.mp = 100
		arena.set_menu())

func craft(id: String) -> void:
	var ok: bool = arena.progress.craft(id)
	build_dialogue(("好了，武器更锋利了。" if id=="sword" else "焰锋大剑结晶精炼好了。火焰更远，也更强。") if ok else arena.progress.last_error)
	if ok:
		arena.play_tone(610,0.1,0.06)
	refresh()

func refresh() -> void:
	var data: AdventureProgress = arena.progress
	var combat: BladeCombat = arena.hero.blades
	var sword: Dictionary = SwordArsenal.data(data.equipped_sword)
	var extra := ""
	if data.equipped_sword=="fire" and combat.state=="charge":
		extra = " · 蓄力 %d%%" % roundi(combat.charge*100)
	elif data.equipped_sword=="thunder":
		extra = " · 电能 "+"●".repeat(combat.thunder_charge)+"○".repeat(3-combat.thunder_charge)
	elif combat.wind_window>0 and data.equipped_sword=="wind":
		extra = " · J 接旋风 %d/5" % combat.wind_count
	hud.text = "%s +%d　攻击 %d\nK %s　Q %s\n魔法 %d/100%s\n金币 %d　铁矿 %d　牙 %d　碎片 %d" % [sword.name,data.sword_level,data.sword_damage(),sword.skill,sword.magic,int(combat.magic_meters[data.equipped_sword]),extra,data.gold,data.materials.ore,data.materials.fang,data.materials.stone]
	mp_bar.value = combat.magic_meters[data.equipped_sword]
	(mp_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = sword.color
	gear.text = "当前武器\n%s +%d\n\n武器技：%s\n元素魔法：%s" % [sword.name,data.sword_level,sword.skill,sword.magic]
	var hits: Array[String] = []
	var times: Array[String] = []
	for index in range(1,4):
		var motion := SwordMotion.profile(index,data.equipped_sword)
		hits.append(str(data.sword_damage()+int(motion.bonus)))
		times.append("%.2f" % float(motion.duration))
	stats.text = "普攻伤害　%s\n出招用时　%s 秒\n魔法槽　%d / 100" % [" / ".join(hits)," / ".join(times),int(combat.magic_meters[data.equipped_sword])]
	sword_help.text = sword.style+"\n"+sword.hint+"\nQ：满槽释放元素魔法"
	inventory.text = "素材\n金币 %d　铁矿 %d　怪物牙 %d　守卫碎片 %d" % [data.gold,data.materials.ore,data.materials.fang,data.materials.stone]
	for id in sword_buttons:
		sword_buttons[id].text = "[%d] %s +%d　%s" % [SwordArsenal.ORDER.find(id)+1,SwordArsenal.data(id).name,data.sword_levels[id],"已装备" if data.equipped_sword==id else "装备"]
		sword_buttons[id].disabled = data.equipped_sword==id

func _process(delta: float) -> void:
	refresh()
	toast_time = maxf(0,toast_time-delta)
	toast.visible = toast_time>0 and not arena.menu_open
	if toast_time<=0:
		notes.clear()
	prompt.text = "E · 与铁匠阿伦交谈" if arena.near_forge() and not arena.menu_open else ""

func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("equipment"):
		arena.set_menu("" if arena.menu_mode=="equipment" else "equipment")
	elif event.is_action_pressed("forge"):
		if arena.menu_mode=="smith":
			arena.set_menu()
		elif not arena.menu_open and arena.near_forge():
			arena.set_menu("smith")
		elif not arena.menu_open:
			if arena.has_method("handle_world_interaction"):
				arena.handle_world_interaction()
			else:
				notify("铁匠阿伦就在空地东侧的火炉旁。")
	elif arena.menu_open and event.is_action_pressed("forge_close"):
		arena.set_menu()
	else:
		return
	get_viewport().set_input_as_handled()
