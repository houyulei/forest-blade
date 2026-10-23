class_name FireBurst
extends Node3D
## Short-lived fire impact; visual radius matches the gameplay radius supplied by Hero.
var arena: Node3D
var radius := 1.3
var elapsed := 0.0
var flame: MeshInstance3D
var ring: MeshInstance3D
var light: OmniLight3D
func _ready() -> void:
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform float life = 0.0;
void fragment(){
 float y=1.0-UV.y;
 float sway=sin(y*15.0-TIME*12.0)*0.055+sin(y*29.0+TIME*9.0)*0.025;
 float x=abs(UV.x-0.5+sway*y);
 float width=(1.0-y)*0.45+0.035;
 float edge=1.0-smoothstep(width*0.4,width,x);
 float tongues=0.78+0.22*sin(UV.x*38.0+sin(TIME*7.0));
 float mask=edge*(1.0-smoothstep(0.4,tongues,y))*smoothstep(0.0,0.12,y);
 float fade=sin(clamp(life,0.0,1.0)*3.14159);
 vec3 heat=mix(vec3(1.0,0.12,0.015),vec3(1.0,0.8,0.2),pow(1.0-y,2.0));
 ALBEDO=heat*1.6; ALPHA=mask*fade*0.92;
}"""
	material.shader = shader
	var quad := QuadMesh.new()
	quad.size = Vector2(radius*2.0,radius*1.45)
	flame = MeshInstance3D.new()
	flame.mesh = quad
	flame.material_override = material
	flame.position.y = radius*0.72
	flame.basis = arena.camera.global_basis
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flame)
	ring = Craft.ring(self,Vector3(0,0.045,0),radius,0.05,Craft.material(Color(1,0.48,0.08,0.7),0.4,1.3))
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	light = OmniLight3D.new()
	light.light_color = Color("ff9a38")
	light.omni_range = radius*3
	light.light_energy = 0.9
	add_child(light)
	arena.burst(global_position+Vector3.UP*0.25,Color("ffbb59"),12)
func _process(delta: float) -> void:
	elapsed += delta
	var progress := elapsed/0.62
	(flame.material_override as ShaderMaterial).set_shader_parameter("life",progress)
	ring.scale = Vector3.ONE*lerpf(0.65,1.0,minf(1,progress*3))
	ring.transparency = clampf(progress,0,1)
	light.light_energy = maxf(0,1-progress)*0.9
	if progress>=1:
		queue_free()
