class_name JourneyObject
extends Node3D
var arena: Node3D
var data: Dictionary
var label: Label3D
var clock:=0.0
var content: Node3D
var opened:=false
func _ready() -> void:
 content=Node3D.new()
 add_child(content)
 var wood:=Craft.material(Color("90714b"))
 var gold:=Craft.material(Color("cfb273"))
 match data.kind:
  "chest","cargo":
   Craft.solid_box(content,Vector3(0,0.30,0),Vector3(0.85,0.55,0.55),wood)
   var lid:=Craft.box(content,Vector3(0,0.62,0),Vector3(0.89,0.14,0.59),wood)
   lid.name="Lid"
   for x in [-0.29,0.29]:Craft.box(content,Vector3(x,0.35,0.29),Vector3(0.07,0.6,0.035),gold)
   Craft.box(content,Vector3(0,0.35,0.31),Vector3(0.15,0.18,0.05),Craft.material(Color("729da5")) if data.kind=="cargo" else gold)
  "gather":
   if data.item=="ore":
    for i in range(4):Craft.ball(content,Vector3((i-1.5)*0.18,0.2+(i%2)*0.08,0),Vector3(0.38,0.42,0.4),Craft.material(Color("7e9aab")))
   elif data.item=="wood":
    for i in range(4):
     var stick:=Craft.cylinder(content,Vector3((i-1.5)*0.15,0.1,0),0.055,0.045,0.8,wood,7)
     stick.rotation=Vector3(PI/2,0,(i-1.5)*0.18)
   else:
    for i in range(6):
     var a:=i*TAU/6
     var leaf:=Craft.ball(content,Vector3(cos(a)*0.12,0.16,sin(a)*0.12),Vector3(0.13,0.34,0.09),Craft.material(Color("8aac58")))
     leaf.rotation.z=cos(a)*0.6
  "camp":
   Craft.ring(content,Vector3(0,0.06,0),0.65,0.12,Craft.material(Color("7f8274")))
   for i in range(3):
    var log_:=Craft.cylinder(content,Vector3(0,0.12,0),0.1,0.1,0.8,wood,7)
    log_.rotation=Vector3(PI/2,0,i*PI/3)
   var flame:=Craft.ball(content,Vector3(0,0.37,0),Vector3(0.25,0.58,0.25),Craft.material(Color("ffb269"),0.6,0.8))
   flame.name="Flame"
   var light:=OmniLight3D.new()
   light.name="CampLight"
   light.position.y=0.8
   light.light_color=Color("ffc17d")
   light.omni_range=4
   light.light_energy=0.8
   content.add_child(light)
 label=Label3D.new()
 label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 label.font_size=25
 label.pixel_size=0.007
 label.position.y=1.1
 label.outline_modulate=Color("20352b")
 add_child(label)
 refresh()
func refresh() -> void:
 opened=data.id in arena.progress.journey.claimed
 if data.kind=="gather":content.visible=not opened
 if data.kind in ["chest","cargo"] and opened:
  content.get_node("Lid").rotation.x=-0.8
 if data.kind=="camp":
  var active: bool=data.id in arena.progress.journey.camps
  content.get_node("Flame").visible=active
  content.get_node("CampLight").visible=active
 label.text=("已开启" if opened else data.name) if data.kind!="camp" else data.name+(" · 已记录" if data.id in arena.progress.journey.camps else " · 未点燃")
 label.modulate=Color("b6b5a1") if opened else Color("ffe0a0")
func _process(delta: float) -> void:
 clock+=delta
 label.visible=arena.hero.alive and global_position.distance_to(arena.hero.global_position)<5.5 and not arena.menu_open
func interact() -> bool:
 return arena.interact_point(self)
