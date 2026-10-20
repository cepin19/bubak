extends Control
## Video call: react to what happens in the meeting by pressing the right button in time.
## Sometimes Bubák photobombs your camera: tap him for a bonus (your colleagues love him).

const ACTIONS := ["nod", "mic", "laugh", "hand"]

var ctl: Node
var _prompt := ""
var _prompt_t := 0.0
var _prompt_len := 2.0
var _gap := 0.6
var _bubble: Label
var _timer: ProgressBar
var _bunny: TextureButton
var _bunny_t := 4.0
var _you: Panel
var _tiles: Array = []


func _ready() -> void:
	# 2x2 call grid on the left: three colleagues and you
	var tints := [Color("#e9a3a0"), Color("#a7c0e8"), Color("#9cc5a1")]
	for i in 4:
		var tile := Panel.new()
		tile.position = Vector2(20 + (i % 2) * 250, 18 + (i / 2) * 178)
		tile.size = Vector2(238, 166)
		tile.clip_contents = true
		tile.add_theme_stylebox_override("panel", UI.box(Color("#20344f"), 12, 2, false))
		add_child(tile)
		_tiles.append(tile)
		var face := TextureRect.new()
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.mouse_filter = MOUSE_FILTER_IGNORE
		if i < 3:
			face.texture = Catalog.icon("follower")
			face.modulate = tints[i]
			face.position = Vector2(54, 18)
			face.size = Vector2(130, 130)
		else:
			face.texture = Catalog.tex("owner")
			face.position = Vector2(30, 6)
			face.size = Vector2(178, 212)
			_you = tile
		tile.add_child(face)
	_bunny = TextureButton.new()
	_bunny.texture_normal = Catalog.tex("icon")
	_bunny.ignore_texture_size = true
	_bunny.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_bunny.size = Vector2(110, 110)
	_bunny.position = Vector2(120, 170)
	_bunny.pressed.connect(_on_bunny)
	_you.add_child(_bunny)
	# speech bubble + timer on the right
	var bubble := PanelContainer.new()
	bubble.position = Vector2(530, 30)
	bubble.custom_minimum_size = Vector2(270, 150)
	add_child(bubble)
	var bv := UI.vbox(10)
	bubble.add_child(bv)
	_bubble = UI.wrap_label("", 22, 240)
	_bubble.custom_minimum_size.y = 96
	_bubble.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bv.add_child(_bubble)
	_timer = ProgressBar.new()
	_timer.custom_minimum_size = Vector2(240, 12)
	_timer.show_percentage = false
	_timer.max_value = 1.0
	_timer.step = 0.001
	bv.add_child(_timer)
	# answer buttons
	var names := {"nod": tr("Nod"), "mic": tr("Unmute"), "laugh": tr("Laugh"), "hand": tr("Wave")}
	for i in ACTIONS.size():
		var b := UI.big_button(ACTIONS[i], names[ACTIONS[i]], 84)
		b.position = Vector2(540 + (i % 2) * 130, 205 + (i / 2) * 104)
		b.custom_minimum_size = Vector2(120, 96)
		b.pressed.connect(_answer.bind(ACTIONS[i], b))
		add_child(b)
	_bubble.text = tr("The meeting is starting...")


func _process(delta: float) -> void:
	if not ctl.is_running():
		return
	if _prompt == "":
		_gap -= delta
		if _gap <= 0:
			_new_prompt()
	else:
		_prompt_t -= delta
		_timer.value = _prompt_t / _prompt_len
		if _prompt_t <= 0:
			ctl.miss()
			ctl.float_text(tr("Too slow!"), Vector2(560, 160), Color("#ff9a9a"))
			_prompt = ""
			_gap = 0.5
	_bunny_t -= delta
	if _bunny_t <= 0:
		_bunny_t = randf_range(4.0, 7.0)
		_photobomb()


func _new_prompt() -> void:
	_prompt = ACTIONS.pick_random()
	_prompt_len = lerpf(2.2, 1.2, ctl.progress())
	_prompt_t = _prompt_len
	_bubble.text = {"nod": tr("\"Does everyone agree?\""), "mic": tr("\"Hello? You're on mute!\""),
		"laugh": tr("The boss made a joke."), "hand": [tr("\"Hi everyone!\""), tr("\"Bye, see you tomorrow!\"")].pick_random()}[_prompt]


func _answer(action: String, b: Control) -> void:
	if _prompt == "" or not ctl.is_running():
		return
	if action == _prompt:
		ctl.hit(b.position + Vector2(0, -30))
		var tile: Panel = _tiles[randi() % 3]   # a colleague lights up
		var t := tile.create_tween()
		t.tween_property(tile, "modulate", Color(1.3, 1.5, 1.2), 0.08)
		t.tween_property(tile, "modulate", Color.WHITE, 0.3)
	else:
		ctl.miss()
		ctl.float_text(tr("Awkward..."), b.position + Vector2(0, -30), Color("#ff9a9a"))
	_prompt = ""
	_bubble.text = "..."
	_timer.value = 0
	_gap = 0.35


func _photobomb() -> void:
	_bunny.set_meta("tapped", false)
	var t := _bunny.create_tween()
	t.tween_property(_bunny, "position:y", 60.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(1.4)
	t.tween_property(_bunny, "position:y", 170.0, 0.25)


func _on_bunny() -> void:
	if _bunny.get_meta("tapped", true) or not ctl.is_running():
		return
	_bunny.set_meta("tapped", true)
	Game.followers += 2
	ctl.hit(_you.position + Vector2(40, 40), 3)
	ctl.float_text(tr("Colleagues love Bubák!"), _you.position + Vector2(0, 100))
