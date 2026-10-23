extends SceneTree
## Export real game frame mapping and combat timings; the viewer contains no copied attack table.
var image_cache := {}
var frame_cache := {}
func frame(atlas: Texture2D, column: int, direction: int, weapon: String, action: String) -> Dictionary:
	var key := atlas.resource_path+":"+str(column)+":"+str(direction)+":"+weapon+":"+action
	if not frame_cache.has(key):
		var result := HeroEightArt.resolve(atlas,column,direction,weapon,action)
		atlas = result.texture
		result.erase("texture")
		result.path = "../"+atlas.resource_path.trim_prefix("res://")
		if not image_cache.has(atlas.resource_path): image_cache[atlas.resource_path] = atlas.get_image()
		var atlas_image: Image = image_cache[atlas.resource_path]
		var used := atlas_image.get_region(Rect2i(result.column*result.cell,result.row*result.cell,result.cell,result.cell)).get_used_rect()
		result.used = [used.position.x,used.position.y,used.end.x,used.end.y]
		frame_cache[key] = result
	return frame_cache[key].duplicate(true)
func sampled(weapon: String, clip: String, direction8: int) -> Dictionary:
	var direction := HeroDirections.cardinal_row(direction8)
	var duration := 1.0
	if clip=="run": duration = ActorSizes.stride_distance("hero")/4.8
	if clip=="chain":
		duration = 0
		for combo in range(1,4): duration += float(SwordMotion.profile(combo,weapon).duration)
	if clip.begins_with("normal"):
		duration = float(SwordMotion.profile(int(clip.right(1)),weapon).duration)
	if clip=="skill": duration = {"wind":1.70,"fire":1.20,"thunder":0.38}[weapon]
	var samples: Array = []
	for i in range(121):
		var t := float(i)/120.0*duration
		var phase := minf(float(i)/120.0,0.99999)
		var combo := 1
		var atlas: Texture2D = HeroSprite.POSES if weapon=="wind" else HeroSprite.normal_atlas(weapon,1)
		var column := 0
		var window := Vector2.ZERO
		var reach := 0.0
		var label_ := "待机"
		if clip=="chain" or clip.begins_with("normal"):
			combo = int(clip.right(1)) if clip.begins_with("normal") else 1
			var local_t := t
			if clip=="chain":
				while combo<3 and local_t>=float(SwordMotion.profile(combo,weapon).duration):
					local_t -= float(SwordMotion.profile(combo,weapon).duration)
					combo += 1
			var data := SwordMotion.profile(combo,weapon)
			phase = minf(local_t/float(data.duration),0.99999)
			atlas = HeroSprite.normal_atlas(weapon,combo)
			column = SwordMotion.frame(combo,phase,weapon)
			if weapon=="wind" and combo==2 and column==5 and direction8%2==0 and direction in [1,2]: column = 4
			window = data.active
			reach = data.reach
			label_ = "前摇" if phase<window.x else ("命中" if phase<=window.y else "收招")
		elif clip=="run":
			atlas = HeroSprite.RUN if weapon=="wind" else (HeroSprite.FIRE_RUN if weapon=="fire" else HeroSprite.SPEAR_RUN)
			if weapon=="wind" and direction8%2==0 and direction in [1,2]: atlas = HeroSprite.RUN_SIDE
			column = int(phase*(16 if atlas==HeroSprite.RUN_SIDE else 6))
			label_ = "跑步"
		elif clip in ["jump","hurt","dash","defeat"]:
			atlas = HeroSprite.state_atlas(weapon)
			column = (3 if phase<0.5 else 4) if weapon=="wind" else (2 if phase<0.5 else 3)
			if clip=="hurt": column = 2 if weapon=="wind" else 1
			if clip=="defeat": column = 5
			if clip=="dash":
				atlas = HeroSprite.POSES if weapon=="wind" else (HeroSprite.FIRE_RUN if weapon=="fire" else HeroSprite.SPEAR_RUN)
				column = 2
			label_ = {"jump":"跳跃","hurt":"受击","dash":"冲刺","defeat":"倒地"}[clip]
		elif clip=="skill":
			if weapon=="wind":
				atlas = HeroSprite.SPIN
				column = int(fposmod(t,0.34)/0.34*16)
				label_ = "旋舞 %d / 5" % mini(5,int(t/0.34)+1)
			elif weapon=="fire":
				atlas = HeroSprite.FIRE_HEAVY
				column = 1 if t<0.8 else 2+clampi(int((t-0.8)/0.4*4),0,3)
				label_ = "蓄力" if t<0.8 else "释放"
			else:
				atlas = HeroSprite.SPEAR_LUNGE
				column = 1 if phase<0.18 else (3 if phase<0.80 else 4)
				label_ = "贯突"
		var sample := frame(atlas,column,direction8,weapon,clip)
		if clip=="run" and weapon in ["fire","thunder"] and direction8%2==0:
			var parts := HeroSprite.run_parts(weapon,direction,phase)
			var layers: Array = []
			var used_bounds := [99999.0,99999.0,-99999.0,-99999.0]
			for part in parts:
				var texture: Texture2D = part.texture
				var rect: Rect2i = part.rect
				var position_: Vector2 = part.position
				var key: String = texture.resource_path+str(rect)
				if not image_cache.has(texture.resource_path): image_cache[texture.resource_path] = texture.get_image()
				if not frame_cache.has(key): frame_cache[key] = (image_cache[texture.resource_path] as Image).get_region(rect).get_used_rect()
				var used: Rect2i = frame_cache[key]
				var left := position_.x+used.position.x
				var right := position_.x+used.end.x
				if part.flip:
					var old := left
					left = -right
					right = -old
				used_bounds[0] = minf(used_bounds[0],left)
				used_bounds[1] = minf(used_bounds[1],position_.y+used.position.y)
				used_bounds[2] = maxf(used_bounds[2],right)
				used_bounds[3] = maxf(used_bounds[3],position_.y+used.end.y)
				layers.append({"path":"../"+texture.resource_path.trim_prefix("res://"),"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"position":[position_.x,position_.y],"flip":part.flip,"fade":part.fade})
			sample.layers = layers
			sample.path = layers[1].path
			sample.row = 0
			sample.column = int(parts[1].rect.position.x)/768
			sample.cell = 768
			sample.baseline = 672
			# Bounds in the same virtual cell coordinates as grip annotations.
			sample.used = [used_bounds[0]+float(sample.cell)/2.0,used_bounds[1]+float(sample.baseline),used_bounds[2]+float(sample.cell)/2.0,used_bounds[3]+float(sample.baseline)]
			sample.flip = false
		sample.direction = direction8
		sample.time = t
		sample.phase = label_
		sample.combo = combo
		sample.reach = reach
		samples.append(sample)
	var bounds := [99999.0,99999.0,-99999.0,-99999.0]
	for sample in samples:
		var used: Array = sample.used
		var left: float = float(used[0])-float(sample.cell)/2.0
		var right: float = float(used[2])-float(sample.cell)/2.0
		if sample.flip:
			var old := left
			left = -right
			right = -old
		bounds[0] = minf(bounds[0],left)
		bounds[1] = minf(bounds[1],float(used[1])-float(sample.baseline))
		bounds[2] = maxf(bounds[2],right)
		bounds[3] = maxf(bounds[3],float(used[3])-float(sample.baseline))
	return {"duration":duration,"samples":samples,"bounds":bounds}
func _initialize() -> void:
	var data := {"weapons":{},"directions":HeroDirections.NAMES,"clips":{"idle":"待机","run":"跑步","normal1":"普攻一","normal2":"普攻二","normal3":"普攻三","chain":"基础三连","skill":"特殊动作","jump":"跳跃","hurt":"受击","dash":"冲刺","defeat":"倒地"}}
	for weapon in SwordArsenal.ORDER:
		var clips := {}
		for clip in data.clips:
			var directions: Array = []
			for direction in range(8): directions.append(sampled(weapon,clip,direction))
			clips[clip] = directions
		data.weapons[weapon] = {"name":SwordArsenal.data(weapon).name,"clips":clips}
	var file := FileAccess.open("res://tools/animation-lab-data.js",FileAccess.WRITE)
	file.store_string("window.MOTION_DATA = "+JSON.stringify(data)+";\n")
	print("MOTION_LAB_EXPORTED")
	quit()
