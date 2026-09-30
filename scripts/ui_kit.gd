class_name UiKit
extends RefCounted

## The UI's look (user request: like a fantasy MMO - dark iron frames with
## worn gold trim, red lacquered buttons, square item slots with rarity
## colours, a navy tooltip, parchment - darker than the reference). The
## pictures come from tools/make_ui_kit.py at twice the size they're shown
## (tex() halves them so they stay sharp on a phone's screen); this puts
## them together as style boxes, buttons, labels and slots, and builds the
## theme every screen uses (install_theme, from the UiTheme autoload).
##
## Rarity (user decision): rods by tier white, green, blue, purple, orange;
## fish white (common), blue (rare), purple (a water's rarest), orange (a
## legend - the game's "epic" catches and the sea's legends).

const GOLD := Color(0.93, 0.76, 0.36)
const GOLD_BRIGHT := Color(1.0, 0.85, 0.42)
const TEXT := Color(0.93, 0.9, 0.82)
const DIM := Color(0.66, 0.63, 0.57)
const DANGER := Color(0.95, 0.36, 0.28)
## Tooltip lines: what a thing does ("使用：") and its flavour text.
const USE := Color(0.3, 0.86, 0.36)
const FLAVOR := Color(0.93, 0.8, 0.42)
const STAT := Color(0.52, 0.6, 1.0)
const OUTLINE := Color(0, 0, 0, 0.85)

const RARITY_ORDER := ["common", "uncommon", "rare", "epic", "legend"]
const RARITY_COLORS := {
	"common": Color(0.91, 0.89, 0.85), "uncommon": Color(0.24, 0.8, 0.28), "rare": Color(0.24, 0.56, 0.95),
	"epic": Color(0.71, 0.38, 1.0), "legend": Color(1.0, 0.54, 0.12),
}
const RARITY_NAMES := {"common": "普通", "uncommon": "優秀", "rare": "稀有", "epic": "史詩", "legend": "傳說"}

const DIR := "res://assets/ui/%s.png"
const FONT := "res://assets/fonts/ui_font.tres"
const FONT_BOLD := "res://assets/fonts/ui_font_bold.tres"

static var _tex := {}
static var _boxes := {}
static var _fonts := {}


## A kit picture at half its pixel size (drawn crisp on 2x screens).
static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		var img: Image = load(DIR % name)
		var t := ImageTexture.create_from_image(img)
		t.set_size_override(Vector2i(img.get_width() / 2, img.get_height() / 2))
		_tex[name] = t
	return _tex[name]


static func font(bold := false) -> Font:
	var key := "bold" if bold else "regular"
	if not _fonts.has(key):
		_fonts[key] = load(FONT_BOLD if bold else FONT)
	return _fonts[key]


## A nine-slice box from a kit picture: `margin` (shown px) of border kept,
## the middle tiled; `content` the padding inside.
static func nine(name: String, margin: float, content := Vector4(12, 8, 12, 8), tile := true) -> StyleBoxTexture:
	var key := "%s|%s|%s|%s" % [name, margin, content, tile]
	if not _boxes.has(key):
		var s := StyleBoxTexture.new()
		s.texture = tex(name)
		s.set_texture_margin_all(margin)
		s.content_margin_left = content.x
		s.content_margin_top = content.y
		s.content_margin_right = content.z
		s.content_margin_bottom = content.w
		if tile:
			s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
			s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		_boxes[key] = s
	return _boxes[key]


## Window frame: iron and gold, gems in the corners.
static func frame_box(dark := false) -> StyleBoxTexture:
	return nine("frame_dark" if dark else "frame", 16.0, Vector4(18, 16, 18, 16))


static func plate_box() -> StyleBoxTexture:
	return nine("plate", 10.0, Vector4(16, 3, 16, 4), false)


static func slot_box() -> StyleBoxTexture:
	return nine("slot", 8.0, Vector4(4, 4, 4, 4), false)


static func tooltip_box() -> StyleBoxTexture:
	return nine("tooltip", 6.0, Vector4(12, 10, 12, 10), false)


static func parchment_box() -> StyleBoxTexture:
	return nine("parchment", 26.0, Vector4(26, 22, 26, 22), false)


static func bar_box() -> StyleBoxTexture:
	return nine("bar_frame", 6.0, Vector4(4, 3, 4, 3), false)


static func button_box(kind: String, state: String) -> StyleBoxTexture:
	return nine("btn_%s_%s" % [kind, state], 9.0, Vector4(14, 5, 14, 6), false)


## Dresses a button: "red" (the main action) or "gray".
static func style_button(b: BaseButton, kind := "gray", size := 16) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(state, button_box(kind, state))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover_pressed", button_box(kind, "pressed"))
	if b is Button:
		b.add_theme_font_override("font", font(true))
		b.add_theme_font_size_override("font_size", size)
		b.add_theme_color_override("font_color", GOLD_BRIGHT if kind == "red" else GOLD)
		b.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.6))
		b.add_theme_color_override("font_pressed_color", Color(1.0, 0.8, 0.4))
		b.add_theme_color_override("font_hover_pressed_color", Color(1.0, 0.8, 0.4))
		b.add_theme_color_override("font_disabled_color", Color(0.55, 0.52, 0.48))
		b.add_theme_color_override("font_outline_color", OUTLINE)
		b.add_theme_constant_override("outline_size", 4)


static func button(text: String, size := 16, kind := "gray") -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	style_button(b, kind, size)
	return b


## A tab: the chosen one red, the rest gray.
static func style_tab(b: Button, on: bool) -> void:
	style_button(b, "red" if on else "gray", int(b.get_theme_font_size("font_size")))


static func label(text: String, size := 16, color := TEXT, bold := false, outline := 3) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(bold))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", OUTLINE)
		l.add_theme_constant_override("outline_size", outline)
	return l


static func panel(dark := false) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", frame_box(dark))
	return p


## A window: the frame with a title plate across its top. Returns [the
## window, its content column].
static func window(title: String) -> Array:
	var p := panel()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	p.add_child(col)
	var head := PanelContainer.new()
	head.name = "Title"
	head.add_theme_stylebox_override("panel", plate_box())
	head.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	head.custom_minimum_size = Vector2(160, 30)
	var t := label(title, 17, GOLD, true)
	t.name = "TitleText"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(t)
	col.add_child(head)
	return [p, col]


## A round portrait in the gold medallion (a Control of `size`).
static func medallion(picture: Texture2D, size := 64.0) -> Control:
	var holder := Control.new()
	holder.name = "Medallion"
	holder.custom_minimum_size = Vector2(size, size)
	holder.size = Vector2(size, size)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := Panel.new()
	var round := StyleBoxFlat.new()
	round.bg_color = Color(0.07, 0.07, 0.09)
	round.set_corner_radius_all(int(size / 2.0))
	back.add_theme_stylebox_override("panel", round)
	back.position = Vector2.ONE * size * 0.1
	back.size = Vector2.ONE * size * 0.8
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	holder.add_child(back)
	if picture != null:
		var pic := TextureRect.new()
		pic.texture = picture
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.set_anchors_preset(Control.PRESET_FULL_RECT)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		back.add_child(pic)
	var ring := TextureRect.new()
	ring.texture = tex("medallion")
	ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(ring)
	return holder


## The round red ✕ button.
static func close_button() -> TextureButton:
	var b := TextureButton.new()
	b.name = "Close"
	b.texture_normal = tex("close")
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.custom_minimum_size = Vector2(34, 34)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


## Gold with its coin: "640 ●".
static func gold_label(amount: int, size := 18) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var n := label(str(amount), size, GOLD_BRIGHT)
	n.name = "Coins"
	row.add_child(n)
	var c := TextureRect.new()
	c.texture = tex("coin")
	c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	c.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	c.custom_minimum_size = Vector2(size, size)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(c)
	return row


## The gold purse panel shown in the corner of the menus.
static func purse() -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "Purse"
	p.add_theme_stylebox_override("panel", plate_box())
	p.custom_minimum_size = Vector2(120, 34)
	var g := gold_label(Profile.gold)
	g.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(g)
	return p


static func set_purse(p: Control, amount: int) -> void:
	var n: Label = p.find_child("Coins", true, false)
	if n != null:
		n.text = str(amount)


## An ornamental line.
static func divider(width := 200.0) -> TextureRect:
	var d := TextureRect.new()
	d.texture = tex("divider")
	d.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	d.stretch_mode = TextureRect.STRETCH_SCALE
	d.custom_minimum_size = Vector2(width, 12)
	d.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return d


## A menu page's back and top bar: dark stone (or, over the 3D camp - the
## page's "over_camp" meta - a see-through shade), a back button top left
## and the purse top right. Returns the purse (set_purse updates it).
static func page_chrome(page: Control, back: Callable, back_name := "Back") -> PanelContainer:
	backdrop(page)
	var b := button("‹ 返回", 16)
	b.name = back_name
	b.position = Vector2(14, 10)
	b.custom_minimum_size = Vector2(104, 40)
	b.pressed.connect(back)
	page.add_child(b)
	var p := purse()
	p.position = Vector2(820, 12)
	p.custom_minimum_size = Vector2(126, 36)
	page.add_child(p)
	return p


## A page's back: dark stone with darkened corners - or, over the 3D camp
## (the page's "over_camp" meta), a see-through shade.
static func backdrop(page: Control) -> void:
	if page.get_meta("over_camp", false):
		var shade := ColorRect.new()
		shade.color = Color(0.0, 0.0, 0.02, 0.55)
		shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		shade.mouse_filter = Control.MOUSE_FILTER_STOP
		page.add_child(shade)
		return
	var stone := TextureRect.new()
	stone.texture = tex("page_bg")
	stone.stretch_mode = TextureRect.STRETCH_TILE
	stone.set_anchors_preset(Control.PRESET_FULL_RECT)
	stone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(stone)
	page.add_child(vignette())


## Leaves a menu page: back to the camp it's open over, or (a page on its
## own) to the main screen.
static func page_back(page: Control) -> void:
	var camp: Object = page.get_meta("camp", null)
	if camp != null and is_instance_valid(camp):
		camp.call("close_page")
	else:
		page.get_tree().change_scene_to_file("res://scenes/title_screen.tscn")


## From one menu page to another ("shop", "fish_log", ...): over the camp
## if that's where it is.
static func page_go(page: Control, to: String) -> void:
	var camp: Object = page.get_meta("camp", null)
	if camp != null and is_instance_valid(camp):
		camp.call("open_page", to)
	else:
		page.get_tree().change_scene_to_file("res://scenes/%s.tscn" % to)


## Darkened corners over the whole screen.
static func vignette(strength := 0.75) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0, 0, 0, strength))
	g.add_point(0.55, Color(0, 0, 0, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.05, 1.05)
	gt.width = 256
	gt.height = 144
	var v := TextureRect.new()
	v.texture = gt
	v.stretch_mode = TextureRect.STRETCH_SCALE
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


## A tooltip-style panel (navy, silver edge).
static func tooltip_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", tooltip_box())
	return p


## A soft round glow (white; tint it), for behind a thing's picture.
static func glow() -> Texture2D:
	if not _tex.has("_glow"):
		_tex["_glow"] = LightTextureFactory.make_radial_texture(64, 0.6)
	return _tex["_glow"]


# ---------------------------------------------------------------- rarity

static func rarity_color(key: String) -> Color:
	return RARITY_COLORS.get(key, RARITY_COLORS.common)


static func rarity_name(key: String) -> String:
	return RARITY_NAMES.get(key, "")


## A thing's rarity by its id (Items).
static func item_rarity(id: String) -> String:
	if id.begins_with("rod_"):
		return RARITY_ORDER[clampi(int(id.substr(4)), 0, RARITY_ORDER.size() - 1)]
	if id == "flashlight":
		return "rare"
	var cost := 0
	if id.begins_with("lure_") and Profile.LURES.has(id.substr(5)):
		cost = int(Profile.LURES[id.substr(5)].cost)
	elif id.begins_with("live_") and Profile.LIVE_BAITS.has(id.substr(5)):
		cost = int(Profile.LIVE_BAITS[id.substr(5)].cost)
	if cost >= 40:
		return "epic"
	if cost >= 20:
		return "rare"
	if cost >= 6:
		return "uncommon"
	return "common"


## A fish's rarity: its catch's rarity and the species.
static func fish_rarity(fish: Dictionary) -> String:
	var id: String = fish.get("id", "")
	if fish.get("rarity", "") == "epic" or fish.get("legend", false) or id in FishData.SEA_LEGEND:
		return "legend"
	if id in FishData.SEA_RARE:
		return "epic"
	for style in FishData.STYLE_FISH:
		if FishData.STYLE_FISH[style][1] == id:
			return "epic"
	if fish.get("rarity", "") == "rare":
		return "rare"
	return "common"


# ---------------------------------------------------------------- drawing

## Draws an item slot (sunken square) at `r`, with a rarity ring when
## `rarity` is given, lit when `lit`.
static func draw_slot(ci: CanvasItem, r: Rect2, rarity := "", lit := false) -> void:
	slot_box().draw(ci.get_canvas_item(), r)
	if rarity != "" and rarity != "common":
		var ring := nine("slot_ring", 10.0, Vector4.ZERO, false)
		ring.modulate_color = Color(rarity_color(rarity), 0.95)
		ring.draw(ci.get_canvas_item(), r.grow(2.0))
		ring.modulate_color = Color.WHITE
	if lit:
		var glow := nine("slot_ring", 10.0, Vector4.ZERO, false)
		glow.modulate_color = Color(1.0, 0.9, 0.55)
		glow.draw(ci.get_canvas_item(), r.grow(3.0))
		glow.modulate_color = Color.WHITE


## A bar: the frame, the fill (tinted `color`) to `share`.
static func draw_bar(ci: CanvasItem, r: Rect2, share: float, color: Color) -> void:
	bar_box().draw(ci.get_canvas_item(), r)
	var inner := r.grow_individual(-3, -3, -3, -3)
	if share > 0.0:
		var fill := Rect2(inner.position, Vector2(inner.size.x * clampf(share, 0.0, 1.0), inner.size.y))
		ci.draw_texture_rect(tex("bar_fill"), fill, false, color)


## Text with a dark outline, the way every label in the game reads.
static func draw_text(ci: CanvasItem, at: Vector2, text: String, size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, bold := false) -> void:
	var f := font(bold)
	ci.draw_string_outline(f, at, text, align, width, size, 4, OUTLINE)
	ci.draw_string(f, at, text, align, width, size, color)


# ---------------------------------------------------------------- theme

## The theme on the root window: every control's default look.
static func install_theme(root: Window) -> void:
	root.theme = make_theme()


static func make_theme() -> Theme:
	var th := Theme.new()
	th.default_font = font()
	th.default_font_size = 16
	# Buttons.
	for state in ["normal", "hover", "pressed", "disabled"]:
		th.set_stylebox(state, "Button", button_box("gray", state))
	th.set_stylebox("hover_pressed", "Button", button_box("gray", "pressed"))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_font("font", "Button", font(true))
	th.set_color("font_color", "Button", GOLD)
	th.set_color("font_hover_color", "Button", Color(1.0, 0.92, 0.6))
	th.set_color("font_pressed_color", "Button", Color(1.0, 0.8, 0.4))
	th.set_color("font_hover_pressed_color", "Button", Color(1.0, 0.8, 0.4))
	th.set_color("font_disabled_color", "Button", Color(0.55, 0.52, 0.48))
	th.set_color("font_outline_color", "Button", OUTLINE)
	th.set_constant("outline_size", "Button", 4)
	# Labels: warm white, outlined.
	th.set_color("font_color", "Label", TEXT)
	th.set_color("font_outline_color", "Label", OUTLINE)
	th.set_constant("outline_size", "Label", 3)
	# Panels.
	th.set_stylebox("panel", "PanelContainer", frame_box())
	th.set_stylebox("panel", "Panel", frame_box())
	th.set_stylebox("panel", "TooltipPanel", tooltip_box())
	th.set_color("font_color", "TooltipLabel", TEXT)
	# Check buttons: gold text.
	th.set_color("font_color", "CheckButton", TEXT)
	th.set_color("font_hover_color", "CheckButton", GOLD_BRIGHT)
	th.set_color("font_pressed_color", "CheckButton", GOLD_BRIGHT)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		th.set_stylebox(state, "CheckButton", StyleBoxEmpty.new())
	# Sliders: a gold-edged trough.
	var slider := StyleBoxFlat.new()
	slider.bg_color = Color(0.03, 0.03, 0.035)
	slider.border_color = Color(0.62, 0.46, 0.17)
	slider.set_border_width_all(1)
	slider.set_corner_radius_all(3)
	slider.content_margin_top = 3
	slider.content_margin_bottom = 3
	th.set_stylebox("slider", "HSlider", slider)
	var area := StyleBoxFlat.new()
	area.bg_color = Color(0.85, 0.62, 0.22)
	area.set_corner_radius_all(3)
	area.content_margin_top = 3
	area.content_margin_bottom = 3
	th.set_stylebox("grabber_area", "HSlider", area)
	th.set_stylebox("grabber_area_highlight", "HSlider", area)
	# Scroll bars: thin iron.
	var bar := StyleBoxFlat.new()
	bar.bg_color = Color(0, 0, 0, 0.35)
	bar.set_corner_radius_all(3)
	bar.content_margin_left = 4
	bar.content_margin_right = 4
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(0.62, 0.46, 0.17, 0.85)
	grab.set_corner_radius_all(3)
	for part in ["scroll"]:
		th.set_stylebox(part, "VScrollBar", bar)
		th.set_stylebox(part, "HScrollBar", bar)
	for part in ["grabber", "grabber_highlight", "grabber_pressed"]:
		th.set_stylebox(part, "VScrollBar", grab)
		th.set_stylebox(part, "HScrollBar", grab)
	# Line edits (search).
	var edit := StyleBoxFlat.new()
	edit.bg_color = Color(0.02, 0.02, 0.025, 0.9)
	edit.border_color = Color(0.4, 0.38, 0.36)
	edit.set_border_width_all(1)
	edit.set_corner_radius_all(3)
	edit.content_margin_left = 8
	edit.content_margin_right = 8
	th.set_stylebox("normal", "LineEdit", edit)
	th.set_stylebox("focus", "LineEdit", edit)
	return th
