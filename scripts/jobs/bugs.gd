extends Control
## Bug hunt: bugs crawl across the screen; squash them before they escape.
## Big bugs take three taps. Ladybugs are features, not bugs: squashing one costs points.

const SIZE := 72.0

var ctl: Node
var _spawn_t := 0.4


func _process(delta: float) -> void:
	if not ctl.is_running():
		return
	_spawn_t -= delta
	if _spawn_t <= 0:
		_spawn_t = lerpf(0.85, 0.4, ctl.progress())
		_spawn()
	var bounds := Rect2(Vector2.ZERO, size).grow(SIZE * 2)
	for b in get_children():
		if not b.has_meta("vel"):
			continue
		b.position += b.get_meta("vel") * delta
		if not bounds.has_point(b.position + b.size / 2.0):
			if not b.get_meta("lady"):
				ctl.miss()   # a bug got away
			b.queue_free()


func _spawn() -> void:
	var lady := randf() < 0.22
	var big: bool = not lady and ctl.progress() > 0.15 and randf() < 0.14
	var b := TextureButton.new()
	b.texture_normal = Catalog.icon("ladybug" if lady else "bug")
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.size = Vector2(SIZE, SIZE) * (1.7 if big else 1.0)
	b.pivot_offset = b.size / 2.0
	if big:
		b.modulate = Color(0.85, 0.7, 1.0)
	# Enter from one edge, head for a random point near the opposite edge.
	var from: Vector2
	var to: Vector2
	var m := b.size.x
	match randi() % 4:
		0:
			from = Vector2(-m, randf_range(0, size.y))
			to = Vector2(size.x + m, randf_range(0, size.y))
		1:
			from = Vector2(size.x + m, randf_range(0, size.y))
			to = Vector2(-m, randf_range(0, size.y))
		2:
			from = Vector2(randf_range(0, size.x), -m)
			to = Vector2(randf_range(0, size.x), size.y + m)
		_:
			from = Vector2(randf_range(0, size.x), size.y + m)
			to = Vector2(randf_range(0, size.x), -m)
	var dir := (to - from).normalized()
	b.position = from - b.size / 2.0
	b.rotation = dir.angle() + PI / 2.0
	b.set_meta("vel", dir * randf_range(110, 180) * (1.0 + ctl.progress()) * (0.55 if big else 1.0))
	b.set_meta("lady", lady)
	b.set_meta("hp", 3 if big else 1)
	add_child(b)
	var wobble := b.create_tween().set_loops()
	wobble.tween_property(b, "scale", Vector2(0.9, 1.05), 0.12)
	wobble.tween_property(b, "scale", Vector2.ONE, 0.12)
	b.pressed.connect(_squash.bind(b))


func _squash(b: TextureButton) -> void:
	if not b.has_meta("vel") or not ctl.is_running():
		return
	if b.get_meta("lady"):
		b.remove_meta("vel")
		ctl.penalty(3, b.position, tr("Not the ladybug!"))
		var fly := b.create_tween()
		fly.tween_property(b, "position:y", b.position.y - 200, 0.5)
		fly.parallel().tween_property(b, "modulate:a", 0.0, 0.5)
		fly.tween_callback(b.queue_free)
		return
	var hp: int = b.get_meta("hp") - 1
	b.set_meta("hp", hp)
	if hp > 0:   # a big one: it flinches and slows down, keep tapping
		b.set_meta("vel", b.get_meta("vel") * 0.7)
		ctl.float_text(tr("%d more!") % hp, b.position, Color("#d9c4ff"), 22)
		var f := b.create_tween()
		f.tween_property(b, "self_modulate", Color(2, 2, 2), 0.05)
		f.tween_property(b, "self_modulate", Color.WHITE, 0.1)
		return
	var big := b.size.x > SIZE * 1.2
	b.remove_meta("vel")
	ctl.hit(b.position + b.size / 4.0, 4 if big else 1)
	b.texture_normal = Catalog.icon("splat")
	b.rotation = randf() * TAU
	b.disabled = true
	var t := b.create_tween()
	t.tween_interval(0.25)
	t.tween_property(b, "modulate:a", 0.0, 0.3)
	t.tween_callback(b.queue_free)
