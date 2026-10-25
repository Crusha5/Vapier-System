shader_type spatial;
// Comic-Kontur nach der Inverted-Hull-Methode (als next_pass am Toon-Material).
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

uniform vec4 outline_color : source_color = vec4(0.015, 0.012, 0.03, 1.0);
uniform float thickness = 0.035;
uniform float radial = 0.0; // 1 = vom Objektmittelpunkt weg (für kantige Kästen ohne Lücken)
uniform bool fade_occluder = false;
uniform vec3 player_pos = vec3(0.0);
uniform vec3 cam_pos = vec3(0.0, 10.0, 10.0);
varying vec3 wpos;

void vertex() {
	// zusammengefasste Level-Meshes tragen die Richtung in der Vertexfarbe (Alpha 0)
	vec3 rdir = COLOR.a < 0.5 ? normalize(COLOR.rgb * 2.0 - 1.0) : normalize(VERTEX + vec3(0.0001));
	vec3 n = normalize(mix(NORMAL, rdir, radial));
	VERTEX += n * thickness;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (fade_occluder) {
		vec3 to_p = player_pos + vec3(0.0, 1.0, 0.0) - cam_pos;
		float len_p = length(to_p);
		vec3 dir = to_p / max(len_p, 0.001);
		vec3 rel = wpos - cam_pos;
		float along = dot(rel, dir);
		float dist = length(rel - dir * along);
		if (along > 0.0 && along < len_p - 0.9 && dist < 2.7 && wpos.y > 0.25) {
			discard;
		}
	}
	ALBEDO = outline_color.rgb;
}
