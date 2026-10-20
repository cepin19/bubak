class_name StageBunny
extends Control
## Bubák drawn big, for training, grooming and the show ring. He faces right and
## performs his tricks with tweens. Pose sprites are 220x200 with his feet at (100, 194).

const Bunny := preload("res://scripts/bunny.gd")
const FEET := Vector2(100, 194)

var k := 1.5                 # drawing scale vs. the sprite
var pivot: Control           # at his feet; moved, flipped and lifted for tricks
var body: TextureRect
var wear: TextureRect
var hoop: TextureRect
var pose := ""
var home := Vector2.ZERO
var _blink_t := 3.0
var _tw: Tween


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	hoop = TextureRect.new()
	hoop.texture = Catalog.tex("hoop")
	hoop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hoop.mouse_filter = MOUSE_FILTER_IGNORE
	hoop.visible = false
	add_child(hoop)
	pivot = Control.new()
	pivot.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(pivot)
	body = TextureRect.new()
	body.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	body.mouse_filter = MOUSE_FILTER_IGNORE
	body.size = Vector2(220, 200) * k
	body.position = -FEET * k
	pivot.add_child(body)
	wear = TextureRect.new()
	wear.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wear.mouse_filter = MOUSE_FILTER_IGNORE
	body.add_child(wear)
	set_pose("sit")
	resized.connect(_place_home)
	_place_home()


func _place_home() -> void:
	home = Vector2(size.x * 0.5 - 20 * k, size.y - 18)
	if _tw == null or not _tw.is_valid():
		pivot.position = home
	hoop.size = Vector2(120, 160) * k * 0.8
	hoop.position = home + Vector2(30 * k, 0) - Vector2(hoop.size.x / 2, hoop.size.y - 4)


func set_pose(p: String) -> void:
	if p == pose:
		return
	pose = p
	body.texture = Catalog.tex("bunny_" + p)
	wear.visible = Game.wearing != "" and Bunny.HEADS.has(p)
	if wear.visible:
		var t: Array = Bunny.wear_transform(p, Game.wearing)
		var tex := Catalog.tex(Catalog.ITEMS[Game.wearing].tex)
		wear.texture = tex
		wear.size = tex.get_size() * k
		wear.position = ((t[0] as Vector2) + (t[2] as Vector2)) * k - wear.size / 2.0
		wear.pivot_offset = wear.size / 2.0
		wear.rotation = t[1]


## Sprite coordinates (e.g. a spot on his back) to this control's coordinates, while resting.
func sprite_point(p: Vector2) -> Vector2:
	return home + (p - FEET) * k


func _process(delta: float) -> void:
	queue_redraw()
	if pose == "sit" or pose == "blink":
		_blink_t -= delta
		if _blink_t <= 0:
			if pose == "sit":
				set_pose("blink")
				_blink_t = 0.14
			else:
				set_pose("sit")
				_blink_t = randf_range(2.0, 5.0)


func _draw() -> void:
	var lift := clampf((home.y - pivot.position.y) / 150.0, 0, 0.7)
	var w := 150.0 * k * (1.0 - lift * 0.5)
	draw_texture_rect(Catalog.soft_circle(), Rect2(pivot.position.x + 6 * k - w / 2, home.y - w * 0.12, w, w * 0.24),
		false, Color(0.28, 0.16, 0.1, 0.35 * (1.0 - lift)))


func _start() -> Tween:
	if _tw and _tw.is_valid():
		_tw.kill()
	pivot.position = home
	pivot.scale = Vector2.ONE
	pivot.rotation = 0
	modulate.a = 1.0
	hoop.visible = false
	set_pose("sit")
	_tw = create_tween()
	return _tw


func _hop(t: Tween, from: Vector2, to: Vector2, height: float, dur: float) -> void:
	t.tween_callback(set_pose.bind("hop"))
	t.tween_method(func(v: float): pivot.position = from.lerp(to, v) - Vector2(0, sin(v * PI) * height), 0.0, 1.0, dur)
	t.tween_callback(set_pose.bind("sit"))
	t.tween_property(pivot, "scale", Vector2(1.12, 0.88), 0.06)
	t.tween_property(pivot, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK)


## Does a trick. Returns [peak, length] in seconds: the moment to reward him, and when he's done.
func perform(trick: String) -> Array:
	var t := _start()
	match trick:
		"come":
			var from := home - Vector2(size.x * 0.36, 0)
			pivot.position = from
			for i in 3:
				var a := from.lerp(home, i / 3.0)
				var b := from.lerp(home, (i + 1) / 3.0)
				_hop(t, a, b, 26 * k, 0.26)
			t.tween_interval(0.6)
			return [0.95, 1.6]
		"stand":
			t.tween_property(pivot, "scale", Vector2(1.08, 0.9), 0.12)
			t.tween_callback(set_pose.bind("stand"))
			t.tween_property(pivot, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)
			t.tween_interval(1.0)
			t.tween_callback(set_pose.bind("sit"))
			return [0.4, 1.4]
		"spin":
			t.tween_callback(set_pose.bind("hop"))
			t.tween_property(pivot, "position:y", home.y - 30 * k, 0.15).set_ease(Tween.EASE_OUT)
			for i in 4:
				t.tween_property(pivot, "scale:x", -1.0 if i % 2 == 0 else 1.0, 0.12)
			t.tween_property(pivot, "position:y", home.y, 0.15).set_ease(Tween.EASE_IN)
			t.tween_callback(set_pose.bind("sit"))
			t.tween_property(pivot, "scale", Vector2(1.12, 0.88), 0.06)
			t.tween_property(pivot, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK)
			t.tween_interval(0.4)
			return [0.8, 1.4]
		"hoop":
			hoop.visible = true
			var from := home - Vector2(size.x * 0.22, 0)
			var to := home + Vector2(size.x * 0.34, 0)
			pivot.position = from
			t.tween_interval(0.25)
			_hop(t, from, to, 70 * k, 0.6)
			t.tween_interval(0.35)
			t.tween_property(self, "modulate:a", 0.0, 0.15)
			t.tween_callback(func():
				pivot.position = home
				hoop.visible = false)
			t.tween_property(self, "modulate:a", 1.0, 0.15)
			return [0.58, 1.5]
	return [0.0, 0.0]


## Gets distracted instead of doing the trick. Returns how long it takes.
func fumble() -> float:
	var t := _start()
	match randi() % 3:
		0:   # a quick face wash
			t.tween_callback(set_pose.bind("eat"))
			for i in 4:
				t.tween_property(pivot, "rotation", -0.1, 0.14)
				t.tween_property(pivot, "rotation", 0.05, 0.14)
			t.tween_property(pivot, "rotation", 0.0, 0.1)
			t.tween_callback(set_pose.bind("sit"))
		1:   # flops down for a rest
			t.tween_callback(set_pose.bind("loaf"))
			t.tween_interval(1.2)
			t.tween_callback(set_pose.bind("sit"))
		_:   # wanders off to sniff something
			_hop(t, home, home + Vector2(size.x * 0.2, 0), 14 * k, 0.3)
			t.tween_interval(0.5)
			t.tween_callback(func(): pivot.scale.x = -1)
			_hop(t, home + Vector2(size.x * 0.2, 0), home, 14 * k, 0.3)
			t.tween_callback(func(): pivot.scale.x = 1)
	pop_text("?")
	return 1.4


## One go at a trick: he gets it right (chance) or gets distracted, and the player
## rewards him, or not. Ends with attempt_done(result):
##   good    - rewarded at the right moment       late   - rewarded, but too early or late
##   missed  - did it, but no reward came          wrong  - rewarded for getting distracted
##   ignored - got distracted and wasn't rewarded (that's correct)
signal attempt_done(result: String)
const WINDOW := Vector2(-0.15, 0.5)   # around the peak
var _try := {}


func attempt(trick: String, chance: float) -> void:
	var ok := randf() < chance
	var r: Array = perform(trick) if ok else [-1.0, fumble()]
	_try = {"ok": ok, "t0": _now(), "peak": r[0], "result": ""}
	get_tree().create_timer(r[1] + 0.15).timeout.connect(_attempt_end)


func attempting() -> bool:
	return not _try.is_empty()


func in_window() -> bool:
	if _try.is_empty() or not _try.ok or _try.result != "":
		return false
	var dt: float = _now() - _try.t0
	return dt >= _try.peak + WINDOW.x and dt <= _try.peak + WINDOW.y


## The player pressed Reward. Returns the result (or "" if there's nothing to reward).
func reward() -> String:
	if _try.is_empty() or _try.result != "":
		return ""
	if not _try.ok:
		_try.result = "wrong"
		pop_text("?")
	elif in_window():
		_try.result = "good"
		pop_icon("heart")
		pop_icon("heart")
	else:
		_try.result = "late"
		pop_icon("heart")
	return _try.result


func _attempt_end() -> void:
	if _try.is_empty():
		return
	var res: String = _try.result
	if res == "":
		res = "missed" if _try.ok else "ignored"
	_try = {}
	attempt_done.emit(res)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## Squirms (grooming or nail trims he isn't ready for).
func wriggle() -> void:
	var keep := pose
	var t := _start()
	set_pose(keep)
	for i in 4:
		t.tween_property(pivot, "rotation", 0.12, 0.06)
		t.tween_property(pivot, "rotation", -0.12, 0.06)
	t.tween_property(pivot, "rotation", 0.0, 0.06)


func happy() -> void:
	var t := _start()
	_hop(t, home, home, 50 * k, 0.4)


## A word or symbol floating up from his head.
func pop_text(text: String, color := UI.INK) -> void:
	var l := UI.label(text, 34, color)
	l.add_theme_color_override("font_outline_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 10)
	l.position = pivot.position + Vector2(10, -170) * k
	add_child(l)
	var t := l.create_tween().set_parallel()
	t.tween_property(l, "position:y", l.position.y - 50, 1.0).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.6)
	t.chain().tween_callback(l.queue_free)


func pop_icon(icon: String, at := Vector2.ZERO) -> void:
	var r := UI.icon_rect(icon, 40)
	r.position = (pivot.position + Vector2(30, -150) * k if at == Vector2.ZERO else at) + Vector2(randf_range(-30, 30), 0)
	add_child(r)
	var t := r.create_tween().set_parallel()
	t.tween_property(r, "position:y", r.position.y - 70, 1.1).set_ease(Tween.EASE_OUT)
	t.tween_property(r, "modulate:a", 0.0, 0.4).set_delay(0.7)
	t.chain().tween_callback(r.queue_free)
