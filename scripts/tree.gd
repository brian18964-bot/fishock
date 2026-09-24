extends Node2D

## Dead-tree, pine, leafy and twisted tree variants pre-rendered from Quaternius' Stylized Nature
## MegaKit (CC0), plus birch, bare, pine (6-10), maple, palm and oak trees from
## Quaternius' nature collections
## (x1.5, that pack is modelled smaller), through the same 55deg orthographic pipeline as the oil
## barrel (see tools/render_sprite.py), all at true scale and the same pixel
## density. One variant is picked per tree each run.

## offset: where the trunk base lands relative to the texture center,
## -center_y * 27.108 px/unit. Dead trees: 270x360 renders, center_y 5.265.
## Pines and leafy trees: 200x216 renders, center_y 2.70.
## Twisted trees: 384x424 renders, center (0.125, 6.37); the lopsided one:
## 384x376, center (4.58, 5.295). offset.x = +center_x * 27.108: the canvas
## shifted right, so the texture moves right to bring the trunk onto the node.
## Birch, bare, pine 6-10, maple, palm and oak trees each have their own tight camera, so their offsets are
## per variant: (center_x, -center_y) * 27.108 (see tools/render_sprite.py).
const DEAD_TREE_OFFSET := Vector2(0, -142.73)
const TREE_OFFSET := Vector2(0, -73.19)
const TWISTED_OFFSET := Vector2(3.39, -172.68)
const TWISTED_LEANING_OFFSET := Vector2(124.15, -143.54)
const SPRITE_SCALE := 0.5
## User feedback: trees bigger - every variant drawn 1.2x, then 1.3x, then
## 1.2x again (~1.87x). The trunk's collision grows with it, more gently.
const TREE_SIZE := 1.87
const TRUNK_SIZE := 1.4

## fade_rect: the branch area (node-local px) where the player counts as
## "behind" the tree, from each model's projected bounds; stops just above
## the trunk base so standing in front of the tree doesn't trigger it.
const VARIANTS := [
	{"albedo": preload("res://assets/sprites/dead_tree/dead_tree_1_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/dead_tree/dead_tree_1_55deg_normal.png"),
	 "family": "dead", "offset": DEAD_TREE_OFFSET, "fade_rect": Rect2(-52, -118, 86, 108)},
	{"albedo": preload("res://assets/sprites/dead_tree/dead_tree_2_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/dead_tree/dead_tree_2_55deg_normal.png"),
	 "family": "dead", "offset": DEAD_TREE_OFFSET, "fade_rect": Rect2(-54, -156, 113, 146)},
	{"albedo": preload("res://assets/sprites/dead_tree/dead_tree_3_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/dead_tree/dead_tree_3_55deg_normal.png"),
	 "family": "dead", "offset": DEAD_TREE_OFFSET, "fade_rect": Rect2(-32, -94, 91, 84)},
	{"albedo": preload("res://assets/sprites/dead_tree/dead_tree_4_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/dead_tree/dead_tree_4_55deg_normal.png"),
	 "family": "dead", "offset": DEAD_TREE_OFFSET, "fade_rect": Rect2(-35, -98, 83, 88)},
	{"albedo": preload("res://assets/sprites/dead_tree/dead_tree_5_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/dead_tree/dead_tree_5_55deg_normal.png"),
	 "family": "dead", "offset": DEAD_TREE_OFFSET, "fade_rect": Rect2(-46, -112, 108, 102)},
	{"albedo": preload("res://assets/sprites/pine/pine_1_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/pine/pine_1_55deg_normal.png"),
	 "family": "pine", "offset": TREE_OFFSET, "fade_rect": Rect2(-41, -87, 88, 77)},
	{"albedo": preload("res://assets/sprites/pine/pine_2_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/pine/pine_2_55deg_normal.png"),
	 "family": "pine", "offset": TREE_OFFSET, "fade_rect": Rect2(-39, -64, 78, 54)},
	{"albedo": preload("res://assets/sprites/pine/pine_3_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/pine/pine_3_55deg_normal.png"),
	 "family": "pine", "offset": TREE_OFFSET, "fade_rect": Rect2(-39, -87, 79, 77)},
	{"albedo": preload("res://assets/sprites/pine/pine_4_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/pine/pine_4_55deg_normal.png"),
	 "family": "pine", "offset": TREE_OFFSET, "fade_rect": Rect2(-29, -64, 49, 54)},
	{"albedo": preload("res://assets/sprites/pine/pine_5_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/pine/pine_5_55deg_normal.png"),
	 "family": "pine", "offset": TREE_OFFSET, "fade_rect": Rect2(-33, -64, 67, 54)},
	{"albedo": preload("res://assets/sprites/leafy_tree/leafy_tree_1_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/leafy_tree/leafy_tree_1_55deg_normal.png"),
	 "family": "leafy", "offset": TREE_OFFSET, "fade_rect": Rect2(-24, -88, 52, 78)},
	{"albedo": preload("res://assets/sprites/leafy_tree/leafy_tree_2_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/leafy_tree/leafy_tree_2_55deg_normal.png"),
	 "family": "leafy", "offset": TREE_OFFSET, "fade_rect": Rect2(-30, -67, 61, 57)},
	{"albedo": preload("res://assets/sprites/leafy_tree/leafy_tree_3_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/leafy_tree/leafy_tree_3_55deg_normal.png"),
	 "family": "leafy", "offset": TREE_OFFSET, "fade_rect": Rect2(-27, -85, 55, 75)},
	{"albedo": preload("res://assets/sprites/leafy_tree/leafy_tree_4_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/leafy_tree/leafy_tree_4_55deg_normal.png"),
	 "family": "leafy", "offset": TREE_OFFSET, "fade_rect": Rect2(-30, -66, 59, 56)},
	{"albedo": preload("res://assets/sprites/leafy_tree/leafy_tree_5_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/leafy_tree/leafy_tree_5_55deg_normal.png"),
	 "family": "leafy", "offset": TREE_OFFSET, "fade_rect": Rect2(-26, -70, 50, 60)},
	{"albedo": preload("res://assets/sprites/twisted_tree/twisted_tree_1_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/twisted_tree/twisted_tree_1_55deg_normal.png"),
	 "family": "twisted", "offset": TWISTED_OFFSET, "fade_rect": Rect2(-51, -177, 129, 167)},
	{"albedo": preload("res://assets/sprites/twisted_tree/twisted_tree_2_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/twisted_tree/twisted_tree_2_55deg_normal.png"),
	 "family": "twisted", "offset": TWISTED_OFFSET, "fade_rect": Rect2(-59, -188, 141, 178)},
	{"albedo": preload("res://assets/sprites/twisted_tree/twisted_tree_3_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/twisted_tree/twisted_tree_3_55deg_normal.png"),
	 "family": "twisted", "offset": TWISTED_OFFSET, "fade_rect": Rect2(-61, -166, 154, 156)},
	{"albedo": preload("res://assets/sprites/twisted_tree/twisted_tree_4_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/twisted_tree/twisted_tree_4_55deg_normal.png"),
	 "family": "twisted", "offset": TWISTED_LEANING_OFFSET, "fade_rect": Rect2(-30, -161, 184, 151)},
	{"albedo": preload("res://assets/sprites/twisted_tree/twisted_tree_5_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/twisted_tree/twisted_tree_5_55deg_normal.png"),
	 "family": "twisted", "offset": TWISTED_OFFSET, "fade_rect": Rect2(-90, -175, 143, 165)},
	{"albedo": preload("res://assets/sprites/birch_tree/birch_tree_1_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/birch_tree/birch_tree_1_55deg_normal.png"),
	 "family": "birch", "offset": Vector2(0.49, -63.19), "fade_rect": Rect2(-27, -66, 55, 56)},
	{"albedo": preload("res://assets/sprites/birch_tree/birch_tree_2_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/birch_tree/birch_tree_2_55deg_normal.png"),
	 "family": "birch", "offset": Vector2(-1.14, -97.32), "fade_rect": Rect2(-35, -100, 68, 90)},
	{"albedo": preload("res://assets/sprites/birch_tree/birch_tree_3_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/birch_tree/birch_tree_3_55deg_normal.png"),
	 "family": "birch", "offset": Vector2(2.14, -68.2), "fade_rect": Rect2(-34, -71, 70, 61)},
	{"albedo": preload("res://assets/sprites/birch_tree/birch_tree_4_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/birch_tree/birch_tree_4_55deg_normal.png"),
	 "family": "birch", "offset": Vector2(1.44, -56.28), "fade_rect": Rect2(-28, -58, 57, 48)},
	{"albedo": preload("res://assets/sprites/birch_tree/birch_tree_5_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/birch_tree/birch_tree_5_55deg_normal.png"),
	 "family": "birch", "offset": Vector2(4.01, -70.05), "fade_rect": Rect2(-34, -73, 72, 63)},
	{"albedo": preload("res://assets/sprites/bare_tree/bare_tree_1_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/bare_tree/bare_tree_1_55deg_normal.png"),
	 "family": "bare", "offset": Vector2(-4.31, -72.68), "fade_rect": Rect2(-34, -76, 63, 66)},
	{"albedo": preload("res://assets/sprites/bare_tree/bare_tree_2_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/bare_tree/bare_tree_2_55deg_normal.png"),
	 "family": "bare", "offset": Vector2(-3.09, -71.59), "fade_rect": Rect2(-36, -73, 69, 63)},
	{"albedo": preload("res://assets/sprites/bare_tree/bare_tree_3_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/bare_tree/bare_tree_3_55deg_normal.png"),
	 "family": "bare", "offset": Vector2(30.77, -59.42), "fade_rect": Rect2(-27, -61, 85, 51)},
	{"albedo": preload("res://assets/sprites/bare_tree/bare_tree_4_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/bare_tree/bare_tree_4_55deg_normal.png"),
	 "family": "bare", "offset": Vector2(-22.09, -56.49), "fade_rect": Rect2(-60, -59, 98, 49)},
	{"albedo": preload("res://assets/sprites/bare_tree/bare_tree_5_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/bare_tree/bare_tree_5_55deg_normal.png"),
	 "family": "bare", "offset": Vector2(2.25, -33.94), "fade_rect": Rect2(-14, -36, 30, 26)},
	{"albedo": preload("res://assets/sprites/bare_tree/bare_tree_6_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/bare_tree/bare_tree_6_55deg_normal.png"),
	 "family": "bare", "offset": Vector2(43.26, -86.64), "fade_rect": Rect2(-33, -92, 110, 82)},
	{"albedo": preload("res://assets/sprites/bare_tree/bare_tree_7_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/bare_tree/bare_tree_7_55deg_normal.png"),
	 "family": "bare", "offset": Vector2(-43.86, -88.67), "fade_rect": Rect2(-84, -94, 124, 84)},
	{"albedo": preload("res://assets/sprites/bare_tree/bare_tree_8_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/bare_tree/bare_tree_8_55deg_normal.png"),
	 "family": "bare", "offset": Vector2(2.66, -112.34), "fade_rect": Rect2(-82, -118, 166, 108)},
	{"albedo": preload("res://assets/sprites/bare_tree/bare_tree_9_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/bare_tree/bare_tree_9_55deg_normal.png"),
	 "family": "bare", "offset": Vector2(11.58, -36.03), "fade_rect": Rect2(-15, -38, 42, 28)},
	{"albedo": preload("res://assets/sprites/bare_tree/bare_tree_10_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/bare_tree/bare_tree_10_55deg_normal.png"),
	 "family": "bare", "offset": Vector2(-11.74, -98.54), "fade_rect": Rect2(-61, -104, 111, 94)},
	{"albedo": preload("res://assets/sprites/pine/pine_6_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/pine/pine_6_55deg_normal.png"),
	 "family": "pine", "offset": Vector2(0.03, -56.06), "fade_rect": Rect2(-30, -63, 60, 53)},
	{"albedo": preload("res://assets/sprites/pine/pine_7_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/pine/pine_7_55deg_normal.png"),
	 "family": "pine", "offset": Vector2(3.44, -84.41), "fade_rect": Rect2(-32, -86, 67, 76)},
	{"albedo": preload("res://assets/sprites/pine/pine_8_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/pine/pine_8_55deg_normal.png"),
	 "family": "pine", "offset": Vector2(1.55, -29.87), "fade_rect": Rect2(-17, -34, 36, 24)},
	{"albedo": preload("res://assets/sprites/pine/pine_9_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/pine/pine_9_55deg_normal.png"),
	 "family": "pine", "offset": Vector2(49.26, -48.52), "fade_rect": Rect2(-25, -61, 99, 51)},
	{"albedo": preload("res://assets/sprites/pine/pine_10_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/pine/pine_10_55deg_normal.png"),
	 "family": "pine", "offset": Vector2(2.77, -52.59), "fade_rect": Rect2(-32, -56, 67, 46)},
	{"albedo": preload("res://assets/sprites/maple_tree/maple_tree_1_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/maple_tree/maple_tree_1_55deg_normal.png"),
	 "family": "maple", "offset": Vector2(42.23, -98.35), "fade_rect": Rect2(-42, -104, 126, 94)},
	{"albedo": preload("res://assets/sprites/maple_tree/maple_tree_2_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/maple_tree/maple_tree_2_55deg_normal.png"),
	 "family": "maple", "offset": Vector2(-40.31, -102.63), "fade_rect": Rect2(-88, -108, 136, 98)},
	{"albedo": preload("res://assets/sprites/maple_tree/maple_tree_3_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/maple_tree/maple_tree_3_55deg_normal.png"),
	 "family": "maple", "offset": Vector2(3.23, -128.03), "fade_rect": Rect2(-90, -133, 183, 123)},
	{"albedo": preload("res://assets/sprites/maple_tree/maple_tree_4_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/maple_tree/maple_tree_4_55deg_normal.png"),
	 "family": "maple", "offset": Vector2(10.44, -50.61), "fade_rect": Rect2(-23, -53, 56, 43)},
	{"albedo": preload("res://assets/sprites/maple_tree/maple_tree_5_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/maple_tree/maple_tree_5_55deg_normal.png"),
	 "family": "maple", "offset": Vector2(-4.17, -106.26), "fade_rect": Rect2(-73, -111, 142, 101)},
	{"albedo": preload("res://assets/sprites/palm_tree/palm_tree_1_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/palm_tree/palm_tree_1_55deg_normal.png"),
	 "family": "palm", "offset": Vector2(-7.67, -90.08), "fade_rect": Rect2(-56, -93, 104, 83)},
	{"albedo": preload("res://assets/sprites/palm_tree/palm_tree_2_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/palm_tree/palm_tree_2_55deg_normal.png"),
	 "family": "palm", "offset": Vector2(56.6, -91.11), "fade_rect": Rect2(-28, -98, 113, 88)},
	{"albedo": preload("res://assets/sprites/palm_tree/palm_tree_3_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/palm_tree/palm_tree_3_55deg_normal.png"),
	 "family": "palm", "offset": Vector2(-10.0, -80.56), "fade_rect": Rect2(-50, -84, 90, 74)},
	{"albedo": preload("res://assets/sprites/palm_tree/palm_tree_4_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/palm_tree/palm_tree_4_55deg_normal.png"),
	 "family": "palm", "offset": Vector2(67.82, -56.41), "fade_rect": Rect2(-14, -79, 96, 69)},
	{"albedo": preload("res://assets/sprites/palm_tree/palm_tree_5_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/palm_tree/palm_tree_5_55deg_normal.png"),
	 "family": "palm", "offset": Vector2(-4.07, -16.51), "fade_rect": Rect2(-38, -39, 71, 29)},
	{"albedo": preload("res://assets/sprites/oak_tree/oak_tree_1_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/oak_tree/oak_tree_1_55deg_normal.png"),
	 "family": "oak", "offset": Vector2(-4.28, -86.56), "fade_rect": Rect2(-43, -90, 82, 80)},
	{"albedo": preload("res://assets/sprites/oak_tree/oak_tree_2_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/oak_tree/oak_tree_2_55deg_normal.png"),
	 "family": "oak", "offset": Vector2(-3.85, -85.5), "fade_rect": Rect2(-48, -87, 92, 77)},
	{"albedo": preload("res://assets/sprites/oak_tree/oak_tree_3_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/oak_tree/oak_tree_3_55deg_normal.png"),
	 "family": "oak", "offset": Vector2(25.64, -66.74), "fade_rect": Rect2(-38, -69, 102, 59)},
	{"albedo": preload("res://assets/sprites/oak_tree/oak_tree_4_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/oak_tree/oak_tree_4_55deg_normal.png"),
	 "family": "oak", "offset": Vector2(-9.65, -65.66), "fade_rect": Rect2(-62, -68, 115, 58)},
	{"albedo": preload("res://assets/sprites/oak_tree/oak_tree_5_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/oak_tree/oak_tree_5_55deg_normal.png"),
	 "family": "oak", "offset": Vector2(-0.22, -43.62), "fade_rect": Rect2(-32, -48, 63, 38)},
]

@onready var sprite: Sprite2D = $Canopy/Visual
@onready var fade_shape: CollisionShape2D = $Canopy/Area2D/CollisionShape2D


## Map theme (map_generator.gd): family -> weight. Empty = every family
## equally likely. Set before the tree enters the tree.
var family_weights: Dictionary = {}


func _ready() -> void:
	apply_variant(_pick_variant())


## Family first, then a variant within it, so families with many models
## (ten bare trees) don't crowd out the ones with few.
func _pick_variant() -> int:
	var families := {}
	for i in VARIANTS.size():
		families.get_or_add(VARIANTS[i].family, []).append(i)
	if family_weights.is_empty():
		return families.values().pick_random().pick_random()
	var total := 0.0
	for f in family_weights:
		if families.has(f):
			total += family_weights[f]
	var roll := randf() * total
	for f in family_weights:
		if not families.has(f):
			continue
		roll -= family_weights[f]
		if roll <= 0.0:
			return families[f].pick_random()
	return families.values().pick_random().pick_random()


func apply_variant(index: int) -> void:
	var variant: Dictionary = VARIANTS[index]

	var tex := CanvasTexture.new()
	tex.diffuse_texture = variant.albedo
	tex.normal_texture = variant.normal
	sprite.texture = tex
	sprite.offset = variant.offset
	sprite.scale = Vector2.ONE * SPRITE_SCALE * TREE_SIZE

	# Built per instance: a shape resource from the .tscn would be shared by
	# every tree, so resizing it for one variant would resize all of them.
	# The trunk's footprint grows with the tree (fresh resources - the
	# scene's are shared by every tree).
	var trunk := RectangleShape2D.new()
	trunk.size = Vector2(16, 12) * TRUNK_SIZE
	$TrunkBody/CollisionShape2D.shape = trunk
	var occ := OccluderPolygon2D.new()
	var h := trunk.size / 2.0
	occ.polygon = PackedVector2Array([Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)])
	$TrunkBody/LightOccluder2D.occluder = occ

	var fade: Rect2 = variant.fade_rect
	var rect := Rect2(fade.position * TREE_SIZE, fade.size * TREE_SIZE)
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	fade_shape.shape = shape
	fade_shape.position = rect.get_center()
