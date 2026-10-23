extends SceneTree
## Render actual shared atlas mappings, at the same body scale, for visual review.
var board: Node2D
func _initialize() -> void:
	run.call_deferred()
func label_(text: String,at: Vector2,size_: int = 18) -> void:
	var view := Label.new()
	view.text = text
	view.position = at
	view.add_theme_font_size_override("font_size",size_)
	view.add_theme_color_override("font_color",Color("edddbd"))
	board.add_child(view)
func frame_(texture: Texture2D,rect: Rect2i,at: Vector2,factor: float,flip: bool = false) -> void:
	var sprite := Sprite2D.new()
	var region := AtlasTexture.new()
	region.atlas = texture
	region.region = rect
	sprite.texture = region
	sprite.centered = false
	sprite.position = at
	sprite.scale = Vector2(-factor if flip else factor,factor)
	board.add_child(sprite)
func run() -> void:
	ThemeDB.fallback_font = preload("res://assets/fonts/ChineseMedium.tres")
	for clip in ["idle","run","normal1","normal2","normal3","skill","jump","hurt","defeat"]:
		board = Node2D.new()
		root.add_child(board)
		var bg := ColorRect.new()
		bg.color = Color("17292e")
		bg.size = Vector2(1440,900)
		board.add_child(bg)
		label_("森之刃 · 主角八向 · "+str({"idle":"待机","run":"移动","normal1":"普攻一","normal2":"普攻二","normal3":"普攻三","skill":"武器技起势","jump":"跳跃","hurt":"受击","defeat":"败退"}[clip]),Vector2(24,16),25)
		label_("游戏共用图集映射 / 同一身高比例 / 关键姿势审阅",Vector2(24,52),14)
		for direction in range(8): label_(HeroDirections.NAMES[direction],Vector2(direction*180+60,95))
		for wi in range(3):
			var weapon: String = SwordArsenal.ORDER[wi]
			label_(SwordArsenal.data(weapon).name,Vector2(20,145+wi*245),17)
			for direction in range(8):
				var row := HeroDirections.cardinal_row(direction)
				var atlas: Texture2D = HeroSprite.POSES if weapon=="wind" else HeroSprite.normal_atlas(weapon,1)
				var column := 0
				if clip=="run":
					atlas = HeroSprite.RUN if weapon=="wind" else (HeroSprite.FIRE_RUN if weapon=="fire" else HeroSprite.SPEAR_RUN)
					column = 3
				if clip.begins_with("normal"):
					atlas = HeroSprite.normal_atlas(weapon,int(clip.right(1)))
					column = 3
				if clip in ["jump","hurt","defeat"]:
					atlas = HeroSprite.state_atlas(weapon)
					column = {"jump":3 if weapon=="wind" else 2,"hurt":2 if weapon=="wind" else 1,"defeat":5}[clip]
				if clip=="skill":
					atlas = HeroSprite.SPIN if weapon=="wind" else HeroSprite.normal_atlas(weapon,3)
					column = 0 if weapon=="wind" else 1
				var display := HeroEightArt.resolve(atlas,column,direction,weapon,clip)
				var foot := Vector2(direction*180+90,350+wi*245)
				var factor: float = display.pixel_size*58.0
				if clip=="run" and weapon!="wind" and row>=0:
					for part in HeroSprite.run_parts(weapon,row,0.55):
						var pos: Vector2 = part.position
						if part.flip: pos.x = -pos.x
						frame_(part.texture,part.rect,foot+pos*factor,factor,part.flip)
				else:
					var pos := Vector2(-float(display.cell)/2,-float(display.baseline))
					if display.flip: pos.x = -pos.x
					frame_(display.texture,Rect2i(display.column*display.cell,display.row*display.cell,display.cell,display.cell),foot+pos*factor,factor,display.flip)
		for i in range(3): await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://artifacts/eight-sheet-"+clip+".png")
		board.free()
	print("EIGHT_SHEETS_COMPLETE")
	quit()
