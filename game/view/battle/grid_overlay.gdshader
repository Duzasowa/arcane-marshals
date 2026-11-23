shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Thin lines between the battle cells over the ground.
uniform vec2 cells = vec2(12.0, 10.0);
uniform vec4 line_color : source_color = vec4(0.05, 0.08, 0.02, 0.45);
uniform float line_width = 0.035;

void fragment() {
	vec2 scaled = UV * cells;
	vec2 to_edge = min(fract(scaled), 1.0 - fract(scaled));
	float edge = min(to_edge.x, to_edge.y);
	float width = fwidth(edge) + line_width;
	float line = 1.0 - smoothstep(line_width, width, edge);
	ALBEDO = line_color.rgb;
	ALPHA = line_color.a * line;
}
