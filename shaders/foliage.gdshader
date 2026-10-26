shader_type spatial;
// Bäume, Büsche, Gras: Vertexfarben, Wind (Vertexfarbe Alpha = Biegsamkeit), weiches Licht von hinten.
render_mode cull_disabled, depth_draw_opaque;

uniform float wind = 1.0;
uniform float translucency = 0.35;
uniform float tint_var = 0.12;

varying float vary;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vary = hash(origin.xz);
	float bend = COLOR.a;
	float ph = TIME * 1.3 + origin.x * 0.15 + origin.z * 0.11;
	VERTEX.x += sin(ph) * 0.12 * bend * wind;
	VERTEX.z += cos(ph * 0.8) * 0.08 * bend * wind;
}

void fragment() {
	vec3 c = COLOR.rgb * (1.0 - tint_var + vary * tint_var * 2.0);
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
	BACKLIGHT = c * translucency;
}
