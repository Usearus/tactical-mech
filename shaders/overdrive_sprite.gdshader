shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.32, 0.74, 1.0, 1.0);
// 0.2 rests near the top of the sprite. 1.0 carries the band to the feet.
uniform float amount = 0.2;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float wash = mix(0.12, 0.42, amount);
	vec3 tinted = mix(tex.rgb, glow_color.rgb, wash);
	float band = 1.0 - smoothstep(0.0, 0.16, abs(UV.y - amount));
	tinted = mix(tinted, glow_color.rgb, band * tex.a);
	COLOR = vec4(tinted, tex.a);
}
