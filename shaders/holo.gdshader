shader_type spatial;
// Hologramme, Runenkreise, Blutsichel, Risse: additiv, unbeleuchtet, mit Scanlines.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(0.3, 0.9, 1.0, 1.0);
uniform float energy = 1.6;
uniform float scan = 0.25;
uniform float ring_mode = 0.0;  // 1 = Ringe/Runen auf einer Scheibe (UV-Mitte)
uniform float speed = 1.0;
uniform float ribbon = 0.0;   // 1 = Schweif (UV.x = Verlauf, UV.y = quer)
instance uniform float alpha = 1.0;

void fragment() {
	float a = 1.0;
	if (ring_mode > 0.5) {
		vec2 p = UV * 2.0 - 1.0;
		float r = length(p);
		float ang = atan(p.y, p.x);
		float rings = smoothstep(0.03, 0.0, abs(r - 0.92)) + smoothstep(0.02, 0.0, abs(r - 0.78))
			+ smoothstep(0.015, 0.0, abs(r - 0.55)) * 0.7;
		float ticks = step(0.82, fract(ang * 6.0 / 3.14159 + TIME * 0.15 * speed)) * step(0.8, r) * step(r, 0.9);
		float glyph = step(0.5, fract(ang * 18.0 / 3.14159 - TIME * 0.3 * speed)) * step(0.6, r) * step(r, 0.74) * 0.35;
		a = clamp(rings + ticks + glyph, 0.0, 1.0) * step(r, 1.0);
	}
	if (ribbon > 0.5) {
		a = pow(UV.x, 1.5) * smoothstep(0.0, 0.35, UV.y) * smoothstep(1.0, 0.55, UV.y);
	}
	float s = 1.0 - scan + scan * step(0.5, fract(FRAGCOORD.y * 0.25 + TIME * 2.0));
	ALBEDO = color.rgb * energy * a * s * alpha;
}
