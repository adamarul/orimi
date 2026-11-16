// fx_sprite.gdshaderinc: the body of fx_sprite.gdshader and fx_sprite_flat.gdshader. Owner: vfx.
// Per instance: transform (origin and size), INSTANCE_CUSTOM = (frame [+64 mirrors], erode 0..1,
// rotation radians, stroke head 0..1), COLOR = (tint rgb, stroke tail 0..1). Uniforms are
// documented in docs/SHADERS_VFX.md.

#include "res://shaders/vfx/vfx_common.gdshaderinc"

uniform sampler2D atlas : filter_linear_mipmap, repeat_disable, hint_default_black;
uniform vec2 atlas_grid = vec2(4.0, 2.0);
// 0 billboard, 1 placed by the transform (flat on the ground), 2 upright card rooted at the
// origin (turns about Y), 3 billboard whose X axis follows the transform's X direction on screen.
uniform int align : hint_range(0, 3) = 0;
// 0 ink (R mask, G soak order), 1 petal (R mask, G edge light, B second pink),
// 2 flower (R blossom, G stem, B centre), 3 stroke (R mask, G arc parameter),
// 4 soot (R mask, G tone, B soak order).
uniform int look : hint_range(0, 4) = 0;
uniform vec4 color_a : source_color = vec4(0.106, 0.102, 0.110, 1.0);
uniform vec4 color_b : source_color = vec4(0.420, 0.400, 0.380, 1.0);
uniform vec4 color_c : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float cutoff : hint_range(0.05, 0.95) = 0.5;
// 0.5 roots the quad at its bottom edge (upright cards), 0 centres it.
uniform float pivot_y : hint_range(0.0, 0.5) = 0.0;
// Distance fade toward paper, matching render's toon (metres, metres, 0..1).
uniform float fade_start = 35.0;
uniform float fade_end = 140.0;
uniform float fade_max : hint_range(0.0, 1.0) = 0.85;

varying vec4 v_custom;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	v_custom = INSTANCE_CUSTOM;
	vec2 q = VERTEX.xy + vec2(0.0, pivot_y);
	if (align == 1) {
		vec3 w = (MODEL_MATRIX * vec4(q, 0.0, 1.0)).xyz;
		VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
	} else if (align == 2) {
		vec3 right = vfx_upright_right(origin, CAMERA_POSITION_WORLD);
		float lean = INSTANCE_CUSTOM.z;
		vec2 p = vec2(q.x * sx, q.y * sy);
		p = vec2(p.x * cos(lean) - p.y * sin(lean), p.x * sin(lean) + p.y * cos(lean));
		vec3 w = origin + right * p.x + vec3(0.0, p.y, 0.0);
		VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
	} else {
		vec3 c = (VIEW_MATRIX * vec4(origin, 1.0)).xyz;
		vec2 axis = vec2(1.0, 0.0);
		float rot = INSTANCE_CUSTOM.z;
		if (align == 3) {
			vec3 d = (VIEW_MATRIX * vec4(MODEL_MATRIX[0].xyz, 0.0)).xyz;
			axis = length(d.xy) > 0.00001 ? normalize(d.xy) : vec2(1.0, 0.0);
		}
		axis = vec2(axis.x * cos(rot) - axis.y * sin(rot), axis.x * sin(rot) + axis.y * cos(rot));
		vec2 p = q * vec2(sx, sy);
		VERTEX = c + vec3(p.x * axis.x - p.y * axis.y, p.x * axis.y + p.y * axis.x, 0.0);
	}
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	float frame = v_custom.x;
	vec2 uv = UV;
	if (frame >= 63.5) {
		frame -= 64.0;
		uv.y = 1.0 - uv.y;
	}
	vec4 t = texture(atlas, vfx_atlas_uv(uv, frame, atlas_grid));
	float erode = v_custom.y;
	vec3 tint = COLOR.rgb;
	vec3 col;
	float mask;
	if (look == 0) {
		mask = t.r;
		if (erode > 0.0 && t.g < erode) {
			discard;
		}
		col = ink_in(color_a.rgb) * tint;
	} else if (look == 1) {
		mask = t.r - erode * 0.45;
		col = mix(ink_in(color_a.rgb), ink_in(color_b.rgb), step(0.5, t.b)) * tint;
		col = mix(col, ink_in(color_c.rgb), clamp(t.g * 1.4, 0.0, 1.0));
	} else if (look == 2) {
		mask = max(t.r, max(t.g, t.b)) - erode * 0.5;
		col = tint;
		col = mix(col, ink_in(color_b.rgb), step(t.r + t.b, t.g));
		col = mix(col, ink_in(color_c.rgb), step(0.5, t.b));
	} else if (look == 3) {
		mask = t.r - erode * 0.45;
		float s = t.g;
		if (s < COLOR.a || s > v_custom.w || s <= 0.0) {
			discard;
		}
		col = ink_in(color_a.rgb) * tint;
	} else {
		mask = t.r;
		if (erode > 0.0 && t.b < erode) {
			discard;
		}
		col = mix(ink_in(color_a.rgb), ink_in(color_b.rgb), t.g) * tint;
	}
	if (mask < cutoff) {
		discard;
	}
	col = mix(col, INK_PAPER, ink_paper_fade(length(VERTEX), fade_start, fade_end) * fade_max);
	ALBEDO = ink_out(col);
#ifdef FX_SPRITE_FLAT
	ALPHA = 1.0;
#endif
}
