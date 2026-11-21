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
## 推進速度 (px/s): how fast the waves come in across the water (their spacing = SPEED x EVERY).
const SPEED := 40.0
## 波浪間隔 (s): a wave reaching the shore every this many seconds, on average.
const EVERY := 7.0
## (0 every wave the same, on the beat .. 1 each its own size, the beat loose by about a quarter)
const IRREGULAR := 1.0
## 上沖距離 (px up the sand from the water's edge): the smallest wave's reach, the biggest's.
const RUN_UP := Vector2(26.0, 70.0)
## (how far below its mean line the water's edge falls between waves, px)
const LOW := 10.0
## 上沖時間: the share of a wave's time it takes to run up (smaller: quicker).
const UP := 0.2
## 回流速度: the share of a wave's time it takes to drain back down (smaller: quicker).
const BACK := 0.46
## 泡沫量 (0 none .. 1 as made .. more).
const FOAM := 1.0
## 乾沙 / 濕沙: the sand's colour dry (on its picture) and soaked (the wet sand's picture, tinted).
const SAND_DRY := Color(1.0, 1.0, 1.0)
const SAND_WET := Color(0.58, 0.6, 0.66)
## 濕沙反光強度 (0 none .. 1 glassy): how much the wet sand gleams.
const SHEEN := 0.4
## 乾燥時間 (s): from soaked to dry again after the water's gone.
const DRY_TIME := 16.0

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
// (how much later the waves reach this stretch of the shore, in waves - a slant along the coast)
float surf_lag(vec2 w) {
	return 0.3 * sin(w.x * 0.11 + w.y * 0.07) + 0.22 * sin(w.x * 0.047 - w.y * 0.093 + 1.7);
}
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
	return 6.0 * sin(w.x * 0.93 + w.y * 0.77 + n * 0.9) + 3.5 * sin(w.x * 2.11 - w.y * 1.79 - n * 1.7) + 1.8 * sin(w.x * 4.3 + w.y * 3.7 + n * 2.3);
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
	return 0.3 * sin(w.x * 0.11 + w.y * 0.07) + 0.22 * sin(w.x * 0.047 - w.y * 0.093 + 1.7)


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
	return 6.0 * sin(w.x * 0.93 + w.y * 0.77 + n * 0.9) + 3.5 * sin(w.x * 2.11 - w.y * 1.79 - n * 1.7) + 1.8 * sin(w.x * 4.3 + w.y * 3.7 + n * 2.3)


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
