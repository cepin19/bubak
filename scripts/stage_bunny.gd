class_name StageBunny
extends Control
## Bubák drawn big, for training, grooming and the show ring. He faces right and
## performs his tricks with tweens. Pose sprites are 220x200 with his feet at (100, 194).

const Bunny := preload("res://scripts/bunny.gd")
const FEET := Vector2(100, 194)

var k := 1.5                 # drawing scale vs. the sprite
var pivot: Control           # at his feet; moved, flipped and lifted for tricks
var body: TextureRect
var hoop: TextureRect
var pose := ""
var who: Pet = null          # whose colours and outfit (null = whoever is performing)
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
	dress()


## Shows what he has on (call again after the outfit changes).
func dress() -> void:
	var p: Pet = who if who else Game.performer
	compose(body, pose, p.skin(), Game.wearing_of(p))


## Builds a bunny in `holder` (a TextureRect sized like the 220x200 pose sprite) from layers:
## body, nose, neck/eyes/head accessories, then the perky ear on top (hats have ear holes)
## with any ear clip riding on it. mirror: for a bunny facing left.
static func compose(holder: TextureRect, p: String, skin: String, outfit: Dictionary, mirror := false) -> void:
	for c in holder.get_children():
		c.free()
	if not Bunny.HEADS.has(p):
		holder.texture = Catalog.tex("bunny_" + p + skin)
		return
	var k := holder.size.x / 220.0
	holder.texture = Catalog.tex("bunny_%s_body%s" % [p, skin])
	var h: Array = Bunny.HEADS[p]
	var rot := deg_to_rad(h[2])
	var head := Vector2(h[0], h[1])
	_layer(holder, "bunny_nose", head + Vector2(40.5, 6).rotated(rot), Vector2(9.5, 10), rot, k, mirror)
	for place in ["neck", "eyes", "head"]:
		if outfit.has(place):
			var id: String = outfit[place]
			var t: Array = Bunny.wear_transform(p, id)
			var tn: String = Catalog.ITEMS[id].tex
			_layer(holder, tn, t[0], Catalog.tex(tn).get_size() / 2.0 - (t[2] as Vector2), t[1], k, mirror)
	var ear := _layer(holder, "bunny_ear" + skin, head + Vector2(-8, -26).rotated(rot), Vector2(30, 104),
		deg_to_rad(h[2] + Bunny.EAR_ANGLE[p]), k, mirror)
	if outfit.has("ear"):
		var id: String = outfit.ear
		var clip := TextureRect.new()
		clip.texture = Catalog.tex(Catalog.ITEMS[id].tex)
		clip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		clip.mouse_filter = MOUSE_FILTER_IGNORE
		clip.size = clip.texture.get_size() * k
		var c := (Vector2(30, 104) + (Bunny.WEAR_ANCHOR[id][0] as Vector2)) * k
		if mirror:
			c.x = ear.size.x - c.x
			clip.flip_h = true
		clip.position = c - clip.size / 2.0
		ear.add_child(clip)


static func _layer(holder: Control, tex_name: String, at: Vector2, pivot_tex: Vector2, rot: float, k: float,
		mirror: bool) -> TextureRect:
	var r := TextureRect.new()
	r.texture = Catalog.tex(tex_name)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.mouse_filter = MOUSE_FILTER_IGNORE
	r.size = r.texture.get_size() * k
	var pv := pivot_tex * k
	var pos := at * k - pv
	if mirror:
		pos.x = holder.size.x - (pos.x + r.size.x)
		pv.x = r.size.x - pv.x
		rot = -rot
		r.flip_h = true
	r.position = pos
	r.pivot_offset = pv
	r.rotation = rot
	holder.add_child(r)
	return r


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
	for p in _props:   # the ball, the hand, your feet: gone until a trick needs them
		if is_instance_valid(p):
			p.queue_free()
	_props = []
	pivot.position = home
	pivot.scale = Vector2.ONE
	pivot.rotation = 0
	modulate.a = 1.0
	hoop.visible = false
	set_pose("sit")
	_tw = create_tween()
	return _tw


## facing: -1 for a hop while facing left (he's flipped).
func _hop(t: Tween, from: Vector2, to: Vector2, height: float, dur: float, facing := 1.0) -> void:
	t.tween_callback(set_pose.bind("hop"))
	t.tween_method(func(v: float): pivot.position = from.lerp(to, v) - Vector2(0, sin(v * PI) * height), 0.0, 1.0, dur)
	t.tween_callback(set_pose.bind("sit"))
	t.tween_property(pivot, "scale", Vector2(1.12 * facing, 0.88), 0.06)
	t.tween_property(pivot, "scale", Vector2(facing, 1.0), 0.14).set_trans(Tween.TRANS_BACK)


## Does a trick. Returns [peaks, length] in seconds: the moments to reward him (one, or two for an
## advanced trick), and when he's done. After each peak he holds the pose for a moment.
func perform(trick: String) -> Array:
	var r: Array = _perform(trick)
	var peaks: Array = r.filter(func(x): return x > 0.0) if r.size() > 1 and r[1] > 0.0 else [r[0]]
	return [peaks, peaks[-1] + _window(peaks.size()).y + 0.3]


## When a reward counts, around a peak: tighter for the two moments of an advanced trick.
func _window(peaks: int) -> Vector2:
	return WINDOW if peaks <= 1 else WINDOW2


## A prop for a trick (removed when the next one starts).
func _prop(c: Control) -> Control:
	c.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(c)
	move_child(c, 0)
	_props.append(c)
	return c


func _perform(trick: String) -> Array:
	var t := _start()
	match trick:
		"come":
			var from := home - Vector2(size.x * 0.36, 0)
			pivot.position = from
			for i in 3:
				var a := from.lerp(home, i / 3.0)
				var b := from.lerp(home, (i + 1) / 3.0)
				_hop(t, a, b, 26 * k, 0.26)
			t.tween_interval(2.0)
			return [1.0, 0]
		"stand":
			t.tween_property(pivot, "scale", Vector2(1.08, 0.9), 0.12)
			t.tween_callback(set_pose.bind("stand"))
			t.tween_property(pivot, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)
			t.tween_interval(WINDOW.y + 0.4)
			t.tween_callback(set_pose.bind("sit"))
			return [0.35, 0]
		"spin":
			t.tween_callback(set_pose.bind("hop"))
			t.tween_property(pivot, "position:y", home.y - 30 * k, 0.15).set_ease(Tween.EASE_OUT)
			for i in 4:
				t.tween_property(pivot, "scale:x", -1.0 if i % 2 == 0 else 1.0, 0.12)
			t.tween_property(pivot, "position:y", home.y, 0.15).set_ease(Tween.EASE_IN)
			t.tween_callback(set_pose.bind("sit"))
			t.tween_property(pivot, "scale", Vector2(1.12, 0.88), 0.06)
			t.tween_property(pivot, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK)
			t.tween_interval(2.0)
			return [0.9, 0]
		"hoop":
			hoop.visible = true
			var from := home - Vector2(size.x * 0.22, 0)
			var to := home + Vector2(size.x * 0.34, 0)
			pivot.position = from
			t.tween_interval(0.25)
			_hop(t, from, to, 70 * k, 0.6)
			t.tween_interval(WINDOW.y + 0.3)
			t.tween_property(self, "modulate:a", 0.0, 0.15)
			t.tween_callback(func():
				pivot.position = home
				hoop.visible = false)
			t.tween_property(self, "modulate:a", 1.0, 0.15)
			return [0.75, 0]
		"bow":   # down on his front paws... and back up
			t.tween_callback(set_pose.bind("stand"))
			t.tween_interval(0.3)
			t.tween_callback(set_pose.bind("eat"))
			t.tween_property(pivot, "rotation", 0.18, 0.2)
			t.tween_interval(1.3)
			t.tween_property(pivot, "rotation", 0.0, 0.15)
			t.tween_callback(set_pose.bind("stand"))
			t.tween_interval(1.2)
			t.tween_callback(set_pose.bind("sit"))
			return [0.6, 2.05]
		"high_five":   # up he goes, and a paw against your hand
			var hand := _prop(UI.icon_rect("hand", 70 * k))
			hand.position = Vector2(size.x + 10, home.y - 190 * k)
			hand.rotation = -0.5
			t.tween_callback(set_pose.bind("stand"))
			t.tween_interval(1.3)
			t.tween_property(hand, "position:x", home.x + 60 * k, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_property(pivot, "position:y", home.y - 12 * k, 0.1)
			t.tween_callback(pop_text.bind(tr("five!"), Color("#e0901c")))
			t.tween_property(pivot, "position:y", home.y, 0.12)
			t.tween_interval(1.0)
			t.tween_property(hand, "position:x", size.x + 10, 0.3)
			t.tween_callback(set_pose.bind("sit"))
			return [0.35, 1.75]
		"fetch":   # the ball rolls off; after it, and back with it
			var ball := _prop(UI.icon_rect("ball", 44 * k))
			var start := home + Vector2(40 * k, -44 * k)
			var far := home + Vector2(size.x * 0.34, -44 * k)
			ball.position = start
			t.tween_property(ball, "position", far, 0.6).set_ease(Tween.EASE_OUT)
			t.parallel().tween_property(ball, "rotation", TAU, 0.6)
			_hop(t, home, home + Vector2(size.x * 0.2, 0), 24 * k, 0.3)
			_hop(t, home + Vector2(size.x * 0.2, 0), home + Vector2(size.x * 0.3, 0), 18 * k, 0.26)
			t.tween_callback(set_pose.bind("eat"))
			t.tween_interval(1.0)
			t.tween_callback(func(): pivot.scale.x = -1)
			_hop(t, home + Vector2(size.x * 0.3, 0), home + Vector2(size.x * 0.1, 0), 18 * k, 0.4, -1.0)
			t.parallel().tween_property(ball, "position", start + Vector2(size.x * 0.02, 0), 0.6)
			_hop(t, home + Vector2(size.x * 0.1, 0), home, 18 * k, 0.3, -1.0)
			t.tween_callback(func(): pivot.scale.x = 1)
			t.tween_interval(1.2)
			return [1.25, 3.05]
		"slalom":   # in and out between your feet, there and back
			for i in 2:
				var foot := _prop(ColorRect.new())
				foot.color = Color("#5b78a8")
				foot.size = Vector2(26 * k, 150 * k)
				foot.position = home + Vector2(size.x * (0.08 + 0.18 * i), -150 * k)
			var xs := [0.0, 0.17, 0.26, 0.4]
			for i in 3:
				_hop(t, home + Vector2(size.x * xs[i], 6 * k * (1 if i % 2 == 0 else -1)), home + Vector2(size.x * xs[i + 1], 6 * k * (-1 if i % 2 == 0 else 1)), 16 * k, 0.26)
			t.tween_interval(1.0)
			t.tween_callback(func(): pivot.scale.x = -1)
			for i in range(3, 0, -1):
				_hop(t, home + Vector2(size.x * xs[i], 0), home + Vector2(size.x * xs[i - 1], 0), 16 * k, 0.26, -1.0)
			t.tween_callback(func(): pivot.scale.x = 1)
			t.tween_interval(1.2)
			return [1.05, 3.1]
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
const WINDOW := Vector2(-0.2, 1.5)   # around the peak: when a treat counts as well timed
const WINDOW2 := Vector2(-0.15, 0.95)   # the same for each of an advanced trick's two moments
var _try := {}
var _tries := 0
var _props: Array = []


func attempt(trick: String, chance: float) -> void:
	var ok := randf() < chance
	var r: Array = perform(trick) if ok else [[-1.0], fumble()]
	_tries += 1
	_try = {"ok": ok, "t0": _now(), "peaks": r[0], "hits": [], "mistap": false, "result": "", "n": _tries}
	if ok:   # he's done it: make it obvious, it's time for the treat
		var w := _window(r[0].size())
		for i in r[0].size():
			get_tree().create_timer(maxf(0.0, r[0][i] + w.x)).timeout.connect(_now_cue.bind(_tries, i))
	get_tree().create_timer(r[1] + 0.15).timeout.connect(_attempt_end)


func _now_cue(n: int, peak := 0) -> void:
	if _try.get("n", -1) != n or _try.result != "" or peak in _try.hits:
		return
	Sfx.play("sparkle")
	for i in 3:
		pop_icon("star", pivot.position + Vector2(-70 + 60 * i, -165) * k)
	# a big "Now!" at the top of the mat that stays while the window is open
	var l := UI.label(tr("Now!"), 52, Color("#e0901c"))
	l.add_theme_color_override("font_outline_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 14)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(size.x, 70)
	l.position = Vector2(0, 6)
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2(0.4, 0.4)
	add_child(l)
	var t := l.create_tween()
	t.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var w := _window(_try.peaks.size())
	t.tween_interval(maxf(0.2, w.y - w.x - 0.55))
	t.tween_property(l, "modulate:a", 0.0, 0.3)
	t.tween_callback(l.queue_free)


## The peak whose reward window is open now (-1 if none).
func _open_peak() -> int:
	if _try.is_empty() or not _try.ok or _try.result != "":
		return -1
	var dt: float = _now() - _try.t0
	var w := _window(_try.peaks.size())
	for i in _try.peaks.size():
		if not i in _try.hits and dt >= _try.peaks[i] + w.x and dt <= _try.peaks[i] + w.y:
			return i
	return -1


## How much of the reward window is left (1 = just opened, 0 = closed or not open).
func window_left() -> float:
	var i := _open_peak()
	if i < 0:
		return 0.0
	var w := _window(_try.peaks.size())
	var dt: float = _now() - _try.t0 - (_try.peaks[i] + w.x)
	return clampf(1.0 - dt / (w.y - w.x), 0.0, 1.0)


func attempting() -> bool:
	return not _try.is_empty()


func in_window() -> bool:
	return _open_peak() >= 0


## The player pressed Reward. Returns the result (or "" if there's nothing to reward, or more to come).
func reward() -> String:
	if _try.is_empty() or _try.result != "":
		return ""
	if not _try.ok:
		_try.result = "wrong"
		pop_text("?")
		return _try.result
	var i := _open_peak()
	if i >= 0:
		_try.hits.append(i)
		pop_icon("heart")
		if _try.hits.size() >= _try.peaks.size():
			_try.result = "late" if _try.mistap else "good"
			pop_icon("heart")
		return _try.result
	if _try.peaks.size() > 1:   # an advanced trick: a treat at the wrong moment, but it isn't over yet
		_try.mistap = true
		return ""
	_try.result = "late"
	pop_icon("heart")
	return _try.result


func _attempt_end() -> void:
	if _try.is_empty():
		return
	var res: String = _try.result
	if res == "":
		if _try.ok:
			res = "late" if not _try.hits.is_empty() or _try.mistap else "missed"
		else:
			res = "ignored"
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
