// Ink stroke: black ink with dry-brush streaks. Geometry comes from BrushStroke: UV.x is arc
// length in pixels, UV.y runs -1..1 across the stroke, vertex COLOR.r is dryness 0..1 and
// COLOR.g the stroke width in pixels / 64 (so bristle streaks keep a constant pixel size),
// COLOR.a an opacity for that vertex.
// Used by the brush view, the glyph cards and the ink pot. Canvas colours are sRGB in both
// renderers, so the ink constant needs no gating.
shader_type canvas_item;
render_mode unshaded;

uniform vec3 ink_colour = vec3(0.106, 0.102, 0.110);
// Overall opacity, for fading a stroke out.
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
// 0 intact, 1 gone: a failed stroke breaks up along its streaks.
uniform float decay : hint_range(0.0, 1.0) = 0.0;
// Extra dryness on top of the per-vertex value (cards and the pot use it for texture).
uniform float dry_bias : hint_range(0.0, 1.0) = 0.0;
// Streak length along the stroke, and bristle spacing across it, in pixels.
uniform float streak_length = 70.0;
uniform float bristle_spacing = 2.6;

varying float dry;
varying float width_px;
varying float vertex_alpha;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Cell coordinates wrap at 289 so the hash keeps its precision far from the origin.
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(mod(i, 289.0));
	float b = hash(mod(i + vec2(1.0, 0.0), 289.0));
	float c = hash(mod(i + vec2(0.0, 1.0), 289.0));
	float d = hash(mod(i + vec2(1.0, 1.0), 289.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void vertex() {
	dry = COLOR.r;
	width_px = COLOR.g * 64.0;
	vertex_alpha = COLOR.a;
}

void fragment() {
	float across = UV.y;
	float e = abs(across);
	float aa = max(fwidth(across) * 1.5, 0.02);
	float edge = 1.0 - smoothstep(1.0 - aa, 1.0, e);
	float d = clamp(dry + dry_bias, 0.0, 1.0);
	// Bristle streaks: noise that varies fast across the stroke and slowly along it.
	// Across coordinate in pixels from the centre line, divided into bristles.
	float bristles = across * 0.5 * max(width_px, 1.0) / bristle_spacing;
	float streak = vnoise(vec2(UV.x / streak_length, bristles + 1.3)) * 0.65
		+ vnoise(vec2(UV.x / (streak_length * 0.25), bristles * 2.3 + 7.1)) * 0.35;
	// Dry ink breaks up at the edges first, then through the middle.
	float cut = d * mix(0.32, 1.0, pow(e, 1.5));
	float keep = smoothstep(cut - 0.06, cut + 0.06, streak);
	// Wet ink pools slightly darker at the edges.
	float body = mix(0.9, 1.0, smoothstep(0.5, 1.0, e)) * (1.0 - d * 0.12);
	float a = edge * keep * body * opacity * vertex_alpha;
	a *= 1.0 - smoothstep(streak - 0.15, streak + 0.05, decay * 1.2 - 0.1);
	COLOR = vec4(ink_colour, a);
}
