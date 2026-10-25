shader_type spatial;
// Cel-Shading für Figuren: zusätzlich Treffer-Blitz und Färbung pro Instanz.
render_mode cull_back, depth_draw_opaque;
#define ACTOR
#include "res://shaders/toon_common.gdshaderinc"
