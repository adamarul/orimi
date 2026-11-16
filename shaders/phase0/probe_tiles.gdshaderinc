// Shared layout for the phase 0 screen-space probe tiles (top-left strip of the screen).
// Each tile is written by one post pass and read back by scripts/phase0/phase0.gd.
// Keep these constants in sync with TILE_* in phase0.gd.

const float TILE_X0 = 0.02;
const float TILE_STEP = 0.06;
const float TILE_W = 0.05;
const float TILE_Y0 = 0.02;
const float TILE_Y1 = 0.08;

const vec3 TILE_PASS = vec3(0.0, 1.0, 0.0);
const vec3 TILE_FAIL = vec3(1.0, 0.0, 0.0);
const vec3 TILE_ALT = vec3(0.0, 0.0, 1.0);
const vec3 TILE_NA = vec3(1.0, 1.0, 0.0);
const vec3 TILE_MARK_A = vec3(1.0, 0.0, 1.0);
const vec3 TILE_MARK_C = vec3(0.0, 1.0, 1.0);

int probe_tile(vec2 uv) {
	if (uv.y < TILE_Y0 || uv.y > TILE_Y1) {
		return -1;
	}
	float f = (uv.x - TILE_X0) / TILE_STEP;
	if (f < 0.0 || fract(f) * TILE_STEP > TILE_W) {
		return -1;
	}
	return int(floor(f));
}

vec2 probe_tile_center(int i) {
	return vec2(TILE_X0 + float(i) * TILE_STEP + TILE_W * 0.5, (TILE_Y0 + TILE_Y1) * 0.5);
}

bool probe_near(vec3 a, vec3 b, float tol) {
	return all(lessThan(abs(a - b), vec3(tol)));
}

vec3 probe_srgb_to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
}
