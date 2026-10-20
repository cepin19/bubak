extends Node2D
## Builds the apartment, routes taps and drags to Bubák and the furniture,
## runs the day/night cycle and takes photos.

const Placeable := preload("res://scripts/placeable.gd")
const Bunny := preload("res://scripts/bunny.gd")
const Hud := preload("res://scripts/hud.gd")

const WINDOW := Rect2(750, 50, 240, 260)
const BX := -2000.0   # = Game.BALCONY_X
const BALCONY_SKY := Rect2(BX - 240, -160, 1250, 570)
const SKY_KEYS := [   # hour, sky top, sky bottom, room tint
	[0.0, "#1d2347", "#3b3f72", "#7c80ad"],
	[5.0, "#2f3566", "#e7a38f", "#b7aec4"],
	[7.0, "#8fc6ea", "#f6d6b0", "#f4eee8"],
	[9.0, "#7fbfe8", "#d3ecf7", "#ffffff"],
	[17.0, "#7fbfe8", "#d3ecf7", "#ffffff"],
	[19.0, "#e98a6f", "#f7c58f", "#f2d8c4"],
	[20.5, "#3a3570", "#c47a8a", "#b4a9c6"],
	[22.0, "#1d2347", "#3b3f72", "#7c80ad"],
	[24.0, "#1d2347", "#3b3f72", "#7c80ad"],
]
const DECOR := ["plant", "lamp", "bed", "rug"]

var world: Node2D
var floor_layer: Node2D
var fx: Node2D
var sky: Node2D
var tint: CanvasModulate
var camera: Camera2D
var hud_layer: CanvasLayer
var hud: Control
var bunny: Node2D        # Bubák
var mate_bunny: Node2D = null
var bunnies: Array = []  # Bubák, and his friend once adopted
var held: Node2D = null  # the bunny picked up for a selfie
var _pet_bunny: Node2D = null
var cable: Node2D
var door: Node2D
var balcony_door: Node2D
var planter: Node2D
var sunspot: Node2D
var desk: Node2D
var chair: Node2D
var shelf: Node2D        # trophy shelf on the wall, appears with the first ribbon
var view := "living"     # which room the camera shows
var clock: Node2D
var glow: Node2D         # additive lights, drawn above the night tint
var beam: Node2D
var dust: CPUParticles2D
var city_lights: Sprite2D
var laptop_glow: Sprite2D
var _lamp_glows := {}    # lamp uid -> [halo, floor pool]
var _bulbs: Array = []   # balcony string light glows
var items := {}          # uid -> Placeable
var fixed: Array = []    # sofa, desk, cable
var dropping_nodes: Array = []

var mode := ""           # "", "move", "treat", "photo"
var treat_selected := ""
var hand: Node2D = null
var hand_pos := Vector2.ZERO
var hand_treat := ""
var hand_time := 0.0

var _sky_colors := ["#7fbfe8", "#d3ecf7"]
var _night := 0.0
var _sky_t := 0.0
var _cable_t := 0.0
var _shake := 0.0
var _debug_hour := -1.0
var _fur_t := 60.0

var _pressing := false
var _press_pos := Vector2.ZERO
var _press_time := 0.0
var _moved := 0.0
var _press_target = null
var _dragging: Node2D = null
var _drag_off := Vector2.ZERO
var _petting := false


func _ready() -> void:
	# Developer options, e.g.:  godot --path . -- --hour=21 --shot=/tmp/a.png --open=shop
	# (only on the first start, not when the scene reloads after loading a save)
	var args: PackedStringArray = PackedStringArray() if Engine.has_meta("started") else OS.get_cmdline_user_args()
	Engine.set_meta("started", true)
	for arg in args:
		if arg.begins_with("--hour="):
			_debug_hour = float(arg.get_slice("=", 1))
		elif arg.begins_with("--shot="):
			_screenshot.call_deferred(arg.get_slice("=", 1))
		elif arg.begins_with("--autotest"):
			Game.use_scratch_game("user://autotest_save.json")
			add_child.call_deferred(load("res://tools/autotest.gd").new())
		elif arg == "--fps":
			var t := Timer.new()
			t.wait_time = 2.0
			t.autostart = true
			t.timeout.connect(func(): print("FPS ", Engine.get_frames_per_second()))
			add_child(t)
		elif arg == "--testplay":   # same as Settings > Test play
			Game.start_test_play()
		elif arg == "--demo":   # a furnished flat, for trying things out
			Game.use_scratch_game("user://demo_save.json")
			_demo.call_deferred()
		elif arg.begins_with("--view="):
			go_to.call_deferred(arg.get_slice("=", 1))
	RenderingServer.set_default_clear_color(Color("#f7e6d0"))
	camera = Camera2D.new()
	camera.position = Vector2(640, 360)
	add_child(camera)

	sky = Node2D.new()
	sky.draw.connect(_draw_sky)
	add_child(sky)
	var bg := Sprite2D.new()
	bg.texture = Catalog.tex("room")
	bg.centered = false
	bg.position = Vector2(-240, -160)
	add_child(bg)
	var bg2 := Sprite2D.new()
	bg2.texture = Catalog.tex("balcony")
	bg2.centered = false
	bg2.position = Vector2(BX - 240, -160)
	add_child(bg2)
	clock = Node2D.new()
	clock.position = Vector2(665, 168)
	clock.draw.connect(_draw_clock)
	add_child(clock)
	floor_layer = Node2D.new()
	add_child(floor_layer)
	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
	fx = Node2D.new()
	fx.z_index = 10
	add_child(fx)
	tint = CanvasModulate.new()
	add_child(tint)

	fixed.append(_make_item("sofa", 0, Vector2(420, 478), "sofa", 0.95))
	door = _make_item("door", 0, Vector2(95, 438), "door_locked", 1.0)
	fixed.append(door)
	balcony_door = _make_item("balcony_door", 0, Vector2(BX + 1150, 438), "balcony_door", 1.0)
	fixed.append(balcony_door)
	planter = _make_item("planter", 0, Vector2(BX + 300, 520))
	fixed.append(planter)
	sunspot = _make_item("sunspot", 0, Vector2(BX + 640, 610))
	fixed.append(sunspot)
	desk = _make_item("desk", 0, Vector2(1110, 480), "desk", 1.0)
	fixed.append(desk)
	chair = _make_item("office_chair", 0, Vector2(1010, 545), "chair", 0.7)
	fixed.append(chair)
	cable = _make_item("cable", 0, Vector2(710, 464), "cable_" + Game.cable, 1.0)
	fixed.append(cable)
	shelf = _make_item("trophy_shelf", 0, Vector2(335, 262), "trophy_shelf", 0.8)
	fixed.append(shelf)
	update_trophies()
	for e in Game.placed:
		_spawn_placed(e)
	for d in Game.droppings:
		_spawn_dropping_node(Vector2(d[0], d[1]))
	for d in Game.fur:
		_spawn_dropping_node(Vector2(d[0], d[1]), true)

	bunny = _add_bunny(Game.bubak, Vector2(640, 600))
	if Game.mate:
		mate_bunny = _add_bunny(Game.mate, Vector2(500, 630))
		bunny.partner = mate_bunny
		mate_bunny.partner = bunny

	_build_lighting()
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 5
	add_child(hud_layer)
	hud = Hud.new()
	hud.main = self
	hud_layer.add_child(hud)

	for b in bunnies:
		b.message.connect(hud.toast)
		b.cable_alert.connect(_on_cable_alert.bind(b))
	Game.item_added.connect(_spawn_placed)
	Game.balcony_milestone.connect(hud.on_balcony_milestone)
	if not Game.welcome.is_connected(_on_welcome):
		Game.welcome.connect(_on_welcome)
	_update_sky()
	if Game.welcome_text != "":
		hud.show_welcome.call_deferred(Game.welcome_text)
		Game.welcome_text = ""
	Game.check_sponsor.call_deferred()


func _process(delta: float) -> void:
	_update_care_items()
	if _pressing and _press_target in bunnies and not _petting and mode == "" \
			and Time.get_ticks_msec() / 1000.0 - _press_time > 0.4 and _moved < 24:
		_pet_bunny = _press_target
		_petting = _pet_bunny.on_pet_start()
		if not _petting:
			_press_target = null
	if _petting and not _pet_bunny.on_pet_hold(delta):
		_petting = false
		_press_target = null
	if hand:
		hand_time -= delta
		if hand_time <= 0:
			Game.inventory[hand_treat] = Game.inventory.get(hand_treat, 0) + 1
			hud.toast(tr("No bunny came this time. The treat went back in the bag."))
			_remove_hand()
	_fur_t -= delta
	if _fur_t <= 0:   # molting: he leaves tufts of fur around
		_fur_t = randf_range(70, 110)
		if Game.molting() and Game.fur.size() < 6 and not bunny.hidden_inside:   # Bubák is the show bunny
			add_fur(bunny.position + Vector2(-bunny.facing * 40, 6))
	if Game.cable == "chewed":
		_cable_t += delta
		if _cable_t > 25:
			_cable_t = 0
			Game.cable = "ok"
			hud.toast(tr("A new charger arrived. Keep an eye on Bubák!"))
	_update_lights()
	sky.queue_redraw()   # drifting clouds, twinkling stars
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	_shake = maxf(0, _shake - delta * 30)
	_sky_t -= delta
	if _sky_t <= 0:
		_sky_t = 10.0
		_update_sky()
		Game.check_sponsor()   # a new day may have started while playing


func _update_care_items() -> void:
	for it in items.values():
		match it.id:
			"bowl": it.set_texture(_tiered("bowl") + ("_full" if Game.bowl > 0 else ""))
			"water": it.set_texture(_tiered("water") + ("_full" if Game.water > 5 else ""))
			"hayrack": it.set_texture(_tiered("hayrack") + ("_full" if Game.hay > 5 else ""))
			"litter": it.set_texture(_tiered("litter") + ("_dirty" if Game.litter > 45 else ""))
			"branch": it.set_texture("branch" if _entry(it).get("bites", 4) > 2 else "branch_bare")
	cable.set_texture("cable_" + Game.cable)
	var gear := ("m" if Game.tier("monitor") > 0 else "") + ("c" if Game.tier("coffee") > 0 else "")
	desk.set_texture("desk" if gear == "" else "desk_" + gear)
	chair.visible = Game.tier("chair") > 0
	door.set_texture(("door_open_night" if _night > 0.6 else "door_open") if Game.balcony == "open" else "door_locked")
	planter.set_texture("planter" if Game.herbs > 40 else "planter_nibbled")
	sunspot.visible = is_daytime()


## Texture name of a care item at its current upgrade tier, e.g. "bowl_t2".
func _tiered(slot: String) -> String:
	var t := Game.tier(slot)
	return slot if t <= 1 else "%s_t%d" % [slot, t]


# ---- world contents -------------------------------------------------------------

func _make_item(id: String, uid: int, pos: Vector2, tex := "", s := -1.0) -> Node2D:
	var it := Placeable.new()
	it.setup(id, uid, tex, s)
	it.position = pos
	it.movable = uid != 0
	if Catalog.ITEMS.get(id, {}).get("flat", false):
		floor_layer.add_child(it)
	else:
		world.add_child(it)
	return it


func _spawn_placed(e: Dictionary) -> void:
	var it := _make_item(e.id, e.uid, Vector2(e.x, e.y))
	items[e.uid] = it
	if not is_node_ready():
		return
	it.wiggle(2.0)
	spawn_fx("star", it.position + Vector2(0, -40))


## First placed item with this id, optionally only in one room.
func find_item(id: String, room := "") -> Node2D:
	for it in items.values():
		if it.id == id and (room == "" or Game.room_at(it.position) == room):
			return it
	return null


func random_furniture(room := "living") -> Node2D:
	var pool: Array = fixed.filter(func(f): return not f in [cable, door, balcony_door, sunspot, chair, shelf])
	for it in items.values():
		if not Catalog.ITEMS[it.id].get("flat", false):
			pool.append(it)
	pool = pool.filter(func(f): return Game.room_at(f.position) == room)
	return pool.pick_random()


func door_of(room: String) -> Node2D:
	return balcony_door if room == "balcony" else door


func is_daytime() -> bool:
	var h := hour()
	return h > 6.5 and h < 20.0


# ---- rooms -------------------------------------------------------------------

func go_to(room: String) -> void:
	if room == view:
		return
	if mode in ["move", "treat"]:
		set_mode("")
	view = room
	var t := create_tween()
	t.tween_property(camera, "position:x", 640.0 + (BX if room == "balcony" else 0.0), 0.7) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	hud.toast(tr("The balcony") if room == "balcony" else tr("The living room"))


func _add_bunny(pet: Pet, pos: Vector2) -> Node2D:
	var b := Bunny.new()
	b.pet = pet
	b.room = self
	b.position = pos
	world.add_child(b)
	bunnies.append(b)
	return b


## The bunny in the room on screen that's nearest to a point (null if none is here).
func bunny_near(p: Vector2) -> Node2D:
	var best: Node2D = null
	for b in bunnies:
		if b.room_id == view and (best == null or b.position.distance_to(p) < best.position.distance_to(p)):
			best = b
	return best


func on_bunny_room_changed(b: Node2D, room: String) -> void:
	if room != view:
		hud.toast(tr("%s hopped out onto the balcony. Tap the door to follow.") % b.pet.display_name() if room == "balcony"
			else tr("%s is back inside.") % b.pet.display_name())


func spawn_bird() -> void:
	var b := Sprite2D.new()
	b.texture = Catalog.tex("bird")
	var y := randf_range(-20, 160)
	b.position = Vector2(BX - 60, y)
	fx.add_child(b)
	var flap := b.create_tween().set_loops(12)
	flap.tween_property(b, "scale:y", 0.6, 0.15)
	flap.tween_property(b, "scale:y", 1.0, 0.15)
	var t := b.create_tween()
	t.tween_property(b, "position", Vector2(BX + 1050, y - 60), 4.0).set_trans(Tween.TRANS_SINE)
	t.tween_callback(b.queue_free)


func save_item_position(it: Node2D) -> void:
	for e in Game.placed:
		if e.uid == it.uid:
			e.x = it.position.x
			e.y = it.position.y
	Game.save_game()


func _entry(it: Node2D) -> Dictionary:
	for e in Game.placed:
		if e.uid == it.uid:
			return e
	return {}


## Bubák took a bite out of something edible (a branch). Gone when all bites are eaten.
func bite_item(it: Node2D) -> void:
	var e := _entry(it)
	if e.is_empty():
		return
	e.bites = e.get("bites", Catalog.ITEMS[it.id].get("bites", 1)) - 1
	if e.bites > 0:
		it.wiggle()
		return
	Game.placed.erase(e)
	items.erase(it.uid)
	spawn_fx("star", it.position + Vector2(0, -30))
	it.queue_free()
	hud.toast(tr("The whole branch is eaten! Time for a fresh one."))
	Game.save_game()


func add_dropping(pos: Vector2) -> void:
	var f := Game.floor_of(Game.room_at(pos))
	pos = Vector2(clampf(pos.x, f.position.x, f.end.x), clampf(pos.y, f.position.y, f.end.y))
	Game.droppings.append([pos.x, pos.y])
	_spawn_dropping_node(pos)


func add_fur(pos: Vector2) -> void:
	var f := Game.floor_of(Game.room_at(pos))
	pos = Vector2(clampf(pos.x, f.position.x, f.end.x), clampf(pos.y, f.position.y, f.end.y))
	Game.fur.append([pos.x, pos.y])
	_spawn_dropping_node(pos, true)


## Droppings and tufts of shed fur: tap to pick them up.
func _spawn_dropping_node(pos: Vector2, is_fur := false) -> void:
	var s := Sprite2D.new()
	s.texture = Catalog.tex("fur_tuft" if is_fur else "dropping")
	s.position = pos
	s.scale = Vector2(0.8, 0.8)
	if is_fur:
		s.set_meta("fur", true)
		s.rotation = randf_range(-0.4, 0.4)
	floor_layer.add_child(s)
	dropping_nodes.append(s)


## Puts Bubák's best ribbons and trophies on the wall shelf.
func update_trophies() -> void:
	for c in shelf.get_children():
		if c != shelf.sprite:
			c.queue_free()
	shelf.visible = not Game.trophies.is_empty()
	var best: Array = Game.trophies.duplicate()
	best.sort_custom(func(a, b): return a.tier > b.tier or (a.tier == b.tier and a.place < b.place))
	best = best.slice(0, 6)
	for i in best.size():
		var t: Dictionary = best[i]
		var r := Sprite2D.new()
		r.texture = Catalog.tex(Catalog.trophy_tex(t))
		r.centered = false
		r.offset = Vector2(-r.texture.get_size().x / 2.0, -r.texture.get_size().y)
		r.scale = Vector2.ONE * 0.5
		r.position = Vector2(-95 + i * 38, -20)
		shelf.add_child(r)



func hour() -> float:
	if _debug_hour >= 0:
		return _debug_hour
	var d := Time.get_datetime_dict_from_system()
	return d.hour + d.minute / 60.0


# ---- input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var wp := _to_world(event.position)
		if event.pressed:
			_on_press(wp)
		else:
			_on_release(wp)
	elif event is InputEventMouseMotion and _pressing and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		var wp := _to_world(event.position)
		_moved = maxf(_moved, wp.distance_to(_press_pos))
		if _press_target in bunnies and mode in ["", "photo"] and _press_pos.y - wp.y > 70:
			# dragging a bunny upwards = trying to pick it up
			var b: Node2D = _press_target
			_press_target = null
			if _petting:
				_pet_bunny.on_pet_end()
				_petting = false
			try_pick_up(b)
		if _dragging:
			var p := wp + _drag_off
			var f := Game.floor_of(view)
			_dragging.position = Vector2(clampf(p.x, f.position.x, f.end.x),
				clampf(p.y, f.position.y - 10, f.end.y + 10))


func _to_world(screen: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen


func _on_press(wp: Vector2) -> void:
	_pressing = true
	_press_pos = wp
	_press_time = Time.get_ticks_msec() / 1000.0
	_moved = 0.0
	_press_target = _hit(wp, mode == "move")
	if mode == "move" and _press_target is Placeable and _press_target.movable:
		_dragging = _press_target
		_drag_off = _dragging.position - wp
		_dragging.set_highlight(true)


func _on_release(wp: Vector2) -> void:
	_pressing = false
	if _dragging:
		_dragging.set_highlight(false)
		save_item_position(_dragging)
		_dragging = null
		return
	if _petting:
		_pet_bunny.on_pet_end()
		_petting = false
		return
	if Time.get_ticks_msec() / 1000.0 - _press_time < 0.4 and _moved < 24:
		_tap(wp, _press_target)


func _hit(wp: Vector2, furniture_only := false):
	if not furniture_only:
		var front: Node2D = null   # the one standing in front wins
		for b in bunnies:
			if b.visible and _bunny_rect(b).has_point(wp) and (front == null or b.position.y > front.position.y):
				front = b
		if front:
			return front
	if not furniture_only:
		for d in dropping_nodes:
			if d.position.distance_to(wp) < 26:
				return d
	var cands: Array = items.values() + fixed
	cands.sort_custom(func(a, b): return a.position.y > b.position.y)
	var flat: Array = []
	for it in cands:
		if not it.visible:
			continue
		if Catalog.ITEMS.get(it.id, {}).get("flat", false):
			flat.append(it)
		elif it.rect().has_point(wp):
			return it
	for it in flat:
		if it.rect().has_point(wp):
			return it
	return null


func _bunny_rect(b: Node2D) -> Rect2:
	var s: float = b.scale_factor()
	return Rect2(b.position + Vector2(-80 * s, -140 * s - b.lift), Vector2(160 * s, 150 * s))


func _tap(wp: Vector2, t) -> void:
	match mode:
		"photo", "move", "selfie":
			return
		"treat":
			if t in bunnies or Game.floor_of(view).grow(40).has_point(wp):
				_offer_treat(t.position if t in bunnies else wp, t if t in bunnies else null)
			return
	if t in bunnies:
		t.on_tap()
	elif t is Sprite2D and t in dropping_nodes:
		dropping_nodes.erase(t)
		var list: Array = Game.fur if t.has_meta("fur") else Game.droppings
		var i := 0
		for d in list:
			if Vector2(d[0], d[1]).distance_to(t.position) < 1:
				list.remove_at(i)
				break
			i += 1
		spawn_fx("clean", t.position)
		t.queue_free()
	elif t is Placeable:
		_use_item(t)
	elif Game.floor_of(view).has_point(wp):
		for b in bunnies:
			if b.room_id == view:
				b.on_floor_tap(wp)


func _use_item(it: Node2D) -> void:
	it.wiggle()
	var above: Vector2 = it.position + Vector2(0, -it.size().y - 10)
	match it.id:
		"bowl":
			if Game.bowl >= [3, 5, 8][Game.tier("bowl") - 1]:
				hud.toast(tr("The bowl is full."))
			elif Game.use_inventory("pellets"):
				Game.bowl += 1
				spawn_fx("text", above, tr("+ pellets"))
			else:
				hud.toast(tr("Out of pellets! Buy more in the shop."))
		"hayrack":
			if Game.hay > 80:
				hud.toast(tr("Plenty of hay in there already."))
			elif Game.use_inventory("hay"):
				Game.hay = minf(100, Game.hay + [55, 80, 100][Game.tier("hayrack") - 1])
				spawn_fx("text", above, tr("+ hay"))
			else:
				hud.toast(tr("Out of hay! Bunnies need lots of it. Visit the shop."))
		"water":
			Game.water = 100
			spawn_fx("text", above, tr("fresh water!"))
		"litter":
			if Game.litter < 5:
				hud.toast(tr("Already spotless."))
			else:
				Game.litter = 0
				spawn_fx("clean", above)
				spawn_fx("text", above, tr("sparkly clean!"))
		"desk", "office_chair":
			hud.open_work()
		"trophy_shelf":
			hud.open_club("Trophies")
		"door":
			match Game.balcony:
				"open":
					go_to("balcony")
				"available":
					hud.toast(tr("Almost! Make the balcony bunny-safe first: Balcony netting is in the Shop (Home)."))
				_:
					hud.toast(tr("The balcony door is locked. It opens once Bubák trusts you (%s) and he has %d followers.\nNow: %s, %d followers.") % [
						Catalog.level_name(Catalog.BALCONY_TRUST), Catalog.BALCONY_FOLLOWERS,
						Catalog.level_name(Game.trust_level()), Game.followers])
		"balcony_door":
			go_to("living")
		"planter":
			hud.toast(tr("Parsley and dandelions. They grow back... if a certain bunny lets them.") if Game.herbs > 40
				else tr("Nibbled down to stubs. They'll grow back in a while."))
		"cable":
			match Game.cable:
				"covered": hud.toast(tr("Safe and sound under its cover."))
				"chewed": hud.toast(tr("Chewed through... A cable cover from the shop would prevent this."))
				_: hud.toast(tr("Bubák eyes this cable a little too often..."))
		"sofa":
			hud.toast([tr("Comfy. Bubák is not allowed up here. (He disagrees.)"),
				tr("You find a hay stalk between the cushions. How?"),
				tr("The sofa has suspicious nibble marks on one leg.")].pick_random())
		"ball":
			var dest: Vector2 = it.position + Vector2(randf_range(-160, 160), randf_range(-60, 60))
			var f := Game.floor_of(Game.room_at(it.position))
			dest = Vector2(clampf(dest.x, f.position.x, f.end.x), clampf(dest.y, f.position.y, f.end.y))
			var tw := it.create_tween()
			tw.tween_property(it, "position", dest, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(it.sprite, "rotation", it.sprite.rotation + TAU, 0.6)
			tw.tween_callback(save_item_position.bind(it))
			var b := bunny_near(it.position)
			if b and b.pet.needs.fun < 90 and b.act in ["idle", "wander", "loaf", "groom"]:
				b.start("play_ball", it)


# ---- treats ------------------------------------------------------------------

func _offer_treat(pos: Vector2, who: Node2D = null) -> void:
	set_mode("")
	if who == null:
		who = bunny_near(pos)
	if who == null:
		hud.toast(tr("Bubák isn't here. He's %s.") % (tr("out on the balcony") if bunny.room_id == "balcony" else tr("inside")))
		return
	if not Game.use_inventory(treat_selected):
		hud.toast(tr("You're out of those."))
		return
	_remove_hand()
	var f := Game.floor_of(view)
	hand_pos = Vector2(clampf(pos.x, f.position.x + 40, f.end.x - 40), clampf(pos.y, f.position.y + 10, f.end.y))
	hand_treat = treat_selected
	hand_time = 8.0
	hand = Node2D.new()
	hand.position = hand_pos
	var h := Sprite2D.new()
	h.texture = Catalog.icon("hand")
	h.position = Vector2(0, -20)
	h.scale = Vector2(1.2, 1.2)
	hand.add_child(h)
	var tr := Sprite2D.new()
	tr.texture = Catalog.icon(hand_treat)
	tr.position = Vector2(4, -52)
	tr.scale = Vector2(0.7, 0.7)
	hand.add_child(tr)
	world.add_child(hand)
	who.offer_treat()


func hand_active() -> bool:
	return hand != null


func take_hand_treat() -> String:
	var t := hand_treat
	_remove_hand()
	return t


func _remove_hand() -> void:
	if hand:
		hand.queue_free()
		hand = null


## Picks up a bunny (by default Bubák, or whoever is here) for a selfie together.
func try_pick_up(b: Node2D = null) -> void:
	if b == null:
		b = bunny if bunny.room_id == view else bunny_near(camera.position)
	if b == null:
		hud.toast(tr("Bubák isn't here. He's %s.") % (tr("out on the balcony") if bunny.room_id == "balcony" else tr("inside")))
		return
	if b.try_pick_up() == "ok":
		held = b
		set_mode("selfie")


## Starts the scene over from the game state (after loading a save or starting a new game).
func reload() -> void:
	get_tree().reload_current_scene()


## Rebuilds the on-screen UI in the newly chosen language.
func apply_language() -> void:
	var old := hud
	hud = Hud.new()
	hud.main = self
	hud_layer.add_child(hud)
	old.queue_free()
	for b in bunnies:
		b.message.connect(hud.toast)
	Game.balcony_milestone.connect(hud.on_balcony_milestone)
	hud.on_mode_changed(mode)


func set_mode(m: String) -> void:
	if mode == "move" and m != "move":
		Game.save_game()
	if mode == "selfie" and m != "selfie" and held:
		held.put_down()
	mode = m
	hud.on_mode_changed(m)


# ---- effects -----------------------------------------------------------------

func spawn_fx(kind: String, pos: Vector2, text := "") -> void:
	if kind == "dust":   # puff when Bubák lands from a hop
		var p := Sprite2D.new()
		p.texture = Catalog.soft_circle()
		p.modulate = Color(1, 0.96, 0.88, 0.75)
		p.scale = Vector2(0.2, 0.14)
		p.position = pos
		fx.add_child(p)
		var pt := p.create_tween().set_parallel()
		pt.tween_property(p, "scale", Vector2(0.42, 0.26), 0.45).set_ease(Tween.EASE_OUT)
		pt.tween_property(p, "position", pos + Vector2(randf_range(-14, 14), -8), 0.45)
		pt.tween_property(p, "modulate:a", 0.0, 0.45)
		pt.chain().tween_callback(p.queue_free)
		return
	if kind == "dirt":   # sand flying out of the dig box
		var d := Sprite2D.new()
		d.texture = Catalog.tex("dropping")
		d.modulate = Color("#e6c98a")
		d.scale = Vector2.ONE * randf_range(0.4, 0.7)
		d.position = pos
		fx.add_child(d)
		var dt := d.create_tween().set_parallel()
		dt.tween_property(d, "position", pos + Vector2(randf_range(-60, 60), randf_range(-60, -20)), 0.45)
		dt.tween_property(d, "modulate:a", 0.0, 0.45)
		dt.chain().tween_callback(d.queue_free)
		return
	var n: CanvasItem
	match kind:
		"heart", "star", "clean":
			var s := Sprite2D.new()
			s.texture = Catalog.icon(kind)
			s.scale = Vector2.ONE * (0.5 if kind == "heart" else 0.38)
			s.position = pos + Vector2(randf_range(-12, 12), 0)
			n = s
		_:
			var l := Label.new()
			l.text = {"z": "z", "!": "!", "?": "?"}.get(kind, text)
			var ls := LabelSettings.new()
			ls.font_size = 34 if kind in ["z", "!", "?"] else 28
			ls.font_color = UI.INK
			ls.outline_size = 10
			ls.outline_color = Color.WHITE
			l.label_settings = ls
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.size = Vector2(200, 48)
			l.position = pos - Vector2(100, 40) + Vector2(randf_range(-6, 6), 0)
			n = l
	fx.add_child(n)
	var t := n.create_tween().set_parallel()
	t.tween_property(n, "position:y", n.position.y - 70, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(n, "modulate:a", 0.0, 0.5).set_delay(0.7)
	t.chain().tween_callback(n.queue_free)


func shake() -> void:
	_shake = 9.0


func _on_cable_alert(active: bool, b: Node2D) -> void:
	if active:
		hud.toast(tr("Uh oh! %s is nibbling the laptop cable! Tap to stop it.") % b.pet.display_name())
		cable.wiggle(1.5)


# ---- day & night ---------------------------------------------------------------

func _update_sky() -> void:
	var h := hour()
	var a: Array = SKY_KEYS[0]
	var b: Array = SKY_KEYS[1]
	for i in SKY_KEYS.size() - 1:
		if h >= SKY_KEYS[i][0] and h < SKY_KEYS[i + 1][0]:
			a = SKY_KEYS[i]
			b = SKY_KEYS[i + 1]
	var k: float = (h - a[0]) / (b[0] - a[0])
	_sky_colors = [Color(a[1]).lerp(Color(b[1]), k), Color(a[2]).lerp(Color(b[2]), k)]
	var c: Color = Color(a[3]).lerp(Color(b[3]), k)
	_night = 1.0 - _daylight(h)
	if (find_item("lamp") or find_item("lantern")) and _night > 0.05:
		c = c.lerp(Color("#f7dcc0"), 0.3 * _night)
	tint.color = c
	sky.queue_redraw()
	beam.queue_redraw()
	clock.queue_redraw()


## 1 in full daylight, 0 at night, with a dawn and a dusk ramp.
func _daylight(h: float) -> float:
	if h < 5.5 or h > 21.0:
		return 0.0
	if h < 8.0:
		return (h - 5.5) / 2.5
	if h > 18.5:
		return (21.0 - h) / 2.5
	return 1.0


func _draw_sky() -> void:
	_draw_sky_in(WINDOW, 1.0)
	_draw_sky_in(BALCONY_SKY, 2.2)


# ---- lights ----------------------------------------------------------------------
# A separate canvas layer that follows the camera but isn't darkened by the night tint,
# with additive blending: sunbeams by day, lamps, screens and city windows by night.

func _build_lighting() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	layer.follow_viewport_enabled = true
	add_child(layer)
	glow = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	layer.add_child(glow)
	beam = Node2D.new()
	beam.use_parent_material = true
	beam.draw.connect(_draw_beam)
	glow.add_child(beam)
	dust = CPUParticles2D.new()
	dust.use_parent_material = true
	dust.texture = Catalog.soft_circle()
	dust.amount = 26
	dust.lifetime = 7.0
	dust.preprocess = 7.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(120, 170)
	dust.direction = Vector2(0, -1)
	dust.spread = 180.0
	dust.initial_velocity_min = 3.0
	dust.initial_velocity_max = 9.0
	dust.gravity = Vector2(0, -1.5)
	dust.scale_amount_min = 0.03
	dust.scale_amount_max = 0.07
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 0.95, 0.8, 0))
	fade.set_color(1, Color(1, 0.95, 0.8, 0))
	fade.add_point(0.5, Color(1, 0.95, 0.8, 0.6))
	dust.color_ramp = fade
	glow.add_child(dust)
	city_lights = Sprite2D.new()
	city_lights.texture = Catalog.tex("balcony_windows")
	city_lights.centered = false
	city_lights.position = Vector2(BX - 240, -160)
	city_lights.use_parent_material = true
	glow.add_child(city_lights)
	laptop_glow = _glow_sprite(Color(0.55, 0.8, 1.0), 1.3)
	laptop_glow.position = Vector2(1100, 296)
	# string lights on the balcony, at the same spots as the bulbs in the background art
	var colors := [Color("#f3cf7a"), Color("#e9a3a0"), Color("#a7c0e8"), Color("#9cc5a1")]
	for i in range(1, 16):
		var t := i / 16.0
		var y := pow(1 - t, 2) * 220 + 2 * (1 - t) * t * 310 + t * t * 210 + 10
		var bulb := _glow_sprite(colors[i % 4], 0.5)
		bulb.position = Vector2(BX - 240 + t * 1250, y - 160)
		_bulbs.append(bulb)
	# soft vignette over the whole scene
	var vlayer := CanvasLayer.new()
	vlayer.layer = 3
	add_child(vlayer)
	var g := Gradient.new()
	g.set_color(0, Color(0.22, 0.12, 0.08, 0))
	g.set_color(1, Color(0.22, 0.12, 0.08, 0.3))
	g.set_offset(0, 0.62)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.08, 0.5)
	var vig := TextureRect.new()
	vig.texture = gt
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vlayer.add_child(vig)


func _glow_sprite(color: Color, size: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = Catalog.soft_circle()
	s.use_parent_material = true
	s.modulate = color
	s.scale = Vector2.ONE * size
	glow.add_child(s)
	return s


func _update_lights() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var night := clampf((_night - 0.2) * 1.6, 0, 1)
	var day := clampf(1.0 - _night * 1.4, 0, 1)
	dust.emitting = day > 0.25
	dust.modulate.a = day
	city_lights.modulate.a = night
	laptop_glow.modulate.a = night * 0.4
	for i in _bulbs.size():
		_bulbs[i].modulate.a = night * (0.75 + 0.25 * sin(t * 2.0 + i * 1.7))
	# lamps and lanterns: a halo around the shade and a warm pool on the floor
	var alive := {}
	for it in items.values():
		if not it.id in ["lamp", "lantern"]:
			continue
		alive[it.uid] = true
		if not _lamp_glows.has(it.uid):
			_lamp_glows[it.uid] = [_glow_sprite(Color(1.0, 0.72, 0.38), 2.8), _glow_sprite(Color(1.0, 0.78, 0.45), 1.0)]
		var halo: Sprite2D = _lamp_glows[it.uid][0]
		var pool: Sprite2D = _lamp_glows[it.uid][1]
		halo.position = it.position + Vector2(0, -it.size().y * (0.84 if it.id == "lamp" else 0.8))
		halo.modulate.a = night * (0.5 if it.id == "lamp" else 0.38) * (0.97 + 0.03 * sin(t * 3.0 + it.uid))
		pool.position = it.position + Vector2(0, -4)
		pool.scale = Vector2(3.4, 0.9)
		pool.modulate.a = night * 0.28
	for uid in _lamp_glows.keys():
		if not alive.has(uid):
			for g in _lamp_glows[uid]:
				g.queue_free()
			_lamp_glows.erase(uid)


## Daylight through the window: a faint shaft and a bright patch on the floor that
## moves with the sun during the day.
func _draw_beam() -> void:
	var day := clampf(1.0 - _night * 1.4, 0, 1)
	if day <= 0.01:
		return
	var sx := lerpf(-240.0, 240.0, clampf((hour() - 7.0) / 12.0, 0, 1))
	var c := Color(1.0, 0.93, 0.75)
	var top := Color(c, 0.09 * day)
	var bot := Color(c, 0.0)
	beam.draw_polygon(PackedVector2Array([Vector2(768, 66), Vector2(972, 66), Vector2(1010 + sx, 690), Vector2(730 + sx, 690)]),
		PackedColorArray([top, top, bot, bot]))
	var patch := Color(c, 0.14 * day)
	var patch_far := Color(c, 0.06 * day)
	beam.draw_polygon(PackedVector2Array([Vector2(790 + sx * 0.7, 520), Vector2(950 + sx * 0.7, 520),
		Vector2(1000 + sx, 690), Vector2(740 + sx, 690)]), PackedColorArray([patch_far, patch_far, patch, patch]))
	dust.position = Vector2(870 + sx * 0.6, 420)


func _draw_clock() -> void:
	var h := hour()
	var m := (h - floorf(h)) * 60.0
	clock.draw_circle(Vector2(3, 5), 34, Color(0.31, 0.2, 0.14, 0.15))
	clock.draw_circle(Vector2.ZERO, 34, UI.INK)
	clock.draw_circle(Vector2.ZERO, 30, Color("#fffaf0"))
	for i in 12:
		var a := TAU * i / 12.0
		var inner := 21.0 if i % 3 == 0 else 24.0
		clock.draw_line(Vector2.from_angle(a) * inner, Vector2.from_angle(a) * 27.0, UI.INK, 3.0 if i % 3 == 0 else 2.0, true)
	var ha := TAU * (fmod(h, 12.0) / 12.0) - PI / 2
	var ma := TAU * (m / 60.0) - PI / 2
	clock.draw_line(Vector2.ZERO, Vector2.from_angle(ha) * 15.0, UI.INK, 4.5, true)
	clock.draw_line(Vector2.ZERO, Vector2.from_angle(ma) * 22.0, UI.INK, 3.0, true)
	clock.draw_circle(Vector2.ZERO, 4, Color("#e9a3a0"))


func _draw_sky_in(r: Rect2, scale: float) -> void:
	var top: Color = _sky_colors[0]
	var bottom: Color = _sky_colors[1]
	sky.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
		Vector2(r.position.x, r.end.y)]), PackedColorArray([top, top, bottom, bottom]))
	if _night > 0.2:
		var rnd := RandomNumberGenerator.new()
		rnd.seed = 7
		for i in 14:
			var p := Vector2(rnd.randf_range(r.position.x + 10, r.end.x - 10), rnd.randf_range(r.position.y + 10, r.end.y - 90))
			var tw := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 1000.0 * 1.7 + i * 1.3)
			sky.draw_circle(p, rnd.randf_range(1.2, 2.6) * scale, Color(1, 1, 0.9, _night * tw))
		var moon := Vector2(r.end.x - 60 * scale, r.position.y + 60 * scale + (120 if scale > 1 else 0))
		sky.draw_circle(moon, 22 * scale, Color("#fff4cf"))
		sky.draw_circle(moon + Vector2(10, -6) * scale, 20 * scale, top)
	else:
		sky.draw_circle(r.position + Vector2(70, 70 + (140 if scale > 1 else 0)) * Vector2(scale, 1), 26 * minf(scale, 1.6), Color("#fff2b0"))
		var drift := Time.get_ticks_msec() / 1000.0 * 5.0
		for cl in [[Vector2(150, 150), 1.0], [Vector2(60, 200), 0.7], [Vector2(420, 90), 0.85]]:
			var c: Vector2 = r.position + cl[0] * scale
			c.x = r.position.x + fposmod(c.x - r.position.x + drift * scale * cl[1], r.size.x + 160) - 80
			var s: float = cl[1] * minf(scale, 1.6)
			for o in [Vector2(-24, 4), Vector2(0, -8), Vector2(24, 4)]:
				sky.draw_circle(c + o * s, 18 * s, Color(1, 1, 1, 0.9))


# ---- photos -------------------------------------------------------------------

func take_photo() -> void:
	var subject := bunny_near(camera.position)   # whoever is nearest the middle of the shot
	var behaviour: String = subject.current_behaviour() if subject else ""
	var decor := 0
	for it in items.values():
		if subject and it.id in DECOR and it.position.distance_to(subject.position) < 260:
			decor += 1
	hud_layer.visible = false
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	hud_layer.visible = true
	var vis := get_viewport().get_visible_rect().size
	var k := img.get_width() / vis.x
	var crop := Vector2(560, 420)
	var center := get_viewport().get_canvas_transform() * ((subject.position if subject else Vector2.ZERO) + Vector2(0, -50))
	if subject == null:
		center = vis / 2.0
	var top_left := Vector2(clampf(center.x - crop.x / 2, 0, vis.x - crop.x), clampf(center.y - crop.y / 2, 0, vis.y - crop.y))
	var sub := img.get_region(Rect2i(Vector2i(top_left * k), Vector2i(crop * k)))
	sub.resize(480, 360, Image.INTERPOLATE_LANCZOS)
	var file := Game.PHOTO_DIR + "p_%d.png" % int(Time.get_unix_time_from_system() * 1000)
	sub.save_png(file)
	var res := Game.record_photo(file, behaviour, decor)
	hud.show_photo_result(sub, res)


# ---- lifecycle ------------------------------------------------------------------

func _demo() -> void:
	await get_tree().process_frame
	hud.close_top()
	Game.coins = 9000
	Game.trust = 70.0
	Game.followers = 400
	Game.balcony = "open"
	Game.career_xp = 4000
	for id in ["rug", "plant", "lamp", "lantern", "bed", "castle", "tunnel", "ball", "flowers", "bowl2", "bowl3",
			"water2", "water3", "hayrack2", "litter2", "chair", "monitor", "coffee", "bow"]:
		Game.buy(id)
	Game.buy("flowers", "balcony")
	Game.buy("beanbag", "balcony")
	Game.welcome_text = ""


func _screenshot(path: String) -> void:
	var delay := 3.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--delay="):
			delay = float(arg.get_slice("=", 1))
	await get_tree().create_timer(delay * 0.5).timeout
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--open="):
			hud._pending.clear()   # startup pop-ups out of the way first
			hud.close_top()
			match arg.get_slice("=", 1):
				"shop": hud.open_shop()
				"journal": hud.open_journal()
				"work": hud.open_work()
				"photo": set_mode("photo")
				"tray": hud._toggle_tray()
				"club": hud.open_club("Shows")
				"hutch": hud.open_hutch()
				"settings": hud.open_settings()
	await get_tree().create_timer(delay * 0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


func _on_welcome(text: String) -> void:
	if hud:
		hud.show_welcome(text)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			Game.save_game()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if hud and not hud.close_top():
				Game.save_game()
				get_tree().quit()
