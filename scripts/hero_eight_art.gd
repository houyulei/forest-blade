class_name HeroEightArt
extends RefCounted
## Shared runtime/review resolver. Cardinal art remains in its original atlas.
const BASE := "res://assets/hero/eight-directions/"
static var textures: Dictionary = {}

static func texture(weapon: String, kind: String) -> Texture2D:
	var path := BASE+weapon+"-"+kind+"-diagonal.png"
	if not textures.has(path): textures[path] = load(path)
	return textures[path]

static func resolve(atlas: Texture2D, column: int, direction: int, weapon: String, action: String = "") -> Dictionary:
	if atlas==HeroSprite.SPIN:
		var index := posmod(column+direction*2,16)
		var cell := atlas.get_width()/4
		return {"texture":atlas,"row":index/4,"column":index%4,"flip":false,"cell":cell,"baseline":cell*0.875,"columns":4,"rows":4,"pixel_size":ActorSizes.pixel_size("hero",0)}
	var row := HeroDirections.diagonal_row(direction)
	if row<0:
		var cardinal := HeroDirections.cardinal_row(direction)
		var result := HeroSprite.display_frame(atlas,column,cardinal)
		result.texture = atlas
		result.rows = 1 if atlas==HeroSprite.RUN_SIDE else 4
		result.pixel_size = ActorSizes.pixel_size("hero",cardinal)
		return result
	var kind := "states"
	if action in ["run","dash"] or atlas in [HeroSprite.RUN,HeroSprite.RUN_SIDE,HeroSprite.FIRE_RUN,HeroSprite.SPEAR_RUN]:
		kind = "run"
		if atlas==HeroSprite.RUN_SIDE: column = column*6/16
	elif atlas in [HeroSprite.ATTACK,HeroSprite.FIRE,HeroSprite.THRUST]: kind = "attack-1"
	elif atlas in [HeroSprite.RETURN,HeroSprite.FIRE_SWEEP,HeroSprite.SPEAR_LOW]: kind = "attack-2"
	elif atlas in [HeroSprite.CLEAVE,HeroSprite.FIRE_HEAVY,HeroSprite.SPEAR_LUNGE]: kind = "attack-3"
	elif weapon=="wind": column = [0,0,1,2,3,5][clampi(column,0,5)]
	if action=="idle" and kind=="states": column = 0
	if action=="land": column = 4
	var image := texture(weapon,kind)
	var cell := image.get_width()/6
	return {"texture":image,"row":row,"column":clampi(column,0,5),"flip":false,"cell":cell,"baseline":cell*0.875,"columns":6,"rows":4,"pixel_size":1.6/210.0}
