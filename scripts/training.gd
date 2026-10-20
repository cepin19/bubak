extends HBoxContainer
## Show club: teach Bubák tricks. Pick a trick; when he does it, tap Reward at once.
## Each try uses up some of his focus, which comes back over time.

var hud: Control
var _stage: StageBunny
var _say: Label
var _focus_row: HBoxContainer
var _focus_note: Label
var _reward: Button
var _rows: VBoxContainer
var _trick := ""
var _t := 0.0


func _ready() -> void:
	add_theme_constant_override("separation", 18)
	var left := UI.vbox(8)
	add_child(left)
	var top := UI.hbox(6)
	left.add_child(top)
	top.add_child(UI.label(tr("Focus"), 18))
	_focus_row = UI.hbox(2)
	top.add_child(_focus_row)
	_focus_note = UI.label("", 15, Color(UI.INK, 0.7))
	_focus_note.size_flags_vertical = SIZE_SHRINK_CENTER
	top.add_child(_focus_note)
	var mat := PanelContainer.new()
	mat.add_theme_stylebox_override("panel", UI.box(Color("#e4efd6"), 22, 3, false))
	mat.custom_minimum_size = Vector2(420, 320)
	left.add_child(mat)
	_stage = StageBunny.new()
	_stage.k = 1.2
	mat.add_child(_stage)
	_stage.attempt_done.connect(_on_done)
	_say = UI.label(tr("Pick a trick to practise."), 22)
	_say.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_say.custom_minimum_size = Vector2(420, 0)
	_say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_say)
	_reward = UI.text_button(tr("Reward!"), "clicker" if "clicker" in Game.gear else "treat", 26)
	_reward.custom_minimum_size = Vector2(260, 64)
	_reward.size_flags_horizontal = SIZE_SHRINK_CENTER
	_reward.disabled = true
	_reward.pressed.connect(_on_reward)
	left.add_child(_reward)

	var right := UI.vbox(8)
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(right)
	right.add_child(UI.wrap_label(tr("Pick a trick. The moment Bubák does it, tap Reward! Don't reward him if he gets distracted."), 17, 340))
	_rows = UI.vbox(8)
	right.add_child(_rows)
	_fill()
	_update_focus()


func _fill() -> void:
	for c in _rows.get_children():
		c.queue_free()
	for id in Catalog.TRICK_ORDER:
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UI.box(Color("#fffdf8"), 16, 2, false))
		var h := UI.hbox(10)
		row.add_child(h)
		h.add_child(UI.icon_rect(Catalog.TRICKS[id].icon, 52))
		var v := UI.vbox(2)
		v.size_flags_horizontal = SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(UI.label(Catalog.trick_name(id), 20))
		var lock := Game.trick_lock(id)
		if lock != "":
			v.add_child(UI.label(lock, 15, Color("#c0504d")))
			row.modulate = Color(1, 1, 1, 0.7)
		else:
			var sh := UI.hbox(2)
			v.add_child(sh)
			var stars := Game.trick_stars(id)
			for i in 3:
				var s := UI.icon_rect("star", 22)
				if i >= stars:
					s.modulate = Color(0.3, 0.25, 0.25, 0.3)
				sh.add_child(s)
			if stars < 3:
				var bar := ProgressBar.new()
				bar.custom_minimum_size = Vector2(90, 10)
				bar.size_flags_vertical = SIZE_SHRINK_CENTER
				bar.show_percentage = false
				bar.max_value = 1.0
				bar.step = 0.001
				bar.value = Game.trick_progress(id)
				bar.add_theme_stylebox_override("fill", UI.bar_fill(UI.GOLD))
				sh.add_child(bar)
			var b := UI.text_button(tr("Practise") if stars > 0 else tr("Teach"), "", 18)
			b.size_flags_vertical = SIZE_SHRINK_CENTER
			b.pressed.connect(cue.bind(id))
			h.add_child(b)
		_rows.add_child(row)


## Asks Bubák for a trick.
func cue(id: String) -> void:
	if _stage.attempting() or Game.trick_lock(id) != "":
		return
	if Game.focus < 1.0:
		_say.text = tr("Bubák has had enough training for now. Let him rest a bit.")
		return
	Game.focus -= 1.0
	_update_focus()
	_trick = id
	_say.text = tr("\"Bubák... %s!\"") % Catalog.trick_name(id).to_lower()
	_reward.disabled = false
	_stage.attempt(id, Game.trick_chance(id))


func _on_reward() -> void:
	_stage.reward()


func _on_done(result: String) -> void:
	_reward.disabled = true
	_reward.modulate = Color.WHITE
	var gained := Game.train(_trick, {"good": "good", "late": "late", "wrong": "wrong"}.get(result, "none"))
	_say.text = {
		"good": tr("Perfect timing! He's getting it."),
		"late": tr("A bit off. He's not sure what the treat was for."),
		"missed": tr("He did it, but you missed the moment to reward him."),
		"wrong": tr("Oops! That rewarded him for getting distracted."),
		"ignored": tr("Right call: no treat for getting distracted."),
	}[result]
	if gained > 0:
		var stars := Game.trick_stars(_trick)
		hud.toast(tr("%s: %d of 3 stars!") % [Catalog.trick_name(_trick), stars] if stars < 3
			else tr("Bubák has mastered %s!") % Catalog.trick_name(_trick), "star", true)
		_stage.happy()
	_fill()


func _update_focus() -> void:
	for c in _focus_row.get_children():
		c.queue_free()
	var n := int(Game.focus)
	for i in Game.focus_max():
		var r := UI.icon_rect("carrot", 22)
		if i >= n:
			r.modulate = Color(0.3, 0.25, 0.25, 0.3)
		_focus_row.add_child(r)
	if n < Game.focus_max():
		var wait := (1.0 - fmod(Game.focus, 1.0)) * Catalog.FOCUS_REFILL
		_focus_note.text = tr("+1 in %s") % Game.duration_text(wait)
	else:
		_focus_note.text = ""


func _process(delta: float) -> void:
	if _stage.in_window():
		var p := 0.75 + 0.25 * sin(Time.get_ticks_msec() / 60.0)
		_reward.modulate = Color(1.0, 0.85 + 0.15 * p, 0.4 + 0.3 * p)
	else:
		_reward.modulate = Color.WHITE
	_t -= delta
	if _t <= 0:
		_t = 1.0
		_update_focus()
