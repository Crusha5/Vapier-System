shader_type spatial;
// Laub, Gras, Farne: Textur mit Alpha-Schnitt, Wind nach Höhe, düster entsättigt, Licht scheint durch.
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float desat = 0.3;
uniform float wind = 1.0;
uniform float height_ref = 6.0;
uniform float translucency = 0.35;
uniform float hue = 0.0;   // Farbton drehen (Bogenmaß), z. B. rotes Laub -> grün

vec3 hue_rot(vec3 c, float a) {
	const vec3 k = vec3(0.57735);
	float ca = cos(a);
	return c * ca + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - ca);
}

varying float vary;

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	vary = fract(sin(dot(o.xz, vec2(12.9898, 78.233))) * 43758.5453);
	float bend = clamp(VERTEX.y / height_ref, 0.0, 1.0);
	bend *= bend;
	float ph = TIME * 1.4 + o.x * 0.15 + o.z * 0.11;
	VERTEX.x += sin(ph + VERTEX.y * 0.5) * 0.12 * bend * wind;
	VERTEX.z += cos(ph * 0.8 + VERTEX.x * 0.3) * 0.08 * bend * wind;
}

void fragment() {
	vec4 t = texture(tex, UV);
	vec3 c = hue_rot(t.rgb, hue) * tint.rgb * (0.88 + vary * 0.24);
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(c, vec3(l), desat);
	ALBEDO = c;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ROUGHNESS = 0.9;
	SPECULAR = 0.12;
	BACKLIGHT = c * translucency;
}
