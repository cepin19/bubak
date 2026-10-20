extends Control
## Inbox zero: tap the task bubbles before they vanish.
## Urgent tasks (red) vanish faster but count double; spam must be left alone.
## Now and then Bubák puts a paw on the keyboard; tapping it earns a little trust instead.

const BUBBLE := 84.0

var ctl: Node
var _spawn_t := 0.3


func _process(delta: float) -> void:
	if not ctl.is_running():
		return
	_spawn_t -= delta
	if _spawn_t <= 0:
		_spawn_t = randf_range(0.4, 0.75) * lerpf(1.0, 0.8, ctl.progress())
		_spawn()


func _spawn() -> void:
	var r := randf()
	var kind := "task"
	if r < 0.1:
		kind = "paw"
	elif r < 0.1 + lerpf(0.06, 0.18, ctl.progress()):
		kind = "spam"
	elif r < 0.45:
		kind = "urgent"
	var b := TextureButton.new()
	b.texture_normal = Catalog.icon(kind)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.size = Vector2(BUBBLE, BUBBLE)
	b.position = _free_spot()
	b.pivot_offset = Vector2(BUBBLE, BUBBLE) / 2.0
	b.scale = Vector2(0.2, 0.2)
	b.set_meta("kind", kind)
	add_child(b)
	b.pressed.connect(_on_hit.bind(b))
	var life := lerpf(1.5, 1.05, ctl.progress()) * (0.7 if kind == "urgent" else 1.0)
	var t := b.create_tween()
	t.tween_property(b, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if kind == "urgent":   # urgent ones tremble
		for i in int(life / 0.1):
			t.tween_property(b, "rotation", 0.12 if i % 2 == 0 else -0.12, 0.1)
	else:
		t.tween_interval(life)
	t.tween_property(b, "scale", Vector2(0.01, 0.01), 0.15)
	t.tween_callback(func():
		if not b.has_meta("hit") and kind in ["task", "urgent"]:
			ctl.miss()
		b.queue_free())


## A spot that doesn't cover another bubble (gives up after a few tries).
func _free_spot() -> Vector2:
	var p := Vector2.ZERO
	for attempt in 8:
		p = Vector2(randf_range(10, size.x - BUBBLE - 10), randf_range(10, size.y - BUBBLE - 10))
		var clear := true
		for c in get_children():
			if c is Control and c.position.distance_to(p) < BUBBLE:
				clear = false
				break
		if clear:
			break
	return p


func _on_hit(b: TextureButton) -> void:
	if b.has_meta("hit") or not ctl.is_running():
		return
	b.set_meta("hit", true)
	match b.get_meta("kind"):
		"paw":
			Game.add_trust(0.5)
			ctl.float_text(tr("aww, a paw!"), b.position)
		"spam":
			ctl.penalty(3, b.position, tr("That was spam!"))
		"urgent":
			ctl.hit(b.position, 2)
		_:
			ctl.hit(b.position)
	var t := b.create_tween()
	t.tween_property(b, "scale", Vector2(1.4, 1.4), 0.1)
	t.parallel().tween_property(b, "modulate:a", 0.0, 0.12)
	t.tween_callback(b.queue_free)
