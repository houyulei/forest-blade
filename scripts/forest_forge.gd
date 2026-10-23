class_name ForestForge
extends Node3D
func _ready() -> void:
	var art := Sprite3D.new()
	art.texture = preload("res://assets/forge/forge.png")
	art.pixel_size = 1.80/art.texture.get_height()
	art.offset.y = art.texture.get_height()*0.5
	art.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	art.shaded = false
	art.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	art.alpha_scissor_threshold = 0.15
	art.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(art)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.15,0.95,0.65)
	collision.position.y = 0.475
	collision.shape = shape
	body.add_child(collision)
	var smith := Sprite3D.new()
	smith.name = "BlacksmithAren"
	smith.texture = preload("res://assets/forge/smith.png")
	smith.pixel_size = 1.92 / smith.texture.get_height()
	smith.offset.y = smith.texture.get_height() * 0.5
	smith.position = Vector3(-0.65, 0, 0.65)
	smith.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	smith.shaded = false
	smith.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	smith.alpha_scissor_threshold = 0.15
	smith.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	smith.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(smith)
	var nameplate := Label3D.new()
	nameplate.text = "阿伦 · 铁匠"
	nameplate.font_size = 25
	nameplate.pixel_size = 0.006
	nameplate.position = Vector3(-0.65, 0, 0.65) + get_parent().camera.global_basis.y * 2.1
	nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nameplate.modulate = Color("ffe1a0")
	nameplate.outline_modulate = Color("19382a")
	nameplate.no_depth_test = false
	add_child(nameplate)
	var light := OmniLight3D.new()
	light.light_color = Color("ffad60")
	light.position = Vector3(0.25,0.7,0)
	light.omni_range = 2.5
	light.light_energy = 0.45
	add_child(light)

func smith_position() -> Vector3:
	return global_position + Vector3(-0.65, 0, 0.65)
