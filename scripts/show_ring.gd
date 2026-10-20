extends VBoxContainer
## A show in progress: Bubák's turn in the ring, then the judges compare him with three rivals.
## Best in Show and Photogenic are judged on how he is doing; Tricks is a live routine.

signal finished

const PLACES := ["1st", "2nd", "3rd", "4th"]

var hud: Control
var tier := 0
var cat := "looks"
var base_score := 0.0        # for looks / photo, worked out before entering
var photo := {}              # the photo entered in Photogenic
var _stage: StageBunny
var _ring: PanelContainer
var _say: Label
var _button: Button
var _rows := {}              # "bubak" / rival id -> {bar, score, place}
var _rivals: Array = []


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var head := UI.hbox(10)
	head.add_child(UI.icon_rect(Catalog.SHOW_CATS[cat].icon, 44))
	head.add_child(UI.label("%s  ·  %s" % [Catalog.tier_name(tier), Catalog.cat_name(cat)], 28))
	add_child(head)
	var body := UI.hbox(16)
	add_child(body)
	_ring = PanelContainer.new()
	var rs := UI.box(Color("#f6e7c9"), 24, 3, false)
	rs.border_color = Color("#c99a6b")
	_ring.add_theme_stylebox_override("panel", rs)
	_ring.custom_minimum_size = Vector2(440, 330)
	body.add_child(_ring)
	_stage = StageBunny.new()
	_stage.k = 1.2
	_ring.add_child(_stage)
	var table := UI.vbox(6)
	table.size_flags_horizontal = SIZE_EXPAND_FILL
	body.add_child(table)
	table.add_child(UI.label(tr("Judges' table"), 20))
	_rivals = Catalog.RIVALS.keys()
	_rivals.shuffle()
	_rivals = _rivals.slice(0, 3)
	_add_row(table, "bubak", "icon", "Bubák")
	for id in _rivals:
		_add_row(table, id, "rival_" + id, Catalog.rival_name(id))
	_say = UI.wrap_label("", 21, 780)
	_say.custom_minimum_size.y = 60
	add_child(_say)
	_button = UI.text_button(tr("Reward!"), "clicker" if "clicker" in Game.gear else "treat", 24)
	_button.custom_minimum_size = Vector2(240, 60)
	_button.size_flags_horizontal = SIZE_SHRINK_CENTER
	_button.disabled = true
	_button.pressed.connect(_on_button)
	add_child(_button)
	_run()


func _add_row(parent: Control, id: String, icon: String, name: String) -> void:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UI.box(Color("#fff3c9") if id == "bubak" else Color("#fffdf8"), 14, 2, false))
	var h := UI.hbox(8)
	row.add_child(h)
	h.add_child(UI.icon_rect(icon, 46))
	var v := UI.vbox(2)
	v.size_flags_horizontal = SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UI.label(name, 17))
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(150, 12)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("fill", UI.bar_fill(UI.PINK if id == "bubak" else Color("#a7c0e8")))
	v.add_child(bar)
	var score := UI.label("", 18)
	score.custom_minimum_size.x = 34
	score.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(score)
	var place := UI.label("", 20, Color("#c0504d"))
	place.custom_minimum_size.x = 44
	place.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(place)
	parent.add_child(row)
	_rows[id] = {"bar": bar, "score": score, "place": place}


## Waits without leaking: if the show is closed, the timer goes with it and nothing resumes.
func _pause(s: float) -> void:
	var t := Timer.new()
	t.one_shot = true
	add_child(t)
	t.start(s)
	await t.timeout
	t.queue_free()


func _run() -> void:
	await _pause(0.5)
	_say.text = tr("Welcome to the %s! Today's category: %s.") % [Catalog.tier_name(tier), Catalog.cat_name(cat)]
	await _pause(1.8)
	var score := base_score
	match cat:
		"looks": await _judge_looks()
		"photo": await _judge_photo()
		"tricks": score = await _perform_tricks()
	score = clampf(score + randf_range(-3, 3), 1, 100)
	await _results(score)


func _judge_looks() -> void:
	var lines := []
	lines.append(tr("Glossy coat! The judge nods.") if Game.coat >= 85 else (tr("A decent coat.") if Game.coat >= 60
		else tr("Scruffy fur... the judge frowns.")))
	lines.append(tr("Neat nails.") if Game.nails < 35 else tr("Those nails are a bit long."))
	lines.append(tr("What a lovely %s!") % Catalog.item_name(Game.wearing).to_lower() if Game.wearing != "" else tr("No outfit today."))
	lines.append(tr("He sits calmly for the judge.") if Game.trust >= 60 else (tr("A little fidgety.") if Game.trust >= 35
		else tr("He tries to hide behind you!")))
	for i in lines.size():
		_say.text = lines[i]
		if i == 1:
			_stage.set_pose("stand")
		elif i == 3:
			if Game.trust < 35:
				_stage.wriggle()
			else:
				_stage.set_pose("sit")
		await _pause(1.6)


func _judge_photo() -> void:
	_stage.visible = false
	var frame := PanelContainer.new()
	var fs := UI.box(Color.WHITE, 6, 3, true)
	fs.set_content_margin_all(8)
	frame.add_theme_stylebox_override("panel", fs)
	frame.size_flags_horizontal = SIZE_SHRINK_CENTER
	frame.size_flags_vertical = SIZE_SHRINK_CENTER
	var r := TextureRect.new()
	var img := Image.load_from_file(photo.file) if FileAccess.file_exists(photo.get("file", "")) else null
	if img:
		r.texture = ImageTexture.create_from_image(img)
	r.custom_minimum_size = Vector2(360, 270)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	frame.add_child(r)
	var center := CenterContainer.new()
	center.add_child(frame)
	_ring.add_child(center)
	UI.pop_in.call_deferred(frame)
	_say.text = tr("The judges study your photo...")
	await _pause(1.8)
	var likes: int = photo.get("likes", 0)
	_say.text = tr_n("%d like! The judges are charmed.", "%d likes! The judges are charmed.", likes) % likes if likes >= 150 \
		else tr_n("%d like. Sweet, but they've seen cuter.", "%d likes. Sweet, but they've seen cuter.", likes) % likes
	await _pause(1.8)


func _perform_tricks() -> float:
	var known: Array = Catalog.TRICK_ORDER.filter(func(id): return Game.trick_stars(id) > 0)
	known.shuffle()
	var routine := []
	for i in 3:
		routine.append(known[i % known.size()])
	var total := 0.0
	for id in routine:
		var stars := Game.trick_stars(id)
		_say.text = tr("The judge asks for: %s!") % Catalog.trick_name(id)
		await _pause(1.0)
		_button.disabled = false
		_stage.attempt(id, Game.trick_chance(id, tier))
		var res: String = await _stage.attempt_done
		_button.disabled = true
		_button.modulate = Color.WHITE
		match res:
			"good":
				total += 55 + 15 * stars
				_say.text = tr("Perfect! The crowd goes \"aww\".")
			"late", "missed":
				total += 30 + 10 * stars
				_say.text = tr("He did it! The reward came a little late.") if res == "late" else tr("He did it! But you forgot to reward him.")
			"wrong":
				total += 5
				_say.text = tr("Oops! Rewarding a mistake... the judge makes a note.")
			_:
				total += 12
				_say.text = tr("He got distracted. Happens to the best of us.")
		await _pause(1.4)
	var variety := Catalog.TRICK_ORDER.filter(func(id): return id in routine).size()
	return total / routine.size() + (variety - 1) * 4.0


func _results(score: float) -> void:
	_say.text = tr("The judges add up the scores...")
	await _pause(1.2)
	var scores := {"bubak": score}
	var t: Dictionary = Catalog.SHOW_TIERS[tier]
	for id in _rivals:
		scores[id] = clampf(Catalog.RIVALS[id][cat] + t.rivals + randf_range(-7, 7), 5, 99)
	for id in ["bubak"] + _rivals:
		var row: Dictionary = _rows[id]
		row.bar.create_tween().tween_property(row.bar, "value", scores[id], 0.7).set_trans(Tween.TRANS_CUBIC)
		row.score.text = str(int(scores[id]))
		await _pause(0.8)
	var order: Array = scores.keys()
	order.sort_custom(func(a, b): return scores[a] > scores[b])
	for i in order.size():
		_rows[order[i]].place.text = tr(PLACES[i])
	var place: int = order.find("bubak") + 1
	var res := Game.finish_show(tier, cat, place)
	var text := ""
	match place:
		1: text = tr("1st place! Bubák wins the %s!") % Catalog.tier_name(tier)
		2, 3: text = tr("%s place! A ribbon for Bubák.") % tr(PLACES[place - 1])
		_: text = tr("4th place. No ribbon this time.")
	if place <= 3:
		text += "  " + tr("+%d coins, +%d followers") % [res.coins, res.fans]
		_rosette(place)
		_stage.happy()
	else:
		text += "\n" + {"looks": tr("Tip: brush him, trim his nails and dress him up."),
			"tricks": tr("Tip: practise to earn more stars, and reward him right on time."),
			"photo": tr("Tip: photos of rare moments get the most likes.")}[cat]
	if place == 1 and tier + 1 < Catalog.SHOW_TIERS.size() and Game.wins_at(tier) == Catalog.SHOW_TIERS[tier + 1].wins:
		text += "\n" + tr("The %s is now open to Bubák!") % Catalog.tier_name(tier + 1)
	_say.text = text
	_button.icon = null
	_button.text = tr("Continue")
	_button.disabled = false


func _rosette(place: int) -> void:
	var r := TextureRect.new()
	r.texture = Catalog.tex(Catalog.trophy_tex({"tier": tier, "place": place}))
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size = Vector2(110, 150)
	r.position = Vector2(_stage.size.x - 130, 10)
	r.pivot_offset = r.size / 2
	r.scale = Vector2.ZERO
	r.mouse_filter = MOUSE_FILTER_IGNORE
	_stage.add_child(r)
	r.create_tween().tween_property(r, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_button() -> void:
	if _button.text == tr("Continue"):
		finished.emit()
	else:
		_stage.reward()


func _process(_delta: float) -> void:
	if _stage.in_window():
		var p := 0.75 + 0.25 * sin(Time.get_ticks_msec() / 60.0)
		_button.modulate = Color(1.0, 0.85 + 0.15 * p, 0.4 + 0.3 * p)
	elif not _button.disabled and _button.text != tr("Continue"):
		_button.modulate = Color.WHITE
