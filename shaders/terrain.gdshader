shader_type spatial;
// Gelände: Vertexfarben + prozedurales Detailrauschen (Gras-/Steinkörnung), weiches Licht.
render_mode cull_back, depth_draw_opaque;

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = COLOR.rgb;
	float n1 = vnoise(wpos.xz * 0.45);
	float n2 = vnoise(wpos.xz * 2.7);
	float n3 = vnoise(wpos.xz * 0.06);
	c *= 0.78 + 0.28 * n1 + 0.12 * n2;
	c = mix(c, c * vec3(1.08, 1.02, 0.86), n3 * 0.5);
	ALBEDO = c;
	ROUGHNESS = 0.96;
	SPECULAR = 0.15;
}
