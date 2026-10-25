shader_type spatial;
// Comic-Kontur für Figuren (mit Treffer-Blitz) nach der Inverted-Hull-Methode (als next_pass am Toon-Material).
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

uniform vec4 outline_color : source_color = vec4(0.015, 0.012, 0.03, 1.0);
uniform float thickness = 0.035;
uniform float radial = 0.0; // 1 = vom Objektmittelpunkt weg (für kantige Kästen ohne Lücken)
instance uniform float flash = 0.0;

void vertex() {
	vec3 n = normalize(mix(NORMAL, normalize(VERTEX + vec3(0.0001)), radial));
	VERTEX += n * thickness;
}

void fragment() {
	ALBEDO = mix(outline_color.rgb, vec3(1.0, 0.2, 0.25), flash * 0.6);
}
