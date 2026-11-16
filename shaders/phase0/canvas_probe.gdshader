// Phase 0 canvas (2D overlay) probe passes.
// mode 0: tile 6 = can a canvas pass read the 3D post output (pass A's marker)?
//         tile 7 = cyan marker; tile 10 = background colour space as seen from canvas
// mode 1: tile target_tile = does this pass see the tile 7 marker (with or without BackBufferCopy)?
shader_type canvas_item;

#include "res://shaders/phase0/probe_tiles.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform int mode = 0;
uniform int target_tile = 8;
uniform vec3 bg_srgb;
uniform vec2 bg_uv;

void fragment() {
	int t = probe_tile(SCREEN_UV);
	vec3 c = TILE_FAIL;
	if (mode == 0) {
		if (t == 6) {
			c = probe_near(texture(screen_tex, probe_tile_center(0)).rgb, TILE_MARK_A, 0.1) ? TILE_PASS : TILE_FAIL;
		} else if (t == 7) {
			c = TILE_MARK_C;
		} else if (t == 10) {
			vec3 s = texture(screen_tex, bg_uv).rgb;
			if (probe_near(s, probe_srgb_to_linear(bg_srgb), 0.04)) {
				c = TILE_PASS;
			} else if (probe_near(s, bg_srgb, 0.04)) {
				c = TILE_ALT;
			}
		} else {
			discard;
		}
	} else {
		if (t != target_tile) {
			discard;
		}
		c = probe_near(texture(screen_tex, probe_tile_center(7)).rgb, TILE_MARK_C, 0.1) ? TILE_PASS : TILE_FAIL;
	}
	COLOR = vec4(c, 1.0);
}
