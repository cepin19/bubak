extends Control
## On-screen UI: status bars, action buttons, toasts and the pop-up screens
## (shop, journal, photos, remote work).

const Bunny := preload("res://scripts/bunny.gd")
const WorkGame := preload("res://scripts/work_game.gd")
const Training := preload("res://scripts/training.gd")
const Grooming := preload("res://scripts/grooming.gd")
const ShowRing := preload("res://scripts/show_ring.gd")
const AgilityRun := preload("res://scripts/agility.gd")


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
var _later: Array = []         # toasts waiting for the open window to close (see toast_when_free)
var _wish_label: Label         # today's wish, under the coins
var _wish_icon: TextureRect
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
var _foster_bar: ProgressBar
var _buttons: HBoxContainer
var _eye: Button              # hides / shows the controls so the floor under them can be reached
var _hideable: Array[Control] = []   # the status cards that the eye button hides
var ui_hidden := false
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
var _wardrobe_pet: Pet = null   # who's being dressed: Bubák (null) or his friend
var _club_pet: Pet = null       # who the club and the walks are with: Bubák (null) or his friend
var _walking := false           # a walk cutscene is playing (its rabbit stays the performer)
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
	Game.trust_day_full.connect(func(): toast_when_free(
		tr("Bubák's trust can't grow any more today. More tomorrow!"), "heart"))
	Game.goal_completed.connect(_on_goal_completed)
	Game.sponsor_paid.connect(_on_sponsor)
	Game.club_unlocked.connect(_on_club_unlocked)
	Game.mate_unlocked.connect(_on_mate_unlocked)
	Game.wish_new.connect(func(t): toast_when_free(t, "wish", true))
	Game.milestone.connect(func(m): _queue(_milestone_popup.bind(m)))
	Game.fame_up.connect(func(l): _queue(_fame_popup.bind(l)))
	Game.wish_granted.connect(func(c, streak, bonus):
		Sfx.play("streak")
		toast(tr("Wish granted! +%d coins. Bubák is delighted.") % c + ("\n" + tr("%d days in a row! A bonus and some rose petals.") % streak
			if bonus else ("  " + tr("Streak: %d") % streak if streak >= 2 else "")), "heart", true))
	Game.mate_trust_up.connect(func(l): toast(tr("%s trusts you more: %s") % [Game.mate.display_name(), Catalog.level_name(l)], "heart", true))
	Game.foster_offer.connect(func(id): _queue(_foster_offer_popup.bind(id)))
	Game.foster_home_found.connect(func(): _queue(_foster_home_popup))
	Game.foster_trust_up.connect(func(l):
		if Game.foster:
			toast(tr("%s trusts you more: %s") % [Game.foster.display_name(), Catalog.level_name(l)], "heart", true))
	Game.bond_missed.connect(func(loss, days): toast_when_free(tr_n("Bubák missed you yesterday. Trust -%.1f: a close bond needs a visit every day.",
		"Bubák missed you for %d days. Trust -%.1f: a close bond needs a visit every day.", days) % ([loss] if days == 1 else [days, loss]), "heart"))
	Game.league_ended.connect(func(r): _queue(_league_popup.bind(r)))
	Game.merch_opened.connect(func(): _queue(_merch_popup))
	Game.daily_task_done.connect(func(id, c): toast(tr("Today's task done: %s. +%d coins") % [Game.daily_text(id), c], "sticker", true))
	Game.sticker_got.connect(func(n, page):
		Sfx.play("streak")
		toast(tr("All of today's tasks done! A sticker for the calendar, +%d coins.") % Catalog.DAILY_ALL
			+ ("\n" + tr("A whole page of %d stickers: +%d coins and two hay cookies!") % [Catalog.STICKER_PAGE, Catalog.STICKER_PAGE_COINS] if page else ""),
			"sticker", true))
	Game.season_found.connect(func(id, season): _queue(_season_popup.bind(id, season)))
	Game.dug_up.connect(_on_dug_up)
	Game.postcard_arrived.connect(func(card): _queue(_postcard_popup.bind(card)))
	Game.trait_up.connect(func(id, lvl, who): toast_when_free(tr("%s's personality is growing: %s, level %d!") % [who, Catalog.trait_name(id), lvl]
		+ ("\n" + tr("Watch out for something new from %s now.") % who if lvl == 3 else ""), Catalog.TRAITS[id].icon, true))
	Game.duel_offered.connect(func(r): toast_when_free(tr("%s demands a rematch! A one-on-one duel: Club > Shows, within %d days.") % [
		Catalog.rival_name(r), Catalog.DUEL_DAYS], "rival_" + r, true))
	Game.rival_arrived.connect(func(r): _queue(_newcomer_popup.bind(r)))
	Game.games_ended.connect(func(res): _queue(_games_popup.bind(res)))
	Game.challenge_ended.connect(func(id, ok):
		Sfx.play("fanfare" if ok else "bad")
		toast_when_free(tr("Challenge done: %s! +%d coins") % [tr(Catalog.CHALLENGES[id].name), Catalog.CHALLENGES[id].reward] if ok
			else tr("Challenge over: %s didn't work out this time.") % tr(Catalog.CHALLENGES[id].name), Catalog.CHALLENGES[id].icon, ok))
	Game.ladder_step_done.connect(func(step, done): toast_when_free(tr("The %s ladder: all the way to the top! A present: %s.") % [
		Catalog.season_name(Game.season()).to_lower(), Catalog.item_name(Catalog.LADDERS[Game.season()].gift).to_lower()] if done
		else tr("The %s ladder: step %d of %d done!") % [Catalog.season_name(Game.season()).to_lower(), step, Catalog.LADDERS[Game.season()].steps.size()],
		"ladder", true))
	Game.certificate.connect(func(id): _queue(_certificate_popup.bind(id)))
	Game.album_page_done.connect(func(i): toast_when_free(tr("A full page in the photo album: %s! +%d coins") % [
		tr(Catalog.ALBUM_PAGES[i].name), Catalog.ALBUM_PAGE_COINS], "album", true))
	_refresh()
	if Game.molting():
		toast_when_free.call_deferred(tr("Bubák is molting! Brush him often and pick up the fur he leaves around."), "brush")


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
	_hideable.append(card)
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
	if Game.foster:
		_build_foster_card(v)

	# one row of need bars per rabbit; with two, each row starts with a little portrait
	var needs := PanelContainer.new()
	_anchor(needs, 0.5, 0, Vector2(0, 12))
	add_child(needs)
	_hideable.append(needs)
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
	_hideable.append(right)
	_coins = _pill(right, "coin")
	_followers = _pill(right, "follower")
	var gear := _icon_button("settings", 50)
	gear.size_flags_vertical = SIZE_SHRINK_CENTER
	gear.pressed.connect(open_settings)
	right.add_child(gear)
	# today's wish: a little thought bubble under the counters
	var wp := PanelContainer.new()
	var ws := UI.box(Color("#fff3c9"), 24, 3, false)
	ws.content_margin_left = 10
	ws.content_margin_right = 14
	ws.content_margin_top = 4
	ws.content_margin_bottom = 4
	wp.add_theme_stylebox_override("panel", ws)
	var wh := UI.hbox(6)
	wp.add_child(wh)
	_wish_icon = UI.icon_rect("wish", 28)
	wh.add_child(_wish_icon)
	_wish_label = UI.label("", 17)
	wh.add_child(_wish_label)
	wp.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and not Game.wish.is_empty():
			toast(Game.wish_text() + "\n" + (tr("Granted! See you tomorrow for the next one.") if Game.wish.get("done", false)
				else tr("Grant it for coins. Every day in a row brings more.")) + "  " + tr("Streak: %d") % Game.wish_streak, "wish"))
	_anchor(wp, 1, 0, Vector2(-14, 76))
	add_child(wp)
	_hideable.append(wp)


## A foster bunny's name and how close they are to being ready for a new home.
func _build_foster_card(v: VBoxContainer) -> void:
	v.add_child(HSeparator.new())
	var h := UI.hbox(8)
	v.add_child(h)
	h.add_child(UI.icon_rect("mate_" + Game.foster.id, 30))
	h.add_child(UI.label(Game.foster.display_name(), 19))
	h.add_child(UI.label(tr("foster bunny"), 15, Color(UI.INK, 0.65)))
	_foster_bar = ProgressBar.new()
	_foster_bar.custom_minimum_size = Vector2(236, 8)
	_foster_bar.show_percentage = false
	_foster_bar.max_value = 1.0
	_foster_bar.step = 0.001
	_foster_bar.add_theme_stylebox_override("fill", UI.bar_fill(Color("#e98fae")))
	v.add_child(_foster_bar)


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
	_eye = UI.big_button("eye_off", tr("Hide"), 72)
	_eye.pressed.connect(func(): set_ui_hidden(not ui_hidden))
	_anchor(_eye, 0, 1, Vector2(14, -14))
	add_child(_eye)


## Hides every control except the eye button, so poop and things behind them can be tapped or dragged.
func set_ui_hidden(on: bool) -> void:
	ui_hidden = on
	_eye.icon = Catalog.icon("eye" if on else "eye_off")
	_eye.text = tr("Show") if on else tr("Hide")
	for c in _hideable:
		c.visible = not on
	on_mode_changed(main.mode)


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
	StageBunny.compose(_selfie_bunny, "loaf", who.pet.skin(), Game.wearing_of(who.pet), true)
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
	var file := Game.photo_dir + "p_%d.png" % int(Time.get_unix_time_from_system() * 1000)
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
		if not _later.is_empty() and _modal == null and _pending.is_empty():
			var t: Array = _later.pop_front()
			toast(t[0], t[1], t[2])


func _refresh() -> void:
	if _modal == null and not _walking and Game.performer != Game.bubak:
		Game.set_performer(Game.bubak)
	_coins.text = str(Game.coins)
	if _last_coins >= 0 and Game.coins != _last_coins:
		Sfx.play("coin" if Game.coins > _last_coins else "buy")
	_last_coins = Game.coins
	_followers.text = str(Game.followers)
	_wish_label.get_parent().get_parent().visible = not Game.wish.is_empty() and not ui_hidden
	_wish_label.text = (tr("Wish: %s") % Game.wish_short()) + ("  x%d" % Game.wish_streak if Game.wish_streak >= 2 else "")
	_wish_icon.texture = Catalog.icon("heart" if Game.wish.get("done", false) else "wish")
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
	if Game.foster and _foster_bar:
		_foster_bar.value = Game.foster.trust / Catalog.level_at(Catalog.FOSTER_GOAL)
	if Game.mate and _mate_trust:
		var ml: int = Game.mate.trust_level()
		_mate_trust.value = Game.mate.trust_progress()
		_bond_bar.value = Game.bond
		for i in _mate_hearts.size():
			_mate_hearts[i].modulate = Color.WHITE if i <= ml else Color(0.55, 0.5, 0.5, 0.35)


func on_mode_changed(m: String) -> void:
	_tray.hide()
	if ui_hidden and m not in ["", "move"]:
		set_ui_hidden(false)   # photo, treat and selfie need their controls
		return
	_buttons.visible = m == "" and not ui_hidden
	_eye.visible = m in ["", "move"]
	_camera_ui.visible = m == "photo"
	if m == "selfie" and not _selfie_ui.visible:
		_start_selfie()
	_selfie_ui.visible = m == "selfie"
	_banner.visible = m in ["move", "treat"] and not ui_hidden
	match m:
		"move":
			_banner_label.text = tr("Drag furniture and toys to rearrange the room.")
			_banner_button.text = tr("Done")
		"treat":
			_banner_label.text = tr("Tap the floor to offer the %s.") % Catalog.item_name(main.treat_selected).to_lower()
			_banner_button.text = tr("Cancel")


# ---- toasts ------------------------------------------------------------------

## A toast that waits until no window is open, so it isn't missed behind one.
func toast_when_free(text: String, icon := "", gold := false) -> void:
	if _modal == null and _pending.is_empty():
		toast(text, icon, gold)
	else:
		_later.append([text, icon, gold])


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
	if lvl == Catalog.TRUST_LEVELS.size() - 1:
		msg += "\n\n" + tr("The deepest bond a bunny can give. Weeks and weeks of care made this happen. He'll never forget it.")
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
		if not _walking:
			Game.set_performer(Game.bubak)   # the club or walk screen is gone: back to Bubák
		if not _pending.is_empty():
			_show_pending.call_deferred()
		return true
	if _tray.visible:
		_tray.hide()
		return true
	if ui_hidden:
		set_ui_hidden(false)
		return true
	if main.mode != "":
		main.set_mode("")
		return true
	return false


## The next queued pop-up, unless another window was opened in the meantime (it then waits for that one).
func _show_pending() -> void:
	if _modal == null and not _pending.is_empty():
		_pending.pop_front().call()


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
			"style":
				var sid: String = id.trim_prefix("style_")
				owned = tr("In use") if Game.room_style == sid else (tr("Owned") if sid in Game.styles else "")
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
		if item.kind == "style" and id.trim_prefix("style_") in Game.styles:
			var ub := UI.text_button(tr("In use") if Game.room_style == id.trim_prefix("style_") else tr("Use"), "", 20)
			ub.disabled = Game.room_style == id.trim_prefix("style_")
			ub.pressed.connect(func():
				Game.set_style(id.trim_prefix("style_"))
				_fill_shop(grid))
			v.add_child(ub)
			grid.add_child(card)
			continue
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
				if item.kind == "style":
					toast(tr("A whole new look: %s!") % tr(item.name), "star", true)
				elif item.kind in ["toy", "decor"]:
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
	var tab_names := ["Goals", "Behaviours", "Album", "Photos", "Memories", "Bubák"]
	if Game.mate:
		tab_names.append("Friend")
	elif _journal_tab == "Friend":
		_journal_tab = "Bubák"
	for tab in tab_names:
		var b := UI.text_button(Game.mate.display_name() if tab == "Friend" else tr(tab), "", 19)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = tab == _journal_tab
		b.custom_minimum_size.x = 96
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
			holder.add_child(_daily_box())
			var cl := UI.hbox(10)
			holder.add_child(cl)
			cl.add_child(_challenge_box())
			cl.add_child(_ladder_box())
			var goals: Array = Catalog.GOALS.filter(func(x): return Game.goal_visible(x))
			var nm := Game.next_milestone()
			holder.add_child(UI.label(tr("Days together: %d") % Game.days_played + ("   " + tr("Next surprise at %d days") % nm.days
				if not nm.is_empty() else ""), 20))
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
					if b.has("season"):
						desc = tr("Needs: %s, out on the balcony") % Catalog.season_name(b.season).to_lower() if b.season != "summer" \
							else tr("Needs: a summer heatwave")
					elif b.has("trait"):
						desc = tr("Needs: %s at level 3 (Journal > Bubák)") % Catalog.trait_name(b.trait)
					elif b.get("needs", "") == "foster":
						desc = tr("Needs: a foster bunny, and Bubák at %s") % Catalog.level_name(Catalog.MENTOR_LEVEL)
					elif b.get("needs", "") == "tricks":
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
		"Album":
			_fill_album(holder)
		"Photos":
			holder.add_child(UI.label(tr("Photo challenges: %d of %d") % [Game.photo_challenges.size(), Catalog.PHOTO_CHALLENGES.size()], 20))
			var cgrid := GridContainer.new()
			cgrid.columns = 4
			holder.add_child(cgrid)
			for c in Catalog.PHOTO_CHALLENGES:
				var done: bool = Game.photo_challenges.has(c.id)
				var cv := UI.vbox(2)
				var cp := PanelContainer.new()
				var cs := UI.box(Color.WHITE if done else Color("#f1e8dc"), 6, 2, false)
				cs.set_content_margin_all(6)
				cp.add_theme_stylebox_override("panel", cs)
				var ctex: Texture2D = _photo_texture(Game.photo_challenges[c.id]) if done else null
				if ctex:
					var cr := TextureRect.new()
					cr.texture = ctex
					cr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					cr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
					cr.custom_minimum_size = Vector2(180, 100)
					cp.add_child(cr)
				else:
					var q := UI.icon_rect("camera", 48)
					q.custom_minimum_size = Vector2(180, 100)
					q.modulate = Color(1, 1, 1, 0.35)
					cp.add_child(q)
				cv.add_child(cp)
				cv.add_child(UI.wrap_label(tr(c.text) + ("" if done else "  (+%d)" % c.reward), 15, 180))
				cgrid.add_child(cv)
			holder.add_child(HSeparator.new())
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
		"Memories":
			holder.add_child(_book_card())
			if Game.memories.is_empty():
				holder.add_child(UI.wrap_label(tr("No memories yet. Firsts go here: the first binky, the first walk, presents..."), 20, 700))
				return
			var mlist: Array = Game.memories.duplicate()
			mlist.reverse()
			for m in mlist:
				var row := PanelContainer.new()
				row.add_theme_stylebox_override("panel", UI.box(Color("#fffdf8"), 16, 2, false))
				var rh := UI.hbox(14)
				row.add_child(rh)
				var mtex: Texture2D = _photo_texture(m.file) if str(m.get("file", "")) != "" else null
				if mtex:
					var mr := TextureRect.new()
					mr.texture = mtex
					mr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					mr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
					mr.custom_minimum_size = Vector2(150, 112)
					rh.add_child(mr)
				else:
					var mi := UI.icon_rect("heart", 60)
					mi.custom_minimum_size = Vector2(150, 112)
					rh.add_child(mi)
				var mv := UI.vbox(4)
				mv.size_flags_vertical = SIZE_SHRINK_CENTER
				rh.add_child(mv)
				mv.add_child(UI.label(date_text(float(m.time)), 15, Color(UI.INK, 0.6)))
				mv.add_child(UI.wrap_label(Game.memory_text(m), 20, 560))
				holder.add_child(row)
		"Bubák":
			var h := UI.hbox(24)
			holder.add_child(h)
			var portrait := UI.icon_rect("icon", 180)
			portrait.size_flags_vertical = SIZE_SHRINK_BEGIN
			h.add_child(portrait)
			var days := int((Time.get_unix_time_from_system() - Game.created_at) / 86400.0) + 1
			var lines := [
				tr("Bubák, a lilac-grey bunny with one perky ear and one floppy one."),
				tr("Personality: cheeky, curious, very food-motivated."),
				"",
				tr("Day %d together") % days + "  " + tr("(played on %d days)") % Game.days_played,
				tr("Birthday: %s") % birthday_text(Game.birthday),
				tr("Trust: %s (%d%%)") % [Catalog.level_name(Game.trust_level()), int(Game.trust)],
				tr("Weight: %s kg, %s (healthy: %s to %s kg)") % [kilos(Game.bubak.weight),
					Catalog.weight_name(Game.bubak.weight_band()).to_lower(),
					kilos(Game.bubak.ideal_weight() * (1.0 + Catalog.WEIGHT_BANDS[1])),
					kilos(Game.bubak.ideal_weight() * (1.0 + Catalog.WEIGHT_BANDS[2]))],
				tr("Followers: %d") % Game.followers + ("  (%s)" % Game.fame_name() if Game.fame >= 0 else ""),
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
				lines.append(tr("Ribbons: %d") % Game.trophies.filter(func(t): return t.get("pet", "bubak") == "bubak").size())
			if not Game.certificates.is_empty():
				lines.append(tr("Master's certificates: %s") % ", ".join(PackedStringArray(Game.certificates.map(func(t): return Catalog.trick_name(t)))))
			if Game.stats.get("duels", 0) > 0:
				lines.append(tr("Duels won: %d of %d") % [Game.stats.get("duels_won", 0), Game.stats.duels])
			if not Game.souvenirs.is_empty():
				lines.append(tr("Souvenirs found: %d of %d") % [Game.souvenirs.size(), Catalog.SOUVENIR_NAMES.size()])
			if Game.favourites.has("toy"):
				lines.append(tr("Favourite toy: %s") % Catalog.item_name(Game.favourites.toy))
			if Game.favourites.has("nap"):
				lines.append(tr("Favourite napping spot: %s") % Catalog.item_name(Game.favourites.nap))
			if Game.favourites.has("walk"):
				lines.append(tr("Favourite walk: %s") % Catalog.walk_name(Game.favourites.walk))
			lines.append(tr("Wishes granted: %d (streak: %d)") % [Game.stats.get("wishes", 0), Game.wish_streak])
			lines.append(tr("Season: %s") % Catalog.season_name(Game.season()) + ("  " + tr("(heatwave!)") if Game.heatwave() else ""))
			if Game.vaccine_overdue():
				lines.append(tr("Vaccination: overdue! No shows, walks or playdates until he's had it."))
			elif Game.vaccine_due():
				lines.append(tr("Vaccination: due now, at the vet."))
			else:
				lines.append(tr("Vaccination: next one in %d days") % ceili((Game.vaccine_due_at() - Time.get_unix_time_from_system()) / 86400.0))
			if Game.nails_long():
				lines.append(tr("His nails are very long: he skids on the floor and does fewer binkies. Time for the clippers!"))
			if Game.coat_matted():
				lines.append(tr("His coat is scruffy and matted: photos get fewer likes. A good brushing will fix it."))
			lines.append("")
			lines.append(tr("Keep his weight just right: playtime, exercise toys and walks burn it off, and only lots of extra treats pile it on."))
			var tv := UI.vbox(10)
			h.add_child(tv)
			tv.add_child(UI.wrap_label("\n".join(PackedStringArray(lines)), 20, 520))
			var vet := UI.text_button(tr("Check-up at the vet") if Game.can_see_vet() else tr("Next check-up in %d days") % ceili(
				((Game.vet_last if Game.vet_last > 0 else Game.created_at) + Catalog.VET_DAYS * 86400.0 - Time.get_unix_time_from_system()) / 86400.0), "vet", 18)
			vet.disabled = not Game.can_see_vet()
			vet.size_flags_horizontal = SIZE_SHRINK_BEGIN
			vet.pressed.connect(open_vet)
			tv.add_child(vet)
			holder.add_child(HSeparator.new())
			holder.add_child(_personality_box(Game.bubak))
			holder.add_child(HSeparator.new())
			holder.add_child(_finds_box())
		"Friend":
			var f: Pet = Game.mate
			var m: Dictionary = Catalog.MATES[f.id]
			var h := UI.hbox(24)
			holder.add_child(h)
			h.add_child(UI.icon_rect("mate_" + f.id, 180))
			var lines := [tr(m.desc), tr("Personality: %s") % tr(m.personality), ""]
			if f.adopted_at > 0:
				var days := int((Time.get_unix_time_from_system() - f.adopted_at) / 86400.0) + 1
				lines.append(tr("Day %d at home with Bubák") % days)
			lines.append(tr("Trust: %s (%d%%)") % [Catalog.level_name(f.trust_level()), int(f.trust)])
			lines.append(tr("Friendship with Bubák: %d%%") % int(Game.bond))
			lines.append(tr("Weight: %s kg, %s (healthy: %s to %s kg)") % [kilos(f.weight),
				Catalog.weight_name(f.weight_band()).to_lower(),
				kilos(f.ideal_weight() * (1.0 + Catalog.WEIGHT_BANDS[1])),
				kilos(f.ideal_weight() * (1.0 + Catalog.WEIGHT_BANDS[2]))])
			lines.append(tr("Warms up to people quickly.") if m.trust_rate > 1.0 else (tr("Takes a while to trust people.") if m.trust_rate < 1.0 else tr("Gets used to people at an easy pace.")))
			if Game.club_stage >= 1:
				lines.append(tr("Trick stars: %d of %d") % [Game.for_pet(f, Game.trick_stars_total), Catalog.TRICKS.size() * 3])
			if Game.club_stage >= 2:
				lines.append(tr("Coat: %d%%") % int(Game.skill(f, "coat")))
			if Game.club_stage >= 3:
				lines.append(tr("Ribbons: %d") % Game.trophies.filter(func(t): return t.get("pet", "bubak") == f.id).size())
			var fcerts: Array = Game.skill(f, "certificates")
			if not fcerts.is_empty():
				lines.append(tr("Master's certificates: %s") % ", ".join(PackedStringArray(fcerts.map(func(t): return Catalog.trick_name(t)))))
			if Game.nails_long(f):
				lines.append(tr("%s's nails are very long: fewer binkies, and skidding on the floor. Time for the clippers!") % f.display_name())
			if Game.coat_matted(f):
				lines.append(tr("%s's coat is scruffy and matted. A good brushing will fix it.") % f.display_name())
			lines.append("")
			lines.append(tr("Pet and play with %s too to build trust. The two bunnies grow closer just by living happily together.") % f.display_name())
			if Game.club_stage >= 1:
				lines.append(tr("In the Club and on walks, the buttons at the top switch between Bubák and %s.") % f.display_name())
			h.add_child(UI.wrap_label("\n".join(PackedStringArray(lines)), 20, 520))
			holder.add_child(HSeparator.new())
			holder.add_child(_personality_box(f))
			if Game.foster_open():
				holder.add_child(HSeparator.new())
				holder.add_child(_foster_panel())
				if not Game.fosters_done.is_empty():
					holder.add_child(HSeparator.new())
					holder.add_child(_hall_box())
				if not Game.postcards.is_empty():
					holder.add_child(HSeparator.new())
					holder.add_child(_postcards_box())


## Journal > Goals: today's three tasks and this month's sticker calendar.
func _daily_box() -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.box(Color("#eef7f1"), 18, 2, false))
	var h := UI.hbox(18)
	card.add_child(h)
	var v := UI.vbox(6)
	v.size_flags_horizontal = SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UI.label(tr("Today's tasks"), 22))
	for task in Game.daily_tasks():
		var p := Game.daily_progress(task)
		var done: bool = task.id in Game.daily.get("done", [])
		var row := UI.hbox(8)
		row.add_child(UI.icon_rect("sticker" if done else "goal", 26))
		var tl := UI.label(Game.daily_text(task.id), 18, Color(UI.INK, 0.55) if done else UI.INK)
		tl.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(tl)
		row.add_child(UI.label("%d/%d" % [p.x, p.y], 16, Color(UI.INK, 0.7)))
		v.add_child(row)
	v.add_child(UI.wrap_label(tr("+%d coins each. All three: a sticker and +%d. Every %d stickers fill a page: +%d.") % [
		Catalog.DAILY_COINS, Catalog.DAILY_ALL, Catalog.STICKER_PAGE, Catalog.STICKER_PAGE_COINS], 15, 430))
	# the calendar
	var cv := UI.vbox(4)
	h.add_child(cv)
	var now := Time.get_date_dict_from_system()
	cv.add_child(UI.label(tr("Stickers: %d") % Game.stickers.size(), 17))
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	cv.add_child(grid)
	var first := Time.get_unix_time_from_datetime_dict({"year": now.year, "month": now.month, "day": 1, "hour": 12})
	var lead: int = (Time.get_date_dict_from_unix_time(first).weekday + 6) % 7   # Monday first
	for i in lead:
		grid.add_child(Control.new())
	var days := Game._days_in_month("%04d-%02d" % [now.year, now.month])
	for d in range(1, days + 1):
		var key := "%04d-%02d-%02d" % [now.year, now.month, d]
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(34, 30)
		cell.add_theme_stylebox_override("panel", UI.box(Color("#fff3c9") if d == now.day else Color("#fffdf8"), 6, 1 if d != now.day else 2, false))
		if key in Game.stickers:
			var st := UI.icon_rect("sticker", 26)
			st.size_flags_horizontal = SIZE_SHRINK_CENTER
			cell.add_child(st)
		else:
			var dl := UI.label(str(d), 13, Color(UI.INK, 0.45))
			dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_child(dl)
		grid.add_child(cell)
	return card


## Journal > Album: a page per kind of moment, a slot for each, filled by your best photo of it.
func _fill_album(holder: VBoxContainer) -> void:
	holder.add_child(UI.label(tr("Photo album: %d of %d moments") % [Game.album_count(), Game.album_size()], 20))
	holder.add_child(UI.wrap_label(tr("Your best photo of each moment goes in its slot. A full page: +%d coins. The whole album: +%d.") % [
		Catalog.ALBUM_PAGE_COINS, Catalog.ALBUM_ALL_COINS], 16, 780))
	for i in Catalog.ALBUM_PAGES.size():
		var page: Dictionary = Catalog.ALBUM_PAGES[i]
		var have: int = page.slots.filter(func(sl): return Game.album.has(sl)).size()
		var head := UI.hbox(8)
		head.add_child(UI.label(tr(page.name), 22))
		head.add_child(UI.label("%d/%d" % [have, page.slots.size()], 17, Color(UI.INK, 0.6)))
		if i in Game.album_pages:
			head.add_child(UI.icon_rect("star", 26))
		holder.add_child(head)
		var grid := GridContainer.new()
		grid.columns = 5
		holder.add_child(grid)
		for slot in page.slots:
			var cv := UI.vbox(2)
			var cp := PanelContainer.new()
			var cs := UI.box(Color.WHITE if Game.album.has(slot) else Color("#f1e8dc"), 6, 2, false)
			cs.set_content_margin_all(4)
			cp.add_theme_stylebox_override("panel", cs)
			var file := Game.album_photo(slot)
			var tex: Texture2D = _photo_texture(file) if file != "" else null
			if tex:
				var r := TextureRect.new()
				r.texture = tex
				r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
				r.custom_minimum_size = Vector2(140, 96)
				cp.add_child(r)
			else:
				var q := UI.icon_rect("mate_" + slot if Catalog.FOSTERS.has(slot) else "camera", 44)
				q.custom_minimum_size = Vector2(140, 96)
				q.modulate = Color(0.3, 0.25, 0.25, 0.3)
				cp.add_child(q)
			cv.add_child(cp)
			var known: bool = Game.seen.has(slot) or Game.album.has(slot) or (Catalog.FOSTERS.has(slot) and Game.fosters_done.any(func(f): return f.id == slot)) \
				or (Game.foster != null and Game.foster.id == slot)
			var cap: String = (Catalog.mate_name(slot) if Catalog.FOSTERS.has(slot) else Catalog.behaviour_name(slot)) if known else "???"
			cv.add_child(UI.wrap_label(cap, 14, 140))
			grid.add_child(cv)


## Journal > Bubák (or the friend's page): who they're becoming.
func _personality_box(p: Pet) -> Control:
	var v := UI.vbox(6)
	v.add_child(UI.label(tr("Personality"), 22))
	v.add_child(UI.wrap_label(tr("A bunny becomes what you do together. Only the two strongest traits can grow all the way."), 16, 780))
	var raw: Dictionary = Game.skill(p, "traits")
	for id in Catalog.TRAIT_ORDER:
		var info: Dictionary = Catalog.TRAITS[id]
		var lvl := Game.trait_level(id, p)
		var row := UI.hbox(10)
		row.add_child(UI.icon_rect(info.icon, 40))
		var tv := UI.vbox(2)
		tv.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(tv)
		var top := UI.hbox(8)
		top.add_child(UI.label(tr(info.name), 19))
		for i in 3:
			var st := UI.icon_rect("star", 20)
			if i >= lvl:
				st.modulate = Color(0.3, 0.25, 0.25, 0.25)
			top.add_child(st)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(180, 10)
		bar.size_flags_vertical = SIZE_SHRINK_CENTER
		bar.show_percentage = false
		var pts := Game.trait_points(id, p)
		var nxt: float = Catalog.TRAIT_AT[mini(lvl, 2)]
		bar.max_value = nxt
		bar.value = minf(pts, nxt)
		top.add_child(bar)
		if lvl == 1 and Game._trait_raw(id, raw) > 1:
			top.add_child(UI.label(tr("(held back by stronger traits)"), 14, Color(UI.INK, 0.6)))
		tv.add_child(top)
		tv.add_child(UI.wrap_label(tr(info.desc), 15, 700))
		v.add_child(row)
	return v


## Journal > Bubák: what he's dug up, and the treasure map.
func _finds_box() -> Control:
	var v := UI.vbox(6)
	v.add_child(UI.label(tr("Dug up in the dig box"), 22))
	if Game.finds.is_empty() and Game.map_pieces == 0:
		v.add_child(UI.wrap_label(tr("Nothing yet. Bubák digs in the dig box (Shop > Toys), and sometimes he turns something up..."), 16, 780))
		return v
	var h := UI.hbox(14)
	v.add_child(h)
	for id in Catalog.FINDS:
		var cv := UI.vbox(2)
		var ic := UI.icon_rect("find_" + id, 44)
		if not Game.finds.has(id):
			ic.modulate = Color(0.3, 0.25, 0.25, 0.25)
		cv.add_child(ic)
		cv.add_child(UI.label(("x%d" % Game.finds[id]) if Game.finds.has(id) else "?", 14))
		h.add_child(cv)
	if not Game.treasure.is_empty():
		var b := UI.text_button(tr("Look at the treasure map"), "treasure_map", 18)
		b.size_flags_horizontal = SIZE_SHRINK_BEGIN
		b.pressed.connect(func():
			close_top()
			treasure_map_popup())
		v.add_child(b)
	else:
		v.add_child(UI.label(tr("Treasure map: %d of %d pieces") % [Game.map_pieces, Catalog.MAP_PIECES], 17))
	return v


## Journal > friend: the fosters who went home, with a gold or silver frame for the ones who stayed till they trusted you deeply.
func _hall_box() -> Control:
	var v := UI.vbox(6)
	v.add_child(UI.label(tr("Hall of Fame"), 22))
	v.add_child(UI.wrap_label(tr("Let a foster bunny stay longer before they go home: at %s they get a silver frame, at %s a gold one, and the rescue thanks you more.") % [
		Catalog.level_name(Catalog.HALL_SILVER), Catalog.level_name(Catalog.HALL_GOLD)], 16, 780))
	var grid := GridContainer.new()
	grid.columns = 6
	v.add_child(grid)
	for f in Game.hall_of_fame():
		var cv := UI.vbox(2)
		var frame := PanelContainer.new()
		var col := Color("#f3c94f") if f.level >= Catalog.HALL_GOLD else (Color("#c9ced8") if f.level >= Catalog.HALL_SILVER else Color("#e6d6c2"))
		var fs := UI.box(Color("#fffdf8"), 10, 6 if f.level >= Catalog.HALL_SILVER else 2, false)
		fs.border_color = col
		frame.add_theme_stylebox_override("panel", fs)
		frame.add_child(UI.icon_rect("mate_" + f.id, 84))
		cv.add_child(frame)
		cv.add_child(UI.label(Catalog.mate_name(f.id), 16))
		cv.add_child(UI.label(Catalog.level_name(f.level), 13, Color(UI.INK, 0.65)))
		grid.add_child(cv)
	return v


## Journal > friend: postcards from the adoptive families, pinned to the fridge.
func _postcards_box() -> Control:
	var v := UI.vbox(6)
	v.add_child(UI.label(tr("On the fridge"), 22))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)
	var list: Array = Game.postcards.duplicate()
	list.reverse()
	for c in list:
		var cv := UI.vbox(2)
		var b := Button.new()
		b.flat = true
		b.custom_minimum_size = Vector2(200, 130)
		var pc := _postcard_pic(c, Vector2(200, 130))
		pc.mouse_filter = MOUSE_FILTER_IGNORE
		b.add_child(pc)
		b.pressed.connect(func(): _postcard_popup(c))
		cv.add_child(b)
		cv.add_child(UI.label(Catalog.mate_name(c.id), 15))
		grid.add_child(cv)
	return v


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
	for id in res.get("challenges", []):
		var c: Dictionary = Game._challenge(id)
		notes.append(tr("Photo challenge done: %s! +%d coins") % [tr(c.text), c.reward])
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
## "03-14" -> "14 March" (Czech: "14. března").
static func birthday_text(md: String) -> String:
	var months := ["January", "February", "March", "April", "May", "June", "July", "August", "September",
		"October", "November", "December"]
	var m := clampi(int(md.get_slice("-", 0)), 1, 12)
	return TranslationServer.translate("%d %s") % [int(md.get_slice("-", 1)), TranslationServer.translate(months[m - 1])]


## Days together: a milestone reached.
func _milestone_popup(m: Dictionary) -> void:
	Sfx.play("fanfare")
	var v := UI.vbox(12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(UI.icon_rect(Catalog.ITEMS[m.gift].icon if m.has("gift") else "heart", 110))
	var title := UI.label(tr("%d days together!") % m.days, 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var lines := [tr("Thank you for looking after Bubák all this time."), tr("+%d coins") % m.coins]
	if m.has("gift"):
		lines.append(tr("A present you can't buy anywhere: %s!") % tr(Catalog.ITEMS[m.gift].name))
	if m.has("unlocks"):
		lines.append(tr("New in the shop (Makeover): %s") % tr(Catalog.ITEMS[m.unlocks].name))
	var nm := Game.next_milestone()
	if not nm.is_empty():
		lines.append(tr("Next surprise at %d days.") % nm.days)
	var l := UI.wrap_label("\n".join(PackedStringArray(lines)), 20, 560)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var ok := UI.text_button(tr("Aww!"))
	ok.size_flags_horizontal = SIZE_SHRINK_CENTER
	ok.pressed.connect(close_top)
	v.add_child(ok)
	_open_modal("", v, Vector2(640, 0))


## Followers made Bubák more famous; at Bunnyfluencer, a magazine cover.
func _fame_popup(level: int) -> void:
	Sfx.play("fanfare")
	var v := UI.vbox(12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := UI.label(tr("Bubák is a %s!") % Game.fame_name(level), 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var tex: Texture2D = _photo_texture(Game.cover) if level == Catalog.COVER_FAME and Game.cover != "" else null
	if tex:   # the magazine cover
		var mag := PanelContainer.new()
		var ms := UI.box(Color("#e8505b"), 6, 3, true)
		ms.set_content_margin_all(10)
		mag.add_theme_stylebox_override("panel", ms)
		mag.size_flags_horizontal = SIZE_SHRINK_CENTER
		var mv := UI.vbox(4)
		mag.add_child(mv)
		var head := UI.label("BUNNY WEEKLY", 30, Color.WHITE)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mv.add_child(head)
		var r := TextureRect.new()
		r.texture = tex
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		r.custom_minimum_size = Vector2(300, 225)
		mv.add_child(r)
		var cap := UI.wrap_label(tr("Bubák: the bunny everyone's talking about"), 17, 300)
		cap.add_theme_color_override("font_color", Color.WHITE)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mv.add_child(cap)
		v.add_child(mag)
	var l := UI.wrap_label(tr("%d followers! Sponsors pay more now (+%d%%).") % [Catalog.FAME[level].at, 15 * (level + 1)]
		+ ("\n" + tr("Your best photo made the cover of a magazine!") if tex else ""), 20, 560)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var ok := UI.text_button(tr("Wow!"))
	ok.size_flags_horizontal = SIZE_SHRINK_CENTER
	ok.pressed.connect(close_top)
	v.add_child(ok)
	_open_modal("", v, Vector2(640, 0))


## A moment as "14 March 2027" (Czech: "14. března 2027").
static func date_text(unix: float) -> String:
	var d := Time.get_date_dict_from_unix_time(int(unix) + Time.get_time_zone_from_system().bias * 60)
	return birthday_text("%02d-%02d" % [d.month, d.day]) + " %d" % d.year


# ---- the veggie patch -------------------------------------------------------------

func open_garden() -> void:
	var v := UI.vbox(12)
	_fill_garden(v)
	_open_modal(tr("Veggie patch"), v, Vector2(860, 0))


func _fill_garden(v: VBoxContainer) -> void:
	for c in v.get_children():
		c.queue_free()
	var watered := Game.is_watered("garden")
	var top := UI.hbox(12)
	v.add_child(top)
	var info := UI.wrap_label(tr("Watered: growing three times faster.") if watered
		else tr("Plant something, water it, and pick it when it's ripe."), 18, 520)
	info.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(info)
	var wb := UI.text_button(tr("Water"), "water", 18)
	wb.disabled = watered
	wb.pressed.connect(func():
		Game.water_plant("garden")
		Sfx.play("water")
		_fill_garden(v))
	top.add_child(wb)
	var seeds: int = Game.inventory.get("golden_seed", 0)
	if seeds > 0:
		v.add_child(UI.label(tr("Golden seeds: %d. Plant one and wait a whole day for a golden carrot!") % seeds, 17))
	var beds := Game.garden_beds()
	var wide := beds.size() <= 3   # the bigger patch: five narrower beds in a row
	var row := GridContainer.new()
	row.columns = beds.size()
	row.add_theme_constant_override("h_separation", 12 if wide else 8)
	v.add_child(row)
	for i in beds.size():
		var b: Dictionary = beds[i]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UI.box(Color("#f3e3cc"), 16, 2, false))
		card.custom_minimum_size = Vector2(250, 230) if wide else Vector2(154, 300)
		row.add_child(card)
		var cv := UI.vbox(8)
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(cv)
		if b.crop == "":
			cv.add_child(UI.label(tr("Empty bed"), 18))
			for crop in Catalog.CROPS:
				if Catalog.CROPS[crop].get("seed", false) and seeds <= 0:
					continue
				var pb := UI.text_button(tr(Catalog.CROPS[crop].name), crop, 15 if wide else 13)
				pb.pressed.connect(func():
					Game.plant(i, crop)
					Sfx.play("dig")
					_fill_garden(v))
				cv.add_child(pb)
			continue
		cv.add_child(UI.icon_rect(b.crop, 64))
		cv.add_child(UI.label(tr(Catalog.CROPS[b.crop].name), 18))
		if b.grow >= 1.0:
			var hb := UI.text_button(tr("Pick"), "", 18)
			hb.pressed.connect(func():
				var crop: String = b.crop
				var n := Game.harvest(i)
				Sfx.play("pluck")
				toast(tr("Picked: %d x %s. Into the treat bag!") % [n, Catalog.item_name(crop)], crop)
				if Game.seed_found:
					toast(tr("Something glints in the soil: a golden seed!"), "golden_seed", true)
				_fill_garden(v))
			cv.add_child(hb)
		else:
			var bar := ProgressBar.new()
			bar.custom_minimum_size = Vector2(200 if wide else 130, 12)
			bar.show_percentage = false
			bar.value = b.grow * 100.0
			bar.add_theme_stylebox_override("fill", UI.bar_fill(UI.GREEN))
			cv.add_child(bar)
			var mins := ceili((1.0 - b.grow) * Catalog.CROPS[b.crop].hours * 60.0 / (3.0 if watered else 1.0))
			cv.add_child(UI.wrap_label(tr("Ripe in about %d min") % mins if mins < 90 else tr("Ripe in about %d h") % ceili(mins / 60.0), 15, 220 if wide else 130))


# ---- the vet --------------------------------------------------------------------------

func open_vet() -> void:
	close_top()
	var res := Game.vet_checkup()
	var v := UI.vbox(10)
	var h := UI.hbox(16)
	v.add_child(h)
	h.add_child(UI.icon_rect("vet", 96))
	h.add_child(UI.wrap_label(tr("The vet listens, looks and gently weighs everyone.") + "\n" + (tr("All healthy! Here's a sticker and %d coins.") % res.coins
		if res.all_ok else tr("Mostly fine. A few tips, and %d coins for coming in.") % res.coins), 20, 560))
	for r in res.report:
		v.add_child(UI.label(r.pet, 22))
		for c in r.checks:
			var ch := UI.hbox(8)
			if c[0]:
				ch.add_child(UI.icon_rect("heart", 22))
			else:
				ch.add_child(UI.label("!", 20, UI.RED))
			ch.add_child(UI.wrap_label(c[1], 17, 640))
			v.add_child(ch)
	if res.vaccine:
		var vh := UI.hbox(8)
		vh.add_child(UI.icon_rect("vet", 22))
		vh.add_child(UI.wrap_label(tr("And the yearly vaccination: a tiny pinch, a big treat. (-%d coins) See you next year!") % Catalog.VACCINE_COST, 17, 640))
		v.add_child(vh)
	var ok := UI.text_button(tr("Thank you, doctor!"))
	ok.size_flags_horizontal = SIZE_SHRINK_CENTER
	ok.pressed.connect(close_top)
	v.add_child(ok)
	Sfx.play("chime")
	_open_modal(tr("Check-up at the vet"), v, Vector2(800, 0))


static func kilos(grams: float) -> String:
	return Catalog.kilos(grams)


# ---- walks -------------------------------------------------------------------------

## Where to go with Bubák today: the places open one by one as you go on more walks.
func open_walks() -> void:
	close_top()
	_use_club_pet()
	var v := UI.vbox(10)
	var walks: int = Game.stats.get("walks", 0)
	var who := Game.performer.display_name()
	if Game.mate:
		var top := UI.hbox(8)
		top.add_child(UI.label(tr("Who's going?"), 19))
		top.add_child(_pet_picker(open_walks))
		v.add_child(top)
	v.add_child(UI.wrap_label(tr("%s has been out today already and is still dreaming about it. Next walk tomorrow!") % who
		if Game.walked_today() else tr("Where shall we go today? A walk makes %s happy and brings you closer.") % who, 19, 760))
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
		var sr := UI.hbox(4)
		for sid in Catalog.SOUVENIRS[id]:
			var si := UI.icon_rect("souv_" + sid, 30)
			if not Game.souvenirs.has(sid):
				si.modulate = Color(0.2, 0.15, 0.15, 0.25)   # still to find
			si.tooltip_text = Game.souvenir_name(sid) if Game.souvenirs.has(sid) else "?"
			si.mouse_filter = Control.MOUSE_FILTER_PASS
			sr.add_child(si)
		tv.add_child(sr)
		var go := UI.text_button(tr("Go!"), "", 20)
		go.disabled = Game.walk_problem(id) != ""
		go.size_flags_vertical = SIZE_SHRINK_CENTER
		go.pressed.connect(func():
			var walker := Game.performer
			close_top()
			play_walk(id, true, 1.0, walker))
		h.add_child(go)
		grid.add_child(card)
	v.add_child(UI.label(tr("Souvenirs found: %d of %d") % [Game.souvenirs.size(), Catalog.SOUVENIR_NAMES.size()], 17, Color(UI.INK, 0.7)))
	_open_modal(tr("Walk with %s") % who, v, Vector2(820, 0))


## Off we go: the walk counts straight away, then the cutscene plays. who: Bubák (null) or his friend.
func play_walk(id: String, count := true, speed := 1.0, who: Pet = null) -> void:
	main.set_mode("")
	_walking = true
	Game.set_performer(who)
	var walker := Game.performer.display_name()
	var res := Game.go_walk(id) if count else {}
	var w := WalkScene.new()
	w.place = id
	w.speed = speed
	add_child(w)
	await w.finished
	_walking = false
	Game.set_performer(Game.bubak)
	if res.is_empty():
		return
	var msg := tr("%s: back home again. %s is beaming!") % [Catalog.walk_name(id), walker]
	if res.followers > 0:
		msg += " " + tr_n("+%d follower", "+%d followers", res.followers) % res.followers
	toast(msg, "heart", true)
	if res.has("souvenir"):
		var sname := Game.souvenir_name(res.souvenir)
		if res.dupe:
			toast(tr("%s brought back another %s. Swapped for 10 coins.") % [walker, sname.to_lower()], "souv_" + res.souvenir)
		else:
			toast(tr("A souvenir from the walk: %s! (Walk > souvenirs)") % sname, "souv_" + res.souvenir, true)
		if res.set_done:
			toast(tr("A whole set from the %s! +%d coins") % [Catalog.walk_name(id), Catalog.SET_REWARD], "star", true)
		if res.all_done:
			toast(tr("Every souvenir found! A souvenir cabinet for the flat."), "curio", true)


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
	return ["Training", "Grooming", "Shows", "Agility", "League", "Trophies"].slice(0, [0, 1, 2, 6][Game.club_stage])


func open_club(tab := "") -> void:
	if tab != "":
		_club_tab = tab
	var tabs_list := _club_tabs()
	if tabs_list.is_empty():
		return
	if not _club_tab in tabs_list:
		_club_tab = tabs_list[0]
	close_top()
	_use_club_pet()
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
	if Game.mate:
		var gap := Control.new()
		gap.size_flags_horizontal = SIZE_EXPAND_FILL
		tabs.add_child(gap)
		tabs.add_child(_pet_picker(func(): _fill_club(holder)))
	_fill_club(holder)
	_open_modal(tr("Show club"), v, Vector2(900, 600))


## Bubák or his friend, whichever was picked last time (the friend may have left).
func _use_club_pet() -> void:
	if _club_pet != null and _club_pet != Game.mate:
		_club_pet = null
	Game.set_performer(_club_pet)


## Two portrait buttons to pick who trains, grooms, shows or walks; then calls refill.
func _pet_picker(refill: Callable) -> Control:
	var pick := UI.hbox(6)
	for p in [Game.bubak, Game.mate]:
		var pb := UI.text_button(p.display_name(), "icon" if p.is_bubak() else "mate_" + p.id, 17)
		pb.toggle_mode = true
		pb.button_pressed = p == Game.performer
		pb.pressed.connect(func():
			_club_pet = null if p.is_bubak() else p
			Game.set_performer(p)
			for o in pick.get_children():
				o.button_pressed = o == pb
			refill.call())
		pick.add_child(pb)
	return pick


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
			list.add_child(_judge_banner())
			if not Game.duel.is_empty():
				list.add_child(_duel_card())
			for tier in Catalog.SHOW_TIERS.size():
				list.add_child(_show_card(tier))
		"Agility":
			holder.add_child(_agility_panel())
		"League":
			var scroll := ScrollContainer.new()
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			scroll.custom_minimum_size = Vector2(0, 450)
			holder.add_child(scroll)
			var lp := _league_panel()
			lp.size_flags_horizontal = SIZE_EXPAND_FILL
			lp.add_child(HSeparator.new())
			lp.add_child(_games_panel())
			scroll.add_child(lp)
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
				var winner: String = t.get("pet", "bubak")
				var lines: Array = [Catalog.tier_name(t.tier), "%s, %s" % [tr(ShowRing.PLACES[t.place - 1]), Catalog.cat_name(t.cat)]]
				if Game.mate or winner != "bubak":
					lines.append("Bubák" if winner == "bubak" else Catalog.mate_name(winner))
				for line in lines:
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
	var cats := GridContainer.new()
	cats.columns = 2
	cats.add_theme_constant_override("h_separation", 10)
	cats.add_theme_constant_override("v_separation", 8)
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
		cv.add_child(UI.wrap_label(hint, 14, 380))
		cats.add_child(cv)
	return card


## A duel or a round of the Bunny Games: no entry fee, no waiting.
func _enter_special(mode: String, tier: int, cat: String) -> void:
	var ring := ShowRing.new()
	ring.hud = self
	ring.mode = mode
	ring.tier = tier
	ring.cat = cat
	ring.base_score = Game.show_score(cat)
	ring.photo = Game.best_photo()
	if cat == "photo" and not ring.photo.is_empty():
		ring.photo.judged = true   # each photo goes in front of the judges once
	ring.finished.connect(func():
		close_top()
		main.update_trophies())
	_open_modal("", ring, Vector2(900, 0))
	club_panel = ring


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


## The head judge's wish this week, and the routine Bubák performs in Tricks shows.
func _judge_banner() -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.box(Color("#fff3c9"), 16, 2, false))
	var v := UI.vbox(6)
	card.add_child(v)
	var like: Dictionary = Catalog.JUDGE_LIKES[Game.judge_like()]
	var jh := UI.hbox(8)
	v.add_child(jh)
	jh.add_child(UI.icon_rect("rosette_1", 34))
	jh.add_child(UI.wrap_label(tr("This week the head judge loves %s (%s, +%d points).") % [
		tr(like.text), Catalog.cat_name(like.cat), int(Catalog.JUDGE_BONUS)], 17, 760))
	var rh := UI.hbox(8)
	v.add_child(rh)
	rh.add_child(UI.label(tr("Tricks routine:"), 17))
	var known: Array = Catalog.TRICK_ORDER.filter(func(id): return Game.trick_stars(id) > 0)
	while Game.routine.size() < Catalog.ROUTINE_MAX:
		Game.routine.append("")
	for i in Catalog.ROUTINE_MAX:
		var b := UI.text_button(Catalog.trick_name(Game.routine[i]) if Game.routine[i] in known else "—", "", 16)
		b.custom_minimum_size.x = 120
		b.pressed.connect(func():
			var opts: Array = [""] + known
			Game.routine[i] = opts[(opts.find(Game.routine[i]) + 1) % opts.size()]
			b.text = Catalog.trick_name(Game.routine[i]) if Game.routine[i] != "" else "—"
			Game.save_game())
		rh.add_child(b)
	v.add_child(UI.wrap_label(tr("Tap a slot to pick a trick. Longer routines and perfect tricks in a row score more. Leave it empty and he picks three himself."), 14, 780))
	return card


## Club > Agility: practise the jumping course.
func _agility_panel() -> Control:
	var v := UI.vbox(10)
	var top := UI.hbox(10)
	v.add_child(top)
	var skill := UI.label("", 20)
	top.add_child(skill)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(240, 14)
	bar.size_flags_vertical = SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.add_theme_stylebox_override("fill", UI.bar_fill(Color("#7fcfb8")))
	top.add_child(bar)
	var show_skill := func():
		skill.text = tr("Agility: %d/100") % int(Game.agility)
		bar.value = Game.agility
	show_skill.call()
	var track := PanelContainer.new()
	track.add_theme_stylebox_override("panel", UI.box(Color("#e4efd6"), 22, 3, false))
	track.custom_minimum_size = Vector2(840, 290)
	track.clip_contents = true
	v.add_child(track)
	var run := AgilityRun.new()
	run.bars = Catalog.AGILITY_PRACTICE_BARS
	run.kinds = ["bar", "bar", "oxer", "tunnel", "weave"]
	track.add_child(run)
	club_panel = run
	var say := UI.wrap_label(tr("Bars: jump in the gold zone. Double bars: the zone is shorter. Tunnels: don't jump, he runs through. Weave poles: tap as each pole reaches him. Each run uses a try of focus."), 17, 820)
	v.add_child(say)
	var bh := UI.hbox(14)
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(bh)
	var go := UI.text_button(tr("Start a run"), "agility", 20)
	bh.add_child(go)
	var daily := UI.text_button(tr("Daily course"), "sticker", 20)
	bh.add_child(daily)
	var jump := UI.text_button(tr("Jump!"), "", 24)
	jump.custom_minimum_size = Vector2(200, 60)
	jump.disabled = true
	jump.pressed.connect(run.jump)
	bh.add_child(jump)
	var begin := func(timed: bool):
		if run.running():
			return
		if Game.count_item("hurdles") == 0:
			say.text = tr("He needs Hop hurdles to practise on: they're in the Shop.")
			return
		if Game.focus < 1.0:
			say.text = tr("Bubák has had enough training for now. Let him rest a bit.")
			return
		Game.focus -= 1.0
		go.disabled = true
		daily.disabled = true
		jump.disabled = false
		run.timed = timed
		run.course = Game.daily_course() if timed else []
		run.ghost = Game.daily_ghost() if timed else []
		say.text = tr("Today's course! Beat your best time: faults add %d seconds each.") % int(Catalog.AGILITY_FAULT_TIME) \
			if timed else tr("Go, go, go!")
		run.start()
	go.pressed.connect(begin.bind(false))
	daily.pressed.connect(begin.bind(true))
	run.finished.connect(func(clears: int, faults: int):
		var gain := Game.practice_agility(clears)
		go.disabled = false
		daily.disabled = false
		jump.disabled = true
		show_skill.call()
		var text := tr("%d of %d cleared.") % [clears, clears + faults] + "  " + tr("Agility +%.1f") % gain
		if run.timed:
			var res := Game.finish_daily_course(run.score_time(), run.record)
			text = tr("Time: %.1f s") % run.score_time() + "  " + (tr("A new best for today!") if res.best else tr("Best today: %.1f s") % Game.daily_best()) \
				+ ("  +%d" % res.coins if res.coins > 0 else "") + "\n" + text
		say.text = text)
	return v


## Club > League: this month's standings.
func _league_panel() -> Control:
	Game._check_league()
	var v := UI.vbox(8)
	var season: String = Game.league_season
	var days_left: int = Game._days_in_month(season) - int(Time.get_date_string_from_system().right(2))
	v.add_child(UI.label(tr("Show league, season %s") % (season.right(2) + "/" + season.left(4)), 24))
	v.add_child(UI.wrap_label(tr("Shows earn league points: %d / %d / %d / %d for 1st to 4th, twice that at the Regional show and four times at the National championship. The season ends with the month (%d days left).") % (
		Catalog.LEAGUE_POINTS + [days_left]), 16, 840))
	var nem := Game.nemesis()
	var table := Game.league_table()
	for i in table.size():
		var r: Dictionary = table[i]
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UI.box(Color("#fff3c9") if r.id == "bubak" else Color("#fffdf8"), 12, 2, false))
		var h := UI.hbox(10)
		row.add_child(h)
		h.add_child(UI.label("%d." % (i + 1), 20))
		h.add_child(UI.icon_rect("icon" if r.id == "bubak" else "rival_" + r.id, 36))
		var nl := UI.label("Bubák" if r.id == "bubak" else Catalog.rival_name(r.id), 19)
		nl.size_flags_horizontal = SIZE_EXPAND_FILL
		h.add_child(nl)
		if r.id == nem:
			h.add_child(UI.label(tr("nemesis"), 15, Color("#c0504d")))
		var pl := UI.label(tr("%d points") % r.points, 18)
		pl.custom_minimum_size.x = 110
		h.add_child(pl)
		v.add_child(row)
	var prize: Dictionary = Catalog.LEAGUE_PRIZES[0]
	v.add_child(UI.wrap_label(tr("This month's nemesis is %s: finish above them for +%d coins. The winner gets %d coins and %d followers.") % [
		Catalog.rival_name(nem), Catalog.NEMESIS_BONUS, prize.coins, prize.fans], 16, 840))
	if not Game.league_history.is_empty():
		var past := []
		for hst in Game.league_history.slice(-4):
			past.append("%s: %s (%d)" % [str(hst.season).right(2) + "/" + str(hst.season).left(4), tr(ShowRing.PLACES[mini(int(hst.place), 4) - 1]) if int(hst.place) <= 4 else "%d." % int(hst.place), int(hst.points)])
		v.add_child(UI.label(tr("Past seasons: %s") % ", ".join(PackedStringArray(past)), 15, Color(UI.INK, 0.7)))
	return v


func _league_popup(r: Dictionary) -> void:
	Sfx.play("fanfare")
	var v := UI.vbox(12)
	v.add_child(UI.icon_rect("league", 110))
	var title := UI.label(tr("The league season is over!"), 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var msg := tr("Bubák finished in place %d of 6 with %d points.") % [r.place, r.points]
	if r.place == 1:
		msg = tr("Bubák WON the league with %d points! Champion of the month!") % r.points
	msg += "\n" + tr("+%d coins, +%d followers") % [r.coins, r.fans]
	msg += "\n" + (tr("And he beat his nemesis, %s! (bonus included)") % Catalog.rival_name(r.nemesis) if r.beat
		else tr("His nemesis, %s, finished ahead. Next month!") % Catalog.rival_name(r.nemesis))
	msg += "\n\n" + tr("A new season starts now.")
	var l := UI.wrap_label(msg, 21, 520)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var ok := UI.text_button(tr("Hooray!"))
	ok.size_flags_horizontal = SIZE_SHRINK_CENTER
	ok.pressed.connect(close_top)
	v.add_child(ok)
	_open_modal("", v, Vector2(600, 0))


# ---- foster bunnies ----------------------------------------------------------------------

## Journal > Friend: the bunny you're fostering, or the next one, and the ones who found homes.
func _foster_panel() -> Control:
	var h := UI.hbox(16)
	h.add_child(UI.icon_rect("foster", 72))
	var v := UI.vbox(6)
	v.size_flags_horizontal = SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UI.label(tr("Foster bunnies"), 22))
	if Game.foster:
		var f: Pet = Game.foster
		var q: String = f.quirk()
		v.add_child(UI.wrap_label(tr("%s is staying with you. %s: %s") % [f.display_name(), Catalog.quirk_name(q), tr(Catalog.QUIRKS[q].desc)], 17, 640))
		v.add_child(UI.label(tr("Trust: %s. A family can adopt them at %s.") % [Catalog.level_name(f.trust_level()), Catalog.level_name(Catalog.FOSTER_GOAL)], 17))
		if Game.mentor_active():
			v.add_child(UI.wrap_label(tr("Bubák is helping: %s settles in faster with him around.") % f.display_name(), 16, 640))
		if Game.foster_ready():
			var rb := UI.text_button(tr("Let the family adopt %s now") % f.display_name(), "heart", 18)
			rb.size_flags_horizontal = SIZE_SHRINK_BEGIN
			rb.pressed.connect(_rehome_now)
			v.add_child(rb)
	elif Game.foster_available():
		var id := Game.next_foster()
		var b := UI.text_button(tr("Take in %s") % Catalog.mate_name(id), "heart", 18)
		b.size_flags_horizontal = SIZE_SHRINK_BEGIN
		b.pressed.connect(func(): _take_foster())
		v.add_child(b)
	else:
		v.add_child(UI.label(tr("The rescue will have another bunny for you tomorrow."), 17))
	if not Game.fosters_done.is_empty():
		var names := Game.fosters_done.map(func(x): return Catalog.mate_name(x.id))
		v.add_child(UI.wrap_label(tr("Found loving homes: %s") % ", ".join(PackedStringArray(names)), 16, 640))
	return h


func _take_foster() -> void:
	var err := Game.take_foster()
	if err != "":
		toast(err)
		return
	var f: Pet = Game.foster
	Game.welcome_text = tr("%s is here! Go slowly: %s") % [f.display_name(), tr(Catalog.QUIRKS[f.quirk()].desc)] \
		+ "\n\n" + tr("Pet them gently and offer treats. At %s, the rescue will find them a forever family.") % Catalog.level_name(Catalog.FOSTER_GOAL)
	close_top()
	main.reload()


func _foster_offer_popup(id: String) -> void:
	if not Game.foster_available():
		return
	var info: Dictionary = Catalog.FOSTERS[id]
	var v := UI.vbox(12)
	v.add_child(UI.icon_rect("mate_" + id, 110))
	var title := UI.label(tr("The rescue needs a foster home"), 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var l := UI.wrap_label(tr("%s needs somewhere calm to learn that people are kind. %s") % [Catalog.mate_name(id), tr(info.desc)]
		+ "\n" + "%s: %s" % [Catalog.quirk_name(info.quirk), tr(Catalog.QUIRKS[info.quirk].desc)]
		+ "\n\n" + tr("Win their trust up to %s and the rescue will find them a forever family.") % Catalog.level_name(Catalog.FOSTER_GOAL), 20, 540)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var h := UI.hbox(12)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var later := UI.text_button(tr("Not now"))
	later.pressed.connect(close_top)
	h.add_child(later)
	var go := UI.text_button(tr("Take them in"), "heart")
	go.pressed.connect(_take_foster)
	h.add_child(go)
	v.add_child(h)
	_open_modal("", v, Vector2(620, 0))


func _foster_home_popup() -> void:
	if not Game.foster_ready():
		return
	Sfx.play("fanfare")
	var f: Pet = Game.foster
	var v := UI.vbox(12)
	v.add_child(UI.icon_rect("mate_" + f.id, 110))
	var title := UI.label(tr("A family wants to adopt %s!") % f.display_name(), 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var l := UI.wrap_label(tr("Thanks to you, %s isn't scared of people any more. A lovely family has come to take them home.") % f.display_name()
		+ "\n\n" + tr("The rescue sends their thanks: +%d coins, +%d followers.") % [Catalog.FOSTER_REWARD, Catalog.FOSTER_FANS]
		+ "\n" + tr("Or let them stay a while longer: the more they trust you when they go, the bigger the thanks, and at %s they join the Hall of Fame.") % Catalog.level_name(Catalog.HALL_SILVER), 20, 540)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var h := UI.hbox(12)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var later := UI.text_button(tr("A little longer"))
	later.pressed.connect(func():
		close_top()
		toast(tr("%s stays a bit longer. When you're ready: Journal > %s.") % [f.display_name(), Game.mate.display_name() if Game.mate else ""]))
	h.add_child(later)
	var ok := UI.text_button(tr("Say goodbye"), "heart")
	ok.pressed.connect(_rehome_now)
	h.add_child(ok)
	v.add_child(h)
	_open_modal("", v, Vector2(620, 0))


func _rehome_now() -> void:
	var res := Game.rehome_foster()
	if not res.is_empty():
		Game.welcome_text = tr("%s went home with their new family. Bubák watched from the window.") % Catalog.mate_name(res.id) \
			+ "\n\n" + tr("The rescue sends their thanks: +%d coins, +%d followers.") % [res.coins, res.fans] \
			+ ("\n" + tr("They trusted you so much that they're in the Hall of Fame now!") if res.level >= Catalog.HALL_SILVER else "") \
			+ "\n\n" + tr("The rescue will have another bunny who needs you tomorrow.")
	close_top()
	main.reload()


# ---- the top of the game: duels, the Bunny Games, challenges, ladders, the book --------------

func _newcomer_popup(id: String) -> void:
	Sfx.play("surprise")
	_note_popup("rival_" + id, tr("A new rival: %s!") % Catalog.rival_name(id), tr(Catalog.RIVALS[id].desc) + "\n\n"
		+ tr("Now that Bubák is a national champion, the best bunnies in the world want to beat him. And the old rivals are training harder too."),
		tr("Bring it on!"))


func _certificate_popup(id: String) -> void:
	Sfx.play("fanfare")
	var v := _note_popup(Catalog.TRICKS[id].icon, tr("Master's certificate!"), tr("Bubák has mastered %s, one of the hardest tricks there is. +%d coins") % [
		Catalog.trick_name(id), Catalog.CERTIFICATE_COINS], tr("Hooray!"))
	v.get_child(0).custom_minimum_size = Vector2(110, 110)


func _duel_card() -> Control:
	var d: Dictionary = Game.duel
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.box(Color("#fde2e2"), 16, 2, false))
	var h := UI.hbox(12)
	card.add_child(h)
	h.add_child(UI.icon_rect("rival_" + d.rival, 60))
	var v := UI.vbox(2)
	v.size_flags_horizontal = SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UI.label(tr("Duel: %s wants a rematch") % Catalog.rival_name(d.rival), 20))
	v.add_child(UI.wrap_label(tr("One on one, %s. Win: +%d coins, +%d followers. Ends in %s.") % [Catalog.cat_name(d.cat),
		Catalog.DUEL_COINS[int(d.tier)], Catalog.DUEL_FANS[int(d.tier)], Game.duration_text(float(d.until) - Time.get_unix_time_from_system())], 15, 560))
	var problem := Game.cat_problem(d.cat)
	var b := UI.text_button(tr("Accept"), Catalog.SHOW_CATS[d.cat].icon, 19)
	b.size_flags_vertical = SIZE_SHRINK_CENTER
	b.disabled = problem != ""
	b.pressed.connect(_enter_special.bind("duel", int(d.tier), d.cat))
	h.add_child(b)
	if problem != "":
		v.add_child(UI.label(problem, 14, Color("#c0504d")))
	return card


## Club > League: the Bunny Games, once a year.
func _games_panel() -> Control:
	var v := UI.vbox(8)
	var h := UI.hbox(10)
	v.add_child(h)
	h.add_child(UI.icon_rect("games_cup", 56))
	var tv := UI.vbox(2)
	h.add_child(tv)
	tv.add_child(UI.label(tr("The Bunny Games"), 24))
	tv.add_child(UI.wrap_label(tr("Every month, in its last %d days: four rounds (Best in Show, Tricks, Agility, Photogenic), one a day, against every rival at their very best. To qualify, earn %d league points at shows that month.") % [
		Catalog.GAMES_DAYS, Catalog.GAMES_QUALIFY], 15, 760))
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(300, 12)
	bar.show_percentage = false
	bar.max_value = Catalog.GAMES_QUALIFY
	bar.value = mini(Game.league_points, Catalog.GAMES_QUALIFY)
	var qh := UI.hbox(8)
	qh.add_child(UI.label(tr("Qualifying:"), 16))
	qh.add_child(bar)
	qh.add_child(UI.label("%d/%d" % [mini(Game.league_points, Catalog.GAMES_QUALIFY), Catalog.GAMES_QUALIFY], 16))
	if Game.games_qualified():
		qh.add_child(UI.label(tr("qualified!"), 16, Color("#3f8f5a")))
	v.add_child(qh)
	if not Game.games_on():
		v.add_child(UI.label(tr("This month's Games start on the %d.") % Game.games_start_day(), 16))
	else:
		var rh := GridContainer.new()
		rh.columns = 4
		rh.add_theme_constant_override("h_separation", 8)
		v.add_child(rh)
		for cat in Catalog.GAMES_ROUNDS:
			var cv := UI.vbox(2)
			var b := UI.text_button(Catalog.cat_name(cat), Catalog.SHOW_CATS[cat].icon, 16)
			var problem := Game.games_problem(cat)
			if problem == "":
				problem = Game.cat_problem(cat)
			b.disabled = problem != ""
			b.pressed.connect(_enter_special.bind("games", 2, cat))
			cv.add_child(b)
			cv.add_child(UI.wrap_label(problem, 13, 190))
			rh.add_child(cv)
		if not Game.games.get("rounds", {}).is_empty():
			var table := Game.games_table()
			var line := []
			for i in table.size():
				line.append("%d. %s %d" % [i + 1, "Bubák" if table[i].id == "bubak" else Catalog.rival_name(table[i].id), table[i].total])
			v.add_child(UI.wrap_label(tr("Standings: %s") % ", ".join(PackedStringArray(line)), 15, 800))
	if not Game.games_history.is_empty():
		var past := Game.games_history.slice(-3).map(func(g): return "%s: %d." % [Game._month_label(str(g.get("month", ""))), int(g.place)])
		v.add_child(UI.label(tr("Past Games: %s") % ", ".join(PackedStringArray(past)), 15, Color(UI.INK, 0.7)))
	return v


func _games_popup(res: Dictionary) -> void:
	Sfx.play("fanfare" if res.place <= 3 else "chime")
	var text := tr("Bubák finished %s overall with %d points.") % [tr(Game.place_name(res.place)), res.total]
	if res.place <= Catalog.GAMES_PRIZES.size():
		text += "\n" + tr("+%d coins, +%d followers") % [res.coins, res.fans]
	if res.cup:
		text += "\n\n" + tr("And the Bunny Games cup! It's in the flat now.")
	if res.get("apples", 0) > 0:
		text += "\n\n" + tr("The champion's prize: %d bags of special dried apples, made from the best apples in the world! Find them with the treats.") % res.apples
	text += "\n\n" + tr("Next month's Games: qualify again with league points.")
	_note_popup("games_cup", tr("Bunny Games champion!") if res.place == 1 else tr("The Bunny Games are over"), text, tr("Hooray!") if res.place <= 3 else "")


## Journal > Goals: this week's challenge.
func _challenge_box() -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", UI.box(Color("#f3ecfb"), 18, 2, false))
	var v := UI.vbox(6)
	card.add_child(v)
	v.add_child(UI.label(tr("Challenge of the week"), 20))
	if not Game.challenge.is_empty():
		var info: Dictionary = Catalog.CHALLENGES[Game.challenge.id]
		v.add_child(UI.label(tr(info.name), 18))
		v.add_child(UI.wrap_label(tr(info.desc), 14, 380))
		var line := tr("%d days left. Reward: %d coins.") % [Game.challenge_days_left(), info.reward]
		if info.has("days"):
			line += "  " + tr("Days done: %d of %d") % [Game.challenge.days.size(), info.days]
		v.add_child(UI.label(line, 15, Color(UI.INK, 0.75)))
		return card
	var offers := Game.challenge_offers()
	if offers.is_empty():
		var last: Dictionary = Game.challenge_last
		v.add_child(UI.wrap_label((tr("Done: %s. Well played!") % tr(Catalog.CHALLENGES[last.id].name) if last.get("ok", false)
			else tr("This week's challenge is over.")) + " " + tr("New challenges next week."), 15, 380))
		return card
	v.add_child(UI.wrap_label(tr("Up for it? Pick one: it runs for 7 days."), 14, 380))
	for id in offers:
		var info: Dictionary = Catalog.CHALLENGES[id]
		var row := UI.hbox(8)
		row.add_child(UI.icon_rect(info.icon, 30))
		var tv := UI.vbox(0)
		tv.size_flags_horizontal = SIZE_EXPAND_FILL
		tv.add_child(UI.label(tr(info.name) + "  (+%d)" % info.reward, 16))
		tv.add_child(UI.wrap_label(tr(info.desc), 13, 270))
		row.add_child(tv)
		var b := UI.text_button(tr("Take it"), "", 15)
		b.size_flags_vertical = SIZE_SHRINK_CENTER
		b.pressed.connect(func():
			Game.start_challenge(id)
			toast(tr("Challenge accepted: %s. Good luck!") % tr(info.name), info.icon, true)
			_fill_journal(card.get_parent().get_parent()))
		row.add_child(b)
		v.add_child(row)
	return card


## Journal > Goals: this season's ladder.
func _ladder_box() -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", UI.box(Color("#fdf1dc"), 18, 2, false))
	var v := UI.vbox(6)
	card.add_child(v)
	var l := Game.ladder_now()
	var steps: Array = Catalog.LADDERS[Game.season()].steps
	var gift: String = Catalog.LADDERS[Game.season()].gift
	var head := UI.hbox(8)
	head.add_child(UI.icon_rect("ladder", 30))
	head.add_child(UI.label(tr("The %s ladder") % Catalog.season_name(Game.season()).to_lower(), 20))
	v.add_child(head)
	var dots := UI.hbox(4)
	for i in steps.size():
		var d := UI.icon_rect("star", 18)
		if i >= int(l.step):
			d.modulate = Color(0.3, 0.25, 0.25, 0.25)
		dots.add_child(d)
	dots.add_child(UI.icon_rect(Catalog.ITEMS[gift].icon, 30))
	v.add_child(dots)
	if Game.ladder_step().is_empty():
		v.add_child(UI.wrap_label(tr("All the way to the top! A new ladder comes with the next season."), 15, 380))
	else:
		var p := Game.ladder_progress()
		v.add_child(UI.wrap_label(tr("Step %d: %s") % [int(l.step) + 1, Game.ladder_text()] + "  (%d/%d)" % [p.x, p.y], 16, 380))
		v.add_child(UI.wrap_label(tr("Ten steps a season, one after another. At the top: %s.") % Catalog.item_name(gift).to_lower(), 13, 380))
	return card


## Journal > Memories: Bubák's book.
func _book_card() -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.box(Color("#eef3fb"), 18, 2, false))
	var h := UI.hbox(14)
	card.add_child(h)
	h.add_child(UI.icon_rect("bubak_book", 64))
	var v := UI.vbox(4)
	v.size_flags_horizontal = SIZE_EXPAND_FILL
	h.add_child(v)
	var open_n := Catalog.BOOK.filter(Game.book_chapter_open).size()
	v.add_child(UI.label(tr("Bubák's book"), 20))
	v.add_child(UI.wrap_label(tr("Published! It's on sale with the merch.") if Game.book_published else
		tr("Chapters written: %d of %d (%d ready to write). Big moments open new chapters.") % [Game.book_written.size(), Catalog.BOOK.size(), open_n - Game.book_written.size()], 15, 560))
	var b := UI.text_button(tr("Open the book"), "", 17)
	b.size_flags_vertical = SIZE_SHRINK_CENTER
	b.pressed.connect(open_book.bind(0))
	h.add_child(b)
	return card


## The photo for a chapter: from the album where there is one.
const BOOK_PHOTOS := {"meet": "hop", "binky": "binky", "balcony": "balcony", "ribbon": "show_off", "friend": "snuggle",
	"foster": "big_brother", "seasons": "leaf_pile", "self": "pose", "inseparable": "trust_nap"}
const BOOK_ICONS := {"ribbon": "rosette_1", "fame": "follower", "champion": "trophy", "treasure": "treasure_chest", "games": "games_cup",
	"seasons": "wear_scarf", "self": "trait_showoff", "friend": "heart", "foster": "foster"}


## The book, a chapter at a time: write the ones that are open, and publish it once they all are.
func open_book(i: int) -> void:
	var ch: Dictionary = Catalog.BOOK[i]
	var opened := Game.book_chapter_open(ch)
	var written: bool = ch.id in Game.book_written
	var v := UI.vbox(10)
	var spread := UI.hbox(0)
	v.add_child(spread)
	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", UI.box(Color("#fffaf0"), 6, 3, false))
	left.custom_minimum_size = Vector2(380, 330)
	spread.add_child(left)
	var file := Game.album_photo(BOOK_PHOTOS.get(ch.id, ""))
	if ch.id == "fame" and FileAccess.file_exists(Game.cover):
		file = Game.cover
	var tex: Texture2D = _photo_texture(file) if file != "" and written else null
	if tex:
		var r := TextureRect.new()
		r.texture = tex
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		left.add_child(r)
	else:
		var ic := UI.icon_rect(BOOK_ICONS.get(ch.id, "icon"), 160)
		if not written:
			ic.modulate = Color(0.3, 0.25, 0.25, 0.25)
		left.add_child(ic)
	var right := PanelContainer.new()
	var rs := UI.box(Color("#fffdf6"), 6, 3, false)
	rs.set_content_margin_all(22)
	right.add_theme_stylebox_override("panel", rs)
	right.custom_minimum_size = Vector2(380, 330)
	spread.add_child(right)
	var tv := UI.vbox(10)
	right.add_child(tv)
	tv.add_child(UI.label(tr("Chapter %d") % (i + 1), 15, Color(UI.INK, 0.6)))
	tv.add_child(UI.wrap_label(tr(ch.title) if opened else "???", 24, 330))
	if written:
		tv.add_child(UI.wrap_label(tr(ch.text), 18, 330))
	elif opened:
		var w := UI.text_button(tr("Write this chapter"), "journal", 18)
		w.pressed.connect(func():
			Game.write_chapter(ch.id)
			Sfx.play("chime")
			open_book(i))
		tv.add_child(w)
		tv.add_child(UI.label(tr("+50 coins"), 14, Color(UI.INK, 0.6)))
	else:
		tv.add_child(UI.wrap_label(tr("This chapter hasn't happened yet."), 17, 330))
	var nav := UI.hbox(12)
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(nav)
	var prev := UI.text_button("<", "", 22)
	prev.disabled = i == 0
	prev.pressed.connect(open_book.bind(i - 1))
	nav.add_child(prev)
	nav.add_child(UI.label("%d / %d" % [i + 1, Catalog.BOOK.size()], 18))
	var nxt := UI.text_button(">", "", 22)
	nxt.disabled = i >= Catalog.BOOK.size() - 1
	nxt.pressed.connect(open_book.bind(i + 1))
	nav.add_child(nxt)
	if Game.book_ready() and not Game.book_published:
		var pub := UI.text_button(tr("Publish the book (%d coins)") % Catalog.BOOK_COST, "bubak_book", 18)
		pub.pressed.connect(func():
			var err := Game.publish_book()
			if err != "":
				toast(err)
				return
			Sfx.play("fanfare")
			close_top()
			_note_popup("bubak_book", tr("Bubák's book is out!"), tr("A book signing, a queue round the block, and +%d followers. It's on sale with the merch now, and a copy is in the flat.") % Catalog.BOOK_FANS, tr("Hooray!")))
		nav.add_child(pub)
	_open_modal(tr("Bubák's book"), v, Vector2(860, 0))


## December: the advent calendar on the wall, a door a day.
func open_advent() -> void:
	var v := UI.vbox(10)
	var opened := Game.advent_opened()
	var today := int(Game.today().right(2))
	v.add_child(UI.wrap_label(tr("A door a day until Christmas Eve. Behind the last one: something to wear. Open all 24 for an extra surprise."), 17, 780))
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	for d in range(1, 25):
		var b := Button.new()
		b.text = str(d)
		b.custom_minimum_size = Vector2(88, 70)
		b.add_theme_font_size_override("font_size", 24)
		var done: bool = d in opened
		b.disabled = done or d != today
		if done:
			b.icon = Catalog.icon("star")
			b.expand_icon = true
		b.pressed.connect(func():
			var res := Game.open_advent()
			if res.is_empty():
				return
			Sfx.play("jingle")
			var what := tr("+%d coins") % res.coins if res.coins > 0 else ""
			if res.item != "":
				what = "%d x %s" % [res.n, Catalog.item_name(res.item)]
			if res.gift != "":
				what = Catalog.item_name(res.gift)
			toast(tr("Door %d: %s!") % [res.day, what], "gift", true)
			if res.all:
				toast(tr("Every door opened! An extra present: %s.") % Catalog.item_name(Catalog.ADVENT_ALL).to_lower(), "gift", true)
			open_advent())
		grid.add_child(b)
	_open_modal(tr("Advent calendar"), v, Vector2(860, 0))


# ---- seasons, the dig box, visitors, postcards ---------------------------------------------

## A one-button pop-up: an icon, a title and some text.
func _note_popup(icon: String, title_text: String, text: String, button := "", icon_size := 110.0) -> VBoxContainer:
	var v := UI.vbox(12)
	v.add_child(UI.icon_rect(icon, icon_size))
	var title := UI.label(title_text, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var l := UI.wrap_label(text, 20, 540)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var ok := UI.text_button(button if button != "" else tr("Lovely!"), "heart")
	ok.size_flags_horizontal = SIZE_SHRINK_CENTER
	ok.pressed.connect(close_top)
	v.add_child(ok)
	_open_modal("", v, Vector2(620, 0))
	return v


func _season_popup(id: String, season: String) -> void:
	Sfx.play("fanfare")
	if id == "":
		_note_popup("gift", Catalog.season_name(season), tr("Bubák is enjoying the season again. He found another little something: +150 coins and some rose petals."))
		return
	_note_popup(Catalog.ITEMS[id].icon, tr("Found in %s!") % Catalog.season_name(season).to_lower(),
		tr("Bubák found a %s. It's in his wardrobe now.") % Catalog.item_name(id).to_lower() + "\n\n"
		+ tr("Each season brings its own find, once a year. Keep an eye on the balcony!"))


func _on_dug_up(res: Dictionary) -> void:
	var found := Catalog.find_name(res.id)
	if res.id == "map":
		if res.map_done:
			_queue(treasure_map_popup)
		else:
			toast(tr("Bubák dug up a piece of a treasure map! (%d of %d)") % [res.pieces, Catalog.MAP_PIECES], "find_map", true)
		return
	toast(tr("Bubák dug something up: %s!") % found + (" +%d" % res.coins if res.coins > 0 else "") + ("  " + tr("(new for the collection)") if res.new else ""),
		"find_" + res.id, res.new)


## The whole map: where to dig in the living room.
func treasure_map_popup() -> void:
	if Game.treasure.is_empty():
		return
	Sfx.play("fanfare")
	var v := UI.vbox(10)
	var title := UI.label(tr("A treasure map!"), 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var map := Control.new()
	map.custom_minimum_size = Vector2(560, 250)
	map.draw.connect(func():   # a sepia sketch of the living room, furniture and all, with the X
		var sz := map.size
		var area := Rect2(0, 180, 1280, 540)   # the part of the room it shows (world)
		var k := (sz - Vector2(20, 20)) / area.size
		var to_map := func(w: Vector2) -> Vector2: return Vector2(10, 10) + (w - area.position) * k
		map.draw_rect(Rect2(Vector2.ZERO, sz), Color("#f1dfb4"))
		var ink := Color(0.55, 0.38, 0.22, 0.6)
		map.draw_texture_rect_region(Catalog.tex(main._room_tex()), Rect2(Vector2(10, 10), sz - Vector2(20, 20)),
			Rect2(area.position + Vector2(240, 160), area.size), Color(0.8, 0.62, 0.4, 0.45))
		var things: Array = main.items.values() + main.fixed
		things.sort_custom(func(a, b): return a.position.y < b.position.y)
		for it in things:
			if it.visible and it.sprite and it.sprite.texture and Game.room_at(it.position) == "living" and it.id != "cable":
				var r: Rect2 = it.rect()
				map.draw_texture_rect(it.sprite.texture, Rect2(to_map.call(r.position), r.size * k), false, ink)
		var p: Vector2 = to_map.call(Game.treasure_spot())
		map.draw_line(p + Vector2(-14, -14), p + Vector2(14, 14), Color("#e8505b"), 7.0)
		map.draw_line(p + Vector2(14, -14), p + Vector2(-14, 14), Color("#e8505b"), 7.0)
		var prev := Vector2(30, sz.y - 24)
		for i in 6:   # a dotted trail to the X
			map.draw_circle(prev.lerp(p, (i + 1) / 7.0) + Vector2(0, sin(i * 1.7) * 10.0), 4, Color("#a8693c"))
		map.draw_rect(Rect2(Vector2.ZERO, sz), UI.INK, false, 4.0))
	v.add_child(map)
	var l := UI.wrap_label(tr("All the pieces fit together: it's the living room! Tap the spot marked X on the floor to dig up the treasure."), 19, 560)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var ok := UI.text_button(tr("Let's dig!"), "find_map")
	ok.size_flags_horizontal = SIZE_SHRINK_CENTER
	ok.pressed.connect(func():
		close_top()
		main.go_to("living"))
	v.add_child(ok)
	_open_modal("", v, Vector2(640, 0))


func treasure_popup(res: Dictionary) -> void:
	_note_popup("treasure_chest", tr("Treasure!"), tr("Right where the X was: %d gold coins!") % res.coins + "\n\n"
		+ (tr("And the chest itself: it's yours to keep, a treasure chest for the flat.") if res.chest
		else tr("And at the bottom, wrapped in a cloth: a golden carrot.")) + "\n\n"
		+ tr("Bubák is already digging for the next map."), tr("Hooray!"), 120)


## The neighbours' child at the door. Gentle hello, or another day?
func kid_popup(kid: String) -> void:
	var v := UI.vbox(12)
	v.add_child(UI.icon_rect("kid", 100))
	var title := UI.label(tr("Ding dong!"), 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var l := UI.wrap_label(tr("%s from next door is at the door and would love to say hello to Bubák.") % kid + "\n"
		+ tr("A friendly visit is lovely for a bunny who trusts people. A shy one might get scared."), 20, 540)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var h := UI.hbox(12)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var no := UI.text_button(tr("Not today"))
	no.pressed.connect(close_top)
	h.add_child(no)
	var yes := UI.text_button(tr("Come in, gently!"), "heart")
	yes.pressed.connect(func():
		var res := Game.kid_visit(kid)
		close_top()
		main.kid_reaction(res)
		toast(res.text, "heart" if res.happy else "kid", res.happy))
	h.add_child(yes)
	v.add_child(h)
	_open_modal("", v, Vector2(620, 0))


## A postcard: a child's drawing of the bunny in their new home, and a few lines.
func _postcard_popup(card: Dictionary) -> void:
	Sfx.play("chime")
	var v := UI.vbox(12)
	var title := UI.label(tr("A postcard from %s's family!") % Catalog.mate_name(card.id), 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	v.add_child(_postcard(card, Vector2(600, 300)))
	var ok := UI.text_button(tr("Pin it to the fridge"), "heart")
	ok.size_flags_horizontal = SIZE_SHRINK_CENTER
	ok.pressed.connect(close_top)
	v.add_child(ok)
	_open_modal("", v, Vector2(660, 0))


func _postcard(card: Dictionary, size: Vector2) -> Control:
	var h := HBoxContainer.new()
	h.custom_minimum_size = size
	h.add_theme_constant_override("separation", 0)
	h.add_child(_postcard_pic(card, Vector2(size.x * 0.5, size.y)))
	var back := PanelContainer.new()
	var bs2 := UI.box(Color("#fffdf6"), 0, 3, false)
	bs2.set_content_margin_all(16)
	back.add_theme_stylebox_override("panel", bs2)
	back.custom_minimum_size = Vector2(size.x * 0.5, size.y)
	var bv := UI.vbox(8)
	back.add_child(bv)
	bv.add_child(UI.wrap_label(Game.postcard_text(card), 18, size.x * 0.5 - 36))
	var sig := UI.label(tr("Love, %s and family") % Catalog.mate_name(card.id), 16, Color(UI.INK, 0.7))
	sig.size_flags_vertical = SIZE_EXPAND_FILL
	sig.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	bv.add_child(sig)
	h.add_child(back)
	return h


## The front of a postcard: a child's crayon drawing of the bunny at their new home.
func _postcard_pic(card: Dictionary, size: Vector2) -> Control:
	var pic := Control.new()
	pic.custom_minimum_size = size
	var seed_n := hash(str(card.id) + str(card.n))
	pic.draw.connect(func():   # a crayon drawing: sky, sun, a house, grass, and the bunny
		var sz := pic.size
		var rs := RandomNumberGenerator.new()
		rs.seed = seed_n
		pic.draw_rect(Rect2(Vector2.ZERO, sz), Color("#fffaf0"))
		pic.draw_rect(Rect2(Vector2(8, 8), Vector2(sz.x - 16, sz.y * 0.62)), Color("#cfe6f5"))
		pic.draw_circle(Vector2(sz.x * 0.82, sz.y * 0.16), sz.y * 0.08, Color("#f6d33c"))
		for i in 8:
			var a := i * TAU / 8.0
			var c := Vector2(sz.x * 0.82, sz.y * 0.16)
			pic.draw_line(c + Vector2(cos(a), sin(a)) * sz.y * 0.1, c + Vector2(cos(a), sin(a)) * sz.y * 0.14, Color("#f2b632"), 3.0)
		var hx := sz.x * rs.randf_range(0.12, 0.2)
		var hy := sz.y * 0.36
		pic.draw_rect(Rect2(hx, hy, sz.x * 0.3, sz.y * 0.3), Color(["#e98fae", "#f3cf7a", "#9cc5a1", "#a7c0e8"][rs.randi() % 4]))
		pic.draw_colored_polygon(PackedVector2Array([Vector2(hx - 8, hy), Vector2(hx + sz.x * 0.15, hy - sz.y * 0.16), Vector2(hx + sz.x * 0.3 + 8, hy)]), Color("#c8562e"))
		pic.draw_rect(Rect2(hx + sz.x * 0.11, hy + sz.y * 0.14, sz.x * 0.08, sz.y * 0.16), Color("#8a5a36"))
		pic.draw_rect(Rect2(Vector2(8, sz.y * 0.66), Vector2(sz.x - 16, sz.y * 0.34 - 8)), Color("#9cd07a"))
		for i in 14:
			var gx := 14.0 + i * (sz.x - 28) / 13.0
			pic.draw_line(Vector2(gx, sz.y * 0.68), Vector2(gx + 4, sz.y * 0.62), Color("#5fa85f"), 3.0)
		var bt: Texture2D = Catalog.tex("bunny_sit_" + str(card.id))
		var bw := sz.x * 0.4
		pic.draw_texture_rect(bt, Rect2(Vector2(sz.x * 0.5, sz.y * 0.94 - bw * 0.9), Vector2(bw, bw * 200.0 / 220.0)), false)
		pic.draw_rect(Rect2(Vector2.ZERO, sz), UI.INK, false, 3.0))
	return pic


# ---- Bubák merch -------------------------------------------------------------------------

func _merch_popup() -> void:
	Sfx.play("fanfare")
	var v := UI.vbox(12)
	v.add_child(UI.icon_rect("merch_plush", 110))
	var title := UI.label(tr("Fans want Bubák merch!"), 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var l := UI.wrap_label(tr("Bubák is famous enough for his own merch. Order stickers and mugs, put your best photo on them, and they sell by the hour, even while you're away.\n\nYou'll find it on the laptop."), 20, 540)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var h := UI.hbox(12)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var later := UI.text_button(tr("Later"))
	later.pressed.connect(close_top)
	h.add_child(later)
	var go := UI.text_button(tr("Let's see!"), "merch_mug")
	go.pressed.connect(func():
		close_top()
		open_merch.call_deferred())
	h.add_child(go)
	v.add_child(h)
	_open_modal("", v, Vector2(600, 0))


func open_merch() -> void:
	var v := UI.vbox(10)
	var top := UI.hbox(12)
	v.add_child(top)
	var waiting := int(Game.merch_pending)
	var tl := UI.label(tr("Sales waiting: %d coins") % waiting, 22)
	tl.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(tl)
	var collect := UI.text_button(tr("Collect"), "coin", 20)
	collect.disabled = waiting <= 0
	collect.pressed.connect(func():
		var n := Game.collect_merch()
		Sfx.play("coin")
		toast(tr("+%d coins from merch sales!") % n, "coin", true)
		open_merch.call_deferred())
	top.add_child(collect)
	v.add_child(UI.label(tr("Earned so far: %d coins. Designs go stale after a few weeks: refresh them with a new photo.") % Game.merch_earned, 15, Color(UI.INK, 0.7)))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 430)
	v.add_child(scroll)
	var list := UI.vbox(8)
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(list)
	for id in Catalog.MERCH_ORDER:
		list.add_child(_merch_row(id))
	_open_modal(tr("Bubák merch"), v, Vector2(900, 0))


func _merch_row(id: String) -> Control:
	var info: Dictionary = Catalog.MERCH[id]
	var m := Game.merch_of(id)
	var open := Game.merch_unlocked(id)
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UI.box(Color("#fffdf8") if open else Color("#f1e8dc"), 14, 2, false))
	var h := UI.hbox(12)
	row.add_child(h)
	h.add_child(UI.icon_rect("merch_" + id, 56))
	var tv := UI.vbox(2)
	tv.size_flags_horizontal = SIZE_EXPAND_FILL
	h.add_child(tv)
	tv.add_child(UI.label(Catalog.merch_name(id), 20))
	if not open:
		tv.add_child(UI.label(tr("Publish Bubák's book first (Journal > Memories).") if info.get("book", false)
			else tr("Unlocks at fame: %s") % Game.fame_name(info.fame), 15, Color("#c0504d")))
		return row
	tv.add_child(UI.label(tr("Sells for %d coins  ·  a batch of %d costs %d") % [info.price, info.batch, info.cost], 15, Color(UI.INK, 0.75)))
	var status := tr("Out of stock") if int(m.stock) <= 0 else tr("In stock: %d  ·  about %.1f sold a day") % [int(m.stock), Game.merch_rate(id) * 24.0]
	if m.photo != "":
		var fresh := Game.merch_freshness(id)
		status += "  ·  " + (tr("fresh design") if fresh > 0.66 else (tr("design getting old") if fresh > 0.3 else tr("stale design: sells less")))
	tv.add_child(UI.label(status + "  ·  " + tr("%d sold") % int(m.sold), 15))
	if m.photo != "":
		var pic := TextureRect.new()
		pic.texture = _photo_texture(m.photo)
		pic.custom_minimum_size = Vector2(84, 63)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		h.add_child(pic)
	var bv := UI.vbox(4)
	h.add_child(bv)
	var order := UI.text_button(tr("Order %d (%d)") % [info.batch, info.cost], "coin", 16)
	order.pressed.connect(func():
		var err := Game.merch_order(id)
		if err != "":
			toast(err)
			return
		Sfx.play("buy")
		open_merch.call_deferred())
	bv.add_child(order)
	if m.photo != "":
		var design := UI.text_button(tr("New design"), "camera", 16)
		design.pressed.connect(func():
			var err := Game.merch_design(id)
			if err != "":
				toast(err)
				return
			toast(tr("New design: your latest best photo is on the %s now.") % Catalog.merch_name(id).to_lower(), "camera")
			open_merch.call_deferred())
		bv.add_child(design)
	return row


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
		if Game.merch_open():
			open_merch()   # the merch business doesn't take breaks
		return
	var w := WorkGame.new()
	w.finished.connect(close_top)
	w.merch_requested.connect(open_merch)
	_open_modal(tr("Remote work"), w, Vector2(860, 0))


# ---- wardrobe --------------------------------------------------------------------

## Bubák (or his friend) up close in everything he has on; tap an accessory to put it on or take it off.
## One thing per place (head, ears, eyes, neck); ones not owned yet can be bought right here.
func open_wardrobe() -> void:
	if _wardrobe_pet != null and _wardrobe_pet != Game.mate:
		_wardrobe_pet = null
	var h := UI.hbox(18)
	var left := UI.vbox(8)
	h.add_child(left)
	if Game.mate:   # who to dress
		var pick := UI.hbox(8)
		pick.alignment = BoxContainer.ALIGNMENT_CENTER
		left.add_child(pick)
		for p in [Game.bubak, Game.mate]:
			var pb := UI.text_button(p.display_name(), "icon" if p.is_bubak() else "mate_" + p.id, 18)
			pb.toggle_mode = true
			pb.button_pressed = (p == Game.mate) == (_wardrobe_pet != null)
			pb.pressed.connect(func():
				_wardrobe_pet = null if p.is_bubak() else p
				for o in pick.get_children():
					o.button_pressed = o == pb
				_wardrobe_stage.who = _wardrobe_pet
				_fill_wardrobe())
			pick.add_child(pb)
	var mirror := PanelContainer.new()
	var ms := UI.box(Color("#f3e3ef"), 22, 3, false)
	mirror.add_theme_stylebox_override("panel", ms)
	mirror.custom_minimum_size = Vector2(360, 380)
	left.add_child(mirror)
	_wardrobe_stage = StageBunny.new()
	_wardrobe_stage.k = 1.55
	_wardrobe_stage.who = _wardrobe_pet
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
	var style := int(Game.style_score(_wardrobe_pet))
	var head := UI.hbox(10)
	_wardrobe_side.add_child(head)
	var sl := UI.label(tr("Style: %d/100") % style, 20)
	sl.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(sl)
	head.add_child(UI.label(tr("Photo likes +%d%%") % (10 * Game.wearing_of(_wardrobe_pet).size()), 17, Color(UI.INK, 0.7)))
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 12)
	bar.show_percentage = false
	bar.value = style
	bar.add_theme_stylebox_override("fill", UI.bar_fill(Color("#d8a7d0")))
	_wardrobe_side.add_child(bar)
	for place in ["head", "ear", "eyes", "neck"]:
		_wardrobe_side.add_child(UI.label(tr(Catalog.WEAR_PLACE_NAMES[place]), 18))
		var scroll := ScrollContainer.new()   # gifts can make a row longer than the panel: it scrolls sideways
		scroll.custom_minimum_size = Vector2(5 * 124 + 4 * 8, 90)
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_wardrobe_side.add_child(scroll)
		var row := UI.hbox(8)
		scroll.add_child(row)
		row.add_child(_wear_tile("", place))
		var gifts: Array = Game.wardrobe.filter(func(w): return Catalog.ITEMS[w].get("gift", false))
		for id in Catalog.SHOP_TABS.Style + gifts:
			if Catalog.ITEMS[id].place == place:
				row.add_child(_wear_tile(id, place))
	_wardrobe_info = UI.wrap_label(tr("Tap something to put it on. One thing in each place.")
		+ ("\n" + tr("There's one of each, so it moves from one bunny to the other.") if Game.mate else ""), 15, 540)
	_wardrobe_info.custom_minimum_size.y = 40
	_wardrobe_side.add_child(_wardrobe_info)
	_wardrobe_stage.dress()


## One accessory in the wardrobe ("" = nothing in that place).
func _wear_tile(id: String, place: String) -> Button:
	var worn: bool = Game.wearing_of(_wardrobe_pet).get(place, "") == id
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
	var w := Game.wearing_of(_wardrobe_pet)
	if id == "":
		if w.has(place):
			Game.toggle_wear(w[place], _wardrobe_pet)
		_fill_wardrobe()
		return
	var item: Dictionary = Catalog.ITEMS[id]
	if id in Game.wardrobe:
		Game.toggle_wear(id, _wardrobe_pet)
		_fill_wardrobe()
		_wardrobe_info.text = "%s: %s" % [Catalog.item_name(id), tr(item.desc)]
		if w.get(place, "") == id:
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
	if _wardrobe_pet:   # bought on Bubák: hand it over
		Game.toggle_wear(id, _wardrobe_pet)
	_fill_wardrobe()
	_wardrobe_info.text = tr("New: %s! %s has it on already.") % [Catalog.item_name(id),
		(_wardrobe_pet if _wardrobe_pet else Game.bubak).display_name()]
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
	var worn := Game.wear_of(e)
	if worn >= 0.3:
		info = tr("worn %d%%") % int(worn * 100) + " · " + info
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
