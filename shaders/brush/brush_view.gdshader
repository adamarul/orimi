// Brush view: turns the frozen frame into a monochrome sepia underpainting on scroll paper.
// Canvas pass on the Brush layer (30), after a BackBufferCopy, so it sees the 3D frame, the
// post chain and the HUD. The canvas screen texture holds sRGB values in both renderers and
// canvas output is sRGB in both, so no renderer gating is needed here.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
// 0 closed, 1 fully open. The paper bleeds in from the corners with a ragged front.
uniform float fade : hint_range(0.0, 1.0) = 0.0;
// How much of the scene shows in the underpainting (0 bare paper, 1 full tonal range).
uniform float scene_strength : hint_range(0.0, 1.0) = 0.62;
// Contrast of the scene's luminance before it is mapped to sepia (1 unchanged).
uniform float contrast : hint_range(0.2, 1.5) = 0.8;
uniform vec3 paper_colour = vec3(0.925, 0.878, 0.776);
uniform vec3 sepia_colour = vec3(0.596, 0.463, 0.322);
uniform vec3 ink_colour = vec3(0.180, 0.125, 0.082);
// Darkening at the edges (0 none, 1 strong).
uniform float vignette : hint_range(0.0, 1.0) = 0.5;
// Paper tooth strength and cell size in pixels at 720 p.
uniform float tooth : hint_range(0.0, 0.2) = 0.07;
uniform float tooth_cell = 3.5;

float hash(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.7);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	float scale = 720.0 * px.y;
	// Soft 9-tap blur: the underpainting is a wash, not a photograph.
	vec2 o = px * 2.0 / scale;
	vec3 c = texture(screen_tex, uv).rgb * 0.25;
	c += (texture(screen_tex, uv + vec2(o.x, 0.0)).rgb + texture(screen_tex, uv - vec2(o.x, 0.0)).rgb
		+ texture(screen_tex, uv + vec2(0.0, o.y)).rgb + texture(screen_tex, uv - vec2(0.0, o.y)).rgb) * 0.125;
	c += (texture(screen_tex, uv + o).rgb + texture(screen_tex, uv - o).rgb
		+ texture(screen_tex, uv + vec2(o.x, -o.y)).rgb + texture(screen_tex, uv + vec2(-o.x, o.y)).rgb) * 0.0625;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	lum = clamp((lum - 0.5) * contrast + 0.55, 0.0, 1.0);
	vec3 tone = lum < 0.5 ? mix(ink_colour, sepia_colour, lum * 2.0) : mix(sepia_colour, paper_colour, lum * 2.0 - 1.0);
	vec3 col = mix(paper_colour, tone, scene_strength);

	// Paper, fixed to the screen: tooth as a relief lit from the upper left, large stains.
	vec2 pix = uv / px * scale;
	float h0 = vnoise(pix / tooth_cell);
	float h1 = vnoise((pix + vec2(-1.0, -1.0)) / tooth_cell);
	col *= 1.0 + (h1 - h0) * tooth * 2.0 + (h0 - 0.5) * tooth * 0.5;
	vec2 aspect = vec2(px.y / px.x, 1.0);
	float stain = fbm(uv * aspect * 2.5 + 3.7);
	col *= 1.0 - 0.08 * smoothstep(0.45, 0.8, stain);

	vec2 d = (uv - 0.5) * aspect;
	float edge = smoothstep(0.3, 0.95, length(d) * 1.25 + (stain - 0.5) * 0.15);
	col = mix(col, col * vec3(0.52, 0.42, 0.33), edge * vignette);

	// Ragged fade: the paper bleeds in from the corners first.
	float n = fbm(uv * aspect * 5.0) * 0.7 + (1.0 - edge) * 0.3;
	float a = smoothstep(n - 0.08, n + 0.08, fade * 1.25 - 0.1);
	COLOR = vec4(col, a);
}
