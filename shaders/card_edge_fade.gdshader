shader_type canvas_item;

void fragment() {
	float fade = smoothstep(0.68, 0.98, UV.x);
	COLOR = vec4(4.0 / 255.0, 11.0 / 255.0, 24.0 / 255.0, fade);
}
