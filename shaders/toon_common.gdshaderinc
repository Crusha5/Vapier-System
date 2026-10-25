// Gemeinsamer Cel-Shading-Code (Level: ohne, Figuren: mit ACTOR-Instanzwerten)

global uniform vec3 player_pos;
global uniform vec3 cam_pos;

uniform vec4 albedo : source_color = vec4(0.7, 0.7, 0.75, 1.0);
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 1.0;
uniform vec4 rim_color : source_color = vec4(0.35, 0.85, 1.0, 1.0);
uniform float rim_strength = 0.0;
uniform float spec_strength = 0.0;
uniform float tiles = 0.0;       // 0 = aus, sonst Stärke der Fugen
uniform float tile_size = 2.0;
uniform float grime = 0.0;        // fleckige Variation pro Kachel / Fläche
uniform bool fade_occluder = false;
#ifdef ACTOR
instance uniform float flash = 0.0;
instance uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
#endif

varying vec3 wpos;
varying vec3 wnorm;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	if (fade_occluder) {
		vec3 to_p = player_pos + vec3(0.0, 1.0, 0.0) - cam_pos;
		float len_p = length(to_p);
		vec3 dir = to_p / max(len_p, 0.001);
		vec3 rel = wpos - cam_pos;
		float along = dot(rel, dir);
		float dist = length(rel - dir * along);
		if (along > 0.0 && along < len_p - 0.9 && dist < 2.6 && wpos.y > 0.25) {
			// Dither: halbe Pixel weglassen
			vec2 sp = floor(FRAGCOORD.xy);
			float d = mod(sp.x + sp.y, 2.0);
			float edge = smoothstep(2.6, 1.6, dist);
			if (d < 1.0 || edge > 0.85) {
				discard;
			}
		}
	}
	vec3 c = albedo.rgb;
#ifdef ACTOR
	c *= tint.rgb;
#endif
	if (tiles > 0.0) {
		vec2 g = wpos.xz / tile_size;
		vec2 cell = floor(g);
		vec2 f = fract(g);
		float line = step(f.x, 0.035) + step(f.y, 0.035);
		c *= mix(0.92, 1.04, hash2(cell));
		c *= 1.0 - tiles * min(line, 1.0);
	}
	if (grime > 0.0) {
		float n = hash2(floor(wpos.xz * 1.3 + wpos.y * 0.7));
		c *= 1.0 - grime * n * 0.35;
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	rim = smoothstep(0.62, 0.68, rim) * rim_strength;
	EMISSION = emission.rgb * emission_energy + rim_color.rgb * rim;
#ifdef ACTOR
	EMISSION += vec3(1.0, 0.95, 0.95) * flash;
#endif
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = smoothstep(0.0, 0.04, ndl) * 0.65 + smoothstep(0.45, 0.49, ndl) * 0.35;
	float att = ATTENUATION;
	// harte Schattenkante, weicher Abfall bei Punktlichtern bleibt erhalten
	DIFFUSE_LIGHT += LIGHT_COLOR * band * att / PI;
	if (spec_strength > 0.0) {
		vec3 h = normalize(LIGHT + VIEW);
		float sp = step(0.965, dot(NORMAL, h));
		SPECULAR_LIGHT += LIGHT_COLOR * sp * spec_strength * att / PI;
	}
}
