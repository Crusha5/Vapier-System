shader_type spatial;
// Weltbezogene Dreifach-Projektion: Stein, Holz, Ziegel auf beliebigen Formen ohne UVs. Mit Schmutz und Moos.
render_mode cull_back, depth_draw_opaque;

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float scale = 0.5;
uniform float grime = 0.4;
uniform float moss = 0.0;
uniform float rough = 0.9;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

varying vec3 wpos;
varying vec3 wnrm;

float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1.0, 0.0)), f.x), mix(h2(i + vec2(0.0, 1.0)), h2(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 b = pow(abs(wnrm), vec3(4.0));
	b /= (b.x + b.y + b.z);
	vec3 cx = texture(tex, wpos.zy * scale).rgb;
	vec3 cy = texture(tex, wpos.xz * scale).rgb;
	vec3 cz = texture(tex, wpos.xy * scale).rgb;
	vec3 c = (cx * b.x + cy * b.y + cz * b.z) * tint.rgb;
	float n = n2(wpos.xz * 0.7 + wpos.y * 0.9) * 0.6 + n2(wpos.xy * 2.5) * 0.4;
	c *= 1.0 - grime * (n - 0.35) * 0.6;
	// Schmutz unten, Moos oben
	c *= mix(0.7, 1.0, clamp(wpos.y * 0.6 + n, 0.0, 1.0) * grime + (1.0 - grime));
	c = mix(c, vec3(0.2, 0.27, 0.12) * (0.6 + n), clamp(wnrm.y * 1.5 - 0.6 + (n - 0.5), 0.0, 1.0) * moss);
	ALBEDO = c;
	ROUGHNESS = rough;
	SPECULAR = 0.2;
	EMISSION = emission_color.rgb;
}
