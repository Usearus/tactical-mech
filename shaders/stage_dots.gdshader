shader_type canvas_item;

uniform vec4 fill_color : source_color = vec4(0.20, 0.21, 0.25, 1.0);
uniform vec4 dot_color : source_color = vec4(0.42, 0.44, 0.50, 0.8);
uniform float spacing = 22.0;
uniform float radius = 1.15;
// Right edge of the portrait shape, in UV across the whole frame. Wider toward the bottom.
uniform float edge_top = 0.24;
uniform float edge_bottom = 0.51;
uniform bool clip_shape = true;
uniform float fill_alpha = 1.0;

void fragment() {
	if (clip_shape) {
		float edge = mix(edge_top, edge_bottom, UV.y);
		if (UV.x > edge) {
			discard;
		}
	}
	vec2 cell = mod(FRAGCOORD.xy, vec2(spacing));
	float dist = distance(cell, vec2(spacing * 0.5));
	float dot_mask = 1.0 - smoothstep(radius - 0.25, radius + 0.55, dist);
	vec4 base = vec4(fill_color.rgb, fill_color.a * fill_alpha);
	vec4 dot = vec4(dot_color.rgb, dot_color.a);
	COLOR = mix(base, dot, dot_mask);
}
