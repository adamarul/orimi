// ink_common.gdshaderinc: the one shared include for every Orimi shader. Owner: render.
// Keep it small and stable; other workstreams include it. Documented in docs/SHADERS.md.
//
// COLOUR RULE (docs/RENDERER_NOTES.md). Do colour maths in display (sRGB) values, the values
// Palette holds. Then:
//   * spatial ALBEDO / EMISSION you computed  -> ink_out(c)     (Forward+ encodes on output)
//   * a source_color uniform or texture read  -> ink_in(c)      (Forward+ hands you linear)
//   * the 3D screen texture (spatial shaders) -> ink_in(c)      (linear on desktop, sRGB on web)
//   * canvas_item shaders and their screen texture are sRGB in both renderers: no conversion.
//   * plain vec4 uniforms (no source_color) set from a Palette Color arrive as sRGB already.
//   * alpha of a dark translucent overlay     -> ink_alpha(a)   (web blends in sRGB space)
// Everything in this file is a function or a constant: no samplers, no varyings. The global
// uniforms below are declared once here so a shader that includes this file can use them.

#ifndef INK_COMMON_INCLUDED
#define INK_COMMON_INCLUDED

global uniform float paper_intensity;
global uniform vec4 curse_zone_0;
global uniform vec4 curse_zone_1;
global uniform vec4 curse_zone_2;
global uniform vec4 curse_zone_3;
global uniform vec4 curse_amount;
global uniform float valley_gloom;
global uniform vec4 wind;
// Light pools (LightPools, scripts/render/light_pools.gd): x drained, y darkness, z warmth,
// w 1 while any pool is lit. light_shade: rgb multiplier at full darkness, a the view distance
// beyond which drained and darkness thin out (the sky keeps its colour).
global uniform vec4 light_field;
global uniform vec4 light_shade;
// rgb: tint of the drained colour (dusk), a: how much of its colour a drained surface keeps.
global uniform vec4 light_tint;
// The nearest pools to the camera: xyz centre, w radius; tint rgb light colour, a strength.
global uniform vec4 light_pool_0;
global uniform vec4 light_pool_1;
global uniform vec4 light_pool_2;
global uniform vec4 light_pool_3;
global uniform vec4 light_pool_4;
global uniform vec4 light_pool_5;
global uniform vec4 light_pool_6;
global uniform vec4 light_pool_7;
global uniform vec4 light_tint_0;
global uniform vec4 light_tint_1;
global uniform vec4 light_tint_2;
global uniform vec4 light_tint_3;
global uniform vec4 light_tint_4;
global uniform vec4 light_tint_5;
global uniform vec4 light_tint_6;
global uniform vec4 light_tint_7;

#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
#define INK_LINEAR_PIPELINE 0
#else
#define INK_LINEAR_PIPELINE 1
#endif

// Palette, as sRGB values (same numbers as scripts/core/palette.gd).
const vec3 INK_PAPER = vec3(0.937, 0.902, 0.824);      // IVORY  efe6d2
const vec3 INK_PARCHMENT = vec3(0.890, 0.827, 0.690);  // PARCHMENT e3d3b0
const vec3 INK_SEPIA = vec3(0.420, 0.290, 0.169);      // SEPIA 6b4a2b
const vec3 INK_BLACK = vec3(0.106, 0.102, 0.110);      // INK 1b1a1c
const vec3 INK_CURSE_RED = vec3(0.702, 0.125, 0.165);  // CURSE_RED b3202a
const vec3 INK_CURSE_INK = vec3(0.051, 0.047, 0.055);  // CURSE_INK 0d0c0e
const vec3 INK_VERMILION = vec3(0.835, 0.251, 0.169);  // VERMILION d5402b
const vec3 INK_GOLD = vec3(0.851, 0.643, 0.255);       // GOLD d9a441

vec3 ink_srgb_to_linear(vec3 c) {
	c = max(c, vec3(0.0));
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec3 ink_linear_to_srgb(vec3 c) {
	c = max(c, vec3(0.0));
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

// A colour you computed (sRGB values) to what a spatial shader writes to ALBEDO / EMISSION.
// On web, each 3D pass crushes the darkest values (measured with scenes/dev/render_probe.tscn,
// ramp=1: 8/255 comes out as 1/255, 24 as 21, 56 and above exact), so the web branch lifts
// values below 56/255 by the measured inverse. With it, Palette INK and CURSE_INK read back
// within 4/255 directly and through the post chain.
// Shaders call it as ink_out(c): a macro (end of this file) that first applies the light pools.
vec3 ink_encode(vec3 srgb) {
#if INK_LINEAR_PIPELINE
	return ink_srgb_to_linear(srgb);
#else
	vec3 t = max(vec3(1.0) - srgb * (255.0 / 56.0), vec3(0.0));
	return srgb + (7.0 / 255.0) * t * sqrt(t);
#endif
}

// A source_color uniform / texture sample, or the 3D screen texture, to sRGB values.
vec3 ink_in(vec3 c) {
#if INK_LINEAR_PIPELINE
	return ink_linear_to_srgb(c);
#else
	return c;
#endif
}

// Alpha for a dark translucent overlay in a spatial shader, so desktop (linear blending) matches
// the web (sRGB blending). Exact for a black overlay; close for any dark one.
float ink_alpha(float a) {
#if INK_LINEAR_PIPELINE
	return 1.0 - pow(1.0 - clamp(a, 0.0, 1.0), 2.2);
#else
	return a;
#endif
}

float ink_luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

// Depth-texture sample at uv to view-space position (spatial shaders, pass INV_PROJECTION_MATRIX).
vec3 ink_view_pos(float depth, vec2 uv, mat4 inv_proj) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(uv * 2.0 - 1.0, depth);
#endif
	vec4 v = inv_proj * vec4(ndc, 1.0);
	return v.xyz / v.w;
}

// ---- noise (cheap, procedural, deterministic) ----

float ink_hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float ink_hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float ink_noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = ink_hash12(i);
	float b = ink_hash12(i + vec2(1.0, 0.0));
	float c = ink_hash12(i + vec2(0.0, 1.0));
	float d = ink_hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float ink_noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	float n000 = ink_hash13(i);
	float n100 = ink_hash13(i + vec3(1.0, 0.0, 0.0));
	float n010 = ink_hash13(i + vec3(0.0, 1.0, 0.0));
	float n110 = ink_hash13(i + vec3(1.0, 1.0, 0.0));
	float n001 = ink_hash13(i + vec3(0.0, 0.0, 1.0));
	float n101 = ink_hash13(i + vec3(1.0, 0.0, 1.0));
	float n011 = ink_hash13(i + vec3(0.0, 1.0, 1.0));
	float n111 = ink_hash13(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(n000, n100, u.x), mix(n010, n110, u.x), u.y),
			mix(mix(n001, n101, u.x), mix(n011, n111, u.x), u.y), u.z);
}

// Time quantised to fps steps: the "lines breathe" re-seed (stepped, never smooth).
float ink_stepped_time(float t, float fps) {
	return floor(t * fps) / max(fps, 0.001);
}

// ---- distance fade toward paper ----

// 0 near, 1 fully faded to paper, by camera distance.
float ink_paper_fade(float dist, float fade_start, float fade_end) {
	float f = clamp((dist - fade_start) / max(fade_end - fade_start, 0.001), 0.0, 1.0);
	return f * f * (3.0 - 2.0 * f);
}

// ---- wind sway (shared by the toon body and its outline so the hull follows) ----

// World-space offset for a vertex at world_pos with sway weight (vertex colour G) and
// a height above the object's origin. wind_vec = the "wind" global, t = TIME.
vec3 ink_wind_offset(vec3 world_pos, float weight, float height, vec4 wind_vec, float t, float amount) {
	vec3 dir = wind_vec.xyz;
	float len = length(dir);
	dir = len > 0.0001 ? dir / len : vec3(1.0, 0.0, 0.0);
	float phase = dot(world_pos.xz, vec2(0.37, 0.23));
	float sway = sin(t * 1.7 + phase) * 0.6 + sin(t * 3.1 + phase * 1.7) * 0.25 + 0.35;
	return dir * sway * wind_vec.w * weight * amount * max(height, 0.0);
}

// ---- curse ----
// A zone is a sphere (curse_zone_N: xyz centre, w radius) with an amount (curse_amount):
// 1 = fully cursed, 0 = clean. Restoration is a hard ragged front: the clean disc around the
// centre grows from radius 0 (amount 1) to past the rim (amount 0). CurseField.front_radius()
// matches INK_CURSE_FRONT on the CPU side.

#define INK_CURSE_FRONT(r, a) ((1.0 - (a)) * ((r) * 1.25 + 2.0))

// Horizontal distance from a zone's centre (zones are upright cylinders, like the wall ring), and
// vert: 1 up to half a radius above or below the centre, fading to 0 over max(0.3 r, 4 m), so a
// tall trunk or cliff fades out of the zone instead of crossing a sphere's shell in a band.
float ink_curse_reach(vec3 world_pos, vec4 zone, out float vert) {
	float h = abs(world_pos.y - zone.y);
	vert = 1.0 - smoothstep(zone.w * 0.5, zone.w * 0.5 + max(zone.w * 0.3, 4.0), h);
	return length(world_pos.xz - zone.xz);
}

// Cursed-ness of one zone at world_pos. rag (0..1) is a noise sample used to tear the edges.
// Outputs: inside (0/1, the drained interior incl. the black wall), wall (0/1, the opaque black
// band just inside the boundary), rim (0..1, the feathered crimson glow just outside it),
// front_edge (0/1, a thin dark lip on the cursed side of a moving restoration front).
// rim_world is the rim width in metres at this pixel (from ink_world_per_screen_h).
void ink_curse_zone(vec3 world_pos, vec4 zone, float amount, float rag, float rim_world,
		inout float inside, inout float wall, inout float rim, inout float front_edge) {
	float r = zone.w;
	if (r <= 0.0 || amount <= 0.0) {
		return;
	}
	float vert;
	float d = ink_curse_reach(world_pos, zone, vert);
	if (vert <= 0.0) {
		return;
	}
	float tear = (rag - 0.5);
	float front = INK_CURSE_FRONT(r, amount) + tear * 1.6;
	float edge = r + tear * max(r * 0.06, 0.6);
	if (d < front || d > edge + rim_world * 1.5) {
		return;
	}
	float in_zone = step(d, edge);
	inside = max(inside, in_zone * vert);
	float wall_w = max(r * 0.035, 0.5) * (0.6 + rag * 0.8);
	wall = max(wall, in_zone * step(edge - wall_w, d) * vert);
	float out_d = (d - edge) / max(rim_world, 0.001);
	rim = max(rim, (1.0 - in_zone) * (1.0 - smoothstep(0.0, 1.5, out_d)) * vert);
	front_edge = max(front_edge, in_zone * (1.0 - step(front + 0.35, d)) * step(0.001, 1.0 - amount) * vert);
}

// Size in metres of one screen height at view distance dist (pass PROJECTION_MATRIX[1][1]; its
// sign differs between renderers because Forward+ flips Y, so only the magnitude is used).
float ink_world_per_screen_h(float dist, float proj_11) {
	return 2.0 * dist / max(abs(proj_11), 0.0001);
}

// All four zones. Same outputs as ink_curse_zone.
void ink_curse(vec3 world_pos, float rag, float rim_world,
		out float inside, out float wall, out float rim, out float front_edge) {
	inside = 0.0;
	wall = 0.0;
	rim = 0.0;
	front_edge = 0.0;
	ink_curse_zone(world_pos, curse_zone_0, curse_amount.x, rag, rim_world, inside, wall, rim, front_edge);
	ink_curse_zone(world_pos, curse_zone_1, curse_amount.y, rag, rim_world, inside, wall, rim, front_edge);
	ink_curse_zone(world_pos, curse_zone_2, curse_amount.z, rag, rim_world, inside, wall, rim, front_edge);
	ink_curse_zone(world_pos, curse_zone_3, curse_amount.w, rag, rim_world, inside, wall, rim, front_edge);
}

// 0..1 closeness to the boundary of the cursed zone world_pos is in: 1 at the rim, falling to 0
// by width metres inside. 0 outside every zone. For the red light that pools near the black mass.
float ink_curse_edge(vec3 world_pos, float width) {
	float result = 0.0;
	vec4 zones[4] = vec4[4](curse_zone_0, curse_zone_1, curse_zone_2, curse_zone_3);
	float amounts[4] = float[4](curse_amount.x, curse_amount.y, curse_amount.z, curse_amount.w);
	for (int i = 0; i < 4; i++) {
		float r = zones[i].w;
		if (r <= 0.0 || amounts[i] <= 0.0) {
			continue;
		}
		float vert;
		float d = ink_curse_reach(world_pos, zones[i], vert);
		if (d > r) {
			continue;
		}
		result = max(result, (1.0 - clamp((r - d) / max(width, 0.001), 0.0, 1.0)) * vert);
	}
	return result;
}

// Soft 0..1 curse amount at world_pos, ignoring the tearing (for effects that only need
// "how cursed is it here", e.g. a sky or water shader). Matches CurseField.amount_at().
float ink_curse_amount_at(vec3 world_pos) {
	float result = 0.0;
	vec4 zones[4] = vec4[4](curse_zone_0, curse_zone_1, curse_zone_2, curse_zone_3);
	float amounts[4] = float[4](curse_amount.x, curse_amount.y, curse_amount.z, curse_amount.w);
	for (int i = 0; i < 4; i++) {
		float r = zones[i].w;
		if (r <= 0.0 || amounts[i] <= 0.0) {
			continue;
		}
		float vert;
		float d = ink_curse_reach(world_pos, zones[i], vert);
		float front = INK_CURSE_FRONT(r, amounts[i]);
		float v = (1.0 - smoothstep(r * 0.9, r, d)) * smoothstep(front - 0.5, front + 0.5, d) * vert;
		result = max(result, v);
	}
	return result;
}

// One light pool: raises lit (inside the ragged edge) and adds its core warmth and colour.
void ink_light_pool(vec3 p, float rag, vec4 pool, vec4 tint, inout float lit, inout vec4 warm) {
	vec3 off = p - pool.xyz;
	off.y *= 0.6;
	float r = max(pool.w, 0.001);
	float d = clamp((length(off) + rag * min(r * 0.3, 1.8)) / r, 0.0, 1.0);
	float s = step(0.001, pool.w) * tint.a;
	lit = max(lit, (1.0 - smoothstep(0.8, 1.0, d)) * s);
	float k = (1.0 - d) * (1.0 - d) * s;
	warm += vec4(tint.rgb * k, k);
}

// Light pools on a finished sRGB colour at world_pos, view_dist metres from the camera. Outside
// every pool, `drained` greys the colour (an unpainted drawing) and `darkness` multiplies it by
// the shade colour; inside a pool the colour comes back, warmed toward the light's colour near
// its centre. Pools have a ragged edge. A no-op (exactly c) while LightPools is off. Kept small
// and written out light by light: every shader that calls ink_out compiles it, and the browser's
// shader compile time grows with it.
vec3 ink_light(vec3 c, vec3 world_pos, float view_dist, float keep) {
	if (light_field.x <= 0.0 && light_field.y <= 0.0 && light_field.w <= 0.0) {
		return c;
	}
	float lit = 0.0;
	vec4 warm = vec4(0.0);
	if (light_field.w > 0.0) {
		float rag = sin(world_pos.x * 1.7 + sin(world_pos.z * 1.3)) * 0.3 + sin(world_pos.z * 2.3 + world_pos.y) * 0.2;
		ink_light_pool(world_pos, rag, light_pool_0, light_tint_0, lit, warm);
		ink_light_pool(world_pos, rag, light_pool_1, light_tint_1, lit, warm);
		ink_light_pool(world_pos, rag, light_pool_2, light_tint_2, lit, warm);
		ink_light_pool(world_pos, rag, light_pool_3, light_tint_3, lit, warm);
		ink_light_pool(world_pos, rag, light_pool_4, light_tint_4, lit, warm);
		ink_light_pool(world_pos, rag, light_pool_5, light_tint_5, lit, warm);
		ink_light_pool(world_pos, rag, light_pool_6, light_tint_6, lit, warm);
		ink_light_pool(world_pos, rag, light_pool_7, light_tint_7, lit, warm);
	}
	vec3 tint = warm.w > 0.0 ? warm.rgb / warm.w : vec3(1.0);
	float core = min(warm.w, 1.0);
	float near = (1.0 - 0.85 * smoothstep(light_shade.a * 0.8, light_shade.a, view_dist)) * (1.0 - clamp(keep, 0.0, 1.0));
	float l = ink_luma(c);
	vec3 drained = mix(vec3(l), c, light_tint.a) * light_tint.rgb;
	c = mix(c, drained, clamp(light_field.x * (1.0 - lit) * near, 0.0, 1.0));
	c = mix(c, c * tint * 1.12, core * light_field.z);
	float dark = clamp(light_field.y * (1.0 - lit) * near, 0.0, 1.0);
	c *= mix(vec3(1.0), light_shade.rgb, dark);
	return c;
}

// The colour rule's output step, with the light pools applied first. Must be called in
// fragment() (it reads VERTEX and INV_VIEW_MATRIX). A shader that draws a full-screen pass
// defines INK_NO_LIGHT before including this file.
// INK_LIGHT_KEEP (define it before the include, as a constant or a uniform's name): how much of
// its own colour the shader keeps against drained and darkness, 0 by default.
#ifndef INK_LIGHT_KEEP
#define INK_LIGHT_KEEP 0.0
#endif
#ifdef INK_NO_LIGHT
#define ink_out(c) ink_encode(c)
#else
#define ink_out(c) ink_encode(ink_light((c), (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz, length(VERTEX), INK_LIGHT_KEEP))
#endif

// For a translucent veil (mist): rgb is ink_out's colour, a is how much of its opacity it keeps,
// the ratio of its lit to its own brightness, so a pale veil fades out in the dark instead of
// lifting the darkened scene behind it. ALBEDO = v.rgb; ALPHA = alpha * v.a.
vec4 ink_light_veil(vec3 c, vec3 world_pos, float view_dist, float keep) {
	vec3 lc = ink_light(c, world_pos, view_dist, keep);
	return vec4(ink_encode(lc), clamp(ink_luma(lc) / max(ink_luma(c), 0.001), 0.0, 1.0));
}
#define ink_veil(c) ink_light_veil((c), (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz, length(VERTEX), INK_LIGHT_KEEP)

#endif
