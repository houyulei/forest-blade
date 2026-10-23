class_name JourneyNPC
extends Node3D
var arena: Node3D
var data: Dictionary
var marker: Label3D
var clock:=0.0
var art: Sprite3D
static var atlas: Texture2D
static var metrics: Dictionary={}
func _ready() -> void:
 if atlas==null:atlas=load("res://assets/journey/villagers.png")
 var cell:=int(data.cell)
 var width:=atlas.get_width()/3
 var height:=atlas.get_height()/2
 var region:=Rect2i((cell%3)*width,floori(cell/3.0)*height,width,height)
 if not metrics.has(cell):
  var image:=atlas.get_image()
  var minp:=Vector2i(width,height)
  var maxp:=Vector2i.ZERO
  for y in range(height):
   for x in range(width):
    if image.get_pixel(region.position.x+x,region.position.y+y).a>0.25:
     minp.x=mini(minp.x,x);minp.y=mini(minp.y,y);maxp.x=maxi(maxp.x,x);maxp.y=maxi(maxp.y,y)
  metrics[cell]=Rect2i(minp,maxp-minp+Vector2i.ONE)
 var used: Rect2i=metrics[cell]
 var texture:=AtlasTexture.new()
 texture.atlas=atlas
 texture.region=region
 art=Sprite3D.new()
 art.texture=texture
 art.pixel_size=1.9/maxi(1,used.size.y)
 art.offset=Vector2(width*0.5-used.get_center().x,used.end.y-height*0.5)
 art.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 art.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
 art.alpha_scissor_threshold=0.20
 art.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 art.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(art)
 marker=Label3D.new()
 marker.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 marker.font_size=25
 marker.pixel_size=0.0065
 marker.position.y=2.22
 marker.outline_modulate=Color("19382a")
 marker.modulate=Color("f1d49a")
 add_child(marker)
 var body:=StaticBody3D.new()
 var shape:=CollisionShape3D.new()
 var capsule:=CapsuleShape3D.new()
 capsule.radius=0.22;capsule.height=1.6
 shape.shape=capsule;shape.position.y=0.8
 body.add_child(shape)
 add_child(body)
func _process(delta: float) -> void:
 clock+=delta
 art.position.y=sin(clock*1.4+data.cell)*0.012
 var id:=JourneyData.quest_for(data.id)
 var sign:=""
 if id!="":sign="◆ " if arena.progress.quest_ready(id) else ("！ " if arena.progress.quest_state(id)=="available" else "")
 marker.text=sign+data.name+" · "+data.role
 marker.visible=global_position.distance_to(arena.hero.global_position)<12 and not arena.menu_open
