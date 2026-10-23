class_name JourneyVolume
extends VolumeStyleWorld
var zone := "village"
var reservations: Array[Vector3] = []
func height_at(x: float,z: float) -> float:
 if zone=="cave":return 0.0
 var h:=0.12*sin(x*0.12)*cos(z*0.13)
 h+=1.2*exp(-((x+29)*(x+29)+(z+27)*(z+27))/140.0)
 if zone=="village":
  var creek:=absf(x-(13.0+sin(z*0.10)*1.8))
  h=lerpf(-0.72,h,smoothstep(1.3,2.8,creek))
 return h
func clear_position(x: float,z: float) -> bool:
 if absf(x-path_x(z))<3.0:return false
 if zone=="cave" and z< -15 and absf(x)<14:return false
 for p in reservations:
  if Vector2(x-p.x,z-p.z).length()<3.0:return false
 for house in houses:
  if absf(x-house.x)<5 and absf(z-house.z)<5:return false
 if zone=="village" and (absf(z-10)<2 or absf(x-(13+sin(z*0.1)*1.8))<2.4):return false
 return true
func build() -> void:
 rng.seed=20261027+zone.hash()
 houses=[Vector3(-9.5,0,3),Vector3(7,0,-9),Vector3(-9,0,-19),Vector3(24,0,8),Vector3(-25,0,-9),Vector3(7,0,25)] if zone=="village" else []
 for data in JourneyData.points(zone):reservations.append(data.p)
 for p in JourneyData.enemy_spawns(zone) if zone!="village" else []:reservations.append(p)
 reservations.append(Vector3(0,0,-27))
 if zone=="village":
  for data in JourneyData.NPCS:reservations.append(data.p)
  reservations.append(Vector3(5,0,0))
 terrain()
 if zone=="village":
  creek()
  for i in range(houses.size()):cottage(houses[i],i%3)
  well(Vector3(-2.6,0,9.5))
  for p in [Vector3(-4,0,12),Vector3(2,0,-13),Vector3(18,0,18),Vector3(-23,0,-17)]:fence(p)
  windmill(Vector3(-28,0,-28))
  village_details()
 if zone=="forest":
  for p in [Vector3(-18,0,14),Vector3(18,0,1),Vector3(-3,0,-22)]:
   reservations.append(p+Vector3(4,0,-3));outpost(p)
 if zone!="cave":
  var trees_to_build:=22 if zone=="village" else 48
  var made:=0
  for i in range(500):
   var x:=rng.randf_range(-36,36)
   var z:=rng.randf_range(-36,36)
   if not clear_position(x,z):continue
   tree(Vector3(x,0,z),rng.randf_range(0.8,1.18))
   made+=1
   if made>=trees_to_build:break
  grass()
  flowers()
 else:
  cavern_features()
 for side in [-1,1]:
  block(Vector3(side*40.4,8 if zone=="cave" else 2,0),Vector3(0.8,18 if zone=="cave" else 5,81),material("boundary",Color("4d6150") if zone!="cave" else Color("36434c")),true).visible=zone=="cave"
  block(Vector3(0,8 if zone=="cave" else 2,side*40.4),Vector3(81,18 if zone=="cave" else 5,0.8),material("boundary",Color("4d6150") if zone!="cave" else Color("36434c")),true).visible=zone=="cave"
 if zone!="cave":backdrop_ridge()
 batch_static_geometry()
func terrain() -> void:
 var st:=SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for z in range(104):
  for x in range(104):
   var a:=Vector3(x-52,0,z-52)
   for p in [a,a+Vector3.RIGHT,a+Vector3.BACK,a+Vector3.RIGHT,a+Vector3(1,0,1),a+Vector3.BACK]:
    p.y=height_at(p.x,p.z)
    st.add_vertex(p)
 st.generate_normals()
 var node:=MeshInstance3D.new()
 node.name="RollingTerrain"
 node.mesh=st.commit()
 var m:=material("terrain",Color.WHITE)
 m.set_shader_parameter("terrain",true)
 if zone=="cave":
  m.shader.code=SURFACE.replace("vec3(0.30,0.43,0.12),vec3(0.53,0.63,0.21)","vec3(0.16,0.20,0.23),vec3(0.29,0.33,0.34)").replace("vec3(0.53,0.44,0.28),vec3(0.74,0.64,0.43)","vec3(0.24,0.26,0.27),vec3(0.38,0.38,0.35)")
 else:
  # Additional cross paths connect housing, camps and side encounters.
  m.shader.code=SURFACE.replace("float path=1.0-smoothstep(width,width+0.85,abs(world.x-center)+noise(world.xz*2.8)*0.22);","float path=1.0-smoothstep(width,width+0.85,min(abs(world.x-center),min(abs(world.z-10.0),abs(world.z+18.0)))+noise(world.xz*2.8)*0.22);")
 node.material_override=m
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(node)
 node.create_trimesh_collision()
 solid_count+=1
func leaf_canopy(parent: Node3D,factor: float) -> void:
 super.leaf_canopy(parent,factor)
 for child in parent.get_children():
  if child is MultiMeshInstance3D:child.multimesh.visible_instance_count=240
func grass() -> void:
 var positions: Array[Vector3]=[]
 for i in range(55000):
  var x:=rng.randf_range(-39,39)
  var z:=rng.randf_range(-39,39)
  if absf(z-10)<2 or absf(z+18)<2 or not clear_position(x,z):continue
  positions.append(Vector3(x,height_at(x,z),z))
 var multi:=MultiMesh.new()
 multi.transform_format=MultiMesh.TRANSFORM_3D
 multi.mesh=grass_mesh()
 multi.instance_count=positions.size()
 for i in range(positions.size()):multi.set_instance_transform(i,Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*rng.randf_range(0.5,1)),positions[i]))
 var node:=MultiMeshInstance3D.new()
 node.multimesh=multi
 var m:=material("grass",Color("718f36"))
 m.set_shader_parameter("grass",true)
 node.material_override=m
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(node)
 grass_count=positions.size()
func creek() -> void:
 super.creek()
 for i in range(6):block(Vector3(16+i*0.44,0.08,10),Vector3(0.44,0.13,1.65),material("bridge",Color("8e7850")),true)
func cavern_features() -> void:
 var rock:=material("cavernrock",Color("4d5a63"))
 for i in range(70):
  var x:=rng.randf_range(-38,38)
  var z:=rng.randf_range(-38,38)
  if not clear_position(x,z) or absf(z+14)<3:continue
  var size_:=rng.randf_range(0.7,2.4)
  organic(self,Vector3(x,size_*0.5,z),Vector3(size_,size_*1.4,size_),rock,i)
  block(Vector3(x,size_*0.5,z),Vector3(size_*1.4,size_,size_*1.4),rock,true).visible=false
 for p in [Vector3(-10,0,25),Vector3(12,0,8),Vector3(-15,0,-6),Vector3(14,0,-23)]:
  for i in range(5):
   var item:=Craft.cylinder(self,p+Vector3((i-2)*0.24,0.7+i%2*0.2,0),0.16,0.01,1.4+i%2*0.4,material("crystal",Color("659ba8")),5)
   item.rotation.z=(i-2)*0.15
  var light:=OmniLight3D.new()
  light.position=p+Vector3.UP*1.5
  light.light_color=Color("7ab1c4")
  light.omni_range=9
  light.light_energy=0.9
  add_child(light)

func backdrop_ridge() -> void:
 var st:=SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(40):
  var x:=-120.0+i*6
  var a:=Vector3(x,10+sin(i*0.6)*4,-60)
  var b:=Vector3(x+6,10+sin((i+1)*0.6)*4,-60)
  for p in [a,b,Vector3(x,-2,-55),b,Vector3(x+6,-2,-55),Vector3(x,-2,-55)]:st.add_vertex(p)
 st.generate_normals()
 var m:=StandardMaterial3D.new();m.albedo_color=Color("78979b");m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 Craft.mesh(self,st.commit(),Vector3.ZERO,m)

func outpost(p: Vector3) -> void:
 var wood:=material("outpostwood",Color("746149"))
 var cloth:=material("outpostcloth",Color("8c7b58"))
 var base:=p+Vector3(4,0,-3);base.y=height_at(base.x,base.z)
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for side in [-1,1]:
  var vertices: Array=[Vector3(0,2,-1.4),Vector3(side*1.2,0,-1.4),Vector3(0,2,1.4),Vector3(0,2,1.4),Vector3(side*1.2,0,-1.4),Vector3(side*1.2,0,1.4)]
  if side<0:vertices.reverse()
  for v in vertices:st.add_vertex(v)
 st.generate_normals();Craft.mesh(self,st.commit(),base,cloth)
 for z in [-1.45,1.45]:beam(self,base+Vector3(0,0,z),base+Vector3(0,2.2,z),0.07,wood)
 block(base+Vector3(0,0.5,0),Vector3(2.0,1,2.6),cloth,true).visible=false
 var pole:=p+Vector3(-3,0,0);pole.y=height_at(pole.x,pole.z)
 beam(self,pole,pole+Vector3.UP*3,0.07,wood)
 Craft.box(self,pole+Vector3(0.5,2.4,0),Vector3(0.9,0.75,0.05),material("outpostflag",Color("a86d4e")))
 for i in range(2):block(base+Vector3(1.8+i*0.7,0.35,0.8),Vector3(0.6,0.7,0.65),wood,true)
