// Phase 0 probe pass B (3D full-screen quad, drawn after pass A). Tile 5 turns green only if this
// pass's screen texture already contains pass A's magenta marker, i.e. 3D screen-reading passes chain.
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://shaders/phase0/probe_tiles.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	if (probe_tile(SCREEN_UV) != 5) {
		discard;
	}
	vec3 s = texture(screen_tex, probe_tile_center(0)).rgb;
	ALBEDO = probe_near(s, TILE_MARK_A, 0.1) ? TILE_PASS : TILE_FAIL;
	ALPHA = 1.0;
}
