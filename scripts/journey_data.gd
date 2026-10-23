class_name JourneyData
extends RefCounted
const EXTENT := Vector2(40,40)
const PREVIEW_AREA := 60.0*64.0
const TOTAL_AREA := 3.0*80.0*80.0
const SLOT_NAMES := {"head":"头部","body":"身体","feet":"鞋","accessory_1":"饰品一","accessory_2":"饰品二"}
const GEAR := {
 "linen_cap":{"name":"旅人布帽","slot":"head","hp":1,"hint":"柔软结实的旅行帽，生命上限 +1。"},
 "ranger_hood":{"name":"林巡兜帽","slot":"head","wind":15,"fire":-5,"hint":"风抗 +15%，火抗 -5%。"},
 "guard_vest":{"name":"守林皮甲","slot":"body","defense":35,"hint":"物理防御 +35，只影响物理伤害。"},
 "ember_coat":{"name":"耐火短衣","slot":"body","defense":15,"fire":20,"wind":-10,"hint":"物防 +15，火抗 +20%，风抗 -10%。"},
 "trail_boots":{"name":"林径短靴","slot":"feet","speed":0.5,"hint":"移动速度 +0.5。"},
 "heart_pendant":{"name":"青芽护符","slot":"accessory","hp":1,"hint":"生命上限 +1。"},
 "wind_leaf":{"name":"苍叶挂坠","slot":"accessory","wind":20,"hint":"风抗 +20%。"},
 "ember_ring":{"name":"余烬指环","slot":"accessory","fire":20,"hint":"火抗 +20%。"},
 "storm_bead":{"name":"鸣雷珠","slot":"accessory","thunder":20,"hint":"雷抗 +20%。"},
 "gold_fang":{"name":"金色獠牙","slot":"accessory","attack":3,"defense":10,"hint":"攻击 +3，物理防御 +10。"}}
const QUESTS := {
 "main":{"name":"深林的金色獠牙","giver":"chief","text":"向侦察员打听林道，清理森林哨点，击败幽根洞穴的黄金波克布林，回村报告。","reward":{"gold":100,"gear":"gold_fang"}},
 "herbs":{"name":"林间药香","giver":"herbalist","text":"为药师采集 3 份青芽草。交付后会消耗材料。","needs":{"herb":3},"reward":{"gold":12,"potion":3}},
 "forge":{"name":"旧炉新火","giver":"smith","text":"为阿伦带来 3 块铁矿和 2 份木材。交付后会消耗材料。","needs":{"ore":3,"wood":2},"reward":{"gear":"guard_vest","gold":12}},
 "patrol":{"name":"清除林道","giver":"scout","text":"击败森林中 6 名不同的哨兵，再向侦察员报告。","reward":{"gear":"trail_boots","gold":20}},
 "hunt":{"name":"猎人的委托","giver":"hunter","text":"为猎人带来 4 枚怪物牙。交付后会消耗材料。","needs":{"fang":4},"reward":{"gear":"wind_leaf","gold":25}},
 "cargo":{"name":"散落的货物","giver":"farmer","text":"找回森林三条支路上的 3 箱货物，带给农人。","reward":{"gold":30,"wood":5}},
 "camps":{"name":"归途之灯","giver":"innkeeper","text":"点亮森林的先遣营地与旧驿路营火，再向旅店老板报告。","reward":{"gear":"heart_pendant","ether":2}}}
const NPCS := [
 {"id":"chief","name":"榆伯","role":"村长","cell":0,"p":Vector3(-2,0,7),"speech":"北边的哨点被波克布林占据了。先找林道口的璃娜问清路况，再去深林。"},
 {"id":"herbalist","name":"米娅","role":"药师","cell":1,"p":Vector3(-4,0,-5),"speech":"青芽草长在溪边和林间。带回来，我会把它们调配成旅途中用得上的药。"},
 {"id":"scout","name":"璃娜","role":"侦察员","cell":2,"p":Vector3(1.8,0,-28),"speech":"森林有三处哨点，支路也通向营火和旧货箱。洞穴入口在最北端。留意小地图。"},
 {"id":"hunter","name":"洛恩","role":"猎人","cell":3,"p":Vector3(-20,0,-16),"speech":"别追着挥棒跑。等它收招再靠近，留一点魔法应付成群的敌人。"},
 {"id":"farmer","name":"阿禾","role":"农人","cell":4,"p":Vector3(21,0,14),"speech":"运回来的货物散落在森林的西侧、东侧和北部支路。箱子上有蓝色布条。"},
 {"id":"merchant","name":"贝克","role":"行商","cell":5,"p":Vector3(7,0,7),"speech":"补给备齐再出发。药品可以放在背包里，也可以按 4、5 快速使用。"},
 {"id":"innkeeper","name":"艾玛","role":"旅店老板","cell":4,"p":Vector3(1,0,23),"speech":"旅人，先在营火旁记下归途。点亮营火可以休整，也会成为这次旅程的重返点。"}]
static func quest_for(npc: String) -> String:
 for id in QUESTS:
  if QUESTS[id].giver==npc:return id
 return ""
static func points(zone: String) -> Array[Dictionary]:
 var result: Array[Dictionary] = []
 var locations := {
 "village":[Vector2(-18,12),Vector2(-22,-2),Vector2(-15,-24),Vector2(5,18),Vector2(21,2),Vector2(26,-17),Vector2(-28,24),Vector2(25,27)],
 "forest":[Vector2(-8,29),Vector2(12,25),Vector2(-22,19),Vector2(-29,5),Vector2(-16,-7),Vector2(-25,-22),Vector2(9,17),Vector2(24,12),Vector2(29,-2),Vector2(22,-17),Vector2(10,-25),Vector2(-9,-30),Vector2(-31,-28),Vector2(30,-30),Vector2(4,-14),Vector2(-12,4)],
 "cave":[Vector2(-16,28),Vector2(18,20),Vector2(-25,8),Vector2(27,0),Vector2(-17,-10),Vector2(16,-18),Vector2(-28,-27),Vector2(27,-29)]}
 var i := 0
 for v in locations[zone]:
  var item: String = ["herb","wood","ore"][i%3] if zone!="cave" else "ore"
  result.append({"id":zone+"/gather/"+str(i),"kind":"gather","item":item,"name":{"herb":"青芽草","wood":"枯木枝","ore":"露天铁矿"}[item],"p":Vector3(v.x,0,v.y),"reward":{item:1 if item=="herb" else 2}})
  i+=1
 var chest_positions: Array = {"village":[Vector2(-32,-24),Vector2(28,25),Vector2(23,-25)],"forest":[Vector2(-30,12),Vector2(30,-13),Vector2(-20,-30)],"cave":[Vector2(-30,20),Vector2(29,-15),Vector2(20,-31)]}[zone]
 var gears: Array = {"village":["linen_cap","",""],"forest":["ranger_hood","ember_ring",""],"cave":["ember_coat","storm_bead",""]}[zone]
 for j in range(3):
  var v: Vector2 = chest_positions[j]
  var reward := {"gold":12+j*5,"potion":1}
  if gears[j]!="":reward["gear"]=gears[j]
  result.append({"id":zone+"/chest/"+str(j),"kind":"chest","name":"旧木宝箱","p":Vector3(v.x,0,v.y),"reward":reward})
 if zone=="forest":
  for j in range(3):
   var v: Vector2 = [Vector2(-24,24),Vector2(25,-5),Vector2(-7,-28)][j]
   result.append({"id":"forest/cargo/"+str(j),"kind":"cargo","name":"散落的货箱","p":Vector3(v.x,0,v.y),"reward":{"cargo":1}})
 for j in range(2 if zone=="forest" else 1):
  var v: Vector2 = {"village":[Vector2(2,18)],"forest":[Vector2(-13,26),Vector2(19,-24)],"cave":[Vector2(6,29)]}[zone][j]
  result.append({"id":zone+"/camp/"+str(j),"kind":"camp","name":("先遣营地" if j==0 else "旧驿路营火") if zone=="forest" else "旅人营火","p":Vector3(v.x,0,v.y),"reward":{}})
 return result
static func enemy_spawns(zone: String) -> Array[Vector3]:
 var result: Array[Vector3] = []
 var pairs: Array = [Vector2(-18,14),Vector2(18,1),Vector2(-3,-22)] if zone=="forest" else [Vector2(-4,20),Vector2(7,6),Vector2(-12,-8)]
 for center in pairs:
  for i in range(4 if zone=="forest" else 2):
   result.append(Vector3(center.x+(i%2)*2.2-1.1,0,center.y+floori(i/2.0)*2.2))
 return result
