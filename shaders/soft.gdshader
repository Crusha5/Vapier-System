shader_type spatial;
// Düster-stilisiertes Material: weiches Licht mit leichtem Wrap, Randlicht, optionales Leuchten, Körnung.
render_mode cull_back, depth_draw_opaque;

uniform vec4 albedo : source_color = vec4(0.6, 0.6, 0.6, 1.0);
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 1.0;
uniform vec4 rim_color : source_color = vec4(0.5, 0.6, 0.8, 1.0);
uniform float rim_strength = 0.0;
uniform float roughness = 0.85;
uniform float metallic = 0.0;
uniform float grime = 0.0;
uniform bool use_vcolor = false;

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
	vec3 c = albedo.rgb;
	if (use_vcolor) { c *= COLOR.rgb; }
	if (grime > 0.0) {
		float n = vnoise(wpos.xz * 1.7 + wpos.y * 1.3) * 0.6 + vnoise(wpos.xy * 4.0 + wpos.z) * 0.4;
		c *= 1.0 - grime * (n - 0.3) * 0.5;
	}
	ALBEDO = c;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * rim_strength;
	EMISSION = emission.rgb * emission_energy + rim_color.rgb * rim;
}
