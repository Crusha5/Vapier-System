shader_type spatial;
// Cel-Shading für Level-Geometrie: harte Licht-/Schattenkanten, Randlicht, Bodenkacheln,
// Ausblenden von Wänden zwischen Kamera und Spieler.
render_mode cull_back, depth_draw_opaque;
#include "res://shaders/toon_common.gdshaderinc"
