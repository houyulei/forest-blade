class_name ActorSizes
extends RefCounted
## Body heights in scene units. Reference pixels measure idle bodies, not canvas or weapons.
## Keep one scale throughout an action; a lifted weapon must not shrink the character.
const PROFILES := {
	"hero": {"height":1.60, "reference_pixels":[211.0,209.0,212.0,199.0],
		"capsule_fraction":0.85, "radius_fraction":0.125,
		"shadow_width_fraction":0.425, "shadow_aspect":0.63, "stride_fraction":1.125},
	"bokoblin": {"height":1.28, "reference_pixels":[186.0,193.0,198.0],
		"capsule_fraction":0.82, "radius_fraction":0.195,
		"shadow_width_fraction":0.39, "shadow_aspect":0.66, "stride_fraction":1.094,
		"health_clearance_fraction":0.33, "alert_clearance_fraction":0.625},
	"sentinel": {"height":2.56, "reference_pixels":[185.0,198.0,197.0,183.0],
		"capsule_fraction":0.86, "radius_fraction":0.28,
		"shadow_width_fraction":0.585, "shadow_aspect":0.65,
		"health_clearance_fraction":0.08}}

static func body_height(kind: String) -> float:
	return PROFILES[kind].height

static func pixel_size(kind: String, direction: int = 0) -> float:
	return body_height(kind)/PROFILES[kind].reference_pixels[direction]

static func configure_capsule(collider: CollisionShape3D, kind: String) -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = body_height(kind)*PROFILES[kind].radius_fraction
	shape.height = body_height(kind)*PROFILES[kind].capsule_fraction
	collider.shape = shape
	# Actor roots are at the feet; resizing cannot introduce a gap below the collider.
	collider.position.y = shape.height*0.5

static func shadow_size(kind: String) -> Vector2:
	var width: float = body_height(kind)*PROFILES[kind].shadow_width_fraction
	return Vector2(width,width*PROFILES[kind].shadow_aspect)

static func health_position(kind: String, camera: Camera3D) -> Vector3:
	# Sprites face the tilted camera. Follow their screen-up axis for overhead UI.
	return camera.global_basis.y*(body_height(kind)*(1.0+PROFILES[kind].health_clearance_fraction))

static func make_health_bar(parent: Node3D, color: Color, pixels: Vector2i) -> Sprite3D:
	var image := Image.create(pixels.x,pixels.y,false,Image.FORMAT_RGBA8)
	image.fill(color)
	var bar := Sprite3D.new()
	bar.texture = ImageTexture.create_from_image(image)
	bar.pixel_size = 0.008
	bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bar.shaded = false
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(bar)
	return bar

static func alert_position(kind: String, camera: Camera3D) -> Vector3:
	return camera.global_basis.y*body_height(kind)*(1.0+PROFILES[kind].alert_clearance_fraction)

static func stride_distance(kind: String) -> float:
	return body_height(kind)*PROFILES[kind].stride_fraction
