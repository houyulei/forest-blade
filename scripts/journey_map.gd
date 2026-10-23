class_name JourneyMap
extends ChapterMap
func _draw() -> void:
 if not is_instance_valid(arena.landscape):return
 draw_style_box(style(),Rect2(Vector2.ZERO,size))
 var path:=Color("8c8467") if arena.zone!="cave" else Color("647275")
 var points:=PackedVector2Array()
 for p in arena.landscape.route:points.append(point(p))
 if points.size()>1:draw_polyline(points,path,5,true)
 for z in [10.0,-18.0]:draw_line(point(Vector3(-37,0,z)),point(Vector3(37,0,z)),Color("526447"),3,true)
 if arena.zone=="village":
  var creek:=PackedVector2Array()
  for z in range(-40,41,2):creek.append(point(Vector3(13+sin(z*0.1)*1.8,0,z)))
  draw_polyline(creek,Color("487a85"),5,true)
  for house in arena.landscape.volume.houses:
   var a:=point(house-Vector3(3,0,3))
   var b:=point(house+Vector3(3,0,3))
   draw_rect(Rect2(a,b-a),Color("75694f"))
   draw_rect(Rect2(a,b-a),Color("ac9771"),false,1)
  draw_line(point(Vector3(8.5,0,10)),point(Vector3(18,0,10)),Color("b5a17b"),4,true)
 elif arena.zone=="cave":
  var a:=point(Vector3(-14,0,-34));var b:=point(Vector3(14,0,-14))
  draw_rect(Rect2(a,b-a),Color("47555e"),false,1)
 for actor in arena.world_objects:
  if not is_instance_valid(actor):continue
  if actor.data.kind=="gather":
   if not actor.opened:draw_circle(point(actor.position),1.8,Color("9fbf78"))
  elif actor.data.kind=="camp":
   draw_circle(point(actor.position),3.2,Color("e6af72") if actor.data.id in arena.journal.journey.camps else Color("8f8d7c"))
   if size.x>400:draw_string(ThemeDB.fallback_font,point(actor.position)+Vector2(5,-5),actor.data.name,HORIZONTAL_ALIGNMENT_LEFT,150,14,Color("e1c596"))
  elif not actor.opened:draw_rect(Rect2(point(actor.position)-Vector2(2.5,2.5),Vector2(5,5)),Color("d4bd75"),false,1)
 for actor in arena.villagers:
  if not is_instance_valid(actor):continue
  draw_circle(point(actor.position),3,Color("89c5dc"))
  var tracked: String=arena.journal.journey.tracked
  if JourneyData.QUESTS[tracked].giver==actor.data.id:draw_arc(point(actor.position),6,0,TAU,20,Color("d8c083"),1,true)
  if size.x>400:draw_string(ThemeDB.fallback_font,point(actor.position)+Vector2(5,-5),actor.data.name,HORIZONTAL_ALIGNMENT_LEFT,100,15,Color("dde8df"))
 if is_instance_valid(arena.forge):
  draw_circle(point(arena.forge.position),3,Color("e9a16e"))
  if size.x>400:draw_string(ThemeDB.fallback_font,point(arena.forge.position)+Vector2(5,-5),"阿伦",HORIZONTAL_ALIGNMENT_LEFT,100,15,Color("dde8df"))
 for enemy in arena.bokoblins:
  if is_instance_valid(enemy) and enemy.alive:draw_circle(point(enemy.position),4 if enemy is GoldenBokoblin else 2.8,Color("eac269") if enemy is GoldenBokoblin else Color("d58f6d"))
 for portal in arena.portals:draw_rect(Rect2(point(portal.position)-Vector2(4,3),Vector2(8,6)),Color("8fcbb7"))
 draw_circle(point(arena.hero.position),4,Color("f9eed0"))
 draw_arc(point(arena.hero.position),6.5,0,TAU,20,Color("f9eed0"),1,true)
