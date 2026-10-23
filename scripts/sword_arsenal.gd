class_name SwordArsenal
extends RefCounted
## Original weapons, combat roles inspired by Ys VI's three-sword system.
const ORDER := ["wind","fire","thunder"]
const SWORDS := {
	"wind":{"name":"苍岚剑","element":"风","color":Color("79e5ee"),"base":10,"skill":"回风连舞","magic":"苍岚龙卷","style":"三连斩后衔接旋风，最多五段","hint":"J 连斩后继续按 J · K 直接起舞"},
	"fire":{"name":"焰锋大剑","element":"火","color":Color("ff9b50"),"base":18,"skill":"蓄焰斩","magic":"贯焰火球","style":"肩劈 → 反横斩 → 过顶重劈","hint":"按住 J / K 蓄力，松开释放"},
	"thunder":{"name":"鸣雷长枪","element":"雷","color":Color("ffe885"),"base":8,"skill":"雷光贯突","magic":"跃雷连锁","style":"平刺 → 低刺 → 踏步贯刺；命中积电","hint":"J 三连刺积电 · K 雷光贯突"}}
static func data(id: String) -> Dictionary:
	return SWORDS.get(id,SWORDS.wind)
