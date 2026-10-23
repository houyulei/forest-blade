class_name JourneyLandscape
extends ChapterLandscape
var volume: JourneyVolume
func build() -> void:
 extent=JourneyData.EXTENT
 route=[Vector3(0,0,35),Vector3(0,0,10),Vector3(0,0,-18),Vector3(0,0,-35)]
 volume=JourneyVolume.new()
 volume.zone=zone
 add_child(volume)
 volume.build()
 collision_count=volume.solid_count
 scenery_count=volume.tree_count
 if zone=="cave":
  gate=StaticBody3D.new()
  gate.position=Vector3(0,1.5,-14)
  var shape:=CollisionShape3D.new()
  var box_:=BoxShape3D.new()
  box_.size=Vector3(80,3,0.3)
  shape.shape=box_
  shape.disabled=true
  gate.add_child(shape)
  add_child(gate)
  gate_art=Node3D.new()
  gate.add_child(gate_art)
  for i in range(21):Craft.box(gate_art,Vector3(-39+i*3.9,0,0),Vector3(0.12,3,0.12),Craft.material(Color(0.28,0.6,0.65,0.5),0.8,0.4))
  gate_art.hide()
func ground_at(p: Vector3) -> Vector3:
 return Vector3(p.x,volume.height_at(p.x,p.z),p.z)
func _process(_delta: float) -> void:
 pass
