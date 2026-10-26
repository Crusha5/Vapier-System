shader_type spatial;
// Wasser: dunkel, Fresnel-Reflexion des Himmels, sanfte Wellen, transparent am Ufer.
render_mode blend_mix, cull_back, depth_draw_opaque, specular_schlick_ggx;

uniform vec4 deep : source_color = vec4(0.03, 0.06, 0.08, 1.0);
uniform vec4 shallow : source_color = vec4(0.1, 0.16, 0.16, 1.0);
uniform vec4 sky_tint : source_color = vec4(0.35, 0.4, 0.5, 1.0);

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
	vec2 uv = wpos.xz;
	float t = TIME;
	float a = vnoise(uv * 0.35 + vec2(t * 0.15, t * 0.1));
	float b = vnoise(uv * 0.8 - vec2(t * 0.2, -t * 0.12));
	vec3 n = normalize(vec3((a - 0.5) * 0.6, 1.0, (b - 0.5) * 0.6));
	NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	vec3 c = mix(deep.rgb, shallow.rgb, a * 0.4);
	ALBEDO = c;
	EMISSION = sky_tint.rgb * fres * 0.35;
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.6;
	ALPHA = 0.88;
}
