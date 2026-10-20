extends Control
## Pair programming: flip cards to find matching pairs. Each new board is bigger;
## the cards are shown for a moment before they turn over. Clear a board for a bonus.

const FACES := ["carrot", "apple", "hay", "parsley", "heart", "coin", "treat", "star", "water", "pellets"]
const BOARDS := [[4, 3], [4, 4], [5, 4]]   # columns, rows

var ctl: Node
var _grid: GridContainer
var _open: Array = []
var _busy := false
var _left := 0
var _board := 0
var _dealt := false


func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 10)
	center.add_child(_grid)
	_deal()


func _deal() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var shape: Array = BOARDS[mini(_board, BOARDS.size() - 1)]
	_grid.columns = shape[0]
	var pairs: int = shape[0] * shape[1] / 2
	var faces: Array = FACES.duplicate()
	faces.shuffle()
	faces = faces.slice(0, pairs)
	faces += faces
	faces.shuffle()
	_left = pairs
	_open.clear()
	_busy = true
	var card_size := Vector2(96, 110) if shape[1] <= 3 else Vector2(84, 88)
	for f in faces:
		var b := Button.new()
		b.custom_minimum_size = card_size
		b.icon = Catalog.icon(f)   # face up during the peek
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.focus_mode = FOCUS_NONE
		b.set_meta("face", f)
		b.pressed.connect(_flip.bind(b))
		_grid.add_child(b)
	# a short peek, then all cards turn over
	var peek := 1.2 if _board == 0 else 0.9
	get_tree().create_timer(peek + (0.6 if not _dealt else 0.0)).timeout.connect(func():
		for b in _grid.get_children():
			if is_instance_valid(b) and not b.is_queued_for_deletion():
				_show(b, false)
		_busy = false)
	_dealt = true


func _show(b: Button, up: bool) -> void:
	b.pivot_offset = b.size / 2.0
	var t := b.create_tween()
	t.tween_property(b, "scale:x", 0.0, 0.08)
	t.tween_callback(func(): b.icon = Catalog.icon(b.get_meta("face") if up else "card_back"))
	t.tween_property(b, "scale:x", 1.0, 0.08)


func _flip(b: Button) -> void:
	if _busy or not ctl.is_running() or b.has_meta("done") or b in _open:
		return
	_show(b, true)
	_open.append(b)
	if _open.size() < 2:
		return
	var a: Button = _open[0]
	var c: Button = _open[1]
	_open.clear()
	if a.get_meta("face") == c.get_meta("face"):
		for card in [a, c]:
			card.set_meta("done", true)
			card.modulate = Color(0.85, 1.0, 0.85)
		ctl.hit(c.position + _grid.position + Vector2(0, 40), 2)
		_left -= 1
		if _left == 0:
			ctl.float_text(tr("Board cleared!"), Vector2(size.x / 2 - 80, 20))
			ctl.hit(Vector2(size.x / 2, 40), 4 + 2 * _board)
			_busy = true
			_board += 1
			get_tree().create_timer(0.6).timeout.connect(_deal)
		return
	ctl.miss()
	_busy = true
	get_tree().create_timer(0.6).timeout.connect(func():
		if is_instance_valid(a):
			_show(a, false)
		if is_instance_valid(c):
			_show(c, false)
		_busy = false)
