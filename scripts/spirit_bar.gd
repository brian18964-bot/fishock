class_name SpiritBar
extends Control

## User request (Camp v2): the traveller's spirit (Profile.spirit) as a
## bar - its colour by how it tells on them (Profile.spirit_penalty: green,
## yellow, orange, red) - with "精神 n" beside it. Drawn under the camp's
## nameplate, and (paint()) on the run's status card.

const COLORS := [Color(0.45, 0.82, 0.45), Color(0.92, 0.8, 0.3), Color(1.0, 0.55, 0.2), Color(0.95, 0.3, 0.25)]
const WORDS := ["", "疲倦", "精神不濟", "精疲力竭"]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(170, 16)
	Profile.profile_changed.connect(queue_redraw)


func _draw() -> void:
	paint(self, Rect2(Vector2(0, 3), Vector2(size.x - 62, 10)))


## The bar in `r`, the number after it.
static func paint(ci: CanvasItem, r: Rect2) -> void:
	var worn := Profile.spirit_penalty()
	UiKit.draw_bar(ci, r, Profile.spirit / Profile.SPIRIT_MAX, COLORS[worn])
	UiKit.draw_text(ci, Vector2(r.end.x + 6, r.position.y + r.size.y), "精神 %d" % roundi(Profile.spirit), 12, COLORS[worn])
