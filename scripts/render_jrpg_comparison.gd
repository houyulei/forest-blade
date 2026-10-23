extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func label_at(parent: Node,text_: String,p: Vector2,font_size: int,color: Color) -> void:
	var label := Label.new()
	label.text = text_
	label.position = p
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)
func run() -> void:
	ThemeDB.fallback_font = load("res://assets/fonts/ChineseMedium.tres")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1440,1110)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var bg := ColorRect.new()
	bg.size = Vector2(1440,1110)
	bg.color = Color("18242a")
	viewport.add_child(bg)
	label_at(bg,"森之刃 / 两种场景路线实机对比",Vector2(30,16),28,Color("f2e2bc"))
	label_at(bg,"相同村庄布局与精灵角色；各自的材质、物件表现和镜头。非原作资源或原作截图。",Vector2(30,58),16,Color("b6c8c8"))
	for col in range(2):
		var variant := "vesperia" if col==0 else "ys"
		var x := 30+col*705
		label_at(bg,"A · 薄暮方向 / 立体手绘村庄" if col==0 else "B · 伊苏方向 / 固定俯视 2.5D",Vector2(x,100),22,Color("e7eddf"))
		for row in range(2):
			var shot := "overview" if row==0 else "street"
			label_at(bg,"全村布局" if row==0 else "行走视角",Vector2(x,144+row*462),15,Color("b6c8c8"))
			var rect := TextureRect.new()
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rect.texture = ImageTexture.create_from_image(Image.load_from_file("res://artifacts/jrpg-%s-%s.png"%[variant,shot]))
			rect.position = Vector2(x,173+row*462)
			rect.size = Vector2(675,422)
			bg.add_child(rect)
	label_at(bg,"运行：TalesVillage.command / YsVillage.command。Tab 切换方案，F3 全村／近景，WASD 走动。",Vector2(30,1080),15,Color("b6c8c8"))
	for i in range(4):
		await process_frame
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var result := viewport.get_texture().get_image().save_png("res://artifacts/jrpg-style-comparison.png")
	print("JRPG_COMPARISON_BOARD ",result)
	quit(0 if result==OK else 1)
