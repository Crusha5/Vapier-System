shader_type spatial;
// Treffer-Blitz / Eklipse-Färbung als Overlay über einer ganzen Figur (nur aktiv, wenn nötig).
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float amount = 0.0;

void fragment() {
	ALBEDO = color.rgb * amount;
}
