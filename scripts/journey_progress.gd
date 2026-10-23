class_name JourneyProgress
extends AdventureProgress
const SUPPLIES := {"herb":"青芽草","wood":"木材","cargo":"找回的货物"}
func _init() -> void:
 initialize_journey()
func initialize_journey() -> void:
 var defaults := {"potions":{"potion":3,"ether":1},"supplies":{"herb":0,"wood":0,"cargo":0},"owned":[],"gear":{"head":"","body":"","feet":"","accessory_1":"","accessory_2":""},"quests":{},"claimed":[],"kills":[],"camps":[],"scout_met":false,"tracked":"main","checkpoint":{"zone":"village","p":[0,0,14]},"visited":["village"]}
 for key in defaults:
  if not journey.has(key) or typeof(journey[key])!=typeof(defaults[key]):journey[key]=defaults[key].duplicate(true) if defaults[key] is Dictionary or defaults[key] is Array else defaults[key]
 for key in ["potion","ether"]:journey.potions[key]=clampi(int(journey.potions.get(key,0)),0,99)
 for key in SUPPLIES:journey.supplies[key]=clampi(int(journey.supplies.get(key,0)),0,9999)
 var owned: Array = []
 for id in journey.owned:
  if JourneyData.GEAR.has(id) and id not in owned:owned.append(id)
 journey.owned=owned
 for slot in JourneyData.SLOT_NAMES:
  var id := str(journey.gear.get(slot,""))
  journey.gear[slot]=id if id in owned and valid_slot(id,slot) else ""
 if journey.gear.accessory_1!="" and journey.gear.accessory_1==journey.gear.accessory_2:journey.gear.accessory_2=""
 for id in journey.quests.keys():
  if not JourneyData.QUESTS.has(id) or journey.quests[id] not in ["active","done"]:journey.quests.erase(id)
 for key in ["claimed","kills","camps","visited"]:
  var values: Array=[]
  for value in journey[key]:
   if value is String and value.length()<120 and value not in values:values.append(value)
  journey[key]=values.slice(0,300)
 if journey.tracked not in JourneyData.QUESTS:journey.tracked="main"
 var checkpoint: Dictionary=journey.checkpoint
 if checkpoint.get("zone","") not in ["village","forest","cave"] or not checkpoint.get("p",[]) is Array or checkpoint.get("p",[]).size()!=3:
  journey.checkpoint=defaults.checkpoint.duplicate(true)
 else:
  for i in range(3):checkpoint.p[i]=clampf(float(checkpoint.p[i]),-37,37) if i!=1 else 0.0
func restore(data: Dictionary) -> void:
 super.restore(data)
 initialize_journey()
func commit(before: Dictionary) -> bool:
 if save():return true
 restore(before)
 return false
func quantity(id: String) -> int:
 if id=="gold":return gold
 if id in materials:return int(materials[id])
 if id in ["potion","ether"]:return int(journey.potions[id])
 return int(journey.supplies.get(id,0))
func apply_reward(reward: Dictionary) -> void:
 for id in reward:
  if id=="gear":
   if JourneyData.GEAR.has(reward[id]) and reward[id] not in journey.owned:journey.owned.append(reward[id])
  elif id=="gold":gold=mini(999999,gold+int(reward[id]))
  elif materials.has(id):materials[id]=mini(99999,int(materials[id])+int(reward[id]))
  elif journey.potions.has(id):journey.potions[id]=mini(99,int(journey.potions[id])+int(reward[id]))
  elif journey.supplies.has(id):journey.supplies[id]=mini(9999,int(journey.supplies[id])+int(reward[id]))
func claim_point(id: String,reward: Dictionary) -> bool:
 if id in journey.claimed:
  last_error="这里已经收集过了。"
  return false
 var before:=snapshot()
 apply_reward(reward)
 journey.claimed.append(id)
 return commit(before)
func quest_state(id: String) -> String:
 return str(journey.quests.get(id,"available"))
func accept_quest(id: String) -> bool:
 if not JourneyData.QUESTS.has(id) or quest_state(id)!="available":return false
 var before:=snapshot()
 journey.quests[id]="active"
 journey.tracked=id
 return commit(before)
func quest_ready(id: String) -> bool:
 if quest_state(id)!="active":return false
 var data: Dictionary=JourneyData.QUESTS[id]
 for item in data.get("needs",{}):
  if quantity(item)<int(data.needs[item]):return false
 match id:
  "main":return chapter_one_completed
  "patrol":return journey.kills.size()>=6
  "cargo":return quantity("cargo")>=3
  "camps":return "forest/camp/0" in journey.camps and "forest/camp/1" in journey.camps
 return true
func quest_detail(id: String) -> String:
 var state:=quest_state(id)
 if state=="done":return "已完成"
 if quest_ready(id):return "目标已完成，返回委托人交付"
 match id:
  "main":return "向村长报告" if chapter_one_completed else ("击败黄金波克布林" if journey.scout_met else "与村口的侦察员璃娜交谈")
  "patrol":return "森林哨兵 %d / 6"%mini(6,journey.kills.size())
  "cargo":return "找回货物 %d / 3"%quantity("cargo")
  "camps":return "点亮森林营火 %d / 2"%int(int("forest/camp/0" in journey.camps)+int("forest/camp/1" in journey.camps))
 var parts:=PackedStringArray()
 for item in JourneyData.QUESTS[id].get("needs",{}):parts.append("%s %d/%d"%[item_name(item),quantity(item),JourneyData.QUESTS[id].needs[item]])
 return "　".join(parts)
func turn_in(id: String) -> bool:
 if not quest_ready(id):
  last_error="委托目标尚未完成。"
  return false
 var before:=snapshot()
 var data: Dictionary=JourneyData.QUESTS[id]
 for item in data.get("needs",{}):
  if materials.has(item):materials[item]-=int(data.needs[item])
  else:journey.supplies[item]-=int(data.needs[item])
 if id=="cargo":journey.supplies.cargo-=3
 apply_reward(data.reward)
 journey.quests[id]="done"
 if journey.tracked==id:journey.tracked="main"
 return commit(before)
func record_kill(id: String) -> bool:
 if not id.begins_with("forest_") or id in journey.kills:return true
 var before:=snapshot()
 journey.kills.append(id)
 return commit(before)
func activate_camp(id: String,zone: String,p: Vector3) -> bool:
 var before:=snapshot()
 if id not in journey.camps:journey.camps.append(id)
 if zone not in journey.visited:journey.visited.append(zone)
 journey.checkpoint={"zone":zone,"p":[p.x,p.y,p.z]}
 return commit(before)
func mark_scout() -> bool:
 if journey.scout_met:return true
 var before:=snapshot()
 journey.scout_met=true
 return commit(before)
func valid_slot(id: String,slot: String) -> bool:
 if not JourneyData.GEAR.has(id):return false
 return JourneyData.GEAR[id].slot==slot or (slot.begins_with("accessory_") and JourneyData.GEAR[id].slot=="accessory")
func equip_gear(id: String,slot: String) -> bool:
 if slot not in JourneyData.SLOT_NAMES or (id!="" and (id not in journey.owned or not valid_slot(id,slot))):return false
 if id!="" and (journey.gear.accessory_1==id or journey.gear.accessory_2==id) and journey.gear[slot]!=id:
  last_error="同一件饰品不能装备两次。"
  return false
 var before:=snapshot()
 journey.gear[slot]=id
 return commit(before)
func stats() -> Dictionary:
 var result: Dictionary={"hp":5,"attack":0,"defense":0,"speed":4.8,"wind":0,"fire":0,"thunder":0}
 for slot in journey.gear:
  var id: String=journey.gear[slot]
  if not JourneyData.GEAR.has(id):continue
  for key in result:result[key]+=JourneyData.GEAR[id].get(key,0)
 return result
func sword_damage() -> int:
 return super.sword_damage()+int(stats().attack)
func buy(id: String) -> bool:
 var prices: Dictionary={"potion":8,"ether":10,"linen_cap":20,"trail_boots":35}
 if not prices.has(id) or gold<int(prices[id]) or (id in JourneyData.GEAR and id in journey.owned) or (id in ["potion","ether"] and quantity(id)>=99):
  last_error="金币不足、物品已拥有，或药品已达上限。"
  return false
 var before:=snapshot()
 gold-=int(prices[id])
 apply_reward({"gear":id} if id in JourneyData.GEAR else {id:1})
 return commit(before)
func consume(id: String) -> bool:
 if id not in ["potion","ether"] or quantity(id)<=0:
  last_error="没有可用的药品。"
  return false
 var before:=snapshot()
 journey.potions[id]-=1
 return commit(before)
func track(id: String) -> bool:
 if id not in JourneyData.QUESTS:return false
 var before:=snapshot()
 journey.tracked=id
 return commit(before)
func boss_reward() -> bool:
 if chapter_one_completed:return true
 var before:=snapshot()
 chapter_one_completed=true
 apply_reward({"gold":80,"ore":5,"fang":3,"stone":2})
 return commit(before)
func item_name(id: String) -> String:
 if id in ITEMS:return ITEMS[id].name
 if id in SUPPLIES:return SUPPLIES[id]
 return {"gold":"金币","potion":"回复药","ether":"魔力药"}.get(id,id)
