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
## Christmas: baubles on the tree (in its art's pixels), and the garland over the window
## (top-left corner; its bulbs follow the swags drawn by gen_art.py garland()).
const TREE_BAUBLES := [Vector2(92, 104), Vector2(128, 96), Vector2(78, 160), Vector2(112, 176), Vector2(146, 154),
	Vector2(64, 214), Vector2(98, 230), Vector2(138, 222), Vector2(172, 208)]
const GARLAND_AT := Vector2(688, 82)

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
var foster_bunny: Node2D = null
var bunnies: Array = []  # Bubák, and his friend once adopted
var held: Node2D = null  # the bunny picked up for a selfie
var _pet_bunny: Node2D = null
var cable: Node2D
var door: Node2D
var balcony_door: Node2D
var planter: Node2D
var sunspot: Node2D
var desk: Node2D
var laptop: Sprite2D
var closet: Node2D
var toy_chest: Node2D
var _chest_t := 2.0
var _feeder_t := 6.0
var _laptop_t := 1.0
var chair: Node2D
var shelf: Node2D        # trophy shelf on the wall, appears with the first ribbon
var xmas_tree: Node2D = null   # over Christmas
var present: Node2D = null     # a wrapped present on a special day
var room_bg: Sprite2D          # wallpaper and floor (Shop > Makeover)
var pumpkin: Node2D = null     # Halloween
var easter_decor: Node2D = null   # a vase of willow and painted eggs
var eggs: Array = []           # Easter eggs still hidden around the flat
var guest: Node2D = null       # a friend's bunny over for a playdate
var _visit_t := 200.0          # till the next chance of a visitor
var _guest_t := 0.0            # how long the guest stays
var _cat_t := 0.0              # the neighbour's cat at the window (seconds left)
var _cat_rise := 0.0
var _crops: Array = []         # sprites on the veggie patch
var storm_t := 0.0             # a thunderstorm: seconds left
var _thunder_t := 0.0
var _flash_t := 0.0
var _storm_day := ""
var leaf_pile: Node2D = null   # autumn, on the balcony
var advent_cal: Node2D = null  # December: the advent calendar on the wall
var _snow_floor: Node2D = null # snow on the balcony on snowy winter days
var _peek: Sprite2D = null     # Bubák's ears sticking out during hide and seek
var _season := ""
var _snowing := false
var _heat := false
var sofa: Node2D
var _xmas_decor: Array = []    # the garland over the window
var _xmas_lights: Array = []   # [glow sprite, size] twinkling on the tree and the garland
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
		elif arg.begins_with("--weightsim="):   # tune the weight numbers (tools/weightsim.gd)
			Game.use_scratch_game("user://weightsim_save.json")
			Game.new_game()
			var sim: Node = load("res://tools/weightsim.gd").new()
			sim.set_meta("arg", arg.get_slice("=", 1))
			add_child.call_deferred(sim)
		elif arg == "--demo":   # a furnished flat, for trying things out
			Game.use_scratch_game("user://demo_save.json")
			_demo.call_deferred()
		elif arg.begins_with("--lang="):   # screenshots in another language, settings untouched
			TranslationServer.set_locale(arg.get_slice("=", 1))
		elif arg.begins_with("--save="):   # play a copy of a save file, e.g. to check an older save still loads
			Game.save_path = arg.get_slice("=", 1)
			if not Game.load_game():
				Game.new_game()   # no such file: a fresh game in it
			Game._settle()
		elif arg.begins_with("--date="):   # try a special day: --date=12-24
			Game.debug_date = arg.get_slice("=", 1)
		elif arg.begins_with("--view="):
			go_to.call_deferred(arg.get_slice("=", 1))
	RenderingServer.set_default_clear_color(Color("#f7e6d0"))
	camera = Camera2D.new()
	camera.position = Vector2(640, 360)
	add_child(camera)

	sky = Node2D.new()
	sky.draw.connect(_draw_sky)
	add_child(sky)
	room_bg = Sprite2D.new()
	var bg := room_bg
	bg.texture = Catalog.tex(_room_tex())
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

	sofa = _make_item("sofa", 0, Vector2(410, 478), "sofa", 0.78)
	fixed.append(sofa)
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
	# the laptop is its own sprite (pivot at its base) so it can jiggle when work is waiting
	laptop = Sprite2D.new()
	laptop.texture = Catalog.tex("laptop")
	laptop.centered = false
	laptop.position = Vector2(-10, -158)
	laptop.offset = Vector2(-110, -62)
	desk.add_child(laptop)
	closet = _make_item("closet", 0, Vector2(362, 226), "closet", 0.7)   # on the wall above the sofa
	fixed.append(closet)
	toy_chest = _make_item("toy_chest", 0, Vector2(905, 484), "toy_chest", 0.8)
	fixed.append(toy_chest)
	chair = _make_item("office_chair", 0, Vector2(1100, 476), "chair", 0.85)   # pushed in under the desk
	fixed.append(chair)
	cable = _make_item("cable", 0, Vector2(1105, 464), "cable_" + Game.cable, 1.0)   # under the desk
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
	if Game.foster:
		foster_bunny = _add_bunny(Game.foster, Vector2(860, 640))

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
	Game.item_worn.connect(_show_wear)
	Game.item_broken.connect(_on_item_broken)
	Game.item_removed.connect(_on_item_removed)
	Game.balcony_milestone.connect(hud.on_balcony_milestone)
	if not Game.welcome.is_connected(_on_welcome):
		Game.welcome.connect(_on_welcome)
	_snow_floor = Node2D.new()
	_snow_floor.draw.connect(_draw_snow_floor)
	floor_layer.add_child(_snow_floor)
	update_season()
	_update_sky()
	update_special_day(true)
	if Game.welcome_text != "":
		hud.show_welcome.call_deferred(Game.welcome_text)
		Game.welcome_text = ""
	Game.check_sponsor.call_deferred()
	Game.check_wish.call_deferred()
	Game.check_day.call_deferred()
	Game.check_daily.call_deferred()
	if Game.vaccine_due():
		hud.toast_when_free.call_deferred(tr("Bubák's yearly vaccination is due: Journal > Bubák > the vet.") if not Game.vaccine_overdue()
			else tr("Bubák's vaccination is overdue: no shows, walks or playdates until he's had it (Journal > Bubák)."), "vet")
	elif Game.vet_due():
		hud.toast_when_free.call_deferred(tr("Bubák's weekly check-up at the vet is due: Journal > Bubák."), "vet")
	Game.style_changed.connect(func():
		room_bg.texture = Catalog.tex(_room_tex())
		spawn_fx("star", Vector2(640, 300)))
	Game.memory_added.connect(_on_memory)
	_visit_t = randf_range(Catalog.VISIT_EVERY[0], Catalog.VISIT_EVERY[1])


func _process(delta: float) -> void:
	Sfx.set_night(not is_daytime())
	_update_care_items()
	_jiggle_laptop(delta)
	_jiggle_chest(delta)
	_feeder_birds(delta)
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
	if Game.greet_pending and hud._modal == null and hud._pending.is_empty() and mode == "":
		Game.greet_pending = false
		_greet()
	_visitors(delta)
	_storm(delta)
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
		Game.check_wish()
		Game.check_day()
		Game.check_daily()
		update_special_day()
		update_season()


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
	var tray := find_item("grass_tray")
	if tray:
		tray.set_texture("grass_tray" if Game.grass > 35 else "grass_tray_short")
	var feeder := find_item("bird_feeder")
	if feeder:
		feeder.set_texture("bird_feeder" if Game.seeds > 0 else "bird_feeder_empty")
	sunspot.visible = is_daytime()
	_update_crops()


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


## Put away in the toy chest: off the floor, and whoever was using it finds something else to do.
## A worn toy looks faded and scuffed.
func _show_wear(uid: int, wear: float) -> void:
	var it: Node2D = items.get(uid)
	if it:
		it.modulate = Color.WHITE.lerp(Color(0.78, 0.72, 0.66), clampf((wear - 0.3) / 0.7, 0.0, 1.0))


func _on_item_broken(id: String) -> void:
	Sfx.play("rip")
	hud.toast(tr("Bubák loved the %s to pieces! Get a new one in the Shop.") % Catalog.item_name(id).to_lower(), Catalog.ITEMS[id].icon, true)


func _on_item_removed(uid: int) -> void:
	var it: Node2D = items.get(uid)
	if it == null:
		return
	items.erase(uid)
	for b in bunnies:
		if b.item == it and b.act != "held":
			b.start("idle", null, b.position)
	spawn_fx("star", it.position + Vector2(0, -30))
	it.queue_free()


func _spawn_placed(e: Dictionary) -> void:
	var it := _make_item(e.id, e.uid, Vector2(e.x, e.y))
	items[e.uid] = it
	_show_wear(e.uid, Game.wear_of(e))
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
	var pool: Array = fixed.filter(func(f): return not f in [cable, door, balcony_door, sunspot, chair, shelf, closet, present])
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
	Sfx.play("door")
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


## Birds drop by the feeder while there are seeds in it.
func _feeder_birds(delta: float) -> void:
	_feeder_t -= delta
	if _feeder_t > 0:
		return
	_feeder_t = randf_range(18, 32)
	var feeder := find_item("bird_feeder")
	if feeder == null or Game.seeds <= 0:
		return
	Game.seeds = maxf(0, Game.seeds - 4)
	land_bird(feeder.position + Vector2(randf_range(-14, 14), -feeder.size().y * 0.62), 4.0)


## A bird flies in, lands at `at` for a while (pecking), then flies off over the railing.
func land_bird(at: Vector2, stay: float) -> void:
	if view == "balcony":
		Sfx.play("chirp")
	var b := Sprite2D.new()
	b.texture = Catalog.tex("bird")
	b.offset = Vector2(0, -b.texture.get_size().y / 2.0)
	b.position = Vector2(BX - 60, at.y - 260)
	b.scale = Vector2(0.8, 0.8)
	b.z_index = 2
	fx.add_child(b)
	var t := b.create_tween()
	t.tween_property(b, "position", at, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for i in int(stay / 0.6):   # peck, look around, peck
		t.tween_property(b, "rotation", 0.35, 0.1)
		t.tween_property(b, "rotation", 0.0, 0.15)
		t.tween_interval(0.35)
		if i % 3 == 2:
			t.tween_callback(func(): b.flip_h = not b.flip_h)
	t.tween_callback(func(): b.flip_h = false)
	t.tween_property(b, "position", Vector2(BX + 1100, at.y - 300), 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(b.queue_free)


## A butterfly that flutters just ahead of a bunny while it's chasing, then flies off.
func spawn_butterfly(chaser: Node2D) -> void:
	var b := Sprite2D.new()
	b.texture = Catalog.tex("butterfly")
	b.position = chaser.position + Vector2(140, -160)
	b.z_index = 3
	b.scale = Vector2(1.4, 1.4)
	fx.add_child(b)
	var flap := b.create_tween().set_loops()
	flap.tween_property(b, "scale:x", 0.4, 0.12)
	flap.tween_property(b, "scale:x", 1.4, 0.12)
	var t0 := Time.get_ticks_msec() / 1000.0
	var follow := func():
		var now := Time.get_ticks_msec() / 1000.0 - t0
		if not is_instance_valid(chaser) or chaser.act != "butterfly" or now > 30.0:
			return false
		var goal: Vector2 = chaser.target + Vector2(60 + sin(now * 2.3) * 50, -170 + sin(now * 3.7) * 30)
		b.position = b.position.lerp(goal, 0.05)
		return true
	var timer := Timer.new()
	timer.wait_time = 1.0 / 60.0
	timer.autostart = true
	b.add_child(timer)
	timer.timeout.connect(func():
		if not follow.call():
			timer.stop()
			var t := b.create_tween()
			t.tween_property(b, "position", b.position + Vector2(260, -380), 2.0)
			t.tween_callback(b.queue_free))


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
	if mode == "" and view == "living" and not Game.treasure.is_empty() and not t in bunnies \
			and wp.distance_to(Game.treasure_spot()) < Catalog.TREASURE_RADIUS:
		_dig_treasure(wp)
		return
	if _cat_t > 0 and mode == "" and WINDOW.has_point(wp) and not t in bunnies:
		_cat_t = minf(_cat_t, 0.6)
		hud.toast(tr("Shoo! The cat strolls off along the windowsill."))
		return
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
		"xmas_tree":
			Sfx.play("jingle")
			spawn_fx("star", above + Vector2(0, 30))
		"pumpkin":
			Sfx.play("surprise")
			spawn_fx("text", above, tr("Boo!"))
		"easter_decor":
			Sfx.play("chime")
			spawn_fx("star", above + Vector2(0, 30))
		"egg":
			_find_egg(it)
		"veg_patch":
			hud.open_garden()
		"advent_calendar":
			Sfx.play("jingle")
			hud.open_advent()
		"leaf_pile":
			Sfx.play("rip")
			for i in 6:
				spawn_fx("paper", above + Vector2(randf_range(-40, 40), 30), ["#d9822b", "#c8562e", "#e8b04a"].pick_random())
		"present":
			if it.has_meta("opening"):
				return
			if bunny.room_id != "living" or bunny.act == "held":
				hud.toast(tr("Bubák isn't here. The present can wait!"))
				return
			Sfx.play("jingle")
			it.set_meta("opening", true)
			bunny.start("unwrap", it)
		"bowl":
			if Game.bowl >= [3, 5, 8][Game.tier("bowl") - 1]:
				hud.toast(tr("The bowl is full."))
			elif Game.use_inventory("pellets"):
				Game.bowl += 1
				Sfx.play("pellets")
				spawn_fx("text", above, tr("+ pellets"))
			else:
				hud.toast(tr("Out of pellets! Buy more in the shop."))
		"hayrack":
			if Game.hay > 80:
				hud.toast(tr("Plenty of hay in there already."))
			elif Game.use_inventory("hay"):
				Game.hay = minf(100, Game.hay + [55, 80, 100][Game.tier("hayrack") - 1])
				Sfx.play("hay")
				spawn_fx("text", above, tr("+ hay"))
			else:
				hud.toast(tr("Out of hay! Bunnies need lots of it. Visit the shop."))
		"water":
			Game.water = 100
			Sfx.play("water")
			spawn_fx("text", above, tr("fresh water!"))
		"litter":
			if Game.litter < 5:
				hud.toast(tr("Already spotless."))
			else:
				Game.litter = 0
				Sfx.play("scrape")
				spawn_fx("clean", above)
				spawn_fx("text", above, tr("sparkly clean!"))
		"desk", "office_chair":
			hud.open_work()
		"closet":
			hud.open_wardrobe()
		"toy_chest":
			hud.open_toy_chest()
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
			var got := Game.harvest_herbs()
			if not got.is_empty():
				Sfx.play("pluck")
				spawn_fx("text", above, tr("+%d parsley") % got.parsley)
				spawn_fx("heart", above + Vector2(30, 10))
				hud.toast(tr("Fresh parsley from the planter, for treats!") + (" " + tr("And a dandelion!") if got.has("dandelion") else ""))
			elif Game.is_watered("herbs"):
				hud.toast(tr("Watered and growing. Pick more once it's leafy again."))
			else:
				Game.water_plant("herbs")
				Sfx.play("drip")
				spawn_fx("text", above, tr("watered!"))
				hud.toast(tr("Not much to pick yet, so you water it. It'll grow back faster now."))
		"grass_tray":
			if Game.is_watered("grass"):
				hud.toast(tr("Freshly watered. Give it time to grow."))
			else:
				Game.water_plant("grass")
				Sfx.play("drip")
				spawn_fx("text", above, tr("watered!"))
				hud.toast(tr("The grass will grow back faster now.") if Game.grass < 90 else tr("Lush and green. Bubák approves."))
		"bird_feeder":
			if Game.seeds > 60:
				hud.toast(tr("Plenty of seeds left. The sparrows are happy."))
			else:
				Game.fill_feeder()
				Sfx.play("seeds")
				spawn_fx("text", above, tr("+ seeds"))
				hud.toast(tr("Feeder filled. The birds will be back soon."))
				_feeder_t = 4.0
		"wind_chime":
			Sfx.play("chime")
			spawn_fx("text", above, tr("ting-a-ling!"))
			for b in bunnies:
				if b.room_id == "balcony":
					b.perk_ears()
		"parasol":
			hud.toast(tr("Nice and shady underneath. Perfect for a nap."))
		"cool_tile":
			hud.toast(tr("Cool to the touch, even in the afternoon sun."))
		"lookout":
			hud.toast(tr("The best view on the street. Ask Bubák."))
		"cable":
			match Game.cable:
				"covered": hud.toast(tr("Safe and sound under its cover."))
				"chewed": hud.toast(tr("Chewed through... A cable cover from the shop would prevent this."))
				_: hud.toast(tr("Bubák eyes this cable a little too often..."))
		"sofa":
			hud.toast([tr("Comfy. Bubák is not allowed up here. (He disagrees.)"),
				tr("You find a hay stalk between the cushions. How?"),
				tr("The sofa has suspicious nibble marks on one leg.")].pick_random())
		"ball", "jingle_ball", "egg_rattle":
			if it.id == "jingle_ball":
				Sfx.play("jingle")
			var dest: Vector2 = it.position + Vector2(randf_range(-160, 160), randf_range(-60, 60))
			var f := Game.floor_of(Game.room_at(it.position))
			dest = Vector2(clampf(dest.x, f.position.x, f.end.x), clampf(dest.y, f.position.y, f.end.y))
			var tw := it.create_tween()
			tw.tween_property(it, "position", dest, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(it.sprite, "rotation", it.sprite.rotation + TAU, 0.6)
			tw.tween_callback(save_item_position.bind(it))
			Sfx.play("ball")
			var b := bunny_near(it.position)
			if b and b.pet.needs.fun < 90 and b.act in ["idle", "wander", "loaf", "groom"]:
				b.start("play_ball", it)
		_:
			# any other toy: he hops over to play with it, if he's not busy
			var use: String = Catalog.ITEMS.get(it.id, {}).get("use", "")
			var tb := bunny_near(it.position)
			if tb and use in tb.TOY_ACTS and tb.act in ["idle", "wander", "loaf", "groom", "sunbathe", "chill"]:
				tb.start(use, it)
				tb.emote("!")


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
	if m == "photo":
		for b in bunnies:
			b.on_camera()


# ---- effects -----------------------------------------------------------------

const FX_SOUND := {"heart": "love", "!": "surprise", "?": "huh", "clean": "sparkle", "star": "star", "dust": "hop", "dirt": "dig"}


func spawn_fx(kind: String, pos: Vector2, text := "") -> void:
	if FX_SOUND.has(kind) and Game.room_at(pos) == view:
		Sfx.play(FX_SOUND[kind])
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
	if kind in ["paper", "confetti"]:   # wrapping paper scraps, party confetti
		var c := Polygon2D.new()
		var w := randf_range(6, 12) if kind == "paper" else randf_range(4, 7)
		c.polygon = PackedVector2Array([Vector2(-w, -w * 0.6), Vector2(w, -w * 0.8), Vector2(w * 0.8, w * 0.6), Vector2(-w * 0.9, w * 0.7)])
		c.color = Color(text if text != "" else ["#e8505b", "#f3cf7a", "#7fb0d8", "#e98fae", "#9cc5a1", "#d8a7d0"].pick_random())
		c.position = pos
		c.rotation = randf() * TAU
		fx.add_child(c)
		var up := randf_range(50, 120)
		var to := pos + Vector2(randf_range(-90, 90), randf_range(10, 40))
		var ct := c.create_tween().set_parallel()
		ct.tween_property(c, "position:x", to.x, 0.9)
		ct.tween_property(c, "position:y", pos.y - up, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		ct.chain().tween_property(c, "position:y", to.y, 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		ct.parallel().tween_property(c, "rotation", c.rotation + randf_range(-6, 6), 0.9)
		ct.chain().tween_property(c, "modulate:a", 0.0, 0.4)
		ct.chain().tween_callback(c.queue_free)
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


# ---- special days -------------------------------------------------------------------

## The Christmas tree and a wrapped present come and go with the date.
func update_special_day(greet := false) -> void:
	if Game.is_christmas() != (xmas_tree != null):
		if xmas_tree:
			fixed.erase(xmas_tree)
			xmas_tree.queue_free()
			xmas_tree = null
			for n in _xmas_decor:
				n.queue_free()
			for l in _xmas_lights:
				l[0].queue_free()
			_xmas_decor = []
			_xmas_lights = []
		else:
			Game.tree_pos = _tree_spot()
			xmas_tree = _make_item("xmas_tree", 0, Game.tree_pos, "xmas_tree", 0.85)
			fixed.append(xmas_tree)
			_deck_the_halls()
	if Game.is_halloween() != (pumpkin != null):
		if pumpkin:
			fixed.erase(pumpkin)
			pumpkin.queue_free()
			pumpkin = null
		else:
			Game.tree_pos = _tree_spot()
			pumpkin = _make_item("pumpkin", 0, Game.tree_pos, "pumpkin", 0.8)
			fixed.append(pumpkin)
			var g := _glow_sprite(Color(1.0, 0.6, 0.2), 1.4)
			g.position = Game.tree_pos + Vector2(0, -40)
			_xmas_lights.append([g, 1.4])
			pumpkin.tree_exiting.connect(func():
				_xmas_lights = _xmas_lights.filter(func(l): return l[0] != g)
				g.queue_free())
	if Game.is_easter() != (easter_decor != null):
		if easter_decor:
			fixed.erase(easter_decor)
			easter_decor.queue_free()
			easter_decor = null
			for e in eggs:
				fixed.erase(e)
				e.queue_free()
			eggs = []
		else:
			Game.tree_pos = _tree_spot()
			easter_decor = _make_item("easter_decor", 0, Game.tree_pos, "easter_decor", 0.85)
			fixed.append(easter_decor)
			var spots: Array = Catalog.EGG_SPOTS.duplicate()
			spots.shuffle()
			spots.sort_custom(func(a, b): return _room_around(a) > _room_around(b))   # not hidden behind furniture
			for i in Game.eggs_left():
				var e := _make_item("egg", 0, spots[i], "egg_%d" % (i % 3), 0.55)
				fixed.append(e)
				eggs.append(e)
			if Game.eggs_left() > 0:
				hud.toast_when_free(tr("Happy Easter! %d painted eggs are hidden around the flat. Can you find them?") % Game.eggs_left(), "star", true)
	if Game.advent_on() != (advent_cal != null):
		if advent_cal:
			fixed.erase(advent_cal)
			advent_cal.queue_free()
			advent_cal = null
		else:
			advent_cal = _make_item("advent_calendar", 0, Vector2(560, 300), "advent_calendar", 0.7)
			advent_cal.shadow = false
			fixed.append(advent_cal)
	if advent_cal and greet and not int(Game.today().right(2)) in Game.advent_opened():
		hud.toast_when_free(tr("Today's door of the advent calendar is waiting. Tap the calendar on the wall!"), "gift", true)
	var ev := Game.present_waiting()
	if present and (ev == "" or present.tex_name != Catalog.EVENTS[ev].present) and not present.has_meta("opening"):
		fixed.erase(present)
		present.queue_free()
		present = null
	if ev != "" and present == null:
		var at: Vector2 = Game.tree_pos + Vector2(72, 26) if ev in ["christmas", "easter", "halloween"] else Catalog.BIRTHDAY_POS
		present = _make_item("present", 0, at, Catalog.EVENTS[ev].present, 0.62)
		fixed.append(present)
		greet = true
	if greet and present:
		match ev:
			"birthday":
				hud.toast_when_free(tr("Happy birthday, Bubák! There's a present waiting. Tap it!"), "heart", true)
			"anniversary":
				hud.toast_when_free(tr("You met Bubák on this day! There's a present for him. Tap it!"), "heart", true)
			"easter":
				hud.toast_when_free(tr("All the eggs found! And look: a present for Bubák. Tap it!"), "star", true)
			"halloween":
				hud.toast_when_free(tr("Happy Halloween! There's a present by the pumpkin. Tap it!"), "star", true)
			_:
				hud.toast_when_free(tr("Merry Christmas! There's a present for Bubák under the tree. Tap it!"), "star", true)


## How far a spot is from the nearest piece of furniture in the living room.
func _room_around(p: Vector2) -> float:
	var nearest := 400.0
	for it in items.values() + fixed:
		if it is Placeable and it.visible and Game.room_at(it.position) == "living" and not it.id in ["egg", "door", "cable"]:
			nearest = minf(nearest, it.rect().grow(10).get_center().distance_to(p) - it.size().length() * 0.35)
	return nearest


## Along the back wall, where it's least in the way of the furniture.
func _tree_spot() -> Vector2:
	var best: Vector2 = Catalog.TREE_SPOTS[0]
	var room_left := -1.0
	for spot in Catalog.TREE_SPOTS:
		var nearest := INF
		for it in items.values():
			if Game.room_at(it.position) == "living" and not Catalog.ITEMS[it.id].get("flat", false):
				nearest = minf(nearest, absf(it.position.x - spot.x) + 0.5 * absf(it.position.y - spot.y))
		if nearest > room_left + 30:   # the first spots are the nicest, so only move for real room
			best = spot
			room_left = nearest
	return best


## Christmas decorations: a garland over the window, and fairy lights that twinkle (most at night).
func _deck_the_halls() -> void:
	var garland := Sprite2D.new()
	garland.texture = Catalog.tex("garland")
	garland.centered = false
	garland.position = GARLAND_AT
	floor_layer.add_child(garland)
	_xmas_decor.append(garland)
	var colors := [Color("#f3cf7a"), Color("#e8505b"), Color("#7fb0d8"), Color("#9cc5a1")]
	var i := 0
	for b in TREE_BAUBLES:
		var g := _glow_sprite(colors[i % 4], 0.3)
		g.position = Game.tree_pos + (b - Vector2(110, 296)) * 0.85
		_xmas_lights.append([g, 0.3])
		i += 1
	var star := _glow_sprite(Color(1.0, 0.85, 0.4), 1.0)
	star.position = Game.tree_pos + (Vector2(110, 30) - Vector2(110, 296)) * 0.85
	_xmas_lights.append([star, 1.0])
	for x in [[14.0, 170.0], [170.0, 326.0]]:
		for t in [0.2, 0.4, 0.6, 0.8]:
			var xm: float = (x[0] + x[1]) / 2.0
			var p := Vector2(pow(1 - t, 2) * x[0] + 2 * (1 - t) * t * xm + t * t * x[1], pow(1 - t, 2) * 14 + 2 * (1 - t) * t * 58 + t * t * 14)
			var g := _glow_sprite(colors[i % 4], 0.3)
			g.position = GARLAND_AT + Vector2(12, 11) + p
			_xmas_lights.append([g, 0.3])
			i += 1


## Bubák has torn the paper off: out comes the gift. Returns false if there was nothing to open.
func open_present(b: Node2D) -> bool:
	if present == null:
		return false
	var at: Vector2 = present.position
	fixed.erase(present)
	present.queue_free()
	present = null
	for i in 14:
		spawn_fx("confetti", at + Vector2(randf_range(-30, 30), -30))
	var f: Rect2 = Game.floor_of("living")
	var res := Game.open_present((at + Vector2(80, 14)).clamp(f.position + Vector2(40, 20), f.end - Vector2(40, 10)))
	if res.is_empty():
		return false
	var item: Dictionary = Catalog.ITEMS[res.id]
	var gift := tr(item.name)
	match res.event:
		"birthday":
			Sfx.play("fanfare")
			hud.toast(tr("Happy birthday, Bubák! In the present: %s. Pure joy!") % gift, "heart", true)
		"christmas":
			Sfx.play("sparkle")
			hud.toast(tr("The paper is in shreds! Inside: %s. Merry Christmas!") % gift, "star", true)
		_:
			Sfx.play("sparkle")
			hud.toast(tr("The paper is in shreds! Inside: %s.") % gift, "star", true)
	for i in 4:
		spawn_fx("heart", b.position + Vector2(randf_range(-30, 30), -80))
	if item.kind == "toy" and items.has(res.uid):
		b.start(item.use, items[res.uid])
	else:
		b.start("binky", null, b.position)
	return true


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
	if storm_t > 0:
		c = c.darkened(0.28)
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
	for i in _xmas_lights.size():   # fairy lights: a soft glow by day, twinkling by night
		_xmas_lights[i][0].modulate.a = (0.3 + 0.7 * night) * (0.55 + 0.45 * sin(t * 2.6 + i * 2.3))
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
	if scale == 1.0 and _cat_rise > 0:   # the neighbour's cat on the windowsill
		var ct: Texture2D = Catalog.tex("window_cat")
		sky.draw_texture(ct, Vector2(r.position.x + 40, r.end.y - ct.get_height() * _cat_rise + 6))
	if pumpkin and _night > 0.3:   # Halloween night: bats flitting past
		var now := Time.get_ticks_msec() / 1000.0
		for i in 3:
			var x := fposmod(now * (60 + i * 25) + i * 300, r.size.x + 120) - 60
			var y := r.size.y * (0.25 + 0.15 * i) + sin(now * 3 + i) * 12
			var flap := 6.0 * sin(now * 14 + i * 2)
			var c := r.position + Vector2(x, y)
			var bat := Color("#2c2433")
			sky.draw_colored_polygon(PackedVector2Array([c, c + Vector2(-14, -6 - flap), c + Vector2(-6, 4)]), bat)
			sky.draw_colored_polygon(PackedVector2Array([c, c + Vector2(6, 4), c + Vector2(14, -6 - flap)]), bat)
			sky.draw_circle(c + Vector2(0, 1), 3.5, bat)
	if storm_t > 0:   # a thunderstorm: dark clouds, rain, lightning
		_draw_storm(r, scale)
		return
	_draw_season(r, scale)
	if _snowing:   # a snowy day (always over Christmas)
		var now := Time.get_ticks_msec() / 1000.0
		var rs := RandomNumberGenerator.new()
		rs.seed = 11
		for i in int(36 * scale):
			var sx := rs.randf() * r.size.x
			var fall := rs.randf_range(16, 38)
			var y := fposmod(rs.randf() * r.size.y + now * fall, r.size.y)
			var x := fposmod(sx + sin(now * 0.8 + i) * 10.0, r.size.x)
			sky.draw_circle(r.position + Vector2(x, y), rs.randf_range(1.6, 3.2) * minf(scale, 1.5), Color(1, 1, 1, 0.92))
		for k in 8:   # snow piled up along the bottom
			sky.draw_circle(r.position + Vector2(r.size.x * k / 7.0, r.size.y + 4), r.size.x / 7.0, Color("#f4f8ff"))
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
	var shy: bool = subject != null and subject.camera_shy()
	if shy:
		behaviour = ""   # he turns his back on the camera
	var decor := 0
	for it in items.values():
		if subject and it.id in DECOR and it.position.distance_to(subject.position) < 260:
			decor += 1
	var ctx := {"room": subject.room_id if subject else view, "hour": hour(), "subject": subject.pet.id if subject else "",
		"tree": xmas_tree != null and subject != null and subject.position.distance_to(xmas_tree.position) < 320}
	if subject:
		ctx.wear = Game.wearing_of(subject.pet).size()
		ctx.wearing = Game.wearing_of(subject.pet).values()
	var sub: Image = await _capture(subject)
	if sub == null:
		return
	var file := Game.photo_dir + "p_%d.png" % int(Time.get_unix_time_from_system() * 1000)
	sub.save_png(file)
	var res := Game.record_photo(file, behaviour, decor, ctx)
	res.shy = shy
	hud.show_photo_result(sub, res)
	if subject and not shy:
		subject.on_flash()


func _room_tex() -> String:
	return "room" if Game.room_style == "cream" else "room_" + Game.room_style


## The shot around a bunny (or the middle of the screen), without the HUD: 480 x 360.
## Returns null if the scene was replaced meanwhile (a save loaded, test play started).
func _capture(subject: Node2D) -> Image:
	hud_layer.visible = false
	await RenderingServer.frame_post_draw
	if not is_inside_tree():
		return null
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
	return sub


## A new memory for the scrapbook: a snapshot of the moment, if Bubák is in view.
func _on_memory(e: Dictionary, snap: bool) -> void:
	if not snap:
		return
	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree() or hud._modal != null or mode != "" or bunny.room_id != view or bunny.hidden_inside:
		return
	var img: Image = await _capture(bunny)
	if img == null:
		return
	var file := Game.photo_dir + "m_%d.png" % int(Time.get_unix_time_from_system() * 1000)
	img.save_png(file)
	e.file = file
	Game.save_game()


# ---- greetings and visitors -------------------------------------------------------

## Back after a while: whoever's in view comes over to say hello.
func _greet() -> void:
	var delay := 0.0
	for b in bunnies:
		if b == guest or b.room_id != view or b.act == "held" or b.hidden_inside:
			continue
		if b.pet.trust_level() < 1:
			b.emote("!")   # still shy: just a look
			continue
		if delay > 0:
			await get_tree().create_timer(delay).timeout
			if not is_inside_tree() or not is_instance_valid(b):
				return
		b.greet()
		delay = 0.7


func _visitors(delta: float) -> void:
	if _cat_t > 0:
		_cat_t -= delta
		_cat_rise = minf(1.0, _cat_rise + delta * 1.5) if _cat_t > 0.6 else maxf(0.0, _cat_rise - delta * 1.8)
	if guest:
		_guest_t -= delta
		if _guest_t <= 0:
			_guest_leaves()
	_visit_t -= delta
	if _visit_t > 0 or mode != "" or hud._modal != null:
		return
	_visit_t = randf_range(Catalog.VISIT_EVERY[0], Catalog.VISIT_EVERY[1])
	var today := Time.get_date_string_from_system()
	var opts := [[0.9, Callable()]]   # [weight, what happens]; mostly nothing
	if guest == null and Game.trust_level() >= 2 and Game.guest_day != today and not Game.vaccine_overdue():
		opts.append([1.0, _guest_arrives])
	if _cat_t <= 0:
		opts.append([0.6, _cat_arrives])
	if storm_t <= 0 and _storm_day != today:
		opts.append([0.45 if _season == "summer" else 0.2, start_storm])
	if Game.kid_day != today and Game.trust_level() >= 1:
		opts.append([0.35, _kid_visits])
	if Game.trust_level() >= 2 and view == "living" and bunny.room_id == "living" and bunny.phase == 1 \
			and bunny.act in ["idle", "loaf", "groom", "wander", "chin"] and bunny.pet.mood() > 55 and storm_t <= 0:
		opts.append([0.5, _hide_and_seek])
	var total := 0.0
	for o in opts:
		total += o[0]
	var r := randf() * total
	for o in opts:
		r -= o[0]
		if r <= 0:
			if o[1].is_valid():
				o[1].call()
			return


## A thunderstorm rolls in: the bunnies hide, trembling, till you comfort them.
func start_storm() -> void:
	storm_t = Catalog.STORM_LENGTH
	_thunder_t = 1.2
	_storm_day = Time.get_date_string_from_system()
	Game.stats.storms = Game.stats.get("storms", 0) + 1
	for b in bunnies:
		b.calmed = false
		if b == guest or b.petting or b.act in ["held", "door", "eat_hand", "approach_hand", "hide_seek"]:
			continue
		b._end_current()
		b._choose_next()
	_update_sky()
	hud.toast(tr("A thunderstorm! The bunnies are scared. Hold your finger on them to comfort them."), "storm")
	Game.remember("storm1", "The first thunderstorm. Bubák hid, trembling, until you came.", [], false)


func _storm(delta: float) -> void:
	if storm_t <= 0:
		return
	storm_t -= delta
	_thunder_t -= delta
	if _flash_t > 0:
		_flash_t -= delta
		if _flash_t <= 0:
			_update_sky()
	if _thunder_t <= 0:
		_thunder_t = randf_range(7, 13)
		_flash_t = 0.18
		tint.color = Color(1.2, 1.2, 1.25)
		get_tree().create_timer(0.45).timeout.connect(func():
			if is_inside_tree() and storm_t > 0:
				Sfx.play("thunder")
				shake())
	if storm_t <= 0:
		storm_t = 0
		_update_sky()
		for b in bunnies:
			if b.act == "storm_hide":
				b.start("idle", null, b.position)
		hud.toast(tr("The storm has passed. The sun peeks out again."))


func _draw_storm(r: Rect2, scale: float) -> void:
	sky.draw_rect(r, Color("#2f3442", 0.72))
	var now := Time.get_ticks_msec() / 1000.0
	for cl in [[Vector2(110, 60), 1.2], [Vector2(320, 40), 1.4], [Vector2(520, 70), 1.1], [Vector2(230, 110), 0.9]]:
		var c: Vector2 = r.position + cl[0] * Vector2(scale, 1.0)
		var sz: float = cl[1] * minf(scale, 1.6)
		for o in [Vector2(-30, 6), Vector2(0, -10), Vector2(30, 6), Vector2(14, 12)]:
			sky.draw_circle(c + o * sz, 26 * sz, Color("#5b6275"))
	var rs := RandomNumberGenerator.new()
	rs.seed = 5
	for i in int(40 * scale):
		var x := rs.randf() * r.size.x
		var y := fposmod(rs.randf() * r.size.y + now * rs.randf_range(380, 520), r.size.y)
		var p := r.position + Vector2(x, y)
		sky.draw_line(p, p + Vector2(-5, 16), Color(0.8, 0.86, 1.0, 0.55), 2.0)
	if _flash_t > 0:
		sky.draw_rect(r, Color(1, 1, 1, 0.75))
		var x0 := r.position.x + r.size.x * 0.6
		var pts := PackedVector2Array([Vector2(x0, r.position.y), Vector2(x0 - 20, r.position.y + r.size.y * 0.3),
			Vector2(x0 + 6, r.position.y + r.size.y * 0.35), Vector2(x0 - 14, r.position.y + r.size.y * 0.7)])
		sky.draw_polyline(pts, Color("#fff6c0"), 4.0)


## Falling blossom in spring, leaves in autumn; a big hazy sun in a heatwave.
func _draw_season(r: Rect2, scale: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if _heat and _night < 0.2:
		var sun := r.position + Vector2(70, 70 + (140 if scale > 1 else 0)) * Vector2(scale, 1)
		sky.draw_circle(sun, 48 * minf(scale, 1.6), Color(1, 0.85, 0.4, 0.35))
	if not _season in ["spring", "autumn"] or _night > 0.6:
		return
	var rs := RandomNumberGenerator.new()
	rs.seed = 3
	var cols: Array = ["#f6c1d0", "#fbe0e8", "#f2a7bd"] if _season == "spring" else ["#d9822b", "#c8562e", "#e8b04a", "#9a5b2e"]
	for i in int(10 * scale):
		var fall := rs.randf_range(14, 30)
		var y := fposmod(rs.randf() * r.size.y + now * fall, r.size.y)
		var x := fposmod(rs.randf() * r.size.x + now * 12.0 + sin(now * 1.3 + i) * 18.0, r.size.x)
		var p := r.position + Vector2(x, y)
		var a := now * 2.0 + i
		var sz := (4.0 if _season == "spring" else 7.0) * minf(scale, 1.5)
		var pts := PackedVector2Array()
		for k in 4:
			var ang := a + k * PI / 2.0
			pts.append(p + Vector2(cos(ang), sin(ang)) * (sz if k % 2 == 0 else sz * 0.45))
		sky.draw_colored_polygon(pts, Color(cols[i % cols.size()]))


## The season's look: a leaf pile on the balcony in autumn, snow on the floor on snowy days.
func update_season() -> void:
	_season = Game.season()
	_snowing = Game.snowing()
	_heat = Game.heatwave()
	var autumn := _season == "autumn"
	if autumn != (leaf_pile != null):
		if leaf_pile:
			fixed.erase(leaf_pile)
			leaf_pile.queue_free()
			leaf_pile = null
		else:
			leaf_pile = _make_item("leaf_pile", 0, Vector2(BX + 900, 640), "leaf_pile", 0.9)
			fixed.append(leaf_pile)
	_snow_floor.visible = _snowing
	_snow_floor.queue_redraw()


func _draw_snow_floor() -> void:
	var f := Game.BALCONY_FLOOR
	var rs := RandomNumberGenerator.new()
	rs.seed = 21
	for i in 34:   # soft drifts
		var p := Vector2(rs.randf_range(f.position.x, f.end.x), rs.randf_range(f.position.y + 10, f.end.y))
		var r := rs.randf_range(50, 110)
		_snow_floor.draw_texture_rect(Catalog.soft_circle(), Rect2(p - Vector2(r, r * 0.3), Vector2(r * 2, r * 0.6)), false, Color(1, 1, 1, 0.95))


## The neighbours' child rings the bell, hoping to meet Bubák.
func _kid_visits() -> void:
	if hud._modal != null:
		return
	Game.kid_day = Time.get_date_string_from_system()
	Game.save_game()
	Sfx.play("notify")
	hud.kid_popup(Catalog.KIDS.pick_random())


## How the visit went (see Game.kid_visit): he hops over for a pat, or hides.
func kid_reaction(res: Dictionary) -> void:
	if bunny.room_id != view or bunny.act in ["held", "hide_seek"]:
		return
	if res.happy:
		bunny.start("binky", null, bunny.position)
		spawn_fx("heart", bunny.position + Vector2(0, -120))
	else:
		bunny.start("thump", null, bunny.position)


## Bubák hides behind something in the living room. Only his ears give him away.
func _hide_and_seek() -> void:
	var spots: Array = [sofa]
	for c in items.values():
		if c.visible and Game.room_at(c.position) == "living" and not Catalog.ITEMS.get(c.id, {}).get("flat", false) \
				and c.size().y > 60 and c.size().x > 60:
			spots.append(c)
	var it: Node2D = spots.pick_random()
	var side := -1.0 if randf() < 0.5 else 1.0
	var spot: Vector2 = it.position + Vector2(side * (it.size().x * 0.5 - 8.0), -10.0)
	spot = Vector2(clampf(spot.x, Game.FLOOR.position.x + 20, Game.FLOOR.end.x - 20), clampf(spot.y, Game.FLOOR.position.y, Game.FLOOR.end.y))
	bunny.teleport(spot)
	bunny.start("hide_seek", null, spot)
	hud.toast(tr("Bubák wants to play hide and seek! He's hiding somewhere in the room. Can you find him?"), "heart")


func show_peek_ears(b: Node2D, on: bool) -> void:
	if _peek:
		_peek.queue_free()
		_peek = null
	if not on:
		return
	_peek = Sprite2D.new()
	_peek.texture = Catalog.tex("peek_ears")
	_peek.offset = Vector2(0, -_peek.texture.get_height() * 0.5 - 70.0 * b.scale_factor())
	_peek.scale = Vector2.ONE * b.scale_factor() * 1.1
	_peek.position = b.position
	world.add_child(_peek)
	var t := _peek.create_tween().set_loops()
	t.tween_interval(randf_range(1.5, 3.0))
	t.tween_property(_peek, "rotation", 0.12, 0.12)
	t.tween_property(_peek, "rotation", -0.08, 0.12)
	t.tween_property(_peek, "rotation", 0.0, 0.12)


## Dug up right where the X is on the map.
func _dig_treasure(at: Vector2) -> void:
	var res := Game.dig_treasure()
	if res.is_empty():
		return
	Sfx.play("fanfare")
	for i in 14:
		spawn_fx("confetti", at + Vector2(0, -20))
	for i in 5:
		spawn_fx("dirt", at)
	hud.treasure_popup(res)


## The neighbour's cat peeks in at the window. Bubák is not amused.
func _cat_arrives() -> void:
	_cat_t = 14.0
	_cat_rise = 0.0
	if bunny.room_id == "living" and bunny.act != "held" and not bunny.hidden_inside:
		bunny.start("thump", null, bunny.position)
	if view == "living":
		Sfx.play("huh")
		hud.toast(tr("The neighbour's cat is peeking in at the window! Bubák is not amused. Tap the window to shoo it."))
	Game.remember("cat1", "The neighbour's cat came to stare. Bubák thumped at it!", [], false)


## A friend drops by with their bunny for a playdate.
func _guest_arrives() -> void:
	var breeds: Array = Catalog.MATES.keys().filter(func(id): return Game.mate == null or id != Game.mate.id)
	var p := Pet.new()
	p.id = breeds.pick_random()
	p.nickname = Catalog.GUESTS.pick_random()
	p.trust = 45.0
	p.needs = Game.needs.duplicate()
	guest = _add_bunny(p, Vector2(240, 640))
	guest.message.connect(hud.toast)
	guest.modulate.a = 0.0
	guest.create_tween().tween_property(guest, "modulate:a", 1.0, 0.6)
	_guest_t = Catalog.GUEST_STAY
	Game.guest_day = Time.get_date_string_from_system()
	hud.toast(tr("Knock knock! A friend dropped by with their bunny, %s. Playdate!") % p.nickname, "heart", true)
	guest.emote("heart")
	if bunny.room_id == "living" and bunny.act != "held":
		bunny.start("zoomies", null, bunny._random_point())
		bunny.data.laps = 4
		bunny.speed = 380.0
	Game.remember("guest1", "%s came over for a playdate.", [p.nickname])


func _guest_leaves() -> void:
	if held == guest:
		_guest_t = 5.0   # still being cuddled for a selfie
		return
	var g := guest
	guest = null
	bunnies.erase(g)
	g.set_process(false)
	var t := g.create_tween()
	t.tween_property(g, "modulate:a", 0.0, 0.6)
	t.tween_callback(g.queue_free)
	Game.bubak.add_need("fun", 30)
	Game.bubak.add_trust(1.0, false)
	Game.stats.guests = Game.stats.get("guests", 0) + 1
	hud.toast(tr("%s hops home. What a playdate! Bubák had a great time.") % g.pet.nickname, "heart")


# ---- Easter, the garden ------------------------------------------------------------

func _find_egg(e: Node2D) -> void:
	eggs.erase(e)
	fixed.erase(e)
	Sfx.play("star")
	for i in 6:
		spawn_fx("confetti", e.position + Vector2(0, -20))
	e.queue_free()
	var left := Game.find_egg()
	if left > 0:
		hud.toast(tr_n("An egg! %d more to find.", "An egg! %d more to find.", left) % left, "star")
	else:
		update_special_day(true)


## Sprouts and ripe veggies on the patch's three beds.
func _update_crops() -> void:
	var patch := find_item("veg_patch")
	if patch == null:
		_crops = []
		return
	if _crops.is_empty() or not is_instance_valid(_crops[0]):
		_crops = []
		for i in Game.garden_bed_count():
			var s := Sprite2D.new()
			s.centered = true
			patch.add_child(s)
			_crops.append(s)
	var beds := Game.garden_beds()
	if _crops.size() != beds.size():   # the patch just got bigger
		for c in _crops:
			c.queue_free()
		_crops = []
		_update_crops()
		return
	var sz: Vector2 = patch.size()
	for i in _crops.size():
		var b: Dictionary = beds[i]
		var s: Sprite2D = _crops[i]
		s.visible = b.crop != ""
		if not s.visible:
			continue
		var ripe: bool = b.grow >= 1.0
		s.texture = Catalog.tex("crop_" + b.crop if ripe else "crop_sprout")
		s.scale = Vector2.ONE * (0.8 if ripe else 0.35 + 0.45 * float(b.grow))
		var n := _crops.size()
		s.position = Vector2((i - (n - 1) / 2.0) * sz.x * 0.6 / (n - 1), -sz.y * 0.55 - s.texture.get_height() * s.scale.y * 0.4)


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
	for id in ["grass_tray", "bird_feeder", "cool_tile", "wind_chime", "parasol", "lookout"]:
		Game.buy(id)
	Game.fill_feeder()
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
				"chest": hud.open_toy_chest()
				"wardrobe": hud.open_wardrobe()
				"settings": hud.open_settings()
				"walks": hud.open_walks()
				var w when w.begins_with("walk_"): hud.play_walk(w.substr(5), false)
	var times: Array = []   # --shots=4,10,16: several screenshots (seconds after opening), path_1.png ...
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			times = Array(arg.get_slice("=", 1).split(",")).map(func(x): return float(x))
	if times.is_empty():
		await get_tree().create_timer(delay * 0.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(path)
	else:
		var waited := 0.0
		for i in times.size():
			await get_tree().create_timer(times[i] - waited).timeout
			waited = times[i]
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.get_basename() + "_%d.png" % (i + 1))
	get_tree().quit()


## Work is waiting: every couple of seconds the laptop does a little hop and wiggle.
## Too much stuff about: the toy chest rattles its lid now and then.
func _jiggle_chest(delta: float) -> void:
	_chest_t -= delta
	if _chest_t > 0:
		return
	_chest_t = 3.0
	if Game.clutter_over("living") + Game.clutter_over("balcony") > 0:
		toy_chest.wiggle(1.6)


func _jiggle_laptop(delta: float) -> void:
	if Game.work_ready_at > Time.get_unix_time_from_system():
		return
	_laptop_t -= delta
	if _laptop_t > 0:
		return
	_laptop_t = 2.4
	var t := laptop.create_tween()
	t.tween_property(laptop, "scale", Vector2(1.06, 0.92), 0.08)
	t.tween_property(laptop, "scale", Vector2(0.97, 1.06), 0.08)
	t.tween_property(laptop, "rotation", 0.07, 0.07)
	t.tween_property(laptop, "rotation", -0.07, 0.1)
	t.tween_property(laptop, "rotation", 0.04, 0.08)
	t.tween_property(laptop, "rotation", 0.0, 0.07)
	t.parallel().tween_property(laptop, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK)


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
