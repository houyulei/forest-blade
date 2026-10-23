extends SceneTree
func _initialize() -> void:
 run.call_deferred()
func run() -> void:
 set_meta("isolated_adventure",true)
 var game=load("res://journey_chapter.tscn").instantiate()
 root.add_child(game);current_scene=game
 var report: Array=[]
 for zone in ["village","forest","cave"]:
  if game.zone!=zone:game.load_room(zone,Vector3(0,0,14))
  game.hero.set_physics_process(false)
  for enemy in game.bokoblins:enemy.set_physics_process(false)
  game.focus=Vector3.INF;game.update_pixel_camera(0)
  await create_timer(1.0).timeout
  var start:=Time.get_ticks_usec()
  var frames:=0
  while Time.get_ticks_usec()-start<3000000:
   await process_frame
   await RenderingServer.frame_post_draw
   frames+=1
  var elapsed:=(Time.get_ticks_usec()-start)/1000000.0
  report.append({"zone":zone,"frames":frames,"seconds":elapsed,"drawn_fps":frames/elapsed,"persistent":game.journal.persistence_enabled})
 var file:=FileAccess.open("res://artifacts/journey-performance.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"\t"))
 print("JOURNEY_PERFORMANCE ",JSON.stringify(report))
 quit()
