shader_type canvas_item;
// Blutsinn: Welt entsättigt und bläulich-dunkel, Rand pulsiert rot.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float amount = 0.0;

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float g = dot(c, vec3(0.3, 0.55, 0.15));
	vec3 cold = vec3(g * 0.55, g * 0.62, g * 0.9) * 0.85;
	vec2 d = SCREEN_UV - 0.5;
	float v = smoothstep(0.25, 0.75, length(d * vec2(1.6, 1.0)));
	float pulse = 0.6 + 0.4 * sin(TIME * 5.0);
	// Herzschläge (gesättigtes Rot/Gold/Violett) bleiben farbig und leuchten nach
	float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
	float keep = smoothstep(0.35, 0.65, sat) * step(0.5, max(c.r, c.b));
	vec3 o = mix(c, cold, amount * 0.85 * (1.0 - keep));
	o += c * keep * amount * 0.6;
	o = mix(o, vec3(0.45, 0.0, 0.04), v * amount * 0.35 * pulse);
	COLOR = vec4(o, 1.0);
}
