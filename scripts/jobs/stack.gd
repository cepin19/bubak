extends Control
## Crate stacking: a carrot crate slides back and forth above the stack; tap to drop it.
## Whatever overhangs is sliced off, so the stack gets narrower; a perfect drop keeps
## (and even widens) it. When it's too thin to go on, a fresh pallet arrives.

const H := 34.0          # crate height
const BASE_W := 240.0
const MIN_W := 24.0
const SHOW_LEVELS := 7   # crates visible before the view scrolls up

var ctl: Node
var _world: Control
var _stack: Array = []   # [x, width] of each crate, bottom first
var _crates: Array = []  # their nodes
var _mover: Panel
var _mx := 0.0
var _dir := 1.0
var _dropping := false
var _perfects := 0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	_world = Control.new()
	_world.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_world)
	await get_tree().process_frame   # needs its final size to centre the pallet
	_new_pallet()


func _floor_y() -> float:
	return size.y - 24.0


func _level_y(i: int) -> float:
	return _floor_y() - (i + 1) * H


func _new_pallet() -> void:
	for c in _crates:
		if is_instance_valid(c):
			var t: Tween = c.create_tween()
			t.tween_property(c, "modulate:a", 0.0, 0.25)
			t.tween_callback(c.queue_free)
	_crates.clear()
	_stack.clear()
	_world.position.y = 0
	_perfects = 0
	var x := (size.x - BASE_W) / 2.0
	_stack.append([x, BASE_W])
	_crates.append(_crate(x, _level_y(0), BASE_W, Color("#b07a45")))
	_next_crate()


func _crate(x: float, y: float, w: float, color := Color("#d9a46a")) -> Panel:
	var p := Panel.new()
	p.mouse_filter = MOUSE_FILTER_IGNORE
	var sb := UI.box(color, 6, 3, false)
	p.add_theme_stylebox_override("panel", sb)
	p.position = Vector2(x, y)
	p.size = Vector2(w, H)
	if w > 60:
		var ic := UI.icon_rect("carrot", 26)
		ic.position = Vector2(w / 2.0 - 13, 4)
		p.add_child(ic)
	_world.add_child(p)
	return p


func _next_crate() -> void:
	var top: Array = _stack[-1]
	var w: float = top[1]
	_dir = 1.0 if randf() < 0.5 else -1.0
	_mx = 10.0 if _dir > 0 else size.x - w - 10.0
	_mover = _crate(_mx, _level_y(_stack.size()) - 110.0, w)
	_dropping = false


func _speed() -> float:
	return 230.0 * (1.0 + 0.9 * ctl.progress()) + _stack.size() * 5.0


func _process(delta: float) -> void:
	if _mover == null or _dropping or not ctl.is_running():
		return
	_mx += _dir * _speed() * delta
	var w: float = _mover.size.x
	if _mx < 10.0 or _mx > size.x - w - 10.0:
		_dir = -_dir
		_mx = clampf(_mx, 10.0, size.x - w - 10.0)
	_mover.position.x = _mx


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		drop()


func drop() -> void:
	if _mover == null or _dropping or not ctl.is_running():
		return
	_dropping = true
	var t := _mover.create_tween()
	t.tween_property(_mover, "position:y", _level_y(_stack.size()), 0.12).set_ease(Tween.EASE_IN)
	t.tween_callback(_land)


func _land() -> void:
	var top: Array = _stack[-1]
	var x: float = _mover.position.x
	var w: float = _mover.size.x
	var left := maxf(x, top[0])
	var right := minf(x + w, top[0] + top[1])
	var screen_pos := _mover.position + _world.position + Vector2(w / 2.0 - 20, -30)
	if right - left <= 0:
		# missed the stack completely: the crate tumbles off
		_fall(_mover, 1.0 if x > top[0] else -1.0)
		_mover = null
		_perfects = 0
		ctl.miss()
		ctl.float_text(tr("Whoops!"), screen_pos, Color("#ff9a9a"))
		_next_crate()
		return
	if absf(x - top[0]) < 7.0:
		# perfect: snaps into place, and a run of perfects widens the stack again
		_perfects += 1
		var nw := minf(BASE_W, float(top[1]) + (8.0 if _perfects >= 3 else 0.0))
		_mover.position.x = top[0] - (nw - top[1]) / 2.0
		_mover.size.x = nw
		_stack.append([_mover.position.x, nw])
		ctl.hit(screen_pos, 2)
		ctl.float_text(tr("Perfect!"), screen_pos + Vector2(-20, -34), Color("#b8f0a0"), 24)
		_squash(_mover)
	else:
		_perfects = 0
		# slice off the overhang and let it drop
		var cut_x := x if x < left else right
		var cut := _crate(cut_x, _mover.position.y, w - (right - left))
		_fall(cut, -1.0 if x < left else 1.0)
		_mover.position.x = left
		_mover.size.x = right - left
		for c in _mover.get_children():
			c.visible = right - left > 60
			c.position.x = (right - left) / 2.0 - 13
		_stack.append([left, right - left])
		ctl.hit(screen_pos, 1)
		_squash(_mover)
	_crates.append(_mover)
	_mover = null
	if _stack[-1][1] < MIN_W:
		ctl.float_text(tr("New pallet!"), Vector2(size.x / 2 - 70, 80), Color.WHITE)
		get_tree().create_timer(0.4).timeout.connect(func():
			if is_inside_tree():
				_new_pallet())
		return
	# keep the top of the stack in view
	if _stack.size() > SHOW_LEVELS:
		_world.create_tween().tween_property(_world, "position:y", (_stack.size() - SHOW_LEVELS) * H, 0.2)
	_next_crate()


func _squash(p: Control) -> void:
	p.pivot_offset = Vector2(p.size.x / 2.0, H)
	var t := p.create_tween()
	t.tween_property(p, "scale", Vector2(1.05, 0.85), 0.06)
	t.tween_property(p, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK)


func _fall(p: Control, side: float) -> void:
	p.pivot_offset = p.size / 2.0
	var t := p.create_tween().set_parallel()
	t.tween_property(p, "position:y", p.position.y + 500, 0.7).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_property(p, "position:x", p.position.x + side * 60, 0.7)
	t.tween_property(p, "rotation", side * 1.2, 0.7)
	t.chain().tween_callback(p.queue_free)
