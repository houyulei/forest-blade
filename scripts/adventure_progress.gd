class_name AdventureProgress
extends RefCounted
## Permanent ARPG progression. Map actors reset; equipment and materials persist.
const ITEMS := {
	"ore":{"name":"铁矿","sell":4,"color":Color("98b8c4")},
	"fang":{"name":"怪物牙","sell":3,"color":Color("e6d6a8")},
	"stone":{"name":"守卫碎片","sell":10,"color":Color("d9a859")}}
const SAVE_PATH := "user://adventure-save-v1.json"
var gold := 0
var chapter_one_completed := false
var materials := {"ore":0,"fang":0,"stone":0}
var equipped_sword := "wind"
var sword_levels := {"wind":0,"fire":0,"thunder":0}
var sword_level: int:
	get:
		return int(sword_levels.get(equipped_sword,0))
	set(value):
		sword_levels[equipped_sword] = clampi(value,0,3)
var needs_migration_backup := false
var fire_core := false
var equipped_core := "starter_ember"
var persistence_enabled := true
var save_path := SAVE_PATH
var last_error := ""
# Preserve optional journey data even if a legacy scene opens and saves this file.
var journey: Dictionary = {}

func sword_damage() -> int:
	return int(SwordArsenal.data(equipped_sword).base)+sword_level*2

func fire_damage() -> int:
	return 22+int(sword_levels.fire)*3+(8 if fire_core else 0)

func fire_radius() -> float:
	return 0.62 if fire_core else 0.52

func snapshot() -> Dictionary:
	return {"version":2,"equipped_sword":equipped_sword,"sword_levels":sword_levels.duplicate(),"gold":gold,"materials":materials.duplicate(),"sword_level":sword_level,"fire_core":fire_core,"equipped_core":equipped_core,"chapter_one_completed":chapter_one_completed,"journey":journey.duplicate(true)}

func restore(data: Dictionary) -> void:
	journey = data.get("journey",{}).duplicate(true) if data.get("journey",{}) is Dictionary else {}
	chapter_one_completed = data.get("chapter_one_completed",false)==true
	gold = clampi(int(data.get("gold",0)),0,999999)
	equipped_sword = str(data.get("equipped_sword","fire" if int(data.get("version",1))==1 else "wind"))
	if equipped_sword not in SwordArsenal.ORDER:
		equipped_sword = "wind"
	var levels: Variant = data.get("sword_levels",{})
	for id in SwordArsenal.ORDER:
		sword_levels[id] = clampi(int(levels.get(id,0)),0,3) if levels is Dictionary else 0
	if int(data.get("version",1))==1:
		sword_levels.fire = clampi(int(data.get("sword_level",0)),0,3)
	fire_core = data.get("fire_core",false)==true
	equipped_core = str(data.get("equipped_core","starter_ember"))
	if equipped_core not in ["","starter_ember","refined_ember"] or (equipped_core=="refined_ember" and not fire_core):
		equipped_core = "starter_ember"
	var items: Variant = data.get("materials",{})
	for id in ITEMS:
		materials[id] = clampi(int(items.get(id,0)),0,99999) if items is Dictionary else 0

func load_save() -> void:
	if not persistence_enabled or not FileAccess.file_exists(save_path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if data is Dictionary and (data.get("version",0)==1 or data.get("version",0)==2):
		restore(data)
		needs_migration_backup = int(data.version)==1
	else:
		last_error = "无法读取存档，已保留原文件。"

func save() -> bool:
	if not persistence_enabled:
		return true
	if needs_migration_backup and FileAccess.file_exists(save_path) and not FileAccess.file_exists(save_path+".v1.bak"):
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(save_path),ProjectSettings.globalize_path(save_path+".v1.bak"))!=OK:
			last_error = "旧存档备份失败，未修改原文件。"
			return false
	var file := FileAccess.open(save_path+".tmp",FileAccess.WRITE)
	if file==null:
		last_error = "无法保存进度。"
		return false
	file.store_string(JSON.stringify(snapshot(),"\t"))
	file.close()
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(save_path+".tmp"),ProjectSettings.globalize_path(save_path))!=OK:
		last_error = "无法更新存档文件。"
		return false
	last_error = ""
	needs_migration_backup = false
	return true

func add_material(id: String, amount: int) -> bool:
	if not ITEMS.has(id) or amount<=0:
		return false
	var before := snapshot()
	materials[id] = mini(99999,int(materials[id])+amount)
	if save():
		return true
	restore(before)
	return false

func complete_chapter_one() -> bool:
	if chapter_one_completed:
		return true
	chapter_one_completed = true
	if save():
		return true
	chapter_one_completed = false
	return false

func add_gold(amount: int) -> bool:
	if amount<=0:
		return false
	var before := snapshot()
	gold = mini(999999,gold+amount)
	if save():
		return true
	restore(before)
	return false

func recipe(id: String) -> Dictionary:
	if id=="sword" and sword_level<3:
		return [{"ore":2,"fang":1,"gold":12},{"ore":4,"fang":2,"stone":1,"gold":30},{"ore":6,"fang":3,"stone":2,"gold":60}][sword_level]
	if id=="fire_core" and not fire_core:
		return {"ore":2,"fang":1,"stone":1,"gold":25}
	return {}

func can_craft(id: String) -> bool:
	var cost := recipe(id)
	if cost.is_empty():
		return false
	for item in cost:
		if (gold if item=="gold" else int(materials.get(item,0)))<int(cost[item]):
			return false
	return true

func craft(id: String) -> bool:
	if not can_craft(id):
		last_error = "素材或金币不足，或已完成强化。"
		return false
	var before := snapshot()
	var cost := recipe(id)
	for item in cost:
		if item=="gold":
			gold -= int(cost[item])
		else:
			materials[item] -= int(cost[item])
	if id=="sword":
		sword_level += 1
	else:
		fire_core = true
		equipped_core = "refined_ember"
	if save():
		return true
	restore(before)
	return false

func sell(id: String, quantity: int = 1) -> bool:
	if not ITEMS.has(id) or quantity<=0 or int(materials[id])<quantity:
		last_error = "没有足够的素材可出售。"
		return false
	var before := snapshot()
	materials[id] -= quantity
	gold += quantity*int(ITEMS[id].sell)
	if save():
		return true
	restore(before)
	return false

func cost_text(id: String) -> String:
	var cost := recipe(id)
	if cost.is_empty():
		return "已完成"
	var parts := PackedStringArray()
	for item in cost:
		parts.append("%d %s" % [cost[item],"金币" if item=="gold" else ITEMS[item].name])
	return "  +  ".join(parts)

func equip_core(id: String) -> bool:
	if id not in ["","starter_ember","refined_ember"] or (id=="refined_ember" and not fire_core):
		return false
	var before := snapshot()
	equipped_core = id
	if save():
		return true
	restore(before)
	return false

func equip_sword(id: String) -> bool:
	if id not in SwordArsenal.ORDER:
		return false
	var before := snapshot()
	equipped_sword = id
	if save():
		return true
	restore(before)
	return false
