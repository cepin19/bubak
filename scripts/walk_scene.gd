class_name WalkScene
extends Control
## A walk with Bubák on his leash: a cutscene with no buttons, about half a minute long. He hops in
## on his harness, has a string of little adventures that depend on the place, and hops off home.
## The place scrolls by while he travels. Emits finished when it's over (and then frees itself).

signal finished

const ART_W := 1600.0
const ART_H := 720.0
const GROUND := 640.0   # feet line in the background art (see tools/gen_art.py)
const SCREEN := Rect2(300, 80, 1000, 340)   # the cinema screen, in background art coordinates

var place := "park"
var speed := 1.0        # >1 plays it faster (playtests)
var _s := 1.0           # art scale to the screen
var _vs := Vector2.ZERO
var _pan_left := 0.0    # how far the background can scroll in all
var _bg: TextureRect
var _bunny: StageBunny
var _over: Control      # leash and harness, on top of Bubák
var _caption: Label
var _caption_box: PanelContainer
var _fade: ColorRect
var _hand := Vector2.ZERO
var _fx: Array = []     # [node, update callable(node, delta)]: things that move on their own


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP   # nothing to do but watch
	clip_contents = true
	_vs = get_viewport().get_visible_rect().size
	_s = maxf(_vs.y / ART_H, _vs.x / ART_W)
	_bg = TextureRect.new()
	_bg.texture = Catalog.tex("walk_" + place)
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.size = Vector2(ART_W, ART_H) * _s
	_bg.position = Vector2(0, _vs.y - _bg.size.y)
	_bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_bg)
	_pan_left = _bg.size.x - _vs.x
	var ground := _bg.position.y + GROUND * _s
	if place == "cinema":
		ground -= 34 * _s   # up on the seat
	_bunny = StageBunny.new()
	_bunny.k = 1.15 * _s
	_bunny.size = _vs
	_bunny.position = Vector2(0, ground - _vs.y + 18)
	add_child(_bunny)
	_over = Control.new()
	_over.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_over.mouse_filter = MOUSE_FILTER_IGNORE
	_over.draw.connect(_draw_leash)
	add_child(_over)
	_caption_box = PanelContainer.new()
	var cs := UI.box(Color(UI.CREAM, 0.92), 18)
	cs.set_content_margin_all(14)
	cs.content_margin_left = 26
	cs.content_margin_right = 26
	_caption_box.add_theme_stylebox_override("panel", cs)
	_caption = UI.label("", 26)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption_box.add_child(_caption)
	_caption_box.modulate.a = 0.0
	add_child(_caption_box)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_fade.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_fade)
	_run()


func _process(delta: float) -> void:
	# whoever holds the leash walks along just above the top of the screen
	var aim := Vector2(_feet().x - 230 * _s, -30)
	_hand = aim if _hand == Vector2.ZERO else _hand.lerp(aim, minf(1.0, delta * 3.0))
	for f in _fx.duplicate():
		if is_instance_valid(f[0]):
			f[1].call(f[0], delta * speed)
		else:
			_fx.erase(f)
	_over.queue_redraw()


# ---- drawing helpers -----------------------------------------------------------------

func _feet() -> Vector2:
	return _bunny.position + _bunny.pivot.position


## A point on him in sprite coordinates, relative to his head in the current pose.
func _at_head(off: Vector2) -> Vector2:
	var head: Array = StageBunny.Bunny.HEADS.get(_bunny.pose, [146, 92, 0])
	var p := (Vector2(head[0], head[1]) + off - StageBunny.FEET) * _bunny.k
	p.x *= signf(_bunny.pivot.scale.x)
	return _feet() + p.rotated(_bunny.pivot.rotation)


func _mouth() -> Vector2:
	return _at_head(Vector2(44, 14))


func _draw_leash() -> void:
	var n := _at_head(Vector2(-44, 30))   # the ring on his back, just behind the head
	# a red harness strap round his neck, and the leash sagging up to the hand
	var strap := PackedVector2Array([n, _at_head(Vector2(-22, 44)), _at_head(Vector2(-4, 50))])
	_over.draw_polyline(strap, Color(UI.INK), 9 * _s, true)
	_over.draw_polyline(strap, Color("#e8505b"), 6 * _s, true)
	var pts := PackedVector2Array()
	for i in 17:
		var t := i / 16.0
		pts.append(_hand.lerp(n, t) + Vector2(0, sin(t * PI) * 60.0 * _s))
	_over.draw_polyline(pts, Color(UI.INK), 7 * _s, true)
	_over.draw_polyline(pts, Color("#e8505b"), 4 * _s, true)
	_over.draw_circle(n, 5 * _s, Color("#c9ccd6"))


## A picture standing on `foot` (its bottom centre). front: in front of Bubák, else behind him.
func _prop(tex: Texture2D, foot: Vector2, scl := 1.0, front := true) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.mouse_filter = MOUSE_FILTER_IGNORE
	r.size = tex.get_size() * _s * scl
	r.position = foot - Vector2(r.size.x / 2, r.size.y)
	r.pivot_offset = Vector2(r.size.x / 2, r.size.y)
	add_child(r)
	move_child(r, _over.get_index() if front else _bunny.get_index())
	return r


func _gone(n: Control, t := 0.4) -> void:
	var tw := n.create_tween()
	tw.tween_property(n, "modulate:a", 0.0, t / speed)
	tw.tween_callback(n.queue_free)


func _overlay(color: Color) -> ColorRect:
	var c := ColorRect.new()
	c.color = color
	c.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	c.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(c)
	move_child(c, _caption_box.get_index())
	return c


# ---- timing and captions ------------------------------------------------------------------

const PACE := 1.3   # time to read the captions: all pauses are stretched by this


func _wait(t: float) -> void:
	await get_tree().create_timer(t * PACE / speed).timeout


func _say(text: String) -> void:
	_caption.text = text
	_caption_box.size = _caption_box.get_combined_minimum_size()
	_caption_box.position = Vector2((_vs.x - _caption_box.size.x) / 2.0, 24)
	_caption_box.modulate.a = 0.0
	_caption_box.create_tween().tween_property(_caption_box, "modulate:a", 1.0, 0.3 / speed)


func _unsay() -> void:
	_caption_box.create_tween().tween_property(_caption_box, "modulate:a", 0.0, 0.3 / speed)


# ---- moving him ---------------------------------------------------------------------------

## Hops dx (screen pixels) in n hops; meanwhile the place scrolls by `pan` (a share of the full scroll).
func _hops(dx: float, n: int, pan := 0.0, height := 22.0, each := 0.32) -> void:
	var facing := -1.0 if dx < 0 else 1.0
	_bunny.pivot.scale.x = facing
	var t := _bunny.create_tween()
	var p := _bunny.pivot.position
	for i in n:
		_bunny._hop(t, p + Vector2(dx * i / n, 0), p + Vector2(dx * (i + 1) / n, 0), height * _s, each / speed, facing)
		t.tween_callback(Sfx.play.bind("hop"))
	if pan > 0.0:
		var by := minf(pan * _pan_left, _bg.position.x + _bg.size.x - _vs.x)
		create_tween().tween_property(_bg, "position:x", _bg.position.x - by, n * (each / speed + 0.2)) \
			.set_trans(Tween.TRANS_SINE)
	await t.finished


func _face(dir: float) -> void:
	_bunny.pivot.scale.x = dir


func _binky() -> void:
	var b := _bunny
	var t := b.create_tween()
	var p := b.pivot.position
	b._hop(t, p, p + Vector2(30 * _s, 0), 110 * _s, 0.55 / speed)
	var r := b.create_tween()
	r.tween_property(b.pivot, "rotation", -0.5, 0.2 / speed)
	r.tween_property(b.pivot, "rotation", 0.3, 0.15 / speed)
	r.tween_property(b.pivot, "rotation", 0.0, 0.15 / speed)
	Sfx.play("boing")
	await t.finished


func _spin() -> void:
	var b := _bunny
	var t := b.create_tween()
	var y := b.pivot.position.y
	t.tween_callback(b.set_pose.bind("hop"))
	t.tween_property(b.pivot, "position:y", y - 40 * _s, 0.15 / speed)
	for i in 4:
		t.tween_property(b.pivot, "scale:x", -1.0 if i % 2 == 0 else 1.0, 0.12 / speed)
	t.tween_property(b.pivot, "position:y", y, 0.15 / speed)
	t.tween_callback(b.set_pose.bind("sit"))
	Sfx.play("boing", 1.2)
	await t.finished


func _thump() -> void:
	var t := _bunny.create_tween().set_loops(2)
	t.tween_property(_bunny.pivot, "scale", Vector2(1.12, 0.84), 0.09)
	t.tween_property(_bunny.pivot, "scale", Vector2.ONE, 0.12)
	Sfx.play("thump")
	_bunny.pop_text(tr("THUMP!"))


func _hearts(n := 2) -> void:
	for i in n:
		_bunny.pop_icon("heart")
	Sfx.play("love")


# ---- the walk -------------------------------------------------------------------------------

func _run() -> void:
	var titles := {"park": tr("A walk in the park"), "field": tr("Off to the meadow"), "beach": tr("A day at the beach"),
		"city": tr("A stroll through town"), "cinema": tr("Movie night")}
	_bunny.pivot.position = Vector2(-140 * _s, _bunny.home.y)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.8 / speed)
	_say(titles[place])
	await _hops(_vs.x * 0.3 + 140 * _s, 5)
	await _wait(0.6)
	_unsay()
	await _wait(0.3)
	match place:
		"park": await _park()
		"field": await _field()
		"beach": await _beach()
		"city": await _city()
		"cinema": await _cinema()
	_say(tr("Time to head home."))
	_face(1)
	await _hops(_vs.x * 0.85, 7, 1.0)
	var out := create_tween()
	out.tween_property(_fade, "color:a", 1.0, 0.6 / speed)
	await out.finished
	finished.emit()
	queue_free()


func _park() -> void:
	var b := _bunny
	_say(tr("He sniffs every single flower."))
	b.set_pose("eat")
	await _wait(1.4)
	b.set_pose("sit")
	await _wait(0.4)
	b.set_pose("eat")
	await _wait(1.2)
	b.set_pose("sit")
	# a butterfly flutters in and lands on his nose
	var fly := _prop(Catalog.tex("butterfly"), Vector2(_vs.x + 60, _vs.y * 0.3), 1.7)
	var land := _at_head(Vector2(52, -6)) + Vector2(0, fly.size.y * 0.5)
	var ft := fly.create_tween()
	ft.tween_property(fly, "position", land - Vector2(fly.size.x / 2, fly.size.y), 2.2 / speed).set_trans(Tween.TRANS_SINE)
	_fx.append([fly, func(n: Control, _d: float): n.scale.y = 0.6 + 0.4 * absf(sin(Time.get_ticks_msec() / 70.0))])
	_say(tr("A butterfly! It lands right on his nose."))
	await ft.finished
	b.pop_text("!")
	Sfx.play("surprise")
	await _wait(1.8)
	_say(tr("...and off it goes. After it!"))
	var away := fly.create_tween()
	away.tween_property(fly, "position", fly.position + Vector2(_vs.x * 0.7, -_vs.y * 0.35), 2.4 / speed)
	away.tween_callback(fly.queue_free)
	await _hops(_vs.x * 0.25, 4, 0.45, 26.0, 0.26)
	b.set_pose("stand")
	await _wait(1.4)
	b.set_pose("sit")
	_say(tr("Phew. A little nap under the tree."))
	b.set_pose("loaf")
	await _wait(1.0)
	b.set_pose("sleep")
	for i in 3:
		b.pop_text("z")
		await _wait(0.8)
	b.set_pose("sit")
	_hearts()
	await _wait(1.0)


func _field() -> void:
	var b := _bunny
	_say(tr("So much grass! He does a binky..."))
	await _binky()
	await _wait(0.4)
	_say(tr("...and another one!"))
	await _binky()
	await _wait(0.5)
	_say(tr("Zoomies!"))
	for i in 3:
		await _hops(_vs.x * 0.22 * (1 if i % 2 == 0 else -1), 3, 0.0, 30.0, 0.2)
	_face(1)
	await _wait(0.3)
	_say(tr("A dandelion! Munch, munch, munch."))
	b.set_pose("eat")
	var flower := _prop(Catalog.icon("dandelion"), _mouth() + Vector2(30 * _s, 40 * _s), 1.6)
	for i in 5:
		Sfx.play("munch")
		flower.scale = Vector2.ONE * (1.0 - 0.14 * (i + 1))
		await _wait(0.5)
	flower.queue_free()
	b.set_pose("sit")
	await _wait(0.4)
	_say(tr("Full and happy. Flop!"))
	b.set_pose("flop")
	Sfx.play("hop", 0.7)
	await _wait(0.6)
	_hearts(3)
	await _wait(2.2)
	b.set_pose("sit")


func _beach() -> void:
	var b := _bunny
	_say(tr("He digs a very serious hole."))
	b.set_pose("eat")
	for i in 9:
		_sand()
		Sfx.play("dig")
		await _wait(0.22)
	b.set_pose("sit")
	var shell := _prop(Catalog.tex("walk_shell"), _feet() + Vector2(-70 * _s, 0), 1.2)
	shell.scale = Vector2(0.2, 0.2)
	shell.create_tween().tween_property(shell, "scale", Vector2.ONE, 0.3 / speed).set_trans(Tween.TRANS_BACK)
	Sfx.play("sparkle")
	_say(tr("Look what he found: a seashell!"))
	_face(-1)
	b.set_pose("eat")
	await _wait(1.6)
	b.set_pose("sit")
	_face(1)
	# a wave rolls up the sand
	var wave := _prop(Catalog.tex("walk_wave"), Vector2(_vs.x / 2, _feet().y - 70 * _s), 1.6, false)
	wave.modulate.a = 0.0
	var wt := wave.create_tween()
	wt.tween_property(wave, "modulate:a", 1.0, 0.3 / speed)
	wt.parallel().tween_property(wave, "position:y", wave.position.y + 70 * _s, 1.0 / speed).set_trans(Tween.TRANS_SINE)
	Sfx.play("water")
	_say(tr("Here comes a wave! Nope, nope, nope."))
	b.pop_text("!")
	await _hops(_vs.x * 0.16, 2, 0.0, 34.0, 0.22)
	var back := wave.create_tween()
	back.tween_property(wave, "position:y", wave.position.y - 40 * _s, 1.0 / speed)
	back.parallel().tween_property(wave, "modulate:a", 0.0, 1.0 / speed)
	back.tween_callback(wave.queue_free)
	_gone(shell)
	await _wait(0.8)
	# a crab scuttles by
	var crab := _prop(Catalog.tex("walk_crab"), Vector2(_vs.x + 80 * _s, _feet().y + 6 * _s), 1.0)
	var stop_x := _feet().x + 190 * _s
	var ct := crab.create_tween()
	ct.tween_property(crab, "position:x", stop_x - crab.size.x / 2, 1.6 / speed)
	_fx.append([crab, func(n: Control, _d: float): n.rotation = 0.08 * sin(Time.get_ticks_msec() / 60.0)])
	_say(tr("A crab! They have a long, serious stare."))
	await ct.finished
	b.set_pose("stand")
	await _wait(2.0)
	b.set_pose("sit")
	var cgo := crab.create_tween()
	cgo.tween_property(crab, "position:x", _vs.x + 100 * _s, 1.4 / speed)
	cgo.tween_callback(crab.queue_free)
	await _wait(0.8)
	# a seagull comes for a look and gets thumped at
	var gull := _prop(Catalog.tex("walk_gull"), Vector2(_feet().x + 230 * _s, -40), 1.0)
	gull.flip_h = true
	var gt := gull.create_tween()
	gt.tween_property(gull, "position:y", _feet().y - gull.size.y, 1.2 / speed).set_trans(Tween.TRANS_SINE)
	Sfx.play("chirp", 0.7)
	_say(tr("A seagull eyes him up. THUMP! Off you go."))
	await gt.finished
	await _wait(0.5)
	_thump()
	await _wait(0.5)
	var gup := gull.create_tween()
	gup.tween_property(gull, "position", Vector2(_vs.x + 200 * _s, -200 * _s), 1.2 / speed)
	gup.tween_callback(gull.queue_free)
	await _wait(1.4)
	# the sun goes down
	var dusk := _overlay(Color(1.0, 0.55, 0.3, 0.0))
	dusk.create_tween().tween_property(dusk, "color:a", 0.28, 2.0 / speed)
	_say(tr("Then they watch the sun go down together."))
	b.set_pose("loaf")
	_hearts()
	await _wait(3.0)
	b.set_pose("sit")


func _city() -> void:
	var b := _bunny
	# a pigeon struts alongside
	var pig := _prop(Catalog.tex("bird"), _feet() + Vector2(150 * _s, 4 * _s), 1.1)
	pig.modulate = Color(0.75, 0.75, 0.82)
	pig.flip_h = true
	_say(tr("A pigeon joins the walk."))
	for i in 4:
		var pt := pig.create_tween()
		pt.tween_property(pig, "position:y", pig.position.y - 14 * _s, 0.12 / speed)
		pt.tween_property(pig, "position:y", pig.position.y, 0.12 / speed)
		await _wait(0.45)
	Sfx.play("chirp", 0.6)
	var pgo := pig.create_tween()
	pgo.tween_property(pig, "position", pig.position + Vector2(300 * _s, -400 * _s), 1.0 / speed)
	pgo.tween_callback(pig.queue_free)
	await _hops(_vs.x * 0.12, 3, 0.45)
	# café stop
	_say(tr("A café stop. The waiter brings him a carrot!"))
	var plate := _prop(Catalog.tex("walk_plate"), _feet() + Vector2(110 * _s, 4 * _s), 1.2)
	plate.modulate.a = 0.0
	plate.create_tween().tween_property(plate, "modulate:a", 1.0, 0.4 / speed)
	await _wait(1.2)
	b.set_pose("eat")
	for i in 5:
		Sfx.play("munch")
		await _wait(0.5)
	b.set_pose("sit")
	_gone(plate)
	_hearts()
	await _wait(0.6)
	# fans
	_say(tr("Everyone on the street stops to say hi."))
	for i in 4:
		await _wait(0.5)
		_camera_flash()
		b.pop_icon("heart")
	_say(tr("He shows off a trick for them!"))
	await _wait(0.6)
	await _spin()
	await _wait(0.2)
	for i in 3:
		b.pop_icon("star")
	Sfx.play("streak")
	_say(tr("Applause! Some of them already follow him online."))
	await _wait(2.4)


func _cinema() -> void:
	var b := _bunny
	var pop := _prop(Catalog.tex("walk_popcorn"), _feet() + Vector2(150 * _s, 2 * _s), 1.2)
	_say(tr("Popcorn and a film about carrots."))
	await _wait(1.6)
	_say(tr("Crunch, crunch, crunch."))
	b.set_pose("eat")
	for i in 6:
		_kernel(pop)
		await _wait(0.45)
	b.set_pose("sit")
	await _wait(0.4)
	# the scary bit: the screen goes red and he hides behind the popcorn
	var tint := ColorRect.new()
	tint.color = Color(0.8, 0.1, 0.15, 0.0)
	tint.position = SCREEN.position * _s
	tint.size = SCREEN.size * _s
	tint.mouse_filter = MOUSE_FILTER_IGNORE
	_bg.add_child(tint)
	tint.create_tween().tween_property(tint, "color:a", 0.55, 0.5 / speed)
	_say(tr("Uh oh, a scary bit!"))
	b.pop_text("!")
	Sfx.play("thump", 0.8)
	await _wait(0.4)
	await _hops(150 * _s, 2, 0.0, 26.0, 0.22)   # behind the bucket: only his ears peek out
	await _wait(2.2)
	var happy := tint.create_tween()
	happy.tween_property(tint, "color", Color(1.0, 0.85, 0.3, 0.35), 0.8 / speed)
	_say(tr("Phew, a happy ending! The carrot is safe."))
	await _hops(-150 * _s, 2, 0.0, 26.0, 0.22)
	_face(1)
	b.set_pose("stand")
	for i in 3:
		b.pop_icon("star")
	Sfx.play("sparkle")
	await _wait(1.8)
	b.set_pose("sit")
	# the credits roll, and he's out like a light
	var end := UI.label(tr("The End"), int(56 * _s), Color("#4f3d33"))
	end.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	end.position = SCREEN.position * _s
	end.size = SCREEN.size * _s
	end.modulate.a = 0.0
	_bg.add_child(end)
	end.create_tween().tween_property(end, "modulate:a", 1.0, 0.8 / speed)
	tint.create_tween().tween_property(tint, "color", Color(1.0, 0.97, 0.9, 0.85), 1.5 / speed)
	_say(tr("...and he's asleep before the credits."))
	b.set_pose("loaf")
	await _wait(0.8)
	b.set_pose("sleep")
	for i in 3:
		b.pop_text("z")
		await _wait(0.8)
	b.set_pose("sit")
	_gone(pop)
	await _wait(0.4)


# ---- little effects --------------------------------------------------------------------

func _sand() -> void:
	var d := TextureRect.new()
	d.texture = Catalog.tex("dropping")
	d.modulate = Color("#e6c98a")
	d.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	d.size = d.texture.get_size() * _s * randf_range(0.8, 1.3)
	d.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(d)
	var from := _feet() + Vector2(-20, -20) * _s
	d.position = from
	var t := d.create_tween().set_parallel()
	t.tween_property(d, "position", from + Vector2(randf_range(-140, -40), randf_range(-90, -30)) * _s, 0.45 / speed)
	t.tween_property(d, "modulate:a", 0.0, 0.45 / speed)
	t.chain().tween_callback(d.queue_free)


## A popcorn kernel hops from the bucket into his mouth.
func _kernel(bucket: Control) -> void:
	var k := TextureRect.new()
	k.texture = Catalog.tex("walk_kernel")
	k.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	k.size = k.texture.get_size() * _s * 1.2
	k.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(k)
	var from := bucket.position + Vector2(bucket.size.x * 0.4, bucket.size.y * 0.15)
	var to := _mouth() - k.size / 2
	var t := k.create_tween()
	t.tween_method(func(v: float): k.position = from.lerp(to, v) - Vector2(0, sin(v * PI) * 60 * _s), 0.0, 1.0, 0.35 / speed)
	t.tween_callback(func():
		Sfx.play("munch")
		k.queue_free())


func _camera_flash() -> void:
	Sfx.play("shutter")
	var f := _overlay(Color(1, 1, 1, 0.7))
	var t := f.create_tween()
	t.tween_property(f, "color:a", 0.0, 0.3 / speed)
	t.tween_callback(f.queue_free)
