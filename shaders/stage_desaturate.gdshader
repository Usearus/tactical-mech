shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float amount : hint_range(0.0, 1.0) = 0.2;

void fragment() {
	vec4 behind = texture(screen_texture, SCREEN_UV);
	float luma = dot(behind.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(behind.rgb, vec3(luma), amount), 1.0);
}