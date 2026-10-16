shader_type canvas_item;

uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float max_c = max(tex.r, max(tex.g, tex.b));
	float min_c = min(tex.r, min(tex.g, tex.b));
	float spread = max_c - min_c;
	// Near-white frame pixels take the mech color. The light grey becomes white.
	float white = step(0.93, min_c);
	float grey = step(0.35, min_c) * step(min_c, 0.85) * step(spread, 0.08);
	vec3 rgb = mix(vec3(1.0), tint.rgb, white);
	COLOR = vec4(rgb, tex.a * max(white, grey));
}
