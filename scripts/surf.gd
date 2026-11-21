class_name Surf
extends RefCounted

## User request (the sandy beach): waves rolling in from the sea, breaking white in the shallows,
## a thin sheet of water running up the sand and draining back down it; the sand dark and wet where
## the water reached, keeping the shape of that wave's reach, drying slowly back to pale - and wet
## again when the next one comes.
##
## One model of the surf for all of it - the sea's surface (RunView3D.WATER_SHADER: the swell, the
## breaking and its foam), the sand (GROUND_SHADER: the sheet, its foam, the wet sand) and the
## sand's wetness (SurfWetness: what the water has covered, kept and drying) - so the water, its
## foam and the wet sand are always in the same place. GLSL here for the shaders, the same in
## GDScript (cover) for the game (footprints washed away, tests).
##
## How it goes: the waves come in one after another, SURF_EVERY s apart on average - each its own:
## a little sooner or later than the beat, bigger or smaller (sets of bigger ones now and then), and
## each running up the beach its own way along the shore; along the coast they arrive a little
## after one another (a slant). A wave's crest reaches the water's edge, breaks into a bore and runs
## up the sand - fast at first, slowing to a stop at its highest (as a ball thrown up a slope), then
## drains back, faster and faster, to the water's edge; there the water waits, a little below its
## mean line, for the next.

# ---------------------------------------------------------------- the knobs (調整參數)

## 浪高 (m): how high the swell lifts the sea out in the water.
const HEIGHT := 0.12
## 浪速 (px/s): how fast the waves come in across the water (their spacing = SPEED x EVERY).
const SPEED := 40.0
## 波浪間隔 (s): a wave reaching the shore every this many seconds, on average.
const EVERY := 7.5
## (0 every wave the same, on the beat .. 1 each its own size, the beat loose by about a quarter)
const IRREGULAR := 1.0
## 上沖距離 (px up the sand from the water's edge): the smallest wave's reach, the biggest's.
const RUN_UP := Vector2(26.0, 64.0)
## 沿岸時間差 (waves): how much sooner or later a wave reaches one stretch of the beach than the
## next - smoothly along it, some metres a little ahead, then a little behind (0: all at once;
## at this, about half a second a metre at most).
const ALONG_LAG := 0.22
## (how far below its mean line the water's edge falls between waves, px)
const LOW := 10.0
## 上沖時間: the share of a wave's time it takes to run up (smaller: quicker).
const UP := 0.22
## 回流速度: the share of a wave's time it takes to drain back down (smaller: quicker).
const BACK := 0.5
## 泡沫量 (0 none .. 1 as made .. more).
const FOAM := 1.0
## 乾沙 (on its picture) / 濕沙深淺 (how much darker soaked sand is: 1 no darker) / 濕沙色調
## (soaked sand's cast - a little cooler).
const SAND_DRY := Color(1.0, 1.0, 1.0)
const WET_DARK := 0.7
const WET_TINT := Color(0.93, 0.97, 1.04)
## 濕沙反光強度 (0 none .. 1 glassy): the wet sand's quiet gleam; and the sheet of water's own.
const SHEEN := 0.35
const SHEET_SHEEN := 0.28
## (the thin sheet of water: how far behind its front it's as deep as it gets (px), and the sea's
## colour in it at its deepest)
const SHEET_DEEP := 46.0
const SHEET_TINT := Color(0.8, 0.9, 0.93)
## 乾燥時間 (s): from soaked to dry again after the water's gone - several waves' time.
const DRY_TIME := 32.0
## 水膜流走時間 (s): the film of water left on the sand as a wave drains - glassy at first - running
## off and sinking in over this long (well before the sand dries: the gleam goes first, then, much
## later, the dark).
const FILM_TIME := 3.0

## The surf's clock (s): RunView3D moves it on each frame and gives it to the shaders as surf_time
## (the shaders' own TIME isn't the game's: the game can ask where the water is - cover). Wraps
## every WRAP s.
static var time := 0.0
const WRAP := 14400.0


static func advance(delta: float) -> void:
	time = fmod(time + delta, WRAP)


## The knobs into a shader using GLSL.
static func uniforms(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("surf_time", time)
	mat.set_shader_parameter("surf_every", EVERY)
	mat.set_shader_parameter("surf_irregular", IRREGULAR)
	mat.set_shader_parameter("surf_len", SPEED * EVERY)
	mat.set_shader_parameter("surf_height", HEIGHT)
	mat.set_shader_parameter("surf_run_up", RUN_UP)
	mat.set_shader_parameter("surf_low", LOW)
	mat.set_shader_parameter("surf_up", UP)
	mat.set_shader_parameter("surf_back", BACK)
	mat.set_shader_parameter("surf_foam", FOAM)
	mat.set_shader_parameter("surf_along", ALONG_LAG)
	mat.set_shader_parameter("surf_out", MapGenerator.sea_side if MapGenerator.sea_side != Vector2.ZERO else Vector2(0, 1))


# ---------------------------------------------------------------- the model (GLSL)

## World positions are 3D x, z (m); `shore` is px up the beach from the sea's mean edge (minus: out
## in the water) - the sea's depth texture's.
const GLSL := """
uniform float surf_time = 0.0;
uniform float surf_every = 7.0;
uniform float surf_irregular = 1.0;
uniform float surf_len = 280.0;
uniform float surf_height = 0.12;
uniform vec2 surf_run_up = vec2(26.0, 70.0);
uniform float surf_low = 10.0;
uniform float surf_up = 0.2;
uniform float surf_back = 0.46;
uniform float surf_foam = 1.0;
uniform float surf_along = 0.22;
// (the way out to sea, the map's: the waves' patterns laid along and across it)
uniform vec2 surf_out = vec2(0.0, 1.0);
// (how much later the waves reach this stretch of the shore, in waves: a slant along the coast,
// and nearer, a stretch a little ahead, the next a little behind - smoothly)
float surf_lag(vec2 w) {
	return 0.18 * sin(w.x * 0.11 + w.y * 0.07) + 0.14 * sin(w.x * 0.047 - w.y * 0.093 + 1.7)
		+ surf_along * (0.6 * sin(w.x * 0.16 + w.y * 0.13) + 0.4 * sin(w.x * 0.083 - w.y * 0.1 + 2.0));
}
// (value noise, and the foam's own pattern from it: three octaves turned against each other, no grid)
// (an integer hash - exact however far from the world's origin (the sine one goes to patterns
// there), well mixed (PCG): no lines or grids in the noise made from it)
float surf_h21(vec2 p) {
	uvec2 v = uvec2(ivec2(floor(p)) + 1048576);
	v = v * 1664525u + 1013904223u;
	v.x += v.y * 1664525u;
	v.y += v.x * 1664525u;
	v = v ^ (v >> 16u);
	v.x += v.y * 1664525u;
	v.y += v.x * 1664525u;
	v = v ^ (v >> 16u);
	return float(v.x) * (1.0 / 4294967296.0);
}
float surf_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(surf_h21(i), surf_h21(i + vec2(1.0, 0.0)), f.x), mix(surf_h21(i + vec2(0.0, 1.0)), surf_h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
float surf_froth(vec2 q) {
	return surf_noise(mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * q) * 0.55 + surf_noise(mat2(vec2(0.28, -0.96), vec2(0.96, 0.28)) * q * 2.1 + vec2(4.1, 1.3)) * 0.3 + surf_noise(q * 4.3 + vec2(1.7, 8.2)) * 0.15;
}
// (foam's look, 0..1 at `q`, `age` 0 fresh .. 1 old: threads round holes, a few softer clumps, broken
// by gaps - thinning, the gaps widening, as it ages)
float surf_lace(vec2 q, float age) {
	// (warped first, so its holes aren't round cells all of a size)
	q += (vec2(surf_noise(q * 0.7 + vec2(3.1, 7.7)), surf_noise(q * 0.7 + vec2(8.3, 2.9))) - 0.5) * 1.8;
	float f = surf_froth(q);
	float threads = smoothstep(0.7 + 0.2 * age, 0.95, 1.0 - abs(2.0 * f - 1.0));
	// (finer threads between them - holes of many sizes - going first as it ages)
	float g = surf_froth(q * 2.7 + vec2(2.2, 6.1));
	float fibres = smoothstep(0.8, 0.97, 1.0 - abs(2.0 * g - 1.0)) * (1.0 - 0.8 * age);
	float clumps = smoothstep(0.6 + 0.22 * age, 0.9, surf_froth(q * 0.55 + vec2(5.3, 1.1)));
	// (bubbly, not flat: a fine grain all through it)
	float speck = 0.6 + 0.4 * surf_noise(q * 6.3 + vec2(1.3, 9.4));
	float gaps = smoothstep(0.22 + 0.3 * age, 0.58 + 0.2 * age, surf_noise(q * 0.33 + vec2(9.1, 4.4)));
	return clamp(max(max(threads * 0.85, fibres * 0.6), clumps * speck) * speck * gaps, 0.0, 1.0);
}
// (a texture's red sampled smoothly - a cubic B-spline from four bilinear taps: its contours with
// no corners at the texels)
vec4 surf_smooth4(sampler2D tex, vec2 uv) {
	vec2 size = vec2(textureSize(tex, 0));
	vec2 p = uv * size - 0.5;
	vec2 i = floor(p);
	vec2 f = p - i;
	vec2 f2 = f * f;
	vec2 f3 = f2 * f;
	vec2 w0 = (-f3 + 3.0 * f2 - 3.0 * f + 1.0) / 6.0;
	vec2 w1 = (3.0 * f3 - 6.0 * f2 + 4.0) / 6.0;
	vec2 w2 = (-3.0 * f3 + 3.0 * f2 + 3.0 * f + 1.0) / 6.0;
	vec2 w3 = f3 / 6.0;
	vec2 g0 = w0 + w1;
	vec2 g1 = w2 + w3;
	vec2 h0 = (i - 0.5 + w1 / g0) / size;
	vec2 h1 = (i + 1.5 + w3 / g1) / size;
	return g0.y * (g0.x * texture(tex, h0) + g1.x * texture(tex, vec2(h1.x, h0.y)))
		+ g1.y * (g0.x * texture(tex, vec2(h0.x, h1.y)) + g1.x * texture(tex, h1));
}
float surf_smooth(sampler2D tex, vec2 uv) { return surf_smooth4(tex, uv).r; }
// (the waves so far here: its whole part the wave, its fraction how far through it - the crest at
// the water's edge at 0; the beat loosened, never backwards)
float surf_phase(vec2 w) {
	float t = surf_time / surf_every;
	return t + surf_irregular * (0.32 * sin(t * 0.73 + 1.1) + 0.12 * sin(t * 0.31 + 0.4)) + surf_lag(w);
}
float surf_hash(float n) {
	uint h = uint(int(n) + 100000) * 747796405u + 2891336453u;
	h = ((h >> ((h >> 28u) + 4u)) ^ h) * 277803737u;
	h = (h >> 22u) ^ h;
	return float(h) * (1.0 / 4294967296.0);
}
// (each wave's size, 0..1: its own, in sets)
float surf_size(float n) {
	float own = (0.3 + 0.7 * surf_hash(n)) * (0.8 + 0.2 * sin(n * 0.83 + 0.6));
	return clamp(mix(0.62, own, surf_irregular), 0.0, 1.0);
}
// (how far up the sand wave n runs here, px: its size, and its own shape along the shore)
float surf_reach(vec2 w, float n) {
	float shape = 1.0 + surf_irregular * (0.18 * sin(w.x * 0.23 + w.y * 0.19 + n * 2.1) + 0.1 * sin(w.x * 0.61 - w.y * 0.47 + n * 1.3));
	return mix(surf_run_up.x, surf_run_up.y, surf_size(n)) * shape;
}
// (where the water's edge is, px up the sand, `u` through a wave reaching `r`)
float surf_front(float u, float r) {
	float lo = -surf_low;
	if (u < surf_up) {
		float k = 1.0 - u / surf_up;
		return lo + (r - lo) * (1.0 - k * k);
	}
	float b = (u - surf_up) / surf_back;
	return b < 1.0 ? r - (r - lo) * b * b : lo;
}
// (the edge's own wiggle along the shore, px - fingers and scallops, its own each wave)
float surf_wiggle(vec2 w, float n) {
	return 4.5 * sin(w.x * 0.83 + w.y * 0.67 + n * 0.9) + 2.2 * sin(w.x * 1.9 - w.y * 1.6 - n * 1.7);
}
// The water here now: its edge (px up the sand), how far through its wave (u), which wave (n),
// that wave's reach (px) - and how much of here it covers (0..1, the edge soft over a px or two).
float surf_at(vec2 w, float shore, out float edge, out float u, out float n, out float reach) {
	float ph = surf_phase(w);
	n = floor(ph);
	u = ph - n;
	reach = surf_reach(w, n);
	float f = surf_front(u, reach);
	edge = f + surf_wiggle(w, n) * clamp((f + surf_low) / max(reach + surf_low, 1.0), 0.0, 1.0);
	return 1.0 - smoothstep(edge - 1.5, edge + 1.5, shore);
}
"""


# ---------------------------------------------------------------- the model (GDScript)

## The lag along the shore (waves) at `w` (3D x, z m).
static func lag(w: Vector2) -> float:
	return 0.18 * sin(w.x * 0.11 + w.y * 0.07) + 0.14 * sin(w.x * 0.047 - w.y * 0.093 + 1.7) \
		+ ALONG_LAG * (0.6 * sin(w.x * 0.16 + w.y * 0.13) + 0.4 * sin(w.x * 0.083 - w.y * 0.1 + 2.0))


static func phase(w: Vector2, at := -1.0) -> float:
	var t := (time if at < 0.0 else at) / EVERY
	return t + IRREGULAR * (0.32 * sin(t * 0.73 + 1.1) + 0.12 * sin(t * 0.31 + 0.4)) + lag(w)


static func hash_of(n: int) -> float:
	var h := ((n + 100000) * 747796405 + 2891336453) & 0xFFFFFFFF
	h = (((h >> ((h >> 28) + 4)) ^ h) * 277803737) & 0xFFFFFFFF
	h = ((h >> 22) ^ h) & 0xFFFFFFFF
	return float(h) / 4294967296.0


static func size_of(n: int) -> float:
	var own := (0.3 + 0.7 * hash_of(n)) * (0.8 + 0.2 * sin(n * 0.83 + 0.6))
	return clampf(lerpf(0.62, own, IRREGULAR), 0.0, 1.0)


static func reach(w: Vector2, n: int) -> float:
	var shape := 1.0 + IRREGULAR * (0.18 * sin(w.x * 0.23 + w.y * 0.19 + n * 2.1) + 0.1 * sin(w.x * 0.61 - w.y * 0.47 + n * 1.3))
	return lerpf(RUN_UP.x, RUN_UP.y, size_of(n)) * shape


static func front(u: float, r: float) -> float:
	var lo := -LOW
	if u < UP:
		var k := 1.0 - u / UP
		return lo + (r - lo) * (1.0 - k * k)
	var b := (u - UP) / BACK
	return r - (r - lo) * b * b if b < 1.0 else lo


static func wiggle(w: Vector2, n: int) -> float:
	return 4.5 * sin(w.x * 0.83 + w.y * 0.67 + n * 0.9) + 2.2 * sin(w.x * 1.9 - w.y * 1.6 - n * 1.7)


## Out in the water, `d` px from the shore at `w`: the waves' count there so far (its whole part the
## wave whose crest last went by, its fraction how far since) - as the sea's shader has the swell.
static func crest(w: Vector2, d: float, at := -1.0) -> float:
	return d / (SPEED * EVERY) + phase(w, at)


## Where the water's edge is at `w` (px up the sand) now (or at the surf's time `at`).
static func edge(w: Vector2, at := -1.0) -> float:
	var ph := phase(w, at)
	var n := floori(ph)
	var r := reach(w, n)
	var f := front(ph - n, r)
	return f + wiggle(w, n) * clampf((f + LOW) / maxf(r + LOW, 1.0), 0.0, 1.0)


## How much of a spot `shore` px up the sand at `w` the water covers now (0..1) - as the shaders
## have it.
static func cover(w: Vector2, shore: float, at := -1.0) -> float:
	var e := edge(w, at)
	return 1.0 - smoothstep(e - 1.5, e + 1.5, shore)


# ---------------------------------------------------------------- the water for the game

## 水膜深度: how deep the sheet of water running up the sand is (m) - none at its very front, about
## SHEET_M a px behind it, never deeper than SHEET_MAX; thinner as it drains. (The wading's, the
## driftwood's: what the ground's shader draws as the sheet.)
const SHEET_M := 0.003
const SHEET_MAX := 0.14


## The water over a spot `shore` px up the sand at `w` now (m deep; 0 when it's bare) - out past the
## waves' lowest, the sea's (SHEET_MAX and more, by `shore`).
static func depth(w: Vector2, shore: float, at := -1.0) -> float:
	var ph := phase(w, at)
	var u := ph - floorf(ph)
	var over := edge(w, at) - shore
	if over <= 0.0:
		return 0.0
	var thin := 1.0 - 0.5 * clampf((u - UP) / BACK, 0.0, 1.0)
	return minf(over * SHEET_M * thin, SHEET_MAX) + maxf(-shore - LOW, 0.0) * 0.004


## Which way the water's going at `w` (px/s up the sand - minus: draining back): as fast as its edge
## near the front, slowing deeper in.
static func flow(w: Vector2, at := -1.0) -> float:
	var t := time if at < 0.0 else at
	return (edge(w, t + 0.05) - edge(w, t - 0.05)) / 0.1


## How wet the sand `shore` px up the beach at `w` still is (0 dry .. 1 soaked): from the last waves
## that reached it, drying over DRY_TIME after each topped out there - near enough as the wetness
## picture (SurfWetness) has it, for the game's own questions (a print dark or loose, sand kicked up).
static func wetness(w: Vector2, shore: float, at := -1.0) -> float:
	if cover(w, shore, at) > 0.5:
		return 1.0
	var ph := phase(w, at)
	var n := floori(ph)
	for j in 8:
		var k := n - j
		# (this wave still coming up the sand - not yet as far as it'll go)
		if j == 0 and ph - k < UP:
			continue
		if reach(w, k) + absf(wiggle(w, k)) * 0.5 >= shore:
			var since := maxf((ph - k - UP) * EVERY, 0.0)
			return clampf(1.0 - since / DRY_TIME, 0.0, 1.0)
	return 0.0
