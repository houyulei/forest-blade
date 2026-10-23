class_name LootPickup
extends Node3D
var arena: Node3D
var item := "gold"
var amount := 1
var collected := false
var clock := 0.0
var visual: MeshInstance3D
func _ready() -> void:
	add_to_group("loot")
	var color: Color = Color("ffd479") if item=="gold" else AdventureProgress.ITEMS[item].color
	visual = Craft.ball(self,Vector3(0,0.18,0),Vector3(0.16,0.22,0.16),Craft.material(color,0.3,1.0))
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mark := Craft.ring(self,Vector3(0,0.018,0),0.13,0.018,Craft.material(Color(color,0.65),0.4,0.5))
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func _physics_process(delta: float) -> void:
	if collected:
		return
	clock += delta
	visual.position.y = 0.18+sin(clock*4)*0.045
	visual.rotation.y += delta*1.8
	if clock>0.32 and arena.hero.alive and global_position.distance_to(arena.hero.global_position)<1.20:
		collect()
func collect() -> bool:
	if collected:
		return false
	var success: bool = arena.progress.add_gold(amount) if item=="gold" else arena.progress.add_material(item,amount)
	if not success:
		arena.adventure_ui.notify(arena.progress.last_error)
		return false
	collected = true
	var title: String = "金币" if item=="gold" else AdventureProgress.ITEMS[item].name
	arena.adventure_ui.notify("+%d %s" % [amount,title])
	arena.play_tone(750,0.045,0.04)
	queue_free()
	return true
