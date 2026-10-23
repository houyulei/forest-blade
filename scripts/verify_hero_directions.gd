extends SceneTree
const Directions=preload("res://scripts/hero_directions.gd")
func _initialize() -> void:
 run.call_deferred()
func run() -> void:
 var checks: Array=[]
 var camera:=Camera3D.new();root.add_child(camera)
 for yaw in [0.0,25.0,75.0,180.0]:
  camera.rotation_degrees=Vector3(-30,yaw,0)
  var right:=camera.global_basis.x;right.y=0;right=right.normalized()
  var away:=-camera.global_basis.z;away.y=0;away=away.normalized()
  for i in range(8):
   var a:=i*PI/4
   var facing: Vector3=-right*sin(a)-away*cos(a)
   checks.append({"yaw":yaw,"direction":i,"passed":Directions.from_world(facing,camera)==i})
 camera.rotation=Vector3.ZERO
 var near_edge:=Vector3(-sin(deg_to_rad(24)),0,cos(deg_to_rad(24)))
 checks.append({"check":"boundary hysteresis","passed":Directions.from_world(near_edge,camera,0)==0})
 checks.append({"check":"stationary direction retained","passed":Directions.from_world(Vector3.ZERO,camera,5)==5})
 var ok:=true
 for check in checks:ok=ok and check.passed
 var f:=FileAccess.open("res://artifacts/hero-direction-verification.json",FileAccess.WRITE);f.store_string(JSON.stringify({"passed":ok,"checks":checks},"\t"))
 print("HERO_DIRECTIONS_OK" if ok else "HERO_DIRECTIONS_FAILED")
 quit(0 if ok else 1)
