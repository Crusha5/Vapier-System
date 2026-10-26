shader_type spatial;
// Gelände: Gras-, Erd- und Felstextur (Gewichte in UV), Vertexfarbe als Tönung, Fels seitlich projiziert.
render_mode cull_back, depth_draw_opaque;

uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap, repeat_enable;

varying vec3 wpos;
varying vec3 wnrm;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = NORMAL;
}

void fragment() {
	vec2 p = wpos.xz;
	// zwei Maßstäbe gegen sichtbare Kachelung
	vec3 g = texture(grass_tex, p * 0.25).rgb * 0.6 + texture(grass_tex, p * 0.061 + 0.37).rgb * 0.4;
	vec3 d = texture(dirt_tex, p * 0.3).rgb * 0.7 + texture(dirt_tex, p * 0.07).rgb * 0.3;
	vec3 an = abs(wnrm);
	vec3 rx = texture(rock_tex, wpos.zy * 0.16).rgb;
	vec3 rz = texture(rock_tex, wpos.xy * 0.16).rgb;
	vec3 ry = texture(rock_tex, p * 0.16).rgb;
	vec3 r = (rx * an.x + ry * an.y * 0.6 + rz * an.z) / (an.x + an.y * 0.6 + an.z);
	float n = vnoise(p * 0.35);
	float dirt_w = clamp(UV.y + (n - 0.5) * 0.5 * UV.y, 0.0, 1.0);
	float rock_w = clamp(UV.x * 1.2 + (n - 0.5) * 0.4, 0.0, 1.0);
	vec3 c = mix(g, d, smoothstep(0.25, 0.75, dirt_w));
	c = mix(c, r, smoothstep(0.3, 0.7, rock_w));
	// Vertexfarbe tönt (Asche nahe dem Schleier, Biome), normiert auf ein mittleres Grün
	vec3 expect = mix(vec3(0.25, 0.27, 0.14), vec3(0.3, 0.24, 0.17), smoothstep(0.25, 0.75, dirt_w));
	expect = mix(expect, vec3(0.34, 0.31, 0.29), smoothstep(0.3, 0.7, rock_w));
	vec3 tint = COLOR.rgb / expect;
	tint = mix(vec3(1.0), clamp(tint, 0.6, 1.6), 0.45);
	c *= tint;
	c *= 0.85 + 0.3 * vnoise(p * 0.05);
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.12;
}
