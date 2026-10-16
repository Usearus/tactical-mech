shader_type canvas_item;

uniform vec4 ink : source_color = vec4(1.0, 0.92, 0.55, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(ink.rgb, tex.a);
}
