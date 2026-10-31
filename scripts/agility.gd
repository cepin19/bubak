extends Control
## An agility course: obstacles come in from the right while Bubák trots along.
## - bar: jump while it's in the gold take-off zone and he sails over;
## - oxer (a double bar): the same, but wider, so the zone is narrower;
## - tunnel: don't jump! He runs through it;
## - weave poles: tap as each pole reaches him (no jumping in between).
## A take-off mid-zone is "Perfect!" and gives a burst of speed; a fault costs a moment.
## Practice gives him more hang time, which widens the zone. On a timed run (the daily course)
## a clock runs, faults add Catalog.AGILITY_FAULT_TIME each, and a ghost of today's best run
## trots along.

signal bar_done(cleared: bool)
signal finished(clears: int, faults: int)

const BAR_H := 50.0        # top of a bar above the ground
const BAR_W := 64.0
const OXER_GAP := 44.0     # between the two rails of a double bar
const JUMP_H := 112.0      # how high his feet get at the top of a jump
const GROUND := 26.0       # ground strip height
const TUNNEL_W := 130.0
const POLES := 5
const POLE_GAP := 52.0
const POLE_WINDOW := 30.0  # how close (px) a pole has to be for a tap to count
const GHOST_STEP := 0.1    # seconds between ghost samples

var bars := Catalog.AGILITY_BARS    # how many obstacles
var speed := 260.0
var kinds: Array = ["bar"]          # what a random course is made of (the first is always a bar)
var course: Array = []              # a fixed course instead: [{"type", "gap"}]
var timed := false
var ghost: Array = []               # distances, every GHOST_STEP seconds
var record: Array = []              # this run's distances, for the next ghost
var autopilot := false              # plays itself (the playtest)
var clears := 0
var faults := 0
var perfects := 0
var elapsed := 0.0
var distance := 0.0
var _stage: StageBunny
var _bars: Array = []      # obstacles: {type, x (front), done, down (s since knocked, -1), poles: [{x, ok, done}]}
var _air := -1.0           # seconds into a jump; -1 on the ground
var _hang := 0.5           # how long a jump lasts
var _rest := 0.0           # after a jump over nothing he needs a moment (no jumping non-stop)
var _jump_used := false    # this jump went over a bar
var _land := 0.0           # landing squash, counts down
var _boost := 0.0          # a perfect take-off: faster for a moment
var _stall := 0.0          # a fault: he stops for a moment
var _sway := 0.0           # weaving left and right
var _fumble := 0.0         # tapped at no pole: a moment before the next tap counts (no tapping non-stop)
var _t := 0.0
var _rec_t := 0.0
var _running := false
var _end_t := 0.0
var _cue: Label
var _clock: Label


func _ready() -> void:
	clip_contents = true
	mouse_filter = MOUSE_FILTER_STOP
	focus_mode = FOCUS_NONE
	_stage = StageBunny.new()
	_stage.k = 0.6
	add_child(_stage)
	_cue = UI.label(tr("JUMP!"), 30, Color("#c0504d"))
	_cue.add_theme_color_override("font_outline_color", Color.WHITE)
	_cue.add_theme_constant_override("outline_size", 10)
	_cue.visible = false
	add_child(_cue)
	_clock = UI.label("", 22)
	_clock.position = Vector2(16, 10)
	_clock.visible = false
	add_child(_clock)
	resized.connect(_layout)
	_layout()
	_hang = 0.3 + 2.0 * Game.agility_window()   # 0.54 s untrained, up to ~0.95 s
	gui_input.connect(func(e):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			jump())


func _unhandled_key_input(e: InputEvent) -> void:
	if _running and e.is_pressed() and not e.is_echo() and (e.is_action("ui_accept") or (e is InputEventKey and e.keycode == KEY_SPACE)):
		jump()
		get_viewport().set_input_as_handled()


func _layout() -> void:
	_stage.position = Vector2.ZERO
	_stage.size = Vector2(size.x * 0.26, size.y - GROUND + 18.0)   # his feet (18 above the stage's bottom) on the ground line


func ground_y() -> float:
	return size.y - GROUND


## The middle of his body, across the track: where an obstacle is judged.
func bunny_x() -> float:
	return _stage.position.x + _stage.home.x + 14.0 * _stage.k   # (sprites face right; his middle is a little ahead of his feet)


## How far ahead of him (from, to) a bar's front may be when he takes off and still clears it.
func zone(type := "bar") -> Vector2:
	var a := asin(BAR_H / JUMP_H) / PI   # the part of the jump spent too low at each end
	var z := Vector2(speed_now() * _hang * a, speed_now() * _hang * (1.0 - a))
	if type == "oxer":
		z.y -= OXER_GAP
	return z


func speed_now() -> float:
	return 0.0 if _stall > 0.0 else speed * (1.15 if _boost > 0.0 else 1.0)


func running() -> bool:
	return _running


## The time that counts: the clock plus a penalty for each fault.
func score_time() -> float:
	return elapsed + faults * Catalog.AGILITY_FAULT_TIME


## Sets out the course and off he goes.
func start() -> void:
	_bars.clear()
	clears = 0
	faults = 0
	perfects = 0
	elapsed = 0.0
	distance = 0.0
	record = [0.0]
	_rec_t = 0.0
	_air = -1.0
	_rest = 0.0
	_boost = 0.0
	_stall = 0.0
	_fumble = 0.0
	var x := size.x + 80.0
	var plan: Array = course if not course.is_empty() else []
	if plan.is_empty():
		for i in bars:
			plan.append({"type": "bar" if i == 0 else kinds.pick_random(), "gap": randf_range(300.0, 440.0)})
	for p in plan:
		var o := {"type": p.type, "x": x, "done": false, "down": -1.0}
		if p.type == "weave":
			o.poles = []
			for j in POLES:
				o.poles.append({"x": x + j * POLE_GAP, "ok": false, "done": false})
		_bars.append(o)
		x += _width(p.type) + float(p.gap)
	bars = _bars.size()
	_running = true
	_end_t = 0.0
	_clock.visible = timed


func _width(type: String) -> float:
	match type:
		"oxer": return BAR_W + OXER_GAP
		"tunnel": return TUNNEL_W
		"weave": return (POLES - 1) * POLE_GAP
	return BAR_W


## The weave poles he's at now, or {}.
func _weave_now() -> Dictionary:
	var bx := bunny_x()
	for o in _bars:
		if o.type == "weave" and not o.done and o.x - bx < 90.0:
			return o
	return {}


## A tap: a jump, or a weave through the next pole.
func jump() -> void:
	if not _running:
		return
	var w := _weave_now()
	if not w.is_empty():
		_weave_tap(w)
		return
	if _air >= 0.0 or _rest > 0.0 or _stall > 0.0:
		return
	_air = 0.0
	_jump_used = false
	Sfx.play("boing")
	# a take-off right in the middle of the zone: perfect, and a burst of speed
	for o in _bars:
		if not o.done:
			if o.type in ["bar", "oxer"]:
				var z := zone(o.type)
				var gap: float = o.x - bunny_x()
				if absf(gap - (z.x + z.y) * 0.5) < (z.y - z.x) * 0.18:
					perfects += 1
					_boost = 1.0
					_stage.pop_text(tr("Perfect!"), Color("#e0ad4a"))
			break


func _weave_tap(w: Dictionary) -> void:
	if _fumble > 0.0:
		return
	var bx := bunny_x()
	for p in w.poles:
		if not p.done and not p.ok and absf(p.x - bx) < POLE_WINDOW:
			p.ok = true
			_sway = -_sway if _sway != 0.0 else 1.0
			Sfx.play("hop")
			return
	_fumble = 0.4   # no pole there: he loses the rhythm for a moment


## His feet above the ground right now.
func feet_height() -> float:
	return sin(_air / _hang * PI) * JUMP_H if _air >= 0.0 else 0.0


func _process(delta: float) -> void:
	if not _running:
		_cue.visible = false
		return
	_t += delta
	elapsed += delta
	_boost = maxf(0.0, _boost - delta)
	_stall = maxf(0.0, _stall - delta)
	_fumble = maxf(0.0, _fumble - delta)
	var v := speed_now()
	distance += v * delta
	_rec_t += delta
	if _rec_t >= GHOST_STEP:
		_rec_t -= GHOST_STEP
		record.append(distance)
	if timed:
		_clock.text = tr("Time: %.1f s") % score_time() + ("   " + tr("Best today: %.1f s") % Game.daily_best() if Game.daily_best() > 0.0 else "")
	if autopilot:
		_autoplay()
	var k := _stage.k
	if _air >= 0.0:
		_air += delta
		if _air >= _hang:
			_air = -1.0
			_land = 0.16
			if not _jump_used:   # jumped at thin air: a moment to catch his breath
				_rest = 0.8
				_stage.pop_text(tr("huff"), Color(UI.INK, 0.6))
	else:
		_rest = maxf(0.0, _rest - delta)
	_land = maxf(0.0, _land - delta)
	# pose: stretched out in the air, a light trot on the ground, a sway through the weave poles
	_sway = move_toward(_sway, 0.0, delta * 2.0) if _weave_now().is_empty() else _sway
	if _air >= 0.0:
		_stage.set_pose("hop")
		_stage.pivot.position = _stage.home - Vector2(0, feet_height())
		_stage.pivot.rotation = lerpf(-0.18, 0.18, _air / _hang)
		_stage.pivot.scale = Vector2.ONE
	else:
		var trot := absf(sin(_t * 8.0)) if v > 0.0 else 0.0
		_stage.set_pose("hop" if trot > 0.35 else "sit")
		_stage.pivot.position = _stage.home - Vector2(0, trot * 7.0 * k)
		_stage.pivot.rotation = _sway * 0.16
		_stage.pivot.scale = Vector2(1.12, 0.88) if _land > 0.0 else Vector2.ONE
	var bx := bunny_x()
	var left := 0
	var cue := -1.0   # where to show the cue, and what it says
	var cue_text := ""
	_stage.visible = true
	for o in _bars:
		o.x -= v * delta
		if o.type == "weave":
			for p in o.poles:
				p.x -= v * delta
		if o.down >= 0.0:
			o.down += delta
		if o.done:
			continue
		left += 1
		var gap: float = o.x - bx
		match o.type:
			"bar", "oxer":
				var z := zone(o.type)
				if gap >= z.x and gap <= z.y and _air < 0.0 and _rest <= 0.0 and cue < 0.0:
					cue = o.x + _width(o.type) * 0.5
					cue_text = tr("JUMP!")
				# judged as each rail passes his middle
				var rails: Array = [o.x + BAR_W * 0.5] if o.type == "bar" else [o.x + BAR_W * 0.5, o.x + BAR_W * 0.5 + OXER_GAP]
				var rail_i: int = o.get("rail", 0)
				if rail_i < rails.size() and rails[rail_i] - BAR_W * 0.5 - bx <= 0.0:
					if _air >= 0.0:
						_jump_used = true
					if feet_height() < BAR_H:
						_fault(o, tr("oops!"))
					else:
						o.rail = rail_i + 1
						if o.rail >= rails.size():
							_clear(o)
			"tunnel":
				if gap < 160.0 and gap > -TUNNEL_W and cue < 0.0:
					cue = o.x + TUNNEL_W * 0.5
					cue_text = tr("Through!")
				if gap <= 0.0 and gap > -TUNNEL_W and _air < 0.0:
					_stage.visible = false   # inside the tunnel
				if gap + TUNNEL_W * 0.5 <= 0.0 and not o.has("judged"):
					o.judged = true
					if _air >= 0.0:
						_jump_used = true
						_fault(o, tr("Over, not through!"))
				if gap + TUNNEL_W <= 0.0 and not o.done:
					_clear(o)
			"weave":
				for p in o.poles:
					if p.done:
						continue
					if not p.ok and absf(p.x - bx) < POLE_WINDOW and cue < 0.0:
						cue = p.x
						cue_text = tr("Tap!")
					if p.x - bx < -POLE_WINDOW:
						p.done = true
						if not p.ok:
							o.missed = int(o.get("missed", 0)) + 1
				if o.poles.all(func(p): return p.done):
					if int(o.get("missed", 0)) > 1:
						_fault(o, tr("Missed the poles!"))
					else:
						_clear(o)
	_cue.visible = cue >= 0.0
	if _cue.visible:   # right above what needs doing
		_cue.text = cue_text
		_cue.position = Vector2(cue - _cue.size.x * 0.5, ground_y() - BAR_H - 96.0)
	if left == 0:
		_end_t += delta
		if _end_t > 0.8:
			_running = false
			_cue.visible = false
			_stage.visible = true
			_stage.pivot.position = _stage.home
			_stage.pivot.rotation = 0.0
			_stage.pivot.scale = Vector2.ONE
			_stage.set_pose("sit")
			finished.emit(clears, faults)
	queue_redraw()


func _clear(o: Dictionary) -> void:
	o.done = true
	clears += 1
	_stage.pop_icon("star")
	Sfx.play("star")
	bar_done.emit(true)


func _fault(o: Dictionary, say: String) -> void:
	o.done = true
	o.down = 0.0
	faults += 1
	_stall = 0.35
	Sfx.play("thump")
	_stage.pop_text(say, Color("#c0504d"))
	bar_done.emit(false)


## The playtest's perfect run: jump mid-zone, tap each pole, stay low for tunnels.
func _autoplay() -> void:
	var bx := bunny_x()
	for o in _bars:
		if o.done:
			continue
		match o.type:
			"bar", "oxer":
				var z := zone(o.type)
				if o.x - bx <= (z.x + z.y) * 0.5 and _air < 0.0:
					jump()
			"weave":
				for p in o.poles:
					if not p.ok and not p.done and absf(p.x - bx) < POLE_WINDOW * 0.6:
						_weave_tap(o)
		return


func _draw() -> void:
	var gy := ground_y()
	draw_rect(Rect2(0, gy, size.x, GROUND), Color("#b9d98f"))
	draw_line(Vector2(0, gy), Vector2(size.x, gy), Color("#8fb466"), 3.0)
	if not _running:
		return
	var bx := bunny_x()
	if timed and not ghost.is_empty():
		_draw_ghost(bx, gy)
	# the take-off zone for the next bar: jump while it's in here
	var next := {}
	for o in _bars:
		if not o.done:
			next = o
			break
	var ready := _air < 0.0 and _rest <= 0.0
	if not next.is_empty() and next.type in ["bar", "oxer"]:
		var z := zone(next.type)
		draw_rect(Rect2(bx + z.x, gy + 4, z.y - z.x, GROUND - 8), Color("#f3c94f", 0.55 if ready else 0.22))
		var mid := bx + (z.x + z.y) * 0.5
		draw_line(Vector2(mid, gy + 4), Vector2(mid, gy + GROUND - 4), Color("#e0ad4a"), 3.0)
	for o in _bars:
		var gap: float = o.x - bx
		match o.type:
			"bar":
				var z := zone("bar")
				_draw_bar(o.x + BAR_W * 0.5, o.down, gy, not o.done and gap >= z.x and gap <= z.y and ready)
			"oxer":
				var z := zone("oxer")
				var lit: bool = not o.done and gap >= z.x and gap <= z.y and ready
				_draw_bar(o.x + BAR_W * 0.5, o.down, gy, lit)
				_draw_bar(o.x + BAR_W * 0.5 + OXER_GAP, o.down, gy, lit)
			"tunnel":
				_draw_tunnel(o.x, gy)
			"weave":
				for p in o.poles:
					var c := Color("#7fb0d8") if not p.done or p.ok else Color("#c0504d")
					if p.ok:
						c = Color("#7fcfb8")
					draw_line(Vector2(p.x, gy), Vector2(p.x, gy - 92), Color(UI.INK), 9.0)
					draw_line(Vector2(p.x, gy - 2), Vector2(p.x, gy - 90), c, 5.0)
					draw_circle(Vector2(p.x, gy - 92), 6, c)


func _draw_bar(x: float, down: float, gy: float, lit: bool) -> void:
	var post := Color("#8a6247")
	var hw := BAR_W * 0.5
	draw_rect(Rect2(x - hw, gy - BAR_H - 6, 8, BAR_H + 6), post)
	draw_rect(Rect2(x + hw - 8, gy - BAR_H - 6, 8, BAR_H + 6), post)
	if lit:
		draw_rect(Rect2(x - hw - 6, gy - BAR_H - 8, BAR_W + 12, 14), Color("#f3c94f", 0.8))
	var tilt := 0.0
	if down >= 0.0:
		tilt = minf(down / 0.25, 1.0) * 1.1
	var from := Vector2(x - hw - 2, gy - BAR_H)
	var dir := Vector2(cos(tilt), sin(tilt))
	draw_line(from, from + dir * (BAR_W + 4), Color("#e8505b"), 9.0)
	for i in 3:   # white stripes on the red bar
		var s := from + dir * (8.0 + i * 22.0)
		draw_line(s, s + dir * 9.0, Color.WHITE, 9.0)


## A fabric tunnel: a blue tube with hoops, open towards him.
func _draw_tunnel(x: float, gy: float) -> void:
	var h := 64.0
	draw_rect(Rect2(x, gy - h, TUNNEL_W, h), Color("#6f9fd8"))
	for i in 5:
		var hx := x + 8.0 + i * (TUNNEL_W - 16.0) / 4.0
		draw_line(Vector2(hx, gy - h), Vector2(hx, gy), Color("#4f7fb8"), 4.0)
	draw_rect(Rect2(x, gy - h, TUNNEL_W, h), UI.INK, false, 3.0)
	draw_circle(Vector2(x, gy - h * 0.5), h * 0.5, Color("#3d5f8a"))
	draw_arc(Vector2(x, gy - h * 0.5), h * 0.5, 0, TAU, 32, UI.INK, 3.0)


## Today's best run, as a see-through bunny: ahead or behind you.
func _draw_ghost(bx: float, gy: float) -> void:
	var i := int(elapsed / GHOST_STEP)
	var gd: float = ghost[mini(i, ghost.size() - 1)]
	if i + 1 < ghost.size():
		gd = lerpf(gd, ghost[i + 1], fmod(elapsed, GHOST_STEP) / GHOST_STEP)
	var x := bx + (gd - distance)
	var tex: Texture2D = Catalog.tex("bunny_hop")
	var sz := tex.get_size() * _stage.k
	var feet := StageBunny.FEET * _stage.k
	var col := Color(0.55, 0.7, 1.0, 0.45)
	if x < -20.0 or x > size.x + 20.0:   # off screen: an arrow at the edge
		var ax := clampf(x, 24.0, size.x - 24.0)
		var d := -1.0 if x < 0 else 1.0
		draw_colored_polygon(PackedVector2Array([Vector2(ax + d * 14, gy - 40), Vector2(ax - d * 6, gy - 54), Vector2(ax - d * 6, gy - 26)]), col)
		return
	draw_texture_rect(tex, Rect2(Vector2(x - 14.0 * _stage.k, gy) - feet, sz), false, col)
