extends VBoxContainer
## Remote work: pick a job (mini-game), play a timed shift, get paid and climb the career ladder.
## Each job lives in scripts/jobs/<id>.gd and reports to this controller through
## hit() / miss() / penalty(); the controller owns time, streaks, pay, stars and XP.

signal finished

const MULT_AT := [0, 5, 12, 20]   # streak needed for x1, x2, x3, x4
const RUSH := 5.0                 # the last seconds of a shift count double
const STAR_BONUS := 0.15          # extra pay per star

var _top: HBoxContainer
var _info: Label
var _time_bar: ProgressBar
var _mult_label: Label
var _area: Panel
var _flash: ColorRect
var _game: Control
var _job := ""
var _running := false
var _t := 0.0
var _earned := 0
var _combo := 0
var _best_combo := 0
var _hits := 0
var _misses := 0
var _rush_shown := false


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_top = UI.hbox(14)
	add_child(_top)
	_info = UI.label("", 20)
	_info.size_flags_horizontal = SIZE_EXPAND_FILL
	_top.add_child(_info)
	_time_bar = ProgressBar.new()
	_time_bar.custom_minimum_size = Vector2(180, 16)
	_time_bar.size_flags_vertical = SIZE_SHRINK_CENTER
	_time_bar.show_percentage = false
	_time_bar.add_theme_stylebox_override("fill", UI.bar_fill(Color("#7fcfb8")))
	_top.add_child(_time_bar)
	_mult_label = UI.label("", 24, Color("#e0ad4a"))
	_mult_label.custom_minimum_size.x = 60
	_mult_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_top.add_child(_mult_label)
	_area = Panel.new()
	_area.custom_minimum_size = Vector2(820, 430)
	_area.clip_contents = true
	_area.add_theme_stylebox_override("panel", UI.box(Color("#33507a"), 18, 3, false))
	add_child(_area)
	_show_menu()


func _clear() -> void:
	for c in _area.get_children():
		c.queue_free()
	_flash = null


func _career_line() -> String:
	var lvl := Game.career_level()
	var line := tr("Career: %s") % Catalog.career_title(lvl)
	if lvl < Catalog.CAREER.size() - 1:
		line += "   " + tr("Next promotion: %d/%d XP") % [Game.career_xp, Catalog.CAREER[lvl + 1].xp]
	return line + "   " + tr("Pay: x%.2f") % Game.work_pay_mult()


func _set_hud(shift: bool) -> void:
	_time_bar.visible = shift
	_mult_label.visible = shift


# ---- job menu -------------------------------------------------------------------

func _show_menu() -> void:
	_clear()
	_set_hud(false)
	_info.text = _career_line()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_area.add_child(center)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 12)
	center.add_child(grid)
	var pick := Game.boss_pick()
	for id in Catalog.JOBS:
		grid.add_child(_job_card(id, id == pick))


func _job_card(id: String, picked: bool) -> Button:
	var job: Dictionary = Catalog.JOBS[id]
	var unlocked: bool = Game.career_level() >= job.level
	var b := Button.new()
	b.custom_minimum_size = Vector2(390, 128)
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = not unlocked
	if picked and unlocked:
		var gold := UI.box(Color("#fff3c9"), 22, 4)
		gold.border_color = Color("#e0ad4a")
		b.add_theme_stylebox_override("normal", gold)
	var h := UI.hbox(12)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 14
	h.offset_right = -12
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var ic := UI.icon_rect(job.icon if unlocked else "lock", 62)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var v := UI.vbox(2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var name_row := UI.hbox(6)
	v.add_child(name_row)
	var nl := UI.label(tr(job.name), 22)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(nl)
	if unlocked:
		var best: Dictionary = Game.job_best.get(id, {"score": 0, "stars": 0})
		for i in 3:
			var st := UI.icon_rect("star", 22)
			st.modulate = Color.WHITE if i < int(best.stars) else Color(0.4, 0.35, 0.35, 0.35)
			name_row.add_child(st)
	var d := tr(job.desc) if unlocked else tr("Unlocks at: %s") % Catalog.career_title(job.level)
	v.add_child(UI.wrap_label(d, 14, 280))
	if unlocked and picked:
		v.add_child(UI.label(tr("Boss's pick today: double XP!"), 15, Color("#c0504d")))
	elif unlocked and Game.job_best.has(id):
		v.add_child(UI.label(tr("Best: %d points") % int(Game.job_best[id].score), 14, Color(UI.INK, 0.65)))
	b.pressed.connect(_start.bind(id))
	return b


# ---- a shift ---------------------------------------------------------------------

func _start(job: String) -> void:
	_clear()
	_set_hud(true)
	_job = job
	_game = load("res://scripts/jobs/%s.gd" % job).new()
	_game.ctl = self
	_game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_area.add_child(_game)
	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 0.3, 0.3, 0)
	_flash.z_index = 4
	_area.add_child(_flash)
	_t = Game.work_duration()
	_earned = 0
	_combo = 0
	_best_combo = 0
	_hits = 0
	_misses = 0
	_rush_shown = false
	_update_hud()
	# Ready... Go!
	_banner(tr("Ready..."), Color.WHITE, 0.55)
	var t := create_tween()
	t.tween_interval(0.6)
	t.tween_callback(func():
		if _game and is_instance_valid(_game):
			_banner(tr("Go!"), Color("#ffe9a8"), 0.5)
			_running = true)


func is_running() -> bool:
	return _running


## 0 at the start of a shift, 1 at the end: jobs use it to speed up.
func progress() -> float:
	return clampf(1.0 - _t / Game.work_duration(), 0, 1)


func multiplier() -> int:
	var m := 1
	for i in MULT_AT.size():
		if _combo >= MULT_AT[i]:
			m = i + 1
	return m


func rush() -> bool:
	return _running and _t <= RUSH


func hit(pos: Vector2, base := 1) -> void:
	if not _running:
		return
	var old := multiplier()
	_combo += 1
	_hits += 1
	_best_combo = maxi(_best_combo, _combo)
	var c := base * multiplier() * (2 if rush() else 1)
	_earned += c
	float_text("+%d" % c, pos, Color("#ffe9a8"), 26 + mini(c, 12))
	if multiplier() > old:
		_banner([tr("Nice streak! x%d"), tr("On fire! x%d"), tr("Unstoppable! x%d")][multiplier() - 2] % multiplier(),
			Color("#ffd27a"), 0.7)
		_pulse(_mult_label)


func miss() -> void:
	if not _running:
		return
	_misses += 1
	if _combo >= MULT_AT[1]:
		float_text(tr("Streak lost"), Vector2(_area.size.x / 2 - 60, 60), Color("#ff9a9a"), 22)
	_combo = 0
	_shake(0.6)


func penalty(points: int, pos: Vector2, text: String) -> void:
	_earned = maxi(0, _earned - points)
	_misses += 1
	_combo = 0
	float_text(text, pos, Color("#ff9a9a"))
	_shake(1.0)


func float_text(text: String, pos: Vector2, color := Color("#ffe9a8"), font := 26) -> void:
	var l := UI.label(text, font, color)
	l.add_theme_color_override("font_outline_color", Color("#20344f"))
	l.add_theme_constant_override("outline_size", 6)
	l.position = pos + Vector2(10, 10)
	l.z_index = 5
	_area.add_child(l)
	var t := l.create_tween().set_parallel()
	t.tween_property(l, "position:y", pos.y - 40, 0.7)
	t.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.25)
	t.chain().tween_callback(l.queue_free)


## A big word across the middle of the screen.
func _banner(text: String, color: Color, life: float) -> void:
	var l := UI.label(text, 46, color)
	l.add_theme_color_override("font_outline_color", Color("#20344f"))
	l.add_theme_constant_override("outline_size", 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(_area.custom_minimum_size.x, 70)
	l.position = Vector2(0, _area.custom_minimum_size.y / 2 - 35)
	l.pivot_offset = l.size / 2
	l.scale = Vector2(0.4, 0.4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_index = 6
	_area.add_child(l)
	var t := l.create_tween()
	t.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(life)
	t.tween_property(l, "modulate:a", 0.0, 0.2)
	t.tween_callback(l.queue_free)


func _shake(strength: float) -> void:
	if _flash:
		_flash.color.a = 0.22 * strength
		_flash.create_tween().tween_property(_flash, "color:a", 0.0, 0.25)
	if _game and is_instance_valid(_game):
		var t := _game.create_tween()
		for i in 4:
			t.tween_property(_game, "position", Vector2(randf_range(-6, 6), randf_range(-4, 4)) * strength, 0.03)
		t.tween_property(_game, "position", Vector2.ZERO, 0.03)


func _pulse(c: Control) -> void:
	c.pivot_offset = c.size / 2
	var t := c.create_tween()
	t.tween_property(c, "scale", Vector2(1.5, 1.5), 0.1)
	t.tween_property(c, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)


func _update_hud() -> void:
	_info.text = tr("Points: %d     Streak: %d") % [_earned, _combo]
	_time_bar.value = 100.0 * _t / Game.work_duration()
	var m := multiplier() * (2 if rush() else 1)
	_mult_label.text = "x%d" % m
	_mult_label.modulate = Color.WHITE if m > 1 else Color(1, 1, 1, 0.4)


func _process(delta: float) -> void:
	if not _running:
		return
	_t -= delta
	if _t <= RUSH and not _rush_shown:
		_rush_shown = true
		_banner(tr("Final rush! Double points!"), Color("#ff9a6a"), 0.8)
		_time_bar.add_theme_stylebox_override("fill", UI.bar_fill(Color("#ff9a6a")))
	_update_hud()
	if _t <= 0:
		_end()


# ---- results ---------------------------------------------------------------------

func _end() -> void:
	_running = false
	_set_hud(false)
	_time_bar.add_theme_stylebox_override("fill", UI.bar_fill(Color("#7fcfb8")))
	var old_level := Game.career_level()
	var stars := Game.job_stars(_job, _earned)
	var picked := _job == Game.boss_pick()
	var xp := _earned * (2 if picked else 1)
	var pay := int(round(_earned * Game.work_pay_mult() * (1.0 + STAR_BONUS * stars)))
	var record := Game.record_shift(_job, _earned, stars)
	Game.career_xp += xp
	Game.add_coins(pay)
	Game.stats.work += 1
	Game.work_ready_at = Time.get_unix_time_from_system() + Game.work_cooldown()
	var lvl := Game.career_level()
	var bonus := 0
	if lvl > old_level:
		bonus = Catalog.PROMOTION_BONUS * lvl
		Game.add_coins(bonus)
	Game.save_game()
	_clear()
	_info.text = tr("Shift over!")
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_area.add_child(center)
	var v := UI.vbox(8)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)

	var star_row := UI.hbox(10)
	star_row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(star_row)
	for i in 3:
		var st := UI.icon_rect("star", 64)
		st.modulate = Color(0.3, 0.3, 0.4, 0.5)
		star_row.add_child(st)
		if i < stars:
			_pop_star.call_deferred(st, 0.25 + 0.3 * i)
	var head: String = [tr("Keep practising!"), tr("Good shift!"), tr("Great shift!"), tr("Outstanding!")][stars]
	_white(v, head, 30)
	_white(v, tr("%d points  ·  best streak %d") % [_earned, _best_combo], 19)
	if record:
		_white(v, tr("New personal best!"), 21, Color("#ffd27a"))
	var pay_line := tr("You earned %d coins.") % pay
	if stars > 0:
		pay_line += "  " + tr("(+%d%% for stars)") % int(STAR_BONUS * stars * 100)
	_white(v, pay_line, 22)
	_white(v, (tr("+%d XP (boss's pick: doubled!)") % xp) if picked else (tr("+%d XP") % xp), 18,
		Color("#ffd27a") if picked else Color.WHITE)
	if lvl > old_level:
		_promotion(v, lvl, bonus)
	else:
		_white(v, _career_line(), 16, Color(1, 1, 1, 0.75))
		if lvl < Catalog.CAREER.size() - 1:
			var bar := ProgressBar.new()
			bar.custom_minimum_size = Vector2(360, 14)
			bar.show_percentage = false
			bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			bar.value = 100.0 * Game.career_progress()
			v.add_child(bar)
	var back := UI.text_button(tr("Back to Bubák"), "work", 22)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): finished.emit())
	v.add_child(back)


func _promotion(v: VBoxContainer, lvl: int, bonus: int) -> void:
	var card := PanelContainer.new()
	var cs := UI.box(Color("#fff3c9"), 18, 3)
	cs.border_color = Color("#e0ad4a")
	cs.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", cs)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(card)
	var cv := UI.vbox(2)
	card.add_child(cv)
	var l := UI.label(tr("PROMOTION! You're now: %s") % Catalog.career_title(lvl), 24, Color("#c0504d"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(l)
	var extras := [tr("Promotion bonus: %d coins") % bonus, tr("Pay: x%.2f") % Game.work_pay_mult()]
	for id in Catalog.JOBS:
		if Catalog.JOBS[id].level == lvl:
			extras.append(tr("New job unlocked: %s") % tr(Catalog.JOBS[id].name))
	for item in Catalog.ITEMS.values():
		if item.get("req_career", -1) == lvl:
			extras.append(tr("New in the shop: %s") % tr(item.name))
	for e in extras:
		var el := UI.label(e, 17)
		el.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(el)
	card.pivot_offset = Vector2(200, 40)
	UI.pop_in.call_deferred(card)


func _white(parent: Control, text: String, font: int, color := Color.WHITE) -> void:
	var l := UI.label(text, font, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)


func _pop_star(st: Control, delay: float) -> void:
	st.pivot_offset = st.size / 2
	var t := st.create_tween()
	t.tween_interval(delay)
	t.tween_callback(func(): st.modulate = Color.WHITE)
	t.tween_property(st, "scale", Vector2(1.4, 1.4), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(st, "scale", Vector2.ONE, 0.15)
