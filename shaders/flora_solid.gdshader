shader_type spatial;
// Rinde, Felsen, Pilze: Textur, düster entsättigt, leichte Moos-/Schmutzvariation.
render_mode cull_back, depth_draw_opaque;

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float desat = 0.25;
uniform float moss = 0.0;

varying float vary;
varying vec3 wnorm;

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	vary = fract(sin(dot(o.xz, vec2(12.9898, 78.233))) * 43758.5453);
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 c = texture(tex, UV).rgb * tint.rgb * (0.9 + vary * 0.2);
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(c, vec3(l), desat);
	// Moos auf Oberseiten
	c = mix(c, vec3(0.16, 0.22, 0.1) * (0.7 + l), clamp(wnorm.y * 1.4 - 0.5, 0.0, 1.0) * moss);
	ALBEDO = c;
	ROUGHNESS = 0.92;
	SPECULAR = 0.15;
}
