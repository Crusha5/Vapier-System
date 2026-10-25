shader_type spatial;
// Blutlache / Spritzer auf dem Boden: unregelmäßige Kleckse aus Kreisen, blendet aus.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(0.6, 0.0, 0.05, 1.0);
uniform float alpha = 1.0;
uniform float seed = 0.0;

float h(float n) { return fract(sin(n * 91.345 + seed * 13.17) * 47453.5453); }

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float m = 0.0;
	m = max(m, smoothstep(0.55, 0.5, length(p * vec2(1.0, 1.2))));
	for (int i = 0; i < 7; i++) {
		float fi = float(i);
		vec2 c = vec2(h(fi) * 2.0 - 1.0, h(fi + 7.0) * 2.0 - 1.0) * 0.7;
		float r = 0.08 + h(fi + 3.0) * 0.18;
		m = max(m, smoothstep(r, r - 0.04, length(p - c)));
	}
	if (m < 0.05) { discard; }
	float edge = smoothstep(0.05, 0.6, m);
	ALBEDO = color.rgb * (0.7 + 0.3 * edge);
	ALPHA = alpha * m * color.a;
}
