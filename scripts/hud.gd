extends Control
## On-screen UI: status bars, action buttons, toasts and the pop-up screens
## (shop, journal, photos, remote work).

const Bunny := preload("res://scripts/bunny.gd")
const WorkGame := preload("res://scripts/work_game.gd")
const Training := preload("res://scripts/training.gd")
const Grooming := preload("res://scripts/grooming.gd")
const ShowRing := preload("res://scripts/show_ring.gd")


class Viewfinder extends Control:
	var safe := Rect2()   # x/y = left/top insets, w/h = right/bottom insets

	func _draw() -> void:
		var r := Rect2(Vector2(90 + safe.position.x, 110 + safe.position.y),
			size - Vector2(180 + safe.position.x + safe.size.x, 250 + safe.position.y + safe.size.y))
		var l := 60.0
		for pass_i in 2:
			var w := 12.0 if pass_i == 0 else 6.0
			var c := UI.INK if pass_i == 0 else Color.WHITE
			for corner in [[r.position, 1, 1], [Vector2(r.end.x, r.position.y), -1, 1],
					[Vector2(r.position.x, r.end.y), 1, -1], [r.end, -1, -1]]:
				var p: Vector2 = corner[0]
				draw_polyline(PackedVector2Array([p + Vector2(0, l * corner[2]), p, p + Vector2(l * corner[1], 0)]), c, w, true)
		var mid := r.get_center()
		draw_line(mid - Vector2(16, 0), mid + Vector2(16, 0), Color(1, 1, 1, 0.8), 3)
		draw_line(mid - Vector2(0, 16), mid + Vector2(0, 16), Color(1, 1, 1, 0.8), 3)
		draw_circle(r.position + Vector2(36, 34), 9, Color("#e8505b"))


## Darkens everything except the selfie frame.
class HoleDim extends Control:
	var hole: Control

	func _draw() -> void:
		var c := Color(0.25, 0.17, 0.12, 0.55)
		var r := hole.get_global_rect()
		draw_rect(Rect2(0, 0, size.x, r.position.y), c)
		draw_rect(Rect2(0, r.end.y, size.x, size.y - r.end.y), c)
		draw_rect(Rect2(0, r.position.y, r.position.x, r.size.y), c)
		draw_rect(Rect2(r.end.x, r.position.y, size.x - r.end.x, r.size.y), c)
		draw_rect(r.grow(5), Color.WHITE, false, 10)


var main: Node
var _coins: Label
var _followers: Label
var _trust_name: Label
var _trust_bar: ProgressBar
var _hearts: Array = []
var _need_bars: Array = []   # per pet: {need: bar}
var _need_icons: Array = []  # per pet: {need: icon button}
var _mate_name: Label
var _mate_hearts: Array = []
var _mate_trust: ProgressBar
var _bond_bar: ProgressBar
var _buttons: HBoxContainer
var _toasts: VBoxContainer
var _banner: PanelContainer
var _banner_label: Label
var _banner_button: Button
var _camera_ui: Control
var _feed_bar: ProgressBar
var _feed_label: Label
var _tray: PanelContainer
var _modal: Control = null
var _refresh_t := 0.0
var _shop_tab := "Food"
var _journal_tab := "Goals"
var _photo_cache := {}
var _last_coins := -1   # to hear coins come in and go out
var _selfie_ui: Control
var _selfie_frame: Control
var _selfie_dim: Control
var _selfie_controls: Control
var _selfie_bunny: TextureRect
var _wriggle_bar: ProgressBar
var _selfie_t := 0.0
var _selfie_hearts_t := 0.0
var _bob: Tween
var _safe := Rect2()
var _pinned: Array = []     # [control, ax, ay, offset] for everything pinned with _anchor()
var _safe_t := 0.0
var _viewfinder: Viewfinder
var _pending: Array = []   # pop-ups waiting for the current one to close
var _cozy_label: Label
var _cozy_bar: ProgressBar
var _journal_badge: PanelContainer
var _club_button: Button
var _walk_button: Button
var _wardrobe_stage: StageBunny
var _wardrobe_side: VBoxContainer
var _wardrobe_info: Label
var _club_tab := "Training"
var club_panel: Control      # the open Training / Grooming / show ring panel
var saves_scroll: ScrollContainer   # for the playtest
var _save_confirm := ""      # file (or "new") waiting for a second tap to confirm


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	theme = UI.make_theme()
	_safe = _read_safe_area()
	_build_top()
	_fit_top_row()
	get_viewport().size_changed.connect(_fit_top_row)
	_build_buttons()
	_build_tray()
	_build_camera_ui()
	_build_selfie_ui()
	_build_banner()
	_toasts = UI.vbox(8)
	_anchor(_toasts, 0.5, 0.0, Vector2(0, 118))
	add_child(_toasts)
	Game.toast.connect(toast)
	Game.discovered.connect(_on_discovered)
	Game.trust_level_up.connect(_on_level_up)
	Game.goal_completed.connect(_on_goal_completed)
	Game.sponsor_paid.connect(_on_sponsor)
	Game.club_unlocked.connect(_on_club_unlocked)
	Game.mate_unlocked.connect(_on_mate_unlocked)
	Game.mate_trust_up.connect(func(l): toast(tr("%s trusts you more: %s") % [Game.mate.display_name(), Catalog.level_name(l)], "heart", true))
	_refresh()
	if Game.molting():
		toast.call_deferred(tr("Bubák is molting! Brush him often and pick up the fur he leaves around."), "brush")


## Pins a control to a screen edge/corner (ax, ay in 0, 0.5, 1). Edge-pinned controls are
## kept inside the safe area (notch, Dynamic Island, camera cutout, home indicator).
func _anchor(c: Control, ax: float, ay: float, offset: Vector2) -> void:
	_pinned.append([c, ax, ay, offset])
	_place_pinned(c, ax, ay, offset)


func _place_pinned(c: Control, ax: float, ay: float, offset: Vector2) -> void:
	var o := offset
	if ax == 0.0:
		o.x += _safe.position.x
	elif ax == 1.0:
		o.x -= _safe.size.x
	if ay == 0.0:
		o.y += _safe.position.y
	elif ay == 1.0:
		o.y -= _safe.size.y
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.grow_horizontal = [GROW_DIRECTION_END, GROW_DIRECTION_BOTH, GROW_DIRECTION_BEGIN][int(ax * 2)]
	c.grow_vertical = [GROW_DIRECTION_END, GROW_DIRECTION_BOTH, GROW_DIRECTION_BEGIN][int(ay * 2)]
	c.offset_left = o.x
	c.offset_right = o.x
	c.offset_top = o.y
	c.offset_bottom = o.y


## Insets of the screen's safe area, in UI units: x/y = left/top, w/h = right/bottom.
func _read_safe_area() -> Rect2:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--safe="):   # simulate a notch: --safe=left,top,right,bottom
			var v := arg.get_slice("=", 1).split(",")
			return Rect2(float(v[0]), float(v[1]), float(v[2]), float(v[3]))
	if not OS.has_feature("mobile"):
		return Rect2()
	var win := Vector2(DisplayServer.window_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if win.x <= 0 or safe.size.x <= 0:
		return Rect2()
	var k := get_viewport().get_visible_rect().size.x / win.x   # screen pixels -> UI units
	var cap := win * 0.25
	return Rect2(clampf(safe.position.x, 0, cap.x) * k, clampf(safe.position.y, 0, cap.y) * k,
		clampf(win.x - safe.end.x, 0, cap.x) * k, clampf(win.y - safe.end.y, 0, cap.y) * k)


func _update_safe_area() -> void:
	var s := _read_safe_area()
	if s == _safe:
		return
	_safe = s
	for p in _pinned:
		if is_instance_valid(p[0]):
			_place_pinned(p[0], p[1], p[2], p[3])
	_viewfinder.safe = s
	_viewfinder.queue_redraw()
	_fit_top_row()


## The top row (trust card | needs | coins) must fit between the safe-area edges:
## on narrow screens with big notches the need bars get shorter.
const BAR_W := 58.0   # need bar length on a wide screen


func _fit_top_row() -> void:
	var free := get_viewport().get_visible_rect().size.x - _safe.position.x - _safe.size.x
	var needed := 1240.0   # card + needs panel + coin/follower pills + margins, with full-size bars
	var w := clampf(BAR_W - maxf(0.0, needed - free) / 5.0, 30.0, BAR_W)
	for bars in _need_bars:
		for bar in bars.values():
			bar.custom_minimum_size.x = w - (12.0 if Game.mate else 0.0)


# ---- building ---------------------------------------------------------------

func _build_top() -> void:
	var card := PanelContainer.new()
	_anchor(card, 0, 0, Vector2(14, 12))
	add_child(card)
	var v := UI.vbox(2)
	card.add_child(v)
	var h := UI.hbox(10)
	v.add_child(h)
	h.add_child(UI.label("Bubák", 30))
	if Game.test_mode:
		var bp := PanelContainer.new()
		var bs := UI.box(Color("#8fa6d6"), 10, 2, false)
		bs.set_content_margin_all(3)
		bs.content_margin_left = 8
		bs.content_margin_right = 8
		bp.add_theme_stylebox_override("panel", bs)
		bp.size_flags_vertical = SIZE_SHRINK_CENTER
		bp.add_child(UI.label(tr("TEST"), 14, Color.WHITE))
		h.add_child(bp)
	var hearts := UI.hbox(0)   # one heart per trust level
	for i in Catalog.TRUST_LEVELS.size():
		var r := UI.icon_rect("heart", 19)
		hearts.add_child(r)
		_hearts.append(r)
	h.add_child(hearts)
	_trust_name = UI.label("", 17)
	v.add_child(_trust_name)
	_trust_bar = ProgressBar.new()
	_trust_bar.custom_minimum_size = Vector2(236, 12)
	_trust_bar.show_percentage = false
	_trust_bar.max_value = 1.0
	_trust_bar.step = 0.001
	v.add_child(_trust_bar)
	var ch := UI.hbox(6)
	ch.add_child(UI.icon_rect("cozy", 24))
	_cozy_label = UI.label("", 16)
	ch.add_child(_cozy_label)
	v.add_child(ch)
	_cozy_bar = ProgressBar.new()
	_cozy_bar.custom_minimum_size = Vector2(236, 8)
	_cozy_bar.show_percentage = false
	_cozy_bar.max_value = 1.0
	_cozy_bar.step = 0.001
	_cozy_bar.add_theme_stylebox_override("fill", UI.bar_fill(UI.GOLD))
	v.add_child(_cozy_bar)
	card.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			toast(tr("The hearts show how much Bubák trusts you: %s, %d of %d. Trust grows with care, petting and treats, a little every day.") % [
				Catalog.level_name(Game.trust_level()), Game.trust_level() + 1, Catalog.TRUST_LEVELS.size()] + "\n"
				+ tr("Coziness grows with furniture, toys and upgrades. Higher levels make Bubák happier, bring more followers and unlock new things in the shop.")
				+ ("\n" + tr("Too cluttered right now (-%d)! Put a few things away in the toy chest by the desk.") % Game.clutter_penalty()
					if Game.clutter_penalty() > 0 else "")))
	if Game.mate:
		_build_mate_card(v)

	# one row of need bars per rabbit; with two, each row starts with a little portrait
	var needs := PanelContainer.new()
	_anchor(needs, 0.5, 0, Vector2(0, 12))
	add_child(needs)
	var rows := UI.vbox(2)
	needs.add_child(rows)
	for pet in Game.pets:
		var nh := UI.hbox(10 if Game.mate == null else 8)
		rows.add_child(nh)
		if Game.mate:
			nh.add_child(UI.icon_rect("icon" if pet.is_bubak() else "mate_" + pet.id, 34))
		var bars := {}
		var icons := {}
		for need in ["food", "water", "fun", "clean", "energy"]:
			var cell := UI.hbox(4)
			var b := _icon_button(need, 40 if Game.mate == null else 32)
			b.pressed.connect(toast.bind(_need_hint(need)))
			cell.add_child(b)
			var bar := ProgressBar.new()
			bar.custom_minimum_size = Vector2(BAR_W, 16 if Game.mate == null else 12)
			bar.size_flags_vertical = SIZE_SHRINK_CENTER
			bar.show_percentage = false
			bar.add_theme_stylebox_override("fill", UI.bar_fill(UI.NEED_COLORS[need]))
			cell.add_child(bar)
			nh.add_child(cell)
			bars[need] = bar
			icons[need] = b
		_need_bars.append(bars)
		_need_icons.append(icons)

	var right := UI.hbox(8)
	_anchor(right, 1, 0, Vector2(-14, 12))
	add_child(right)
	_coins = _pill(right, "coin")
	_followers = _pill(right, "follower")
	var gear := _icon_button("settings", 50)
	gear.size_flags_vertical = SIZE_SHRINK_CENTER
	gear.pressed.connect(open_settings)
	right.add_child(gear)


## Under Bubák's card: his friend's name, trust and how close the two are.
func _build_mate_card(v: VBoxContainer) -> void:
	v.add_child(HSeparator.new())
	var h := UI.hbox(8)
	v.add_child(h)
	h.add_child(UI.icon_rect("mate_" + Game.mate.id, 34))
	_mate_name = UI.label(Game.mate.display_name(), 22)
	h.add_child(_mate_name)
	var hearts := UI.hbox(0)
	for i in Catalog.TRUST_LEVELS.size():
		var r := UI.icon_rect("heart", 16)
		hearts.add_child(r)
		_mate_hearts.append(r)
	hearts.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(hearts)
	_mate_trust = ProgressBar.new()
	_mate_trust.custom_minimum_size = Vector2(236, 10)
	_mate_trust.show_percentage = false
	_mate_trust.max_value = 1.0
	_mate_trust.step = 0.001
	v.add_child(_mate_trust)
	var bh := UI.hbox(6)
	v.add_child(bh)
	bh.add_child(UI.label(tr("Bond"), 16))
	_bond_bar = ProgressBar.new()
	_bond_bar.custom_minimum_size = Vector2(170, 8)
	_bond_bar.size_flags_vertical = SIZE_SHRINK_CENTER
	_bond_bar.show_percentage = false
	_bond_bar.add_theme_stylebox_override("fill", UI.bar_fill(Color("#d8a7d0")))
	bh.add_child(_bond_bar)


func _need_hint(need: String) -> String:
	match need:
		"food": return tr("Food: tap the bowl to add pellets, the hay rack to add hay. Treats help too.")
		"water": return tr("Water: tap the water bowl to refill it.")
		"fun": return tr("Fun: pet Bubák, give him toys from the shop, or toss his ball.")
		"energy": return tr("Energy: Bubák naps when he's tired, and recovers fastest in a cozy bed. Let him sleep!")
	return tr("Clean: tap the litter box to clean it, and pick up any droppings.")


func _icon_button(icon: String, size: float) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = Catalog.icon(icon)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.custom_minimum_size = Vector2(size, size)
	b.focus_mode = FOCUS_NONE
	return b


func _pill(parent: Control, icon: String) -> Label:
	var p := PanelContainer.new()
	var s := UI.box(UI.CREAM, 30)
	s.content_margin_left = 10
	s.content_margin_right = 16
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", s)
	var h := UI.hbox(6)
	h.add_child(UI.icon_rect(icon, 34))
	var l := UI.label("0", 24)
	l.custom_minimum_size.x = 44
	h.add_child(l)
	p.add_child(h)
	parent.add_child(p)
	return l


func _build_buttons() -> void:
	_buttons = UI.hbox(10)
	_anchor(_buttons, 1, 1, Vector2(-14, -14))
	add_child(_buttons)
	var defs := [["treat", tr("Treats"), _toggle_tray], ["shop", tr("Shop"), open_shop],
		["camera", tr("Photo"), func(): main.set_mode("photo")], ["leash", tr("Walk"), open_walks], ["club", tr("Club"), open_club],
		["journal", tr("Journal"), open_journal],
		["move", tr("Move"), func(): main.set_mode("move")]]
	for d in defs:
		var b := UI.big_button(d[0], d[1])
		b.pressed.connect(d[2])
		_buttons.add_child(b)
		if d[0] == "club":
			_club_button = b
		if d[0] == "leash":
			_walk_button = b
		if d[0] == "journal":
			_journal_badge = PanelContainer.new()
			var bs := UI.box(Color("#e8505b"), 14, 2, false)
			bs.set_content_margin_all(2)
			bs.content_margin_left = 8
			bs.content_margin_right = 8
			_journal_badge.add_theme_stylebox_override("panel", bs)
			_journal_badge.add_child(UI.label("!", 16, Color.WHITE))
			_journal_badge.position = Vector2(64, -8)
			_journal_badge.mouse_filter = MOUSE_FILTER_IGNORE
			b.add_child(_journal_badge)


func _build_tray() -> void:
	_tray = PanelContainer.new()
	_anchor(_tray, 1, 1, Vector2(-14, -122))
	_tray.hide()
	add_child(_tray)


func _toggle_tray() -> void:
	if _tray.visible:
		_tray.hide()
		return
	for c in _tray.get_children():
		c.queue_free()
	var v := UI.vbox(8)
	_tray.add_child(v)
	var treats := Game.treats_in_inventory()
	if treats.is_empty():
		v.add_child(UI.label(tr("No treats left. The shop has some!"), 20))
	else:
		v.add_child(UI.label(tr("Pick a treat to hand-feed:"), 20))
		var h := HFlowContainer.new()   # wraps onto a second row when there are many treats
		h.add_theme_constant_override("h_separation", 8)
		h.add_theme_constant_override("v_separation", 8)
		h.custom_minimum_size.x = mini(treats.size(), 6) * 138
		v.add_child(h)
		for id in treats:
			var b := UI.big_button(id, "%s x%d" % [Catalog.item_name(id), Game.inventory[id]], 100)
			b.custom_minimum_size = Vector2(130, 100)
			b.pressed.connect(func():
				_tray.hide()
				main.treat_selected = id
				main.set_mode("treat"))
			h.add_child(b)
	_tray.show()
	UI.pop_in.call_deferred(_tray)


func _build_banner() -> void:
	_banner = PanelContainer.new()
	_anchor(_banner, 0.5, 1, Vector2(0, -20))
	add_child(_banner)
	var h := UI.hbox(16)
	_banner.add_child(h)
	_banner_label = UI.label("", 22)
	_banner_label.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(_banner_label)
	_banner_button = UI.text_button(tr("Done"))
	_banner_button.pressed.connect(func(): main.set_mode(""))
	h.add_child(_banner_button)
	_banner.hide()


func _build_camera_ui() -> void:
	_camera_ui = Control.new()
	_camera_ui.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_camera_ui.mouse_filter = MOUSE_FILTER_IGNORE
	_camera_ui.hide()
	add_child(_camera_ui)
	var vf := Viewfinder.new()
	vf.safe = _safe
	_viewfinder = vf
	vf.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	vf.mouse_filter = MOUSE_FILTER_IGNORE
	_camera_ui.add_child(vf)
	var shutter := UI.big_button("camera", tr("Snap!"), 110)
	_anchor(shutter, 0.5, 1, Vector2(0, -16))
	shutter.pressed.connect(_snap)
	_camera_ui.add_child(shutter)
	var close := UI.text_button(tr("Close"), "close", 20)
	_anchor(close, 1, 1, Vector2(-16, -24))
	close.pressed.connect(func(): main.set_mode(""))
	_camera_ui.add_child(close)
	var selfie := UI.text_button(tr("Selfie"), "heart", 20)
	_anchor(selfie, 1, 1, Vector2(-16, -96))
	selfie.pressed.connect(func(): main.try_pick_up())
	_camera_ui.add_child(selfie)
	var hint := PanelContainer.new()
	_anchor(hint, 0, 1, Vector2(16, -24))
	var hv := UI.vbox(4)
	hint.add_child(hv)
	hv.add_child(UI.wrap_label(tr("Catch Bubák doing something cute!\nSparkles mean a rare moment."), 17, 300))
	# followers' attention: posting too often wears it out
	var fh := UI.hbox(6)
	fh.add_child(UI.icon_rect("follower", 22))
	_feed_label = UI.label("", 16)
	fh.add_child(_feed_label)
	hv.add_child(fh)
	_feed_bar = ProgressBar.new()
	_feed_bar.custom_minimum_size = Vector2(300, 10)
	_feed_bar.show_percentage = false
	_feed_bar.max_value = 1.0
	_feed_bar.step = 0.001
	hv.add_child(_feed_bar)
	_camera_ui.add_child(hint)


func _build_selfie_ui() -> void:
	_selfie_ui = Control.new()
	_selfie_ui.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_selfie_ui.mouse_filter = MOUSE_FILTER_STOP
	_selfie_ui.hide()
	add_child(_selfie_ui)
	_selfie_frame = Control.new()
	_selfie_frame.custom_minimum_size = Vector2(600, 450)
	_selfie_frame.size = Vector2(600, 450)
	_selfie_frame.clip_contents = true
	_selfie_frame.mouse_filter = MOUSE_FILTER_IGNORE
	_anchor(_selfie_frame, 0.5, 0.5, Vector2(0, -50))
	_selfie_dim = HoleDim.new()
	_selfie_dim.hole = _selfie_frame
	_selfie_dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_selfie_dim.mouse_filter = MOUSE_FILTER_IGNORE
	_selfie_ui.add_child(_selfie_dim)
	_selfie_ui.add_child(_selfie_frame)

	var you := TextureRect.new()
	you.texture = Catalog.tex("owner")
	you.position = Vector2(70, 450 - 400)
	you.size = Vector2(335, 400)
	you.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	you.mouse_filter = MOUSE_FILTER_IGNORE
	_selfie_frame.add_child(you)
	_selfie_bunny = TextureRect.new()
	_selfie_bunny.texture = Catalog.tex("bunny_loaf")
	_selfie_bunny.flip_h = true
	_selfie_bunny.position = Vector2(282, 168)
	_selfie_bunny.size = Vector2(270, 245)
	_selfie_bunny.pivot_offset = Vector2(135, 215)
	_selfie_bunny.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_selfie_bunny.mouse_filter = MOUSE_FILTER_IGNORE
	_selfie_frame.add_child(_selfie_bunny)
	var hand := TextureRect.new()
	hand.texture = Catalog.tex("owner_hand")
	hand.position = Vector2(372, 300)
	hand.size = Vector2(180, 180)
	hand.flip_h = true
	hand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hand.mouse_filter = MOUSE_FILTER_IGNORE
	_selfie_frame.add_child(hand)

	_selfie_controls = UI.hbox(14)
	_anchor(_selfie_controls, 0.5, 1, Vector2(0, -14))
	_selfie_ui.add_child(_selfie_controls)
	var snap := UI.big_button("camera", tr("Snap!"), 96)
	snap.pressed.connect(_snap_selfie)
	_selfie_controls.add_child(snap)
	var wv := UI.vbox(4)
	wv.alignment = BoxContainer.ALIGNMENT_CENTER
	var wl := UI.label(tr("Patience left"), 17, Color.WHITE)
	wl.add_theme_color_override("font_outline_color", UI.INK)
	wl.add_theme_constant_override("outline_size", 6)
	wv.add_child(wl)
	_wriggle_bar = ProgressBar.new()
	_wriggle_bar.custom_minimum_size = Vector2(180, 18)
	_wriggle_bar.show_percentage = false
	_wriggle_bar.max_value = 1.0
	_wriggle_bar.step = 0.001
	wv.add_child(_wriggle_bar)
	_selfie_controls.add_child(wv)
	var down := UI.text_button(tr("Put him down"), "", 20)
	down.size_flags_vertical = SIZE_SHRINK_CENTER
	down.pressed.connect(func(): main.set_mode(""))
	_selfie_controls.add_child(down)


func _start_selfie() -> void:
	var who: Node2D = main.held
	# mirrored: in the selfie he faces left
	StageBunny.compose(_selfie_bunny, "loaf", who.pet.skin(), Game.wearing if who.pet.is_bubak() else {}, true)
	_selfie_t = 0.0
	_selfie_hearts_t = 0.0
	if _bob:
		_bob.kill()
	_bob = _selfie_bunny.create_tween().set_loops()
	_bob.tween_property(_selfie_bunny, "scale", Vector2(1.03, 0.97), 0.6).set_trans(Tween.TRANS_SINE)
	_bob.tween_property(_selfie_bunny, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)
	toast(tr("%s is in your arms! Cheek to cheek... now snap a selfie before the wriggling starts.") % who.pet.display_name())


func _update_selfie(delta: float) -> void:
	_selfie_dim.queue_redraw()
	if _modal:
		return  # time stands still while you admire the photo
	_selfie_t += delta
	var limit: float = main.held.hold_limit()
	_wriggle_bar.value = 1.0 - _selfie_t / limit
	var wriggly := _selfie_t > limit * 0.75
	_selfie_bunny.rotation = sin(_selfie_t * 30.0) * 0.06 if wriggly else 0.0
	_selfie_hearts_t -= delta
	if _selfie_hearts_t <= 0 and not wriggly:
		_selfie_hearts_t = 0.7
		var h := UI.icon_rect("heart", 34)
		h.position = Vector2(randf_range(250, 520), randf_range(140, 260))
		_selfie_frame.add_child(h)
		var t := h.create_tween().set_parallel()
		t.tween_property(h, "position:y", h.position.y - 90, 1.4)
		t.tween_property(h, "modulate:a", 0.0, 0.6).set_delay(0.8)
		t.chain().tween_callback(h.queue_free)
	if _selfie_t > limit:
		toast(tr("%s is getting wriggly. Back on the floor!") % main.held.pet.display_name())
		main.set_mode("")


func _snap_selfie() -> void:
	_selfie_controls.visible = false
	_toasts.visible = false
	for c in _selfie_frame.get_children():
		if c is TextureRect and c.texture == Catalog.icon("heart"):
			c.visible = false
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_selfie_controls.visible = true
	_toasts.visible = true
	var k := img.get_width() / get_viewport().get_visible_rect().size.x
	var r := _selfie_frame.get_global_rect()
	var sub := img.get_region(Rect2i(Vector2i(r.position * k), Vector2i(r.size * k)))
	sub.resize(480, 360, Image.INTERPOLATE_LANCZOS)
	var file := Game.PHOTO_DIR + "p_%d.png" % int(Time.get_unix_time_from_system() * 1000)
	sub.save_png(file)
	Game.discover("selfie")
	_flash()
	show_photo_result(sub, Game.record_photo(file, "selfie", 0))


# ---- per-frame -----------------------------------------------------------------

func _process(delta: float) -> void:
	if _selfie_ui.visible:
		_update_selfie(delta)
	_safe_t -= delta
	if _safe_t <= 0:   # re-check now and then: the notch side flips when the phone is turned
		_safe_t = 1.0
		_update_safe_area()
	_refresh_t -= delta
	if _refresh_t <= 0:
		_refresh_t = 0.2
		_refresh()


func _refresh() -> void:
	_coins.text = str(Game.coins)
	if _last_coins >= 0 and Game.coins != _last_coins:
		Sfx.play("coin" if Game.coins > _last_coins else "buy")
	_last_coins = Game.coins
	_followers.text = str(Game.followers)
	if _camera_ui.visible:
		var a := Game.feed_attention()
		_feed_bar.value = a
		_feed_label.text = tr("Followers' attention: %s") % (tr("Flooded!") if a < Catalog.FEED_FLOODED
			else tr("Fresh") if a > 0.8 else tr("Busy"))
		_feed_bar.add_theme_stylebox_override("fill", UI.bar_fill(UI.RED if a < Catalog.FEED_FLOODED else UI.GOLD if a <= 0.8 else UI.GREEN))
	var lvl := Game.trust_level()
	_trust_name.text = tr("Trust: %s") % Catalog.level_name(lvl)
	_trust_bar.value = Game.trust_progress()
	var cl := Game.cozy_level()
	_cozy_label.text = tr("Cozy level %d: %s") % [cl, Catalog.cozy_name(cl)]
	var messy := Game.clutter_penalty() > 0
	if messy:
		_cozy_label.text = tr("Cozy level %d: %s") % [cl, tr("Cluttered!")]
	_cozy_label.add_theme_color_override("font_color", Color("#c0392b") if messy else UI.INK)
	_cozy_bar.value = Game.cozy_progress()
	_club_button.visible = Game.club_stage >= 1
	_walk_button.visible = "leash" in Game.gear
	var claim := Game.claimable_goals()
	_journal_badge.visible = claim > 0
	(_journal_badge.get_child(0) as Label).text = str(claim)
	for i in _hearts.size():
		_hearts[i].modulate = Color.WHITE if i <= lvl else Color(0.55, 0.5, 0.5, 0.35)
	var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 150.0)
	for i in mini(_need_bars.size(), Game.pets.size()):
		for need in _need_bars[i]:
			var p: Pet = Game.pets[i]
			var v: float = p.energy if need == "energy" else p.needs[need]
			_need_bars[i][need].value = v
			if need == "energy":   # tiredness isn't an emergency: he just naps. Asleep, the moon glows.
				_need_icons[i][need].modulate = Color(1.15, 1.1, 0.75) if p.asleep else Color.WHITE
			else:
				_need_icons[i][need].modulate = Color(1, pulse, pulse) if v < 25 else Color.WHITE
	if Game.mate and _mate_trust:
		var ml: int = Game.mate.trust_level()
		_mate_trust.value = Game.mate.trust_progress()
		_bond_bar.value = Game.bond
		for i in _mate_hearts.size():
			_mate_hearts[i].modulate = Color.WHITE if i <= ml else Color(0.55, 0.5, 0.5, 0.35)


func on_mode_changed(m: String) -> void:
	_tray.hide()
	_buttons.visible = m == ""
	_camera_ui.visible = m == "photo"
	if m == "selfie" and not _selfie_ui.visible:
		_start_selfie()
	_selfie_ui.visible = m == "selfie"
	_banner.visible = m in ["move", "treat"]
	match m:
		"move":
			_banner_label.text = tr("Drag furniture and toys to rearrange the room.")
			_banner_button.text = tr("Done")
		"treat":
			_banner_label.text = tr("Tap the floor to offer the %s.") % Catalog.item_name(main.treat_selected).to_lower()
			_banner_button.text = tr("Cancel")


# ---- toasts ------------------------------------------------------------------

func toast(text: String, icon := "", gold := false) -> void:
	Sfx.play("notify")
	var p := PanelContainer.new()
	var s := UI.box(Color("#fff3c9") if gold else UI.CREAM, 18)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = MOUSE_FILTER_IGNORE
	var h := UI.hbox(10)
	p.add_child(h)
	if icon != "":
		h.add_child(UI.icon_rect(icon, 32))
	var l := UI.label(text, 20)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if text.length() > 48:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 560
	h.add_child(l)
	_toasts.add_child(p)
	while _toasts.get_child_count() > 3:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	p.modulate.a = 0
	p.scale = Vector2(0.85, 0.85)
	p.resized.connect(func(): p.pivot_offset = p.size / 2.0)
	p.create_tween().tween_property(p, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var t := p.create_tween()
	t.tween_property(p, "modulate:a", 1.0, 0.2)
	t.tween_interval(2.6 + text.length() / 35.0)
	t.tween_property(p, "modulate:a", 0.0, 0.4)
	t.tween_callback(p.queue_free)


func _on_discovered(b: String) -> void:
	toast(tr("New behaviour: %s  (see Journal)") % Catalog.behaviour_name(b), "star", true)


func _queue(popup: Callable) -> void:
	if _modal:
		_pending.append(popup)
	else:
		popup.call()


func _on_goal_completed(id: String) -> void:
	for g in Catalog.GOALS:
		if g.id == id:
			toast(tr("Goal complete: %s! Claim the reward in the Journal.") % Catalog.goal_text(g), "goal", true)


func _on_sponsor(amount: int, streak: int) -> void:
	_queue(func():
		var v := UI.vbox(12)
		v.add_child(UI.icon_rect("gift", 110))
		var title := UI.label(tr("Sponsor deal!"), 34)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(title)
		var msg := tr("A pet shop loved Bubák's posts and paid you %d coins.") % amount
		if streak > 1:
			msg += "\n" + tr("Daily streak: %d days in a row!") % streak
		msg += "\n\n" + tr("Come back tomorrow for another deal. More followers and a cozier home mean bigger deals.")
		var l := UI.wrap_label(msg, 21, 500)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		var ok := UI.text_button(tr("Thanks!"))
		ok.size_flags_horizontal = SIZE_SHRINK_CENTER
		ok.pressed.connect(close_top)
		v.add_child(ok)
		_open_modal("", v, Vector2(580, 0)))


func on_balcony_milestone() -> void:
	_queue(func():
		Sfx.play("fanfare")
		var v := UI.vbox(12)
		var pic := UI.icon_rect("door_open", 150)
		v.add_child(pic)
		var title := UI.label(tr("Milestone reached!"), 34)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(title)
		var l := UI.wrap_label(tr("Bubák trusts you and %d people follow his adventures. Time for some fresh air!") % Game.followers
			+ "\n\n" + tr("Make the balcony bunny-safe with Balcony netting (Shop, Home tab), and the door to the balcony will open."), 21, 500)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		var ok := UI.text_button(tr("Can't wait!"))
		ok.size_flags_horizontal = SIZE_SHRINK_CENTER
		ok.pressed.connect(close_top)
		v.add_child(ok)
		_open_modal("", v, Vector2(580, 0)))


func _on_level_up(lvl: int) -> void:
	_queue(_level_up_popup.bind(lvl))


func _level_up_popup(lvl: int) -> void:
	Sfx.play("fanfare")
	var count := 0
	for b in Catalog.BEHAVIOURS.values():
		if b.get("level", 0) == lvl:
			count += 1
	var v := UI.vbox(12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var heart := UI.icon_rect("heart", 96)
	v.add_child(heart)
	var title := UI.label(tr("Bubák trusts you more!"), 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var msg := tr("He now feels %s with you.") % Catalog.level_name(lvl).to_upper()
	if count > 0:
		msg += "\n" + tr_n("%d new behaviour to discover. Keep watching!", "%d new behaviours to discover. Keep watching!", count) % count
	if lvl == Catalog.SELFIE_TRUST:
		msg += "\n\n" + tr("He'll let you pick him up now! Drag him upwards (or tap Selfie in Photo mode) and snap a selfie together.")
	var l := UI.wrap_label(msg, 22, 480)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var ok := UI.text_button(tr("Aww!"))
	ok.size_flags_horizontal = SIZE_SHRINK_CENTER
	ok.pressed.connect(close_top)
	v.add_child(ok)
	_open_modal("", v, Vector2(560, 0))


# ---- modals ------------------------------------------------------------------

func _open_modal(title: String, content: Control, min_size := Vector2(860, 560)) -> void:
	close_top()
	if main.mode == "treat" or main.mode == "move":
		main.set_mode("")
	var dim := ColorRect.new()
	dim.color = Color(0.25, 0.17, 0.12, 0.45)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.mouse_filter = MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.mouse_filter = MOUSE_FILTER_IGNORE
	dim.add_child(center)
	var panel := PanelContainer.new()
	var ps := UI.box(UI.CREAM, 26)
	ps.set_content_margin_all(26)
	panel.add_theme_stylebox_override("panel", ps)
	panel.custom_minimum_size = min_size
	center.add_child(panel)
	var v := UI.vbox(10)
	panel.add_child(v)
	if title != "":
		var h := UI.hbox(10)
		v.add_child(h)
		var t := UI.label(title, 32)
		t.size_flags_horizontal = SIZE_EXPAND_FILL
		h.add_child(t)
		var x := _icon_button("close", 52)
		x.pressed.connect(close_top)
		h.add_child(x)
	content.size_flags_vertical = SIZE_EXPAND_FILL
	v.add_child(content)
	_modal = dim
	UI.pop_in.call_deferred(panel)


func close_top() -> bool:
	if _modal:
		_modal.queue_free()
		_modal = null
		if not _pending.is_empty():
			_pending.pop_front().call_deferred()
		return true
	if _tray.visible:
		_tray.hide()
		return true
	if main.mode != "":
		main.set_mode("")
		return true
	return false


func show_welcome(text: String) -> void:
	var v := UI.vbox(14)
	var h := UI.hbox(18)
	v.add_child(h)
	h.add_child(UI.icon_rect("icon", 140))
	h.add_child(UI.wrap_label(text, 22, 520))
	var ok := UI.text_button(tr("Let's go!"))
	ok.size_flags_horizontal = SIZE_SHRINK_CENTER
	ok.pressed.connect(close_top)
	v.add_child(ok)
	_open_modal("", v, Vector2(720, 0))


# ---- shop --------------------------------------------------------------------

func open_shop() -> void:
	var v := UI.vbox(10)
	var tabs := UI.hbox(8)
	v.add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 440)
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	v.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(grid)
	var group := ButtonGroup.new()
	for tab in Catalog.SHOP_TABS:
		if tab == "Club" and Game.club_stage < 1:
			continue
		if tab == "Balcony" and Game.balcony == "locked" and not Game.test_mode:
			continue
		var b := UI.text_button(tr(tab), "", 18)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = tab == _shop_tab
		b.custom_minimum_size.x = 80
		b.pressed.connect(func():
			_shop_tab = tab
			_fill_shop(grid))
		tabs.add_child(b)
	if Game.mate_stage == 1:
		var adopt := UI.text_button(tr("Adopt a friend"), "heart")
		adopt.pressed.connect(open_hutch)
		tabs.add_child(adopt)
	_fill_shop(grid)
	_open_modal(tr("Shop"), v)


func _fill_shop(grid: GridContainer) -> void:
	for c in grid.get_children():
		c.queue_free()
	if _shop_tab == "Club" and Game.club_stage < 1:
		_shop_tab = "Food"
	for id in Catalog.SHOP_TABS[_shop_tab]:
		var item: Dictionary = Catalog.ITEMS[id]
		if Game.club_stage < item.get("stage", 0):
			continue
		var locked := Game.lock_reason(id)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UI.box(Color("#fffdf8"), 18, 2, false))
		card.size_flags_horizontal = SIZE_EXPAND_FILL
		var v := UI.vbox(4)
		card.add_child(v)
		var top := UI.hbox(10)
		v.add_child(top)
		var ic := UI.icon_rect(item.get("icon", id), 64)
		top.add_child(ic)
		var nv := UI.vbox(0)
		var name_label := UI.wrap_label(tr(item.name), 20, 150)
		nv.add_child(name_label)
		var owned := ""
		var done := false   # nothing more to buy here
		match item.kind:
			"food", "hay", "treat":
				owned = tr("You have %d") % Game.inventory.get(id, 0)
			"toy", "decor":
				owned = tr("Owned %d/%d") % [Game.count_item(id), item.get("max", 1)]
				done = Game.count_item(id) >= item.get("max", 1)
			"wear":
				done = id in Game.wardrobe
				owned = tr("Wearing") if id in Game.wearing.values() else (tr("Owned") if done else "")
			"gear":
				done = id in Game.gear
				owned = tr("Owned") if done else ""
			"upgrade":
				if id == "balcony_net":
					owned = {"locked": tr("Locked: needs %s trust + %d followers") % [
						Catalog.level_name(Catalog.BALCONY_TRUST), Catalog.BALCONY_FOLLOWERS],
						"available": tr("Unlocked!"), "open": tr("Installed")}[Game.balcony]
					done = Game.balcony != "available"
				elif id == "cable_cover":
					done = Game.cable == "covered"
					owned = tr("Installed") if done else ""
				else:
					done = Game.tier(item.slot) >= item.tier
					owned = tr("Installed") if done else ""
		if locked != "" and not done:
			owned = locked
			ic.modulate = Color(1, 1, 1, 0.45)
		nv.add_child(UI.label(owned, 15, Color("#c0504d") if locked != "" and not done else Color(UI.INK, 0.7)))
		top.add_child(nv)
		var desc := UI.wrap_label(tr(item.desc), 16, 230)
		desc.size_flags_vertical = SIZE_EXPAND_FILL
		v.add_child(desc)
		if item.kind == "wear" and done:
			var wb := UI.text_button(tr("Wardrobe"), "wardrobe", 20)
			wb.pressed.connect(open_wardrobe)
			v.add_child(wb)
			grid.add_child(card)
			continue
		var buy := UI.text_button(str(item.price), "coin", 22)
		buy.disabled = done or locked != "" or Game.coins < item.price
		buy.pressed.connect(func():
			var err := Game.buy(id, main.view)
			if err != "":
				toast(err)
			else:
				var qty: int = item.get("qty", 1)
				if id == "balcony_net":
					close_top()
					toast(tr("The balcony door is open! Bubák will pop out when he feels like it.\nTap the door to go out yourself."))
					return
				if item.kind in ["toy", "decor"]:
					toast(tr("%s is in the room now. Use Move to arrange it.") % tr(item.name))
				elif qty > 1:
					toast(tr("Bought %s (x%d)!") % [tr(item.name), qty])
				else:
					toast(tr("Bought %s!") % tr(item.name))
			_fill_shop(grid))
		v.add_child(buy)
		grid.add_child(card)


# ---- journal -----------------------------------------------------------------

func open_journal() -> void:
	var v := UI.vbox(10)
	var tabs := UI.hbox(8)
	v.add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 440)
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	v.add_child(scroll)
	var holder := UI.vbox(10)
	holder.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(holder)
	var group := ButtonGroup.new()
	for tab in ["Goals", "Behaviours", "Photos", "Bubák"]:
		var b := UI.text_button(tr(tab))
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = tab == _journal_tab
		b.custom_minimum_size.x = 140
		b.pressed.connect(func():
			_journal_tab = tab
			_fill_journal(holder))
		tabs.add_child(b)
	_fill_journal(holder)
	_open_modal(tr("Journal"), v)


func _fill_journal(holder: VBoxContainer) -> void:
	for c in holder.get_children():
		c.queue_free()
	match _journal_tab:
		"Goals":
			var goals: Array = Catalog.GOALS.filter(func(x): return Game.goal_visible(x))
			holder.add_child(UI.label(tr("Goals completed: %d of %d") % [Game.goals_claimed.size(), goals.size()], 20))
			var shown := 0
			var ordered: Array = goals.filter(func(x): return Game.goal_done(x)) \
				+ goals.filter(func(x): return not Game.goal_done(x))
			for g in ordered:
				if g.id in Game.goals_claimed:
					continue
				var done := Game.goal_done(g)
				if not done and shown >= 6:
					continue
				shown += 1
				var row := PanelContainer.new()
				row.add_theme_stylebox_override("panel", UI.box(Color("#fff3c9") if done else Color("#fffdf8"), 16, 2, false))
				var h := UI.hbox(12)
				row.add_child(h)
				h.add_child(UI.icon_rect("star" if done else "goal", 40))
				var gv := UI.vbox(2)
				gv.size_flags_horizontal = SIZE_EXPAND_FILL
				gv.add_child(UI.label(Catalog.goal_text(g), 19))
				var target := Game.goal_target(g)
				var pv := UI.hbox(8)
				var bar := ProgressBar.new()
				bar.custom_minimum_size = Vector2(260, 12)
				bar.size_flags_vertical = SIZE_SHRINK_CENTER
				bar.show_percentage = false
				bar.max_value = target
				bar.value = mini(Game.goal_value(g), target)
				pv.add_child(bar)
				pv.add_child(UI.label("%d/%d" % [mini(Game.goal_value(g), target), target], 15, Color(UI.INK, 0.7)))
				gv.add_child(pv)
				h.add_child(gv)
				h.add_child(UI.icon_rect("coin", 28))
				var rl := UI.label(str(g.reward), 20)
				rl.size_flags_vertical = SIZE_SHRINK_CENTER
				h.add_child(rl)
				if done:
					var cb := UI.text_button(tr("Claim"), "", 20)
					cb.size_flags_vertical = SIZE_SHRINK_CENTER
					cb.pressed.connect(func():
						var got := Game.claim_goal(g.id)
						if got > 0:
							toast(tr("Goal reward: +%d coins!") % got, "coin", true)
						_fill_journal(holder))
					h.add_child(cb)
				holder.add_child(row)
		"Behaviours":
			holder.add_child(UI.label(tr("Discovered %d of %d") % [Game.seen.size(), Catalog.BEHAVIOUR_ORDER.size()], 20))
			var grid := GridContainer.new()
			grid.columns = 2
			holder.add_child(grid)
			for id in Catalog.BEHAVIOUR_ORDER:
				var b: Dictionary = Catalog.BEHAVIOURS[id]
				var seen := Game.seen.has(id)
				var card := PanelContainer.new()
				card.add_theme_stylebox_override("panel", UI.box(Color("#fffdf8") if seen else Color("#f1e8dc"), 16, 2, false))
				card.size_flags_horizontal = SIZE_EXPAND_FILL
				var h := UI.hbox(10)
				card.add_child(h)
				var ic := UI.icon_rect("star", 44)
				if not seen:
					ic.modulate = Color(0.3, 0.25, 0.25, 0.3)
				h.add_child(ic)
				var tv := UI.vbox(0)
				h.add_child(tv)
				tv.add_child(UI.label(tr(b.name) if seen else "???", 20))
				var desc: String = tr(b.desc)
				if not seen:
					if b.get("needs", "") == "tricks":
						desc = tr("Needs: a trick with 2 stars")
					elif b.get("needs", "") == "mate":
						desc = tr("Needs: a friend for Bubák")
					elif b.has("needs"):
						desc = tr("Needs: %s") % (Catalog.item_name(b.needs) if Catalog.ITEMS.has(b.needs) else tr("the balcony"))
					elif b.get("level", 0) > Game.trust_level():
						desc = tr("Needs trust: %s") % Catalog.level_name(b.level)
					else:
						desc = tr("Keep watching...")
				tv.add_child(UI.wrap_label(desc, 15, 310))
				grid.add_child(card)
		"Photos":
			if Game.photos.is_empty():
				holder.add_child(UI.wrap_label(tr("No photos yet. Tap Photo and catch Bubák doing something cute!"), 20, 700))
				return
			var grid := GridContainer.new()
			grid.columns = 4
			holder.add_child(grid)
			var list: Array = Game.photos.duplicate()
			list.reverse()
			for p in list.slice(0, 40):
				var tex := _photo_texture(p.file)
				if tex == null:
					continue
				var pv := UI.vbox(2)
				var pc := PanelContainer.new()
				var ps := UI.box(Color.WHITE, 6, 2, false)
				ps.set_content_margin_all(6)
				pc.add_theme_stylebox_override("panel", ps)
				var r := TextureRect.new()
				r.texture = tex
				r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
				r.custom_minimum_size = Vector2(180, 135)
				pc.add_child(r)
				pv.add_child(pc)
				var cap: String = Catalog.behaviour_name(p.behaviour)
				pv.add_child(UI.label("%s  -  %s" % [cap, tr_n("%d like", "%d likes", p.likes) % p.likes], 15))
				grid.add_child(pv)
		"Bubák":
			var h := UI.hbox(24)
			holder.add_child(h)
			h.add_child(UI.icon_rect("icon", 180))
			var days := int((Time.get_unix_time_from_system() - Game.created_at) / 86400.0) + 1
			var lines := [
				tr("Bubák, a lilac-grey bunny with one perky ear and one floppy one."),
				tr("Personality: cheeky, curious, very food-motivated."),
				"",
				tr("Day %d together") % days,
				tr("Trust: %s (%d%%)") % [Catalog.level_name(Game.trust_level()), int(Game.trust)],
				tr("Weight: %s kg, %s (healthy: %s to %s kg)") % [kilos(Game.bubak.weight),
					Catalog.weight_name(Game.bubak.weight_band()).to_lower(),
					kilos(Game.bubak.ideal_weight() * (1.0 + Catalog.WEIGHT_BANDS[1])),
					kilos(Game.bubak.ideal_weight() * (1.0 + Catalog.WEIGHT_BANDS[2]))],
				tr("Followers: %d") % Game.followers,
				tr("Photos taken: %d") % Game.stats.photos,
				tr("Treats given: %d") % Game.stats.treats,
				tr("Cuddle sessions: %d") % Game.stats.pets,
				tr("Work shifts: %d") % Game.stats.work,
				tr("Career: %s") % Catalog.career_title(Game.career_level()),
				tr("Cozy level %d: %s") % [Game.cozy_level(), Catalog.cozy_name(Game.cozy_level())],
			]
			if Game.club_stage >= 1:
				lines.append(tr("Trick stars: %d of %d") % [Game.trick_stars_total(), Catalog.TRICKS.size() * 3])
			if Game.club_stage >= 2:
				lines.append(tr("Coat: %d%%") % int(Game.coat))
			if Game.club_stage >= 3:
				lines.append(tr("Ribbons: %d") % Game.trophies.size())
			lines.append("")
			lines.append(tr("Keep his weight just right: playtime, exercise toys and walks burn it off, and only lots of extra treats pile it on."))
			h.add_child(UI.wrap_label("\n".join(PackedStringArray(lines)), 20, 520))


func _photo_texture(file: String) -> Texture2D:
	if not _photo_cache.has(file):
		var img := Image.load_from_file(file) if FileAccess.file_exists(file) else null
		_photo_cache[file] = ImageTexture.create_from_image(img) if img else null
	return _photo_cache[file]


# ---- photos ------------------------------------------------------------------

func _snap() -> void:
	main.take_photo()
	_flash()


func _flash() -> void:
	Sfx.play("shutter")
	var flash := ColorRect.new()
	flash.color = Color.WHITE
	flash.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	flash.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(flash)
	var t := flash.create_tween()
	t.tween_property(flash, "color:a", 0.0, 0.35)
	t.tween_callback(flash.queue_free)


func show_photo_result(img: Image, res: Dictionary) -> void:
	_photo_cache[res.file] = ImageTexture.create_from_image(img)
	var v := UI.vbox(10)
	var pc := PanelContainer.new()
	var ps := UI.box(Color.WHITE, 8, 3, true)
	ps.content_margin_bottom = 14
	pc.add_theme_stylebox_override("panel", ps)
	pc.size_flags_horizontal = SIZE_SHRINK_CENTER
	var r := TextureRect.new()
	r.texture = _photo_cache[res.file]
	r.custom_minimum_size = Vector2(440, 330)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pc.add_child(r)
	v.add_child(pc)
	var caption := tr("Oops, missed him!")
	if res.get("shy", false):
		caption = tr("He turned his back on the camera.")
	elif res.behaviour != "":
		caption = Catalog.behaviour_name(res.behaviour)
	var ch := UI.hbox(12)
	ch.alignment = BoxContainer.ALIGNMENT_CENTER
	ch.add_child(UI.label(caption, 30))
	if res.new:
		var badge := PanelContainer.new()
		var bs := UI.box(UI.GOLD, 12, 2, false)
		bs.set_content_margin_all(4)
		bs.content_margin_left = 10
		bs.content_margin_right = 10
		badge.add_theme_stylebox_override("panel", bs)
		badge.add_child(UI.label(tr("NEW!"), 18))
		badge.size_flags_vertical = SIZE_SHRINK_CENTER
		ch.add_child(badge)
	v.add_child(ch)
	var stats := UI.hbox(8)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	var gained: int = res.followers - res.get("lost", 0)
	for s in [["heart", tr_n("%d like", "%d likes", res.likes) % res.likes], ["coin", "+%d" % res.coins],
			["follower", tr_n("+%d follower", "+%d followers", gained) % gained if gained >= 0
				else tr_n("%d follower", "%d followers", -gained) % gained]]:
		stats.add_child(UI.icon_rect(s[0], 30))
		stats.add_child(UI.label(s[1] + "   ", 21, UI.RED if s[1].begins_with("-") else UI.INK))
	if res.behaviour != "":
		v.add_child(stats)
	var notes: Array[String] = []
	if res.behaviour == "":
		notes.append(tr("Not worth posting. Wait for him to do something cute."))
	elif res.get("lost", 0) > 0:
		notes.append(tr("Too many posts! Your feed is flooded and some followers unfollowed. Give it a break."))
	elif res.get("attention", 1.0) < 0.8:
		notes.append(tr("You've posted a lot lately, so fewer people saw this one."))
	if res.stale:
		notes.append(tr("Your followers have seen this one a lot lately."))
	for n in notes:
		var nl := UI.wrap_label(n, 17, 480)
		nl.add_theme_color_override("font_color", Color(UI.INK, 0.7))
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nl)
	var ok := UI.text_button(tr("Nice!") if res.behaviour != "" else tr("OK"))
	ok.size_flags_horizontal = SIZE_SHRINK_CENTER
	ok.pressed.connect(close_top)
	v.add_child(ok)
	_open_modal("", v, Vector2(540, 0))


## Grams as kilos with two decimals, with a decimal comma in Czech.
static func kilos(grams: float) -> String:
	var s := "%.2f" % (grams / 1000.0)
	return s.replace(".", ",") if TranslationServer.get_locale().begins_with("cs") else s


# ---- walks -------------------------------------------------------------------------

## Where to go with Bubák today: the places open one by one as you go on more walks.
func open_walks() -> void:
	var v := UI.vbox(10)
	var walks: int = Game.stats.get("walks", 0)
	v.add_child(UI.wrap_label(tr("You've been out today already. Bubák is still dreaming about it. Next walk tomorrow!")
		if Game.walked_today() else tr("Where shall we go today? A walk makes Bubák happy and brings you closer."), 19, 760))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for id in Catalog.WALKS:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UI.box(Color.WHITE if Game.walk_open(id) else Color("#efe6da"), 16, 3, false))
		card.custom_minimum_size = Vector2(380, 0)
		var h := UI.hbox(12)
		card.add_child(h)
		var ic := UI.icon_rect(id, 56)
		if not Game.walk_open(id):
			ic.modulate = Color(1, 1, 1, 0.4)
		h.add_child(ic)
		var tv := UI.vbox(2)
		tv.size_flags_horizontal = SIZE_EXPAND_FILL
		h.add_child(tv)
		tv.add_child(UI.label(Catalog.walk_name(id), 22))
		var note := tr("Visited") if id in Game.walk_places else tr("New!")
		if not Game.walk_open(id):
			var left: int = Catalog.WALKS[id].after - walks
			note = tr_n("Opens after %d more walk", "Opens after %d more walks", left) % left
		tv.add_child(UI.label(note, 15, Color(UI.INK, 0.7)))
		var go := UI.text_button(tr("Go!"), "", 20)
		go.disabled = Game.walk_problem(id) != ""
		go.size_flags_vertical = SIZE_SHRINK_CENTER
		go.pressed.connect(func():
			close_top()
			play_walk(id))
		h.add_child(go)
		grid.add_child(card)
	_open_modal(tr("Walk with Bubák"), v, Vector2(820, 0))


## Off we go: the walk counts straight away, then the cutscene plays.
func play_walk(id: String, count := true, speed := 1.0) -> void:
	main.set_mode("")
	var res := Game.go_walk(id) if count else {}
	var w := WalkScene.new()
	w.place = id
	w.speed = speed
	add_child(w)
	await w.finished
	if res.is_empty():
		return
	var msg := tr("%s: back home again. Bubák is beaming!") % Catalog.walk_name(id)
	if res.followers > 0:
		msg += " " + tr_n("+%d follower", "+%d followers", res.followers) % res.followers
	toast(msg, "heart", true)


# ---- settings ------------------------------------------------------------------

func open_settings() -> void:
	var v := UI.vbox(10)
	var h := UI.hbox(10)
	v.add_child(h)
	var lang := UI.label(tr("Language"), 24)
	lang.custom_minimum_size.x = 150
	h.add_child(lang)
	var group := ButtonGroup.new()
	for code in Game.LANGUAGES:
		var b := UI.text_button(Game.LANGUAGES[code])
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = code == Game.language
		b.custom_minimum_size.x = 160
		b.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
		b.pressed.connect(func():
			if code != Game.language:
				Game.set_language(code)
				main.apply_language()
				main.hud.open_settings.call_deferred())
		h.add_child(b)
	v.add_child(HSeparator.new())
	var snd := UI.hbox(10)
	v.add_child(snd)
	var snd_label := UI.label(tr("Sound"), 24)
	snd_label.custom_minimum_size.x = 150
	snd.add_child(snd_label)
	for which in ["sound", "music"]:
		var sb := UI.text_button(tr("Sound effects") if which == "sound" else tr("Music"), "", 18)
		sb.toggle_mode = true
		sb.button_pressed = Sfx.sound_on if which == "sound" else Sfx.music_on
		sb.custom_minimum_size.x = 160
		sb.toggled.connect(func(on: bool):
			if which == "sound":
				Sfx.set_sound_on(on)
			else:
				Sfx.set_music_on(on))
		snd.add_child(sb)
	v.add_child(HSeparator.new())
	v.add_child(UI.label(tr("While the game is closed"), 24))
	var away := UI.hbox(10)
	v.add_child(away)
	var away_group := ButtonGroup.new()
	var away_note := UI.wrap_label("", 15, 580)
	var note := func(): away_note.text = tr("Bubák keeps living: he eats from his bowls, uses the litter box and gets hungry.") \
		if Game.life_goes_on else tr("The game pauses: his needs, waits and timers stop until you come back.")
	for on in [true, false]:
		var b := UI.text_button(tr("Life goes on") if on else tr("Time stops"), "", 18)
		b.toggle_mode = true
		b.button_group = away_group
		b.button_pressed = Game.life_goes_on == on
		b.custom_minimum_size.x = 200
		b.pressed.connect(func():
			Game.set_life_goes_on(on)
			note.call())
		away.add_child(b)
	note.call()
	v.add_child(away_note)
	v.add_child(HSeparator.new())
	v.add_child(UI.label(tr("Game pace"), 24))
	var pace := UI.hbox(10)
	v.add_child(pace)
	var pace_group := ButtonGroup.new()
	var pace_note := UI.wrap_label("", 15, 580)
	var pace_text := func(): pace_note.text = tr("Bubák bonds with you quickly: the balcony, selfies and a friend come within a session or two.") \
		if Game.fast_game else tr("Trust takes days to build: first the balcony, then selfies, and a friend only after a long game.")
	for fast in [false, true]:
		var b := UI.text_button(tr("Fast game") if fast else tr("Normal game"), "", 18)
		b.toggle_mode = true
		b.button_group = pace_group
		b.button_pressed = Game.fast_game == fast
		b.custom_minimum_size.x = 200
		b.pressed.connect(func():
			Game.set_fast_game(fast)
			pace_text.call())
		pace.add_child(b)
	pace_text.call()
	v.add_child(pace_note)
	v.add_child(HSeparator.new())
	var sv_row := UI.hbox(14)
	v.add_child(sv_row)
	var sv_label := UI.label(tr("Saved games"), 24)
	sv_label.size_flags_horizontal = SIZE_EXPAND_FILL
	sv_row.add_child(sv_label)
	var n_saves := Game.list_saves().size()
	sv_row.add_child(UI.label(tr_n("%d save", "%d saves", n_saves) % n_saves, 17, Color(UI.INK, 0.7)))
	var open_saves_b := UI.text_button(tr("Save or load"), "journal", 18)
	open_saves_b.pressed.connect(open_saves)
	sv_row.add_child(open_saves_b)
	v.add_child(HSeparator.new())
	var tp := UI.hbox(12)
	v.add_child(tp)
	if Game.test_mode:
		var back := UI.text_button(tr("Back to my game"), "", 18)
		back.pressed.connect(func():
			Game.end_test_play()
			close_top()
			main.reload())
		tp.add_child(back)
	else:
		var test := UI.text_button(tr("Test play"), "star", 18)
		test.pressed.connect(func():
			Game.start_test_play()
			close_top()
			main.reload())
		tp.add_child(test)
	tp.add_child(UI.wrap_label(tr("A sandbox with everything unlocked and 10000 coins. Your real game stays safe."), 15, 360))
	_save_confirm = ""
	_open_modal(tr("Settings"), v, Vector2(640, 0))


## Named saves: save the current game under a name, load or delete saves, start over.
## Destructive buttons ask for a second tap. The list scrolls, so any number of saves fits.
func open_saves() -> void:
	_save_confirm = ""
	var v := UI.vbox(10)
	var sh := UI.hbox(10)
	v.add_child(sh)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = tr("Name of the save")
	name_edit.text = tr("Bubák, day %d") % (int((Time.get_unix_time_from_system() - Game.created_at) / 86400.0) + 1)
	name_edit.max_length = 40
	name_edit.custom_minimum_size = Vector2(340, 52)
	name_edit.add_theme_font_size_override("font_size", 20)
	name_edit.select_all_on_focus = true
	sh.add_child(name_edit)
	var save_b := UI.text_button(tr("Save"), "", 20)
	sh.add_child(save_b)
	save_b.pressed.connect(func():
		var nm := name_edit.text.strip_edges()
		if nm == "":
			toast(tr("Give the save a name first."))
			return
		if Game.save_exists(nm) and _save_confirm != "over:" + nm:
			_save_confirm = "over:" + nm
			save_b.text = tr("Overwrite?")
			return
		if Game.save_named(nm):
			toast(tr("Saved as \"%s\".") % nm, "journal")
			open_saves.call_deferred())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 400)
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	v.add_child(scroll)
	saves_scroll = scroll
	var list := UI.vbox(6)
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(list)
	var saves := Game.list_saves()
	if saves.is_empty():
		list.add_child(UI.label(tr("No saved games yet."), 18, Color(UI.INK, 0.7)))
	for sv in saves:
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UI.box(Color("#fffdf8"), 14, 2, false))
		row.mouse_filter = MOUSE_FILTER_PASS   # a finger dragging on the row scrolls the list
		var rh := UI.hbox(8)
		row.add_child(rh)
		var info := UI.vbox(0)
		info.size_flags_horizontal = SIZE_EXPAND_FILL
		info.add_child(UI.label(sv.name, 19))
		var when := Time.get_datetime_string_from_unix_time(int(sv.saved_at) + Time.get_time_zone_from_system().bias * 60, true)
		info.add_child(UI.label(tr("Day %d  ·  %s  ·  %d coins  ·  %s") % [sv.days, Catalog.level_name(sv.trust), sv.coins,
			when.left(16)], 14, Color(UI.INK, 0.7)))
		rh.add_child(info)
		var load_b := UI.text_button(tr("Load"), "", 18)
		load_b.size_flags_vertical = SIZE_SHRINK_CENTER
		load_b.pressed.connect(func():
			if _save_confirm != "load:" + sv.file:
				_save_confirm = "load:" + sv.file
				load_b.text = tr("Sure?")
				toast(tr("Loading replaces the game you're playing now. Save it first if you want to keep it."))
				return
			if Game.load_named(sv.file):
				close_top()
				main.reload())
		rh.add_child(load_b)
		var del_b := UI.text_button(tr("Delete"), "", 18)
		del_b.size_flags_vertical = SIZE_SHRINK_CENTER
		del_b.pressed.connect(func():
			if _save_confirm != "del:" + sv.file:
				_save_confirm = "del:" + sv.file
				del_b.text = tr("Sure?")
				return
			Game.delete_named(sv.file)
			open_saves.call_deferred())
		rh.add_child(del_b)
		list.add_child(row)
	var new_b := UI.text_button(tr("Start a new game"), "", 18)
	new_b.size_flags_horizontal = SIZE_SHRINK_BEGIN
	new_b.pressed.connect(func():
		if _save_confirm != "new":
			_save_confirm = "new"
			new_b.text = tr("Sure? Unsaved progress is lost")
			return
		Game.new_game()
		close_top()
		main.reload())
	var bottom := UI.hbox(10)
	v.add_child(bottom)
	var back := UI.text_button(tr("Back to settings"), "", 18)
	back.pressed.connect(open_settings)
	bottom.add_child(back)
	var gap := Control.new()
	gap.size_flags_horizontal = SIZE_EXPAND_FILL
	bottom.add_child(gap)
	bottom.add_child(new_b)
	_open_modal(tr("Saved games"), v, Vector2(700, 0))


# ---- show club -------------------------------------------------------------------

## The tabs grow as the club opens up: training, then grooming, then shows.
func _club_tabs() -> Array:
	return ["Training", "Grooming", "Shows", "Trophies"].slice(0, [0, 1, 2, 4][Game.club_stage])


func open_club(tab := "") -> void:
	if tab != "":
		_club_tab = tab
	var tabs_list := _club_tabs()
	if tabs_list.is_empty():
		return
	if not _club_tab in tabs_list:
		_club_tab = tabs_list[0]
	var v := UI.vbox(10)
	var tabs := UI.hbox(8)
	v.add_child(tabs)
	var holder := UI.vbox(10)
	holder.size_flags_vertical = SIZE_EXPAND_FILL
	v.add_child(holder)
	var group := ButtonGroup.new()
	for t in tabs_list:
		var b := UI.text_button(tr(t))
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = t == _club_tab
		b.custom_minimum_size.x = 140
		b.pressed.connect(func():
			_club_tab = t
			_fill_club(holder))
		tabs.add_child(b)
	_fill_club(holder)
	_open_modal(tr("Show club"), v, Vector2(900, 600))


func _fill_club(holder: VBoxContainer) -> void:
	for c in holder.get_children():
		c.queue_free()
	match _club_tab:
		"Training":
			var t := Training.new()
			t.hud = self
			holder.add_child(t)
			club_panel = t
		"Grooming":
			var g := Grooming.new()
			g.hud = self
			holder.add_child(g)
			club_panel = g
		"Shows":
			var scroll := ScrollContainer.new()
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			scroll.custom_minimum_size = Vector2(0, 450)
			holder.add_child(scroll)
			var list := UI.vbox(10)
			list.size_flags_horizontal = SIZE_EXPAND_FILL
			scroll.add_child(list)
			for tier in Catalog.SHOW_TIERS.size():
				list.add_child(_show_card(tier))
		"Trophies":
			if Game.trophies.is_empty():
				holder.add_child(UI.wrap_label(tr("No ribbons yet. Enter a show and bring one home!"), 20, 700))
				return
			var scroll := ScrollContainer.new()
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			scroll.custom_minimum_size = Vector2(0, 450)
			holder.add_child(scroll)
			var grid := GridContainer.new()
			grid.columns = 5
			scroll.add_child(grid)
			var list: Array = Game.trophies.duplicate()
			list.reverse()
			for t in list:
				var cv := UI.vbox(2)
				cv.custom_minimum_size.x = 160
				var r := UI.icon_rect(Catalog.trophy_tex(t), 84)
				r.size_flags_horizontal = SIZE_SHRINK_CENTER
				cv.add_child(r)
				for line in [Catalog.tier_name(t.tier), "%s, %s" % [tr(ShowRing.PLACES[t.place - 1]), Catalog.cat_name(t.cat)]]:
					var l := UI.wrap_label(line, 14, 150)
					l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					cv.add_child(l)
				grid.add_child(cv)


func _show_card(tier: int) -> Control:
	var info: Dictionary = Catalog.SHOW_TIERS[tier]
	var card := PanelContainer.new()
	var open := Game.show_unlocked(tier)
	card.add_theme_stylebox_override("panel", UI.box(Color("#fffdf8") if open else Color("#f1e8dc"), 16, 2, false))
	var v := UI.vbox(6)
	card.add_child(v)
	var h := UI.hbox(12)
	v.add_child(h)
	h.add_child(UI.icon_rect("trophy" if tier == 2 else "rosette_1", 52))
	var tv := UI.vbox(0)
	tv.size_flags_horizontal = SIZE_EXPAND_FILL
	h.add_child(tv)
	tv.add_child(UI.label(Catalog.tier_name(tier), 24))
	var note := tr("Entry %d coins  ·  1st prize %d coins, %d followers") % [info.fee, info.prize[0], info.fans[0]]
	if not open:
		note = tr("Win the %s %d times to enter.") % [Catalog.tier_name(tier - 1), info.wins] \
			+ "  (%d/%d)" % [Game.wins_at(tier - 1), info.wins]
	elif Game.show_wait(tier) > 0:
		note = tr("Next show in %s") % Game.duration_text(Game.show_wait(tier))
	tv.add_child(UI.label(note, 16, Color(UI.INK, 0.75)))
	if not open:
		return card
	var cats := UI.hbox(10)
	v.add_child(cats)
	for cat in Catalog.SHOW_CATS:
		var cv := UI.vbox(2)
		cv.size_flags_horizontal = SIZE_EXPAND_FILL
		var b := UI.text_button(Catalog.cat_name(cat), Catalog.SHOW_CATS[cat].icon, 19)
		var problem := Game.show_problem(tier, cat)
		b.disabled = problem != ""
		b.pressed.connect(_enter_show.bind(tier, cat))
		cv.add_child(b)
		var hint := problem if problem != "" and Game.show_wait(tier) <= 0 and Game.coins >= info.fee else tr(Catalog.SHOW_CATS[cat].desc)
		cv.add_child(UI.wrap_label(hint, 14, 250))
		cats.add_child(cv)
	return card


func _enter_show(tier: int, cat: String) -> void:
	var photo := Game.best_photo()
	var score := Game.show_score(cat)   # before entering: entering uses up the photo
	var err := Game.enter_show(tier, cat)
	if err != "":
		toast(err)
		return
	var ring := ShowRing.new()
	ring.hud = self
	ring.tier = tier
	ring.cat = cat
	ring.base_score = score
	ring.photo = photo
	ring.finished.connect(func():
		close_top()
		main.update_trophies())
	_open_modal("", ring, Vector2(900, 0))
	club_panel = ring


func _on_club_unlocked(stage: int) -> void:
	var texts := {
		1: [tr("Bunny Show Club!"), "club", tr("A flyer came through the door: the local Bunny Show Club is looking for new members!\n\nYou can now teach Bubák tricks. Tap Club to start training. The Shop has training gear on the new Club tab.")],
		2: [tr("Grooming"), "brush", tr("Bubák learned his first trick! Show bunnies need a glossy coat too.\n\nGet a Soft brush from the Shop (Club tab) and groom him in the Club. Clippers keep his nails neat.")],
		3: [tr("Show time!"), "rosette_1", tr("Bubák knows his tricks and looks smart. He's ready for his first show!\n\nEnter the Neighbourhood show in the Club. Win ribbons, beat the rivals and work your way up to the National championship.")],
	}
	var t: Array = texts[stage]
	_queue(func():
		var v := UI.vbox(12)
		v.add_child(UI.icon_rect(t[1], 110))
		var title := UI.label(t[0], 34)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(title)
		var l := UI.wrap_label(t[2], 21, 520)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		var h := UI.hbox(12)
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		var later := UI.text_button(tr("Later"))
		later.pressed.connect(close_top)
		h.add_child(later)
		var go := UI.text_button(tr("Let's go!"))
		go.pressed.connect(func():
			close_top()
			open_club.call_deferred(["", "Training", "Grooming", "Shows"][stage]))
		h.add_child(go)
		v.add_child(h)
		_open_modal("", v, Vector2(600, 0)))


# ---- the rescue's hutch: adopt a friend for Bubák ----------------------------------

const HUTCH_SCALE := 0.92
const MATE_ORDER := ["luna", "caramel", "hazel", "shadow"]   # left to right in the hutch


func _on_mate_unlocked() -> void:
	_queue(func():
		Sfx.play("fanfare")
		var v := UI.vbox(12)
		v.add_child(UI.icon_rect("icon", 110))
		var title := UI.label(tr("Bubák seems a little lonely..."), 32)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(title)
		var l := UI.wrap_label(tr("Rabbits are happiest in pairs. The bunny rescue down the street has a few rabbits looking for a home.\n\nMaybe it's time to find Bubák a friend?"), 21, 520)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		var h := UI.hbox(12)
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		var later := UI.text_button(tr("Later"))
		later.pressed.connect(close_top)
		h.add_child(later)
		var go := UI.text_button(tr("Visit the rescue"), "heart")
		go.pressed.connect(func():
			close_top()
			open_hutch.call_deferred())
		h.add_child(go)
		v.add_child(h)
		_open_modal("", v, Vector2(600, 0)))


func open_hutch(selected := "luna") -> void:
	var v := UI.vbox(10)
	v.add_child(UI.wrap_label(tr("These rabbits are looking for a home. Tap one to meet them."), 19, 820))
	var hutch := Control.new()
	var hsize := Vector2(880, 360) * HUTCH_SCALE
	hutch.custom_minimum_size = hsize
	hutch.size_flags_horizontal = SIZE_SHRINK_CENTER
	v.add_child(hutch)
	var bg := TextureRect.new()
	bg.texture = Catalog.tex("hutch")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.size = hsize
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	hutch.add_child(bg)
	var frame := Panel.new()   # highlight around the chosen compartment
	var fs := StyleBoxFlat.new()
	fs.draw_center = false
	fs.set_border_width_all(6)
	fs.border_color = UI.GOLD
	fs.set_corner_radius_all(12)
	frame.add_theme_stylebox_override("panel", fs)
	frame.mouse_filter = MOUSE_FILTER_IGNORE
	var info := UI.hbox(18)
	for i in MATE_ORDER.size():
		var id: String = MATE_ORDER[i]
		var cell := Rect2(Vector2(40 + i * 205, 80) * HUTCH_SCALE, Vector2(190, 220) * HUTCH_SCALE)
		var r := TextureRect.new()
		r.texture = Catalog.tex("bunny_sit_" + id)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.size = Vector2(176, 160) * HUTCH_SCALE
		r.position = cell.position + Vector2(cell.size.x / 2 - r.size.x / 2 - 8, cell.size.y - r.size.y - 14)
		r.pivot_offset = Vector2(r.size.x / 2, r.size.y)
		r.mouse_filter = MOUSE_FILTER_IGNORE
		hutch.add_child(r)
		var bob := r.create_tween().set_loops()   # each breathes / fidgets at its own pace
		bob.tween_interval(randf() * 2.0)
		bob.tween_property(r, "scale", Vector2(1.04, 0.96), 0.5).set_trans(Tween.TRANS_SINE)
		bob.tween_property(r, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)
		var pick := Button.new()
		pick.flat = true
		pick.focus_mode = FOCUS_NONE
		pick.position = cell.position
		pick.size = cell.size
		pick.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		pick.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		pick.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		pick.pressed.connect(func():
			frame.position = cell.position - Vector2(5, 5)
			frame.size = cell.size + Vector2(10, 10)
			r.create_tween().tween_property(r, "position:y", r.position.y - 30, 0.15).set_ease(Tween.EASE_OUT)
			r.create_tween().tween_property(r, "position:y", r.position.y, 0.25).set_delay(0.15).set_trans(Tween.TRANS_BOUNCE)
			_fill_mate_info(info, id))
		hutch.add_child(pick)
		if id == selected:
			frame.position = cell.position - Vector2(5, 5)
			frame.size = cell.size + Vector2(10, 10)
	var mesh := TextureRect.new()
	mesh.texture = Catalog.tex("hutch_mesh")
	mesh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mesh.size = hsize
	mesh.mouse_filter = MOUSE_FILTER_IGNORE
	hutch.add_child(mesh)
	hutch.add_child(frame)
	v.add_child(info)
	_fill_mate_info(info, selected)
	_open_modal(tr("Bunny rescue"), v, Vector2(900, 0))


func _fill_mate_info(info: HBoxContainer, id: String) -> void:
	for c in info.get_children():
		c.queue_free()
	var m: Dictionary = Catalog.MATES[id]
	info.add_child(UI.icon_rect("mate_" + id, 96))
	var tv := UI.vbox(4)
	tv.size_flags_horizontal = SIZE_EXPAND_FILL
	info.add_child(tv)
	tv.add_child(UI.label(Catalog.mate_name(id), 28))
	tv.add_child(UI.wrap_label(tr(m.desc), 18, 440))
	var warm: String = tr("Warms up to people quickly.") if m.trust_rate > 1.0 else (tr("Takes a while to trust people.") if m.trust_rate < 1.0 else tr("Gets used to people at an easy pace."))
	tv.add_child(UI.label(warm, 16, Color(UI.INK, 0.7)))
	var bv := UI.vbox(4)
	bv.size_flags_vertical = SIZE_SHRINK_CENTER
	info.add_child(bv)
	var problem := Game.adopt_problem(id)
	var b := UI.text_button(tr("Adopt for %d") % m.price, "coin", 22)
	b.disabled = problem != ""
	b.pressed.connect(func():
		var err := Game.adopt(id)
		if err != "":
			toast(err)
			return
		Game.welcome_text = tr("%s is home!\n\nBubák is curious, and a little unsure. Give them time: when both are happy they grow closer, and best friends snuggle together.\n\nThe newcomer has their own needs and trust, so look after both.") % Catalog.mate_name(id)
		close_top()
		main.reload())
	bv.add_child(b)
	if problem != "":
		bv.add_child(UI.wrap_label(problem, 15, 220))


# ---- work ----------------------------------------------------------------------

func open_work() -> void:
	var wait := Game.work_ready_at - Time.get_unix_time_from_system()
	if wait > 0:
		toast(tr("Coffee break! Back to work in %d s. Go hang out with Bubák.") % int(ceil(wait)))
		return
	var w := WorkGame.new()
	w.finished.connect(close_top)
	_open_modal(tr("Remote work"), w, Vector2(860, 0))


# ---- wardrobe --------------------------------------------------------------------

## Bubák up close in everything he has on; tap an accessory to put it on or take it off.
## One thing per place (head, ears, eyes, neck); ones not owned yet can be bought right here.
func open_wardrobe() -> void:
	var h := UI.hbox(18)
	var left := UI.vbox(8)
	h.add_child(left)
	var mirror := PanelContainer.new()
	var ms := UI.box(Color("#f3e3ef"), 22, 3, false)
	mirror.add_theme_stylebox_override("panel", ms)
	mirror.custom_minimum_size = Vector2(360, 380)
	left.add_child(mirror)
	_wardrobe_stage = StageBunny.new()
	_wardrobe_stage.k = 1.55
	mirror.add_child(_wardrobe_stage)
	var poses := UI.hbox(8)
	poses.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_child(poses)
	for p in [["sit", tr("Sit")], ["stand", tr("Stand up")], ["loaf", tr("Loaf")]]:
		var pb := UI.text_button(p[1], "", 17)
		pb.pressed.connect(func():
			_wardrobe_stage.set_pose(p[0])
			_wardrobe_stage.pop_icon("heart"))
		poses.add_child(pb)
	_wardrobe_side = UI.vbox(6)
	_wardrobe_side.size_flags_horizontal = SIZE_EXPAND_FILL
	h.add_child(_wardrobe_side)
	_open_modal(tr("Wardrobe"), h, Vector2(980, 0))
	_fill_wardrobe()


func _fill_wardrobe() -> void:
	for c in _wardrobe_side.get_children():
		c.queue_free()
	var style := int(Game.style_score())
	var head := UI.hbox(10)
	_wardrobe_side.add_child(head)
	var sl := UI.label(tr("Style: %d/100") % style, 20)
	sl.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(sl)
	head.add_child(UI.label(tr("Photo likes +%d%%") % (10 * Game.wearing.size()), 17, Color(UI.INK, 0.7)))
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 12)
	bar.show_percentage = false
	bar.value = style
	bar.add_theme_stylebox_override("fill", UI.bar_fill(Color("#d8a7d0")))
	_wardrobe_side.add_child(bar)
	for place in ["head", "ear", "eyes", "neck"]:
		_wardrobe_side.add_child(UI.label(tr(Catalog.WEAR_PLACE_NAMES[place]), 18))
		var row := UI.hbox(8)
		_wardrobe_side.add_child(row)
		row.add_child(_wear_tile("", place))
		for id in Catalog.SHOP_TABS.Style:
			if Catalog.ITEMS[id].place == place:
				row.add_child(_wear_tile(id, place))
	_wardrobe_info = UI.wrap_label(tr("Tap something to put it on. He can wear one thing in each place."), 15, 540)
	_wardrobe_info.custom_minimum_size.y = 40
	_wardrobe_side.add_child(_wardrobe_info)
	_wardrobe_stage.dress()


## One accessory in the wardrobe ("" = nothing in that place).
func _wear_tile(id: String, place: String) -> Button:
	var worn: bool = Game.wearing.get(place, "") == id
	var owned := id == "" or id in Game.wardrobe
	var b := Button.new()
	b.custom_minimum_size = Vector2(124, 84)
	b.focus_mode = FOCUS_NONE
	if worn:
		var gold := UI.box(Color("#fff3c9"), 18, 4)
		gold.border_color = Color("#e0ad4a")
		b.add_theme_stylebox_override("normal", gold)
		b.add_theme_stylebox_override("hover", gold)
	var v := UI.vbox(0)
	v.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = MOUSE_FILTER_IGNORE
	b.add_child(v)
	if id == "":
		var none := UI.label(tr("Nothing"), 16, Color(UI.INK, 0.6))
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(none)
	else:
		var ic := UI.icon_rect(Catalog.ITEMS[id].icon, 46)
		ic.size_flags_horizontal = SIZE_SHRINK_CENTER
		if not owned:
			ic.modulate = Color(1, 1, 1, 0.4)
		v.add_child(ic)
		var cap := UI.label(Catalog.item_name(id) if owned else "%d" % Catalog.ITEMS[id].price, 13,
			UI.INK if owned else Color("#b07a2c"))
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.clip_text = true
		cap.custom_minimum_size.x = 112
		v.add_child(cap)
	b.pressed.connect(_on_wear_tile.bind(id, place))
	return b


func _on_wear_tile(id: String, place: String) -> void:
	if id == "":
		if Game.wearing.has(place):
			Game.toggle_wear(Game.wearing[place])
		_fill_wardrobe()
		return
	var item: Dictionary = Catalog.ITEMS[id]
	if id in Game.wardrobe:
		Game.toggle_wear(id)
		_fill_wardrobe()
		_wardrobe_info.text = "%s: %s" % [Catalog.item_name(id), tr(item.desc)]
		if Game.wearing.get(place, "") == id:
			_wardrobe_stage.pop_icon("heart")
		return
	# not owned yet: the first tap tells you about it, the second buys it
	var lock := Game.lock_reason(id)
	if lock != "":
		_wardrobe_info.text = "%s: %s" % [Catalog.item_name(id), lock]
		return
	if _wardrobe_info.get_meta("buy", "") != id:
		_wardrobe_info.set_meta("buy", id)
		_wardrobe_info.text = tr("%s for %d coins: %s Tap again to buy it.") % [Catalog.item_name(id), item.price, tr(item.desc)]
		return
	var err := Game.buy(id)
	if err != "":
		_wardrobe_info.text = err
		return
	_fill_wardrobe()
	_wardrobe_info.text = tr("New: %s! He's wearing it already.") % Catalog.item_name(id)
	_wardrobe_stage.happy()


# ---- toy chest -------------------------------------------------------------------

var _chest_box: VBoxContainer
var _chest_room := "living"   # where taken-out things go


func open_toy_chest() -> void:
	_chest_box = UI.vbox(8)
	_chest_room = main.view if main.view == "balcony" else "living"
	_open_modal(tr("Toy chest"), _chest_box, Vector2(960, 0))
	_fill_chest()


func _fill_chest() -> void:
	for c in _chest_box.get_children():
		c.queue_free()
	var rooms := ["living"]
	if Game.balcony == "open":
		rooms.append("balcony")
	for room in rooms:
		var r := UI.hbox(12)
		_chest_box.add_child(r)
		var nm := UI.label(tr("Living room") if room == "living" else tr("Balcony"), 18)
		nm.custom_minimum_size.x = 150
		r.add_child(nm)
		var used := Game.room_clutter(room)
		var cap := Game.room_space(room)
		var over := Game.clutter_over(room)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 16)
		bar.size_flags_horizontal = SIZE_EXPAND_FILL
		bar.size_flags_vertical = SIZE_SHRINK_CENTER
		bar.show_percentage = false
		bar.max_value = cap
		bar.value = used
		var col := Color("#8fcf7a") if used <= cap * 0.75 else (Color("#f2c14e") if over == 0 else Color("#e8735f"))
		bar.add_theme_stylebox_override("fill", UI.bar_fill(col))
		r.add_child(bar)
		var st := UI.label(tr("Space %d/%d") % [used, cap] + (" · " + tr("Cozy -%d") % (Catalog.CLUTTER_COZY * over) if over > 0 else ""), 17, Color("#c0392b") if over > 0 else Color(UI.INK, 0.75))
		st.custom_minimum_size.x = 250
		r.add_child(st)
	_chest_box.add_child(UI.wrap_label(tr("Too much stuff out makes the flat less cozy. Things in the chest don't take up space, but they don't add to coziness either. Tap something to move it."), 15, 900))
	var cols := UI.hbox(14)
	_chest_box.add_child(cols)
	var out := Game.placed.filter(func(e): return Catalog.ITEMS[e.id].kind in ["toy", "decor"])
	out.sort_custom(func(a, b): return [Game.room_at(Vector2(a.x, a.y)), a.id] < [Game.room_at(Vector2(b.x, b.y)), b.id])
	var left := _chest_column(cols, tr("Out in the flat"), tr("Nothing out. A bit bare in here!"))
	for e in out:
		var room := Game.room_at(Vector2(e.x, e.y))
		left.add_child(_chest_tile(e, tr("Balcony") if room == "balcony" else "", true))
	var stored := Game.stored.duplicate()
	stored.sort_custom(func(a, b): return a.id < b.id)
	var right := _chest_column(cols, tr("In the chest"), tr("The chest is empty."))
	if rooms.size() > 1:
		var pick := UI.hbox(6)
		pick.add_child(UI.label(tr("Take out to:"), 15, Color(UI.INK, 0.75)))
		for room in rooms:
			var rb := UI.text_button(tr("Living room") if room == "living" else tr("Balcony"), "", 15)
			rb.disabled = _chest_room == room
			rb.pressed.connect(func():
				_chest_room = room
				_fill_chest())
			pick.add_child(rb)
		var right_col: Control = right.get_parent().get_parent()
		right_col.add_child(pick)
		right_col.move_child(pick, 1)
	for e in stored:
		right.add_child(_chest_tile(e, "", false))


## A titled, scrolling grid; returns the grid to put tiles in.
func _chest_column(parent: Control, title: String, empty: String) -> GridContainer:
	var col := UI.vbox(6)
	col.size_flags_horizontal = SIZE_EXPAND_FILL
	parent.add_child(col)
	col.add_child(UI.label(title, 19))
	var empty_l := UI.label(empty, 16, Color(UI.INK, 0.6))
	empty_l.visible = false
	col.add_child(empty_l)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 300)
	col.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	(func(): empty_l.visible = grid.get_child_count() == 0).call_deferred()   # once the tiles are in
	return grid


func _chest_tile(e: Dictionary, tag: String, is_out: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(140, 104)
	b.focus_mode = FOCUS_NONE
	b.mouse_filter = MOUSE_FILTER_PASS   # dragging on a tile scrolls
	if not is_out:
		var sb := UI.box(Color("#f3e6d3"), 18, 3)
		b.add_theme_stylebox_override("normal", sb)
	var v := UI.vbox(0)
	v.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = MOUSE_FILTER_IGNORE
	b.add_child(v)
	var ic := UI.icon_rect(Catalog.ITEMS[e.id].icon, 44)
	ic.size_flags_horizontal = SIZE_SHRINK_CENTER
	v.add_child(ic)
	var cap := UI.label(Catalog.item_name(e.id), 14)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.clip_text = true
	cap.custom_minimum_size.x = 128
	v.add_child(cap)
	var info := tr("Put away") if is_out else tr("Take out")
	if tag != "":
		info = "%s · %s" % [tag, info]
	var sub := UI.label(info, 13, Color("#b07a2c"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	b.pressed.connect(func():
		if is_out:
			Game.put_away(e.uid)
		else:
			Game.take_out(e.uid, _chest_room)
		_fill_chest())
	return b
