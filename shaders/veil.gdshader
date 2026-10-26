shader_type spatial;
// Der Schleier: wabernde rote Sturmwand am Rand der Welt (additiv).
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(0.9, 0.1, 0.15, 1.0);
uniform float strength = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	float n = vnoise(vec2(uv.x * 80.0, uv.y * 3.0 - TIME * 0.5)) * 0.6 + vnoise(vec2(uv.x * 220.0 + TIME * 0.3, uv.y * 8.0 - TIME * 1.2)) * 0.4;
	float fade = smoothstep(0.0, 0.25, uv.y) * smoothstep(1.0, 0.45, uv.y);
	float a = pow(n, 2.2) * fade;
	ALBEDO = color.rgb * a * 1.6 * strength;
}
