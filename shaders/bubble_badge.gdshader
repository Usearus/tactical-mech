shader_type canvas_item;

uniform vec4 rim : source_color = vec4(1.0);

void fragment() {
	vec4 bubble = texture(TEXTURE, UV);
	float border = step(0.5, max(bubble.r, max(bubble.g, bubble.b)));
	vec3 rgb = mix(bubble.rgb, rim.rgb, border);
	COLOR = vec4(rgb, bubble.a);
}
