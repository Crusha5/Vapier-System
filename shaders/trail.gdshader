shader_type spatial;
// Klingenspur: additiv, Helligkeit aus der Vertexfarbe (Alpha = Alter).
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.12, 0.22, 1.0);

void fragment() {
	float a = COLOR.a;
	vec3 core = mix(color.rgb, vec3(1.0, 0.9, 0.9), smoothstep(0.75, 1.0, UV.y) * a);
	ALBEDO = core * 2.2 * a * a;
}
