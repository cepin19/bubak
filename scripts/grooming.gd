extends HBoxContainer
## Show club: brush out loose fur (swipe over the tufts) and trim his nails.
## He only sits still for so long; the more he trusts you, the longer.

var hud: Control
var _stage: StageBunny
var _mat: PanelContainer
var _tufts: Array = []
var _brush_icon: TextureRect
var _say: Label
var _coat_bar: ProgressBar
var _nail_bar: ProgressBar
var _patience: ProgressBar
var _nail_button: Button
var _gained := 0.0
var _brushing := false
var _started := false
var _done := false
var _time := 0.0
var _limit := 10.0


func _ready() -> void:
	add_theme_constant_override("separation", 18)
	_mat = PanelContainer.new()
	_mat.add_theme_stylebox_override("panel", UI.box(Color("#f3e3ef"), 22, 3, false))
	_mat.custom_minimum_size = Vector2(440, 400)
	_mat.mouse_filter = MOUSE_FILTER_STOP
	_mat.gui_input.connect(_on_input)
	add_child(_mat)
	_stage = StageBunny.new()
	_stage.k = 1.45
	_mat.add_child(_stage)

	var right := UI.vbox(10)
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(right)
	_say = UI.wrap_label("", 18, 330)
	right.add_child(_say)
	_coat_bar = _bar(right, tr("Coat"), Color("#c9b8e8"))
	_nail_bar = _bar(right, tr("Nails"), Color("#e9a3a0"))
	_patience = _bar(right, tr("Patience left"), UI.PINK)
	_nail_button = UI.text_button(tr("Trim nails"), "clippers", 20)
	_nail_button.size_flags_horizontal = SIZE_SHRINK_BEGIN
	_nail_button.pressed.connect(_trim)
	right.add_child(_nail_button)
	if Game.molting():
		right.add_child(UI.wrap_label(tr("He's molting! Loose fur everywhere: brush him often for a few days."), 16, 330))
	_brush_icon = UI.icon_rect("comb" if "comb" in Game.gear else "brush", 64)
	_brush_icon.visible = false
	_brush_icon.z_index = 1
	_stage.add_child(_brush_icon)
	_limit = 10.0 + 4.0 * Game.trust_level()
	_setup.call_deferred()


func _bar(parent: Control, caption: String, color: Color) -> ProgressBar:
	var h := UI.hbox(8)
	var l := UI.label(caption, 17)
	l.custom_minimum_size.x = 130
	h.add_child(l)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(170, 14)
	bar.size_flags_vertical = SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.add_theme_stylebox_override("fill", UI.bar_fill(color))
	h.add_child(bar)
	parent.add_child(h)
	return bar


func _setup() -> void:
	await get_tree().process_frame   # the stage needs its final size to place the tufts
	_stage.set_pose("loaf")
	_nail_button.visible = "clippers" in Game.gear
	if not "brush" in Game.gear and not "comb" in Game.gear:
		_say.text = tr("You'll need a Soft brush first. It's in the Shop, on the Club tab.")
		_done = true
	elif Game.coat >= 92 and not Game.molting():
		_say.text = tr("His coat is already gleaming. Come back in a while.")
		_done = true
	else:
		_say.text = tr("Swipe over the loose fur to brush it out, before he runs out of patience.")
		var n := clampi(int(round((100.0 - Game.coat) / 7.0)), 3, 12) + (4 if Game.molting() else 0)
		# spots on his back and sides in the loaf pose (sprite coordinates)
		for i in n:
			# spread over his back and sides in the loaf pose (sprite coordinates), some on his head
			var p := Vector2(randf_range(46, 150), randf_range(126, 168))
			if i % 4 == 3:
				p = Vector2(140, 122) + Vector2(randf_range(-22, 22), randf_range(-16, 14))
			var t := UI.icon_rect("fur_tuft", 46)
			t.position = _stage.sprite_point(p) - Vector2(23, 23)
			t.rotation = randf_range(-0.5, 0.5)
			t.pivot_offset = Vector2(23, 23)
			_stage.add_child(t)
			_tufts.append(t)
	_refresh()


func _on_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_brushing = e.pressed
		_brush_icon.visible = e.pressed and not _done
		if e.pressed:
			_brush_at(e.position)
	elif e is InputEventMouseMotion and _brushing:
		_brush_at(e.position)


func _brush_at(p: Vector2) -> void:
	_brush_icon.position = p - _stage.position - Vector2(20, 50)
	if _done:
		return
	_started = true
	var reach := 70.0 if "comb" in Game.gear else 44.0
	for t: TextureRect in _tufts.duplicate():
		var c: Vector2 = t.position + Vector2(23, 23) + _stage.position
		if c.distance_to(p) < reach:
			_tufts.erase(t)
			_gained += 7.0
			var tw := t.create_tween().set_parallel()
			tw.tween_property(t, "position", t.position + Vector2(randf_range(-80, 80), -90), 0.5).set_ease(Tween.EASE_OUT)
			tw.tween_property(t, "modulate:a", 0.0, 0.5)
			tw.tween_property(t, "rotation", t.rotation + 2.0, 0.5)
			tw.chain().tween_callback(t.queue_free)
			if randf() < 0.4:
				_stage.pop_icon("heart")
	_refresh()
	if _tufts.is_empty():
		_finish(tr("All brushed! His coat is soft and glossy."))


func _finish(text: String) -> void:
	if _done:
		return
	_done = true
	_brushing = false
	_brush_icon.visible = false
	_say.text = text
	Game.finish_grooming(_gained)
	_gained = 0.0
	_stage.happy()
	_refresh()


func _trim() -> void:
	var err := Game.trim_nails()
	if err != "":
		_stage.wriggle()
		hud.toast(err)
	else:
		_stage.pop_text(tr("snip snip"))
		_say.text = tr("Neat little nails. The judges will approve.")
	_refresh()


func _refresh() -> void:
	_coat_bar.value = minf(100, Game.coat + _gained)
	_nail_bar.value = 100.0 - Game.nails
	_patience.value = 100.0 * (1.0 - _time / _limit)
	_nail_button.disabled = Game.nails < 15


func _process(delta: float) -> void:
	if _started and not _done:
		_time += delta
		_patience.value = 100.0 * (1.0 - _time / _limit)
		if _time > _limit * 0.75 and fmod(_time, 0.6) < delta:
			_stage.wriggle()
		if _time >= _limit:
			_finish(tr("Bubák has had enough and hops off. Good job anyway!"))


func _exit_tree() -> void:
	if _started and not _done:   # closed half way: what was brushed still counts
		Game.finish_grooming(_gained)
