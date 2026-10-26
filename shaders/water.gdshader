shader_type spatial;
// Wasser: Tiefe aus der Gelände-Höhenkarte (flach = hell und klar, tief = dunkel), Ufer-Schaum,
// Wellen, Fresnel-Spiegelung des Himmels.
render_mode blend_mix, cull_back, depth_draw_opaque, specular_schlick_ggx;

uniform vec4 deep : source_color = vec4(0.02, 0.05, 0.07, 1.0);
uniform vec4 shallow : source_color = vec4(0.14, 0.22, 0.2, 1.0);
uniform vec4 sky_tint : source_color = vec4(0.45, 0.5, 0.6, 1.0);
uniform sampler2D height_tex : filter_linear;
uniform float world_size = 640.0;

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
	float c2 = vnoise(uv * 2.2 + vec2(t * 0.35, t * 0.22));
	vec3 n = normalize(vec3((a - 0.5) * 0.5 + (c2 - 0.5) * 0.2, 1.0, (b - 0.5) * 0.5));
	NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;
	// Gelände unter dem Wasser (negativ = Wassertiefe)
	float gh = texture(height_tex, (wpos.xz + world_size * 0.5) / world_size).r;
	float depth = clamp(-gh, 0.0, 4.0);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	vec3 col = mix(shallow.rgb, deep.rgb, smoothstep(0.0, 2.5, depth));
	// Schaum am Ufer, bewegt
	float foam_band = 1.0 - smoothstep(0.0, 0.35, depth);
	float foam = foam_band * smoothstep(0.45, 0.75, vnoise(uv * 3.0 + vec2(t * 0.5, -t * 0.3)) + foam_band * 0.4);
	col = mix(col, vec3(0.75, 0.78, 0.8), foam * 0.7);
	ALBEDO = col;
	EMISSION = sky_tint.rgb * fres * 0.4;
	ROUGHNESS = mix(0.06, 0.6, foam);
	METALLIC = 0.0;
	SPECULAR = 0.6;
	ALPHA = mix(0.6, 0.94, smoothstep(0.0, 1.2, depth)) + foam * 0.3;
}
