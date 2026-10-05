shader_type canvas_item;

void fragment() {
	float fade = smoothstep(0.68, 0.98, UV.x);
	COLOR = vec4(0.08, 0.09, 0.12, fade);
}
