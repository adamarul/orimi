// Dev probe only (scenes/dev/render_probe.tscn): writes one of the include's Palette constants
// through ink_out(), to prove shader-made colours read back as written in both renderers.
shader_type spatial;
render_mode unshaded, shadows_disabled, fog_disabled;

#include "res://shaders/render/ink_common.gdshaderinc"

uniform int index = 0;

void fragment() {
	vec3 c = INK_PAPER;
	if (index == 1) { c = INK_VERMILION; }
	if (index == 2) { c = INK_GOLD; }
	if (index == 3) { c = INK_BLACK; }
	if (index == 4) { c = INK_CURSE_RED; }
	if (index == 5) { c = INK_SEPIA; }
	if (index == 6) { c = INK_PARCHMENT; }
	if (index == 7) { c = INK_CURSE_INK; }
	if (index >= 100) { c = vec3(float(index - 100) / 255.0); }
	ALBEDO = ink_out(c);
}
