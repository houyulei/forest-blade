class_name HeroDirections
extends RefCounted
## Eight screen-relative directions. This is separate from legacy four-row atlas indices.
const NAMES := ["正面","左前","左侧","左后","背面","右后","右侧","右前"]
const CARDINAL_ROWS := {0:0,2:1,4:3,6:2}
const DIAGONAL_ROWS := {1:0,3:1,5:2,7:3}
static func screen_angle(facing: Vector3,camera: Camera3D) -> float:
 var right:=camera.global_basis.x
 right.y=0
 var away:=-camera.global_basis.z
 away.y=0
 return atan2(-facing.dot(right.normalized()),-facing.dot(away.normalized()))
static func from_world(facing: Vector3,camera: Camera3D,previous: int = -1) -> int:
 if Vector2(facing.x,facing.z).length_squared()<0.0001:return previous if previous in range(8) else 0
 var angle:=screen_angle(facing,camera)
 if previous in range(8):
  var difference:=wrapf(angle-previous*PI/4.0,-PI,PI)
  if absf(difference)<=PI/8.0+deg_to_rad(3):return previous
 return posmod(roundi(angle/(PI/4.0)),8)
static func cardinal_row(direction: int) -> int:
 return int(CARDINAL_ROWS.get(direction,-1))
static func diagonal_row(direction: int) -> int:
 return int(DIAGONAL_ROWS.get(direction,-1))
