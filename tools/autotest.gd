extends Node
const HudScript := preload("res://scripts/hud.gd")
## Scripted playtest. Run:  godot --path . -- --autotest[=<screenshot dir>]
## Drives real input events through the game and checks the results.

var main: Node
var shots := ""
var failures := 0


func _ready() -> void:
	main = get_parent()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autotest="):
			shots = arg.get_slice("=", 1)
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		failures += 1


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func shot(name: String) -> void:
	if shots == "":
		return
	# wait for a drawn frame, but don't hang the whole run if the display stops drawing
	var drawn := [false]
	RenderingServer.frame_post_draw.connect(func(): drawn[0] = true, CONNECT_ONE_SHOT)
	var t0 := Time.get_ticks_msec()
	while not drawn[0] and Time.get_ticks_msec() - t0 < 3000:
		await get_tree().process_frame
	if not drawn[0]:
		print("  (no frame drawn for screenshot %s)" % name)
		return
	get_viewport().get_texture().get_image().save_png(shots.path_join(name + ".png"))


func to_screen(world: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world


func press(world: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = to_screen(world)
	e.global_position = e.position
	Input.parse_input_event(e)


func tap(world: Vector2) -> void:
	var t0 := Time.get_ticks_msec()
	press(world, true)
	await wait(0.08)
	if Time.get_ticks_msec() - t0 > 350:
		print("  (slow tap: held %d ms of real time)" % (Time.get_ticks_msec() - t0))
	press(world, false)
	await wait(0.1)


func close_popups() -> void:
	for i in 6:
		if main.hud._modal or not main.hud._pending.is_empty():
			main.hud.close_top()
		await wait(0.05)


## Keeps the run predictable: no random visitors or storms, and the seasons' finds already found
## (their own checks undo this).
func quiet() -> void:
	main._visit_t = 1e9
	var year: int = Time.get_date_dict_from_system().year
	for y in [year - 1, year]:
		for id in Catalog.SEASONS:
			if not "%s-%d" % [id, y] in Game.season_finds:
				Game.season_finds.append("%s-%d" % [id, y])


## Reloads the game scene (as loading a save does) without losing the test, which lives in it.
func reload_scene() -> void:
	reparent(get_tree().root)
	main.reload()
	await wait(0.6)
	main = get_tree().current_scene
	quiet()
	await close_popups()


## The playtest checks English texts; it switches language for itself only, never saving it.
func _lang(code: String) -> void:
	Game.language = code
	TranslationServer.set_locale(code)
	main.apply_language()


## Presses a button that reloads the game scene, keeping the test (which lives in the scene) alive.
func press_reload(btn: Button) -> void:
	reparent(get_tree().root)
	btn.pressed.emit()
	await wait(0.6)
	main = get_tree().current_scene
	quiet()
	await close_popups()


## Plays an agility course by itself (the course's autopilot), with a screenshot as the first obstacle nears.
func auto_jump(run: Node, snap := "", limit := 25.0) -> void:
	var t := 0.0
	run.autopilot = true
	while run.running() and t < limit:
		await get_tree().process_frame
		t += get_process_delta_time()
		if snap != "" and not run._bars.is_empty() and run._bars[0].x - run.bunny_x() <= run.zone().y - 6.0:
			await shot(snap)
			snap = ""
	run.autopilot = false


## Buttons in the open window with this text.
func _buttons(text: String) -> Array:
	if main.hud._modal == null:
		return []
	return main.hud._modal.find_children("*", "Button", true, false).filter(func(x): return x.text == text)


func bunny_center() -> Vector2:
	return main.bunny.position + Vector2(0, -40)


func _run() -> void:
	var b = main.bunny
	await wait(0.5)
	main.hud.close_top()
	_lang("en")
	quiet()
	print("AUTOTEST start")

	# Care items respond to taps
	Game.bowl = 0
	var pellets: int = Game.inventory.pellets
	await tap(main.find_item("bowl").position + Vector2(0, -20))
	check(Game.bowl == 1 and Game.inventory.pellets == pellets - 1, "tapping bowl adds pellets")
	Game.water = 10
	await tap(main.find_item("water").position + Vector2(0, -20))
	check(Game.water == 100, "tapping water bowl refills it")
	Game.litter = 60
	await tap(main.find_item("litter").position + Vector2(0, -20))
	check(Game.litter == 0, "tapping litter box cleans it")
	main.add_dropping(Vector2(560, 560))
	var n_drop: int = Game.droppings.size()
	await tap(Vector2(560, 560))
	check(Game.droppings.size() == n_drop - 1, "tapping a dropping removes it")
	# a dropping under the control buttons: hide the controls, then it can be picked up
	var under := Vector2.ZERO
	var brect: Rect2 = main.hud._buttons.get_global_rect()
	var fl: Rect2 = Game.floor_of(main.view)
	for x in range(int(fl.end.x), int(fl.position.x), -10):
		var p := Vector2(x, fl.end.y - 4)
		if brect.has_point(to_screen(p)):
			under = p
			break
	check(under != Vector2.ZERO, "some of the floor lies under the control buttons")
	main.add_dropping(under)
	n_drop = Game.droppings.size()
	main.hud._eye.pressed.emit()
	check(main.hud.ui_hidden and not main.hud._buttons.visible and main.hud._eye.visible, "the eye button hides the controls")
	await tap(under)
	check(Game.droppings.size() == n_drop - 1, "with the controls hidden, the dropping under them can be picked up")
	main.set_mode("move")
	check(not main.hud._banner.visible and main.hud._eye.visible, "Move mode keeps the controls hidden")
	main.set_mode("")
	main.hud._eye.pressed.emit()
	check(not main.hud.ui_hidden and main.hud._buttons.visible, "the eye button shows the controls again")
	main.hud.set_ui_hidden(true)
	main.set_mode("photo")
	check(not main.hud.ui_hidden, "photo mode brings the controls back")
	main.set_mode("")

	# The balcony door starts locked
	await tap(main.door.position + Vector2(0, -120))
	check(main.view == "living" and Game.balcony == "locked", "balcony door is locked at the start")

	# Shop
	Game.coins = 500
	check(Game.buy("ball") == "", "buy ball")
	check(Game.buy("box") == "", "buy box")
	check(Game.buy("rug") == "", "buy rug")
	check(Game.buy("plant") == "", "buy plant")
	check(Game.buy("bed") == "", "buy bed")
	check(Game.buy("apple") == "", "buy apple")
	check(Game.buy("branch") == "", "buy leafy branch")
	check(Game.buy("pellets") == "" and Game.buy("hay") == "", "buy pellets and hay")
	check(main.find_item("ball") != null and main.find_item("rug") != null, "bought items appear in room")
	check(Game.buy("box") != "", "box max 1 enforced")

	# Upgrades, coziness, accessories, goals, sponsor
	Game.coins = 5000
	check(Game.buy("bowl3") != "", "tier 3 needs tier 2 first")
	check(Game.buy("bowl2") == "" and Game.tier("bowl") == 2, "bowl upgraded to tier 2")
	await wait(0.1)
	check(main.find_item("bowl").tex_name.begins_with("bowl_t2"), "upgraded bowl looks different")
	Game.bowl = 4
	await tap(main.find_item("bowl").position + Vector2(0, -20))
	check(Game.bowl == 5, "bigger bowl holds more portions")
	var cozy_before: int = Game.cozy_level()
	for id in ["water2", "hayrack2", "litter2", "chair", "digbox", "puzzle", "tunnel", "lamp"]:
		Game.buy(id)
	await wait(1.2)
	check(Game.cozy_level() > cozy_before, "buying stuff raises coziness (%d -> %d, %d pts)" % [cozy_before, Game.cozy_level(), Game.cozy_points()])
	check(main.chair.visible, "office chair appears at the desk")
	check(Game.buy("monitor") != "", "second monitor needs a promotion first")
	check(Game.buy("bow") == "" and Game.wearing.get("ear") == "bow", "bought and wearing the bow")
	await wait(0.1)
	check(b.wear_sprites.ear.visible, "Bubák shows the bow")
	# wardrobe: one thing per place, several places at once; buying puts it straight on
	check(Game.buy("bandana") == "" and Game.buy("glasses") == "" and Game.buy("beanie") == "", "buy more accessories")
	check(Game.outfit() == ["bandana", "glasses", "bow", "beanie"], "wearing one thing in each place")
	check(Game.buy("daisy") == "" and Game.wearing.ear == "daisy" and "bow" in Game.wardrobe, "a new ear clip replaces the bow")
	var style_full := Game.style_score()
	Game.toggle_wear("beanie")
	check(not Game.wearing.has("head") and Game.style_score() < style_full, "taking off the beanie lowers style")
	await tap(main.closet.position + Vector2(0, -60))   # the little wardrobe on the wall
	await wait(0.6)
	check(main.hud._wardrobe_stage != null and is_instance_valid(main.hud._wardrobe_stage), "tapping the wardrobe opens it")
	main.hud._on_wear_tile("beanie", "head")
	main.hud._on_wear_tile("bow", "ear")
	await wait(0.3)
	check(Game.wearing.head == "beanie" and Game.wearing.ear == "bow", "wardrobe tiles put things on")
	main.hud._on_wear_tile("bowtie", "neck")
	main.hud._on_wear_tile("bowtie", "neck")   # second tap buys
	await wait(0.6)
	check("bowtie" in Game.wardrobe and Game.wearing.neck == "bowtie", "buy in the wardrobe, worn right away")
	await shot("wardrobe")
	main.hud._wardrobe_stage.set_pose("stand")
	await wait(0.5)
	await shot("wardrobe_stand")
	main.hud.close_top()
	await wait(0.2)
	check(b.wear_sprites.neck.visible and b.wear_sprites.head.visible, "Bubák wears the whole outfit in the room")
	var old_save := Game.to_dict()
	old_save.wearing = "glasses"
	Game._apply(old_save)
	check(Game.wearing == {"eyes": "glasses"}, "old saves with one accessory still load")
	Game.wearing = {"neck": "bowtie", "eyes": "glasses", "ear": "bow", "head": "beanie"}
	await close_popups()
	for act in ["dig", "forage"]:
		var it: Node2D = main.find_item({"dig": "digbox", "forage": "puzzle"}[act])
		b.teleport(it.use_point(b.position))
		b.start(act, it)
		await wait(0.8)
		await shot("act_" + act)
		check(b.act == act, "new activity: %s" % act)
	# toy chest: put things away and take them out again; too much stuff out costs coziness
	var chest_at: Vector2 = main.toy_chest.position + Vector2(0, -40)
	for dy in [-40, -20, -60, -75, -10]:   # a spot where nothing stands in front of the chest
		for dx in [0, -40, 40]:
			if main._hit(main.toy_chest.position + Vector2(dx, dy)) == main.toy_chest:
				chest_at = main.toy_chest.position + Vector2(dx, dy)
	await tap(chest_at)
	await wait(0.6)
	check(main.hud._chest_box != null and is_instance_valid(main.hud._chest_box), "tapping the toy chest opens it")
	await shot("toy_chest")
	var dig: Node2D = main.find_item("digbox")
	var dig_uid: int = dig.uid
	b.teleport(dig.use_point(b.position))
	b.start("dig", dig)
	var cozy_chest := Game.cozy_points()
	var raw_chest := Game.cozy_points() + Game.clutter_penalty()   # before clutter is taken off
	check(Game.put_away(dig_uid), "put the dig box away")
	await wait(0.3)
	check(main.find_item("digbox") == null and b.act != "dig", "it leaves the room, and Bubák stops digging")
	check(Game.cozy_points() + Game.clutter_penalty() == raw_chest - Catalog.ITEMS.digbox.cozy, "stored things don't add coziness")
	check(Game.count_item("digbox") == 1 and Game.buy("digbox") != "", "the stored one still counts as owned")
	var reloaded := Game.to_dict()
	Game._apply(reloaded)
	check(Game.stored.size() == 1 and Game.stored[0].id == "digbox", "the chest is saved")
	main.hud._fill_chest()
	check(Game.take_out(dig_uid) and main.find_item("digbox") != null, "take it out again")
	check(Game.cozy_points() == cozy_chest, "coziness comes back")
	var junk := []
	while Game.clutter_over("living") < 3:
		var e := {"uid": 9000 + junk.size(), "id": "plant", "x": 600.0, "y": 600.0}
		junk.append(e)
		Game.placed.append(e)
	Game._recount_cozy()
	check(Game.clutter_penalty() >= 3 * Catalog.CLUTTER_COZY
		and Game.cozy_points() == maxi(0, raw_chest + junk.size() * Catalog.ITEMS.plant.cozy - Game.clutter_penalty()), "clutter lowers coziness")
	await wait(0.4)
	check(tr("Cluttered!") in main.hud._cozy_label.text, "the cozy label warns about clutter")
	main.hud._fill_chest()
	await wait(0.2)
	await shot("toy_chest_cluttered")
	for e in junk:
		Game.placed.erase(e)
	Game._recount_cozy()
	main.hud.close_top()
	Game.stats.photos = 3
	await wait(1.2)
	check(Game.claimable_goals() > 0, "goals become claimable")
	var c_goal: int = Game.coins
	check(Game.claim_goal("photo3") > 0 and Game.coins > c_goal, "claiming a goal pays")
	main.hud.open_journal()
	await wait(0.4)
	await shot("journal_goals")
	main.hud.close_top()
	Game.followers = 120
	Game.sponsor_day = ""
	var c_sp: int = Game.coins
	Game.check_sponsor()
	await wait(0.3)
	check(Game.coins > c_sp and main.hud._modal != null, "daily sponsor pays (+%d)" % (Game.coins - c_sp))
	await shot("sponsor")
	await close_popups()
	Game.followers = 0
	main.hud._shop_tab = "Upgrades"
	main.hud.open_shop()
	await wait(0.4)
	await shot("shop_upgrades")
	main.hud._shop_tab = "Style"
	main.hud.open_shop()
	await wait(0.4)
	await shot("shop_style")
	main.hud.close_top()

	# Picking him up with low trust: he bolts and trust drops
	Game.trust = 20.0
	b.start("idle", null, Vector2(640, 600))
	b.teleport(Vector2(640, 600))
	b.act_t = 30
	var low_trust: float = Game.trust
	main.try_pick_up()
	check(main.mode != "selfie" and Game.trust < low_trust, "low trust: pick-up fails and trust drops (%.1f -> %.1f)" % [low_trust, Game.trust])
	check(b.act == "thump", "low trust: he thumps and runs")
	await wait(1.5)
	Game.trust = 0.0

	# Trust level up popup
	Game.add_trust(70)
	await wait(0.3)
	check(main.hud._modal != null, "level-up popup shown")
	await shot("levelup")
	await close_popups()

	# Balcony milestone -> netting -> door opens -> Bubák goes out and comes back
	check(Game.buy("balcony_net") != "", "netting can't be bought before the milestone")
	Game.followers = 300
	await wait(0.3)
	check(Game.balcony == "available" and main.hud._modal != null, "milestone reached: balcony unlocked + popup")
	await shot("milestone")
	await close_popups()
	check(Game.buy("balcony_net") == "" and Game.balcony == "open", "netting bought, balcony open")
	await wait(0.2)
	check(main.door.tex_name in ["door_open", "door_open_night"], "door shows open")
	b.teleport(Vector2(400, 560))
	b.start("door", main.door_of("living"))
	await wait(4.5)
	check(b.room_id == "balcony" and Game.room_at(b.position) == "balcony", "Bubák went out to the balcony")
	await tap(main.door.position + Vector2(0, -120))
	await wait(0.9)
	check(main.view == "balcony", "tapping the door takes you to the balcony")
	b.start("sunbathe", null, main.sunspot.position)
	await wait(2.0)
	await shot("balcony_sunbathe")
	var herbs: float = Game.herbs
	b.teleport(main.planter.use_point(b.position))
	b.start("herb_thief", main.planter)
	await wait(5.4)
	check(Game.herbs < herbs, "Bubák nibbled the herb planter")
	b.start("bird_watch", null, b.position)
	await wait(1.2)
	await shot("balcony_birds")
	# balcony garden: pick herbs, water things, and the balcony-only amenities
	Game.herbs = 100.0
	var parsley: int = Game.inventory.get("parsley", 0)
	main._use_item(main.planter)
	check(Game.inventory.get("parsley", 0) == parsley + 2 and Game.inventory.get("dandelion", 0) >= 1, "picking herbs gives parsley (and a dandelion)")
	main._use_item(main.planter)
	check(Game.is_watered("herbs"), "a picked-over planter gets watered instead")
	Game.coins += 2000
	for id in ["grass_tray", "bird_feeder", "cool_tile", "wind_chime", "parasol", "lookout"]:
		check(Game.buy(id) == "", "bought %s" % id)
		var it: Node2D = main.find_item(id)
		check(it != null and Game.room_at(it.position) == "balcony", "%s goes on the balcony" % id)
	check(Game.goal_value({"type": "outdoor"}) == 6, "balcony things counted for the goal")
	var tray: Node2D = main.find_item("grass_tray")
	Game.grass = 100.0
	b.teleport(tray.use_point(b.position))
	b.start("graze", tray)
	await wait(1.0)
	await shot("balcony_graze")
	await wait(8.0)
	check(Game.grass < 100.0 and Game.seen.has("graze"), "Bubák grazes the wheatgrass")
	main._use_item(tray)
	check(Game.is_watered("grass"), "watering the grass tray")
	var deck: Node2D = main.find_item("lookout")
	b.teleport(deck.use_point(b.position))
	b.start("lookout", deck)
	await wait(1.0)
	check(is_equal_approx(b.lift, b.LOOKOUT_LIFT) and Game.seen.has("lookout"), "up on the lookout deck")
	await shot("balcony_lookout")
	var tile: Node2D = main.find_item("cool_tile")
	b.start("chill", tile, tile.position)
	await wait(2.5)
	check(b.act == "chill" and b.lift == 0.0, "stretched out on the cool tile")
	await shot("balcony_chill")
	Game.seeds = 0.0
	main._use_item(main.find_item("bird_feeder"))
	check(Game.seeds == 100.0, "filling the bird feeder")
	main._feeder_t = 0.0
	var fx_before: int = main.fx.get_child_count()
	await wait(0.2)
	check(Game.seeds < 100.0 and main.fx.get_children().any(func(n): return n is Sprite2D and n.texture == Catalog.tex("bird")),
		"a bird comes to the feeder (%d effects before)" % fx_before)
	b.start("bird_friend", null, b.position)
	await wait(1.9)
	await shot("balcony_bird_friend")
	check(Game.seen.has("bird_friend"), "a feathered friend visits Bubák")
	b.start("butterfly", null, b.position + Vector2(200, 0))
	b.data.laps = 2
	Game.discover("butterfly")
	main.spawn_butterfly(b)
	await wait(1.5)
	await shot("balcony_butterfly")
	check(b.current_behaviour() == "butterfly", "chasing a butterfly")
	await wait(5.0)
	Game.energy = 20.0
	var umbrella: Node2D = main.find_item("parasol")
	b.teleport(umbrella.use_point(b.position) + Vector2(-40, 0))   # close by, so he's there before we look
	b.start("sleep", null, umbrella.use_point(b.position))
	await wait(2.5)
	check(b.room_id == "balcony" and b.act == "sleep" and b.current_behaviour() == "shade_nap", "a nap in the shade, out on the balcony (room=%s act=%s phase=%s beh=%s)" % [b.room_id, b.act, b.phase, b.current_behaviour()])
	await shot("balcony_shade_nap")
	b.start("idle", null, b.position)
	Game.energy = 80.0
	Game.needs.water = 30
	b.teleport(main.balcony_door.use_point(b.position))
	b.start("idle", null, b.position)
	b.act_t = 0.01
	await wait(1.5)
	check(b.room_id == "living", "thirsty Bubák goes back inside on his own")
	await tap(main.balcony_door.position + Vector2(0, -120))
	await wait(0.9)
	check(main.view == "living", "balcony door leads back to the living room")
	Game.needs.water = 80

	# Petting: hold finger on bunny
	b.start("idle", null, Vector2(640, 600))
	b.teleport(Vector2(640, 600))
	b.act_t = 30
	await wait(0.1)
	var pets: int = Game.stats.pets
	Game.bubak.trust_today = 0.0   # earlier steps may have used up today's trust maximum
	var trust_before: float = Game.trust
	press(bunny_center(), true)
	await wait(2.0)
	check(b.act == "petted", "holding on bunny starts petting (act=%s)" % b.act)
	await shot("petting")
	press(bunny_center(), false)
	await wait(0.2)
	check(Game.stats.pets == pets + 1, "petting session counted")
	check(Game.trust > trust_before, "petting raised trust")
	# within the hour, another petting session is just a cuddle: no trust (checked within one frame,
	# since a good mood also builds trust slowly over time)
	var real_trust: float = Game.trust
	Game.bubak.trust = 65.0   # Cuddly: he never runs off when petted
	b.start("idle", null, Vector2(640, 600))
	b._pet_fatigue = 0.0
	Game.bubak.trust_today = 0.0
	var petted_again: bool = b.on_pet_start()
	var trust_again: float = Game.trust
	var fun_again: float = Game.needs.fun
	b.on_pet_hold(1.0)
	var trust_after: float = Game.trust
	b.on_pet_end()
	Game.bubak.pet_trust_at = 0.0
	b.start("idle", null, Vector2(640, 600))
	b._pet_fatigue = 0.0
	var petted_fresh: bool = b.on_pet_start()
	var trust_fresh: float = Game.trust
	b.on_pet_hold(1.0)
	var trust_fresh_after: float = Game.trust
	b.on_pet_end()
	check(petted_again and trust_after == trust_again and (Game.needs.fun > fun_again or fun_again >= 100.0)
		and petted_fresh and trust_fresh_after > trust_fresh,
		"petting builds trust once an hour; in between it's only a cuddle")
	Game.bubak.trust = real_trust
	Game.bubak.settle_level()
	Game.bubak.pet_trust_at = 0.0

	# Hand-feeding
	b.start("idle", null, Vector2(400, 620))
	b.teleport(Vector2(400, 620))
	b.act_t = 30
	var treats: int = Game.stats.treats
	main.treat_selected = "apple"
	main.set_mode("treat")
	await tap(Vector2(800, 620))
	check(main.hand_active(), "treat offered on floor")
	await wait(4.5)
	check(Game.stats.treats == treats + 1, "Bubák came and ate the treat")
	# his favourite: dried apple rings make him binky
	Game.coins += 100
	check(Game.buy("dried_apple") == "", "buy dried apple rings")
	b.start("idle", null, Vector2(400, 620))
	b.teleport(Vector2(400, 620))
	b.act_t = 30
	main.treat_selected = "dried_apple"
	main.set_mode("treat")
	await tap(Vector2(800, 620))
	var binked := false
	for i in 60:
		await wait(0.1)
		if b.act == "binky":
			binked = true
			break
	check(binked, "his favourite treat makes him binky")
	check(Catalog.ITEMS.dried_apple.trust > 3 * Catalog.ITEMS.apple.trust, "fancy treats win much more trust")

	# Trust takes time: slower at higher levels, less after a lot of bonding today, and treats wear off
	var pet_b: Pet = Game.bubak
	var keep_trust: float = pet_b.trust
	pet_b.trust = 0.0
	pet_b.trust_day = ""
	pet_b.add_trust(1.0)
	var first_gain: float = pet_b.trust
	pet_b.trust_today = 3.0 * Catalog.TRUST_DAILY
	var t0: float = pet_b.trust
	pet_b.add_trust(1.0)
	check(is_equal_approx(first_gain, 1.0) and pet_b.trust - t0 < 0.3,
		"after a lot of bonding today, trust comes slower (%.2f then %.2f)" % [first_gain, pet_b.trust - t0])
	pet_b.trust = 80.0
	pet_b.trust_day = ""
	pet_b.add_trust(1.0)
	check(pet_b.trust - 80.0 < 0.5, "trust comes slower at high levels (+%.2f)" % (pet_b.trust - 80.0))
	# a hard daily maximum at the top levels, walks and presents included
	pet_b.trust = 80.0
	pet_b.trust_day = ""
	var full_days: Array = []
	var on_full := func(): full_days.append(1)
	pet_b.trust_day_full.connect(on_full)
	for _i in 40:
		pet_b.add_trust(5.0)
	var capped_at: float = pet_b.trust
	pet_b.add_trust(Catalog.WALK_TRUST, false)
	pet_b.trust_day_full.disconnect(on_full)
	check(is_equal_approx(capped_at - 80.0, Catalog.TRUST_DAY_MAX[5]) and pet_b.trust == capped_at and full_days.size() == 1,
		"Bonded: at most +%.1f trust a day, walks included (+%.2f, %d notice)" % [Catalog.TRUST_DAY_MAX[5], capped_at - 80.0, full_days.size()])
	pet_b.trust_day = ""
	# the final level, Inseparable, needs many days at Best buds
	pet_b.trust = 95.0
	pet_b.trust_day = ""
	for _i in 40:
		pet_b.add_trust(5.0)
	pet_b.add_trust(Catalog.WALK_TRUST, false)
	var top_day: float = pet_b.trust - 95.0
	pet_b.trust = 99.95
	check(top_day <= Catalog.TRUST_DAY_MAX[6] + 0.001 and pet_b.trust_level() == Catalog.TRUST_LEVELS.size() - 1
		and Catalog.level_name(7) == "Inseparable" and (Catalog.TRUST_LEVELS[7].at - Catalog.TRUST_LEVELS[6].at) / Catalog.TRUST_DAY_MAX[6] > 35,
		"Inseparable: a top level that takes weeks at Best buds (+%.2f a day)" % top_day)
	pet_b.trust_day = ""
	var tt1: float = pet_b.treat_trust()
	var tt2: float = pet_b.treat_trust()
	check(tt1 == 1.0 and tt2 < 1.0, "each treat today counts less for trust (%.2f, %.2f)" % [tt1, tt2])
	check(Catalog.BALCONY_TRUST < Catalog.SELFIE_TRUST and Catalog.SELFIE_TRUST < Catalog.mate_trust(),
		"balcony first, then selfies, then a friend")
	# Settings > Game pace > Fast: the original quick game
	Game.fast_game = true
	pet_b.trust = 72.0
	pet_b.trust_day = ""
	pet_b.trust_today = 50.0
	pet_b.add_trust(1.0)
	check(pet_b.trust_level() == 5 and is_equal_approx(pet_b.trust, 73.0) and pet_b.treat_trust() == 1.0
		and pet_b.treat_trust() == 1.0 and Catalog.treat_trust("dried_apple") == 12.0 and Catalog.mate_trust() == Catalog.SELFIE_TRUST,
		"fast game: quick levels, no slowdown, treats count fully")
	Game.fast_game = false
	check(pet_b.trust_level() == 4, "normal game: the same trust is a lower level")
	pet_b.trust = keep_trust
	pet_b.trust_day = ""
	pet_b.settle_level()
	await close_popups()

	# Moving furniture
	main.set_mode("move")
	var ball: Node2D = main.find_item("ball")
	for spot in [Vector2(640, 560), Vector2(450, 580), Vector2(820, 570), Vector2(560, 520), Vector2(1000, 590)]:   # clear of the on-screen panels
		ball.position = spot   # somewhere nothing else covers it, so the drag grabs the ball
		if main._hit(spot + Vector2(0, -20), true) == ball:
			break
	var from := ball.position
	press(from + Vector2(0, -20), true)
	await wait(0.05)
	var drop := Vector2(from.x + (220 if from.x < 640 else -220), from.y)
	var m := InputEventMouseMotion.new()
	m.position = to_screen(drop)
	m.button_mask = MOUSE_BUTTON_MASK_LEFT
	m.global_position = m.position
	Input.parse_input_event(m)
	await wait(0.05)
	press(drop, false)
	await wait(0.1)
	check(ball.position.distance_to(from) > 50, "dragging moves furniture in Move mode (hit=%s at %s, now %s, mode=%s)" % [
		main._hit(from + Vector2(0, -20), true).get("id") if main._hit(from + Vector2(0, -20), true) else "none", from, ball.position, main.mode])
	main.set_mode("")

	# Rare behaviours + photo
	b.teleport(Vector2(700, 620))
	b.start("binky", null, b.position)
	await wait(0.25)
	var photos: int = Game.photos.size()
	var coins: int = Game.coins
	main.set_mode("photo")
	main.hud._snap()
	await wait(0.6)
	check(Game.photos.size() == photos + 1, "photo recorded")
	check(Game.photos[-1].behaviour == "binky", "photo caught a binky (%s)" % Game.photos[-1].behaviour)
	check(Game.coins > coins, "photo paid coins (+%d)" % (Game.coins - coins))
	check(FileAccess.file_exists(Game.photos[-1].file), "photo file saved")
	await shot("photo_result")
	main.hud.close_top()
	main.set_mode("")

	# Posting too often: followers' attention runs out, likes drop, then people unfollow
	check(Game.feed_attention() < 0.85, "a post uses up followers' attention (%.2f)" % Game.feed_attention())
	var shot_file: String = Game.photos[-1].file
	Game.feed = 1.0
	Game.feed_time = Time.get_unix_time_from_system()
	var fresh: Dictionary = Game.record_photo(shot_file, "zoomies", 0)
	Game.feed = 0.1
	var fol: int = Game.followers
	var flooded: Dictionary = Game.record_photo(shot_file, "zoomies", 0)
	check(flooded.likes < fresh.likes * 0.6 and flooded.lost > 0 and Game.followers < fol,
		"a flooded feed gets fewer likes and loses followers (%d vs %d likes, -%d)" % [flooded.likes, fresh.likes, flooded.lost])
	Game.feed_time -= Catalog.FEED_REFILL
	check(Game.feed_attention() == 1.0, "followers' attention comes back over time")
	var c_miss: int = Game.coins
	var missed: Dictionary = Game.record_photo(shot_file, "", 0)
	check(missed.likes == 0 and Game.coins == c_miss and Game.feed_attention() == 1.0, "a missed shot pays nothing and isn't posted")
	main.set_mode("photo")
	await wait(0.3)
	check(main.hud._feed_label.text != "" and main.hud._feed_bar.value > 0.9, "camera shows followers' attention")
	main.set_mode("")

	# Too many flashes and Bubák has had enough of the camera
	var trust_cam: float = Game.bubak.trust
	b.teleport(Vector2(640, 600))
	b.start("idle", null, b.position)
	for i in Catalog.CAMERA_PATIENCE + 1:
		b.on_flash()
	check(b.camera_shy() and b.act == "flee" and Game.bubak.trust < trust_cam, "too many flashes and he's had enough")
	main.set_mode("photo")
	main.hud._snap()
	await wait(0.6)
	check(Game.photos[-1].behaviour == "", "a camera-shy Bubák turns his back on the camera")
	await shot("photo_shy")
	main.hud.close_top()
	main.set_mode("")
	b._camera_shy_until = 0.0
	b._flashes.clear()
	Game.bubak.trust = trust_cam


	var rug: Node2D = main.find_item("rug")
	b.teleport(rug.position)
	b.start("flop", null, rug.position)
	await wait(1.5)
	check(b.pose == "flop", "flop pose")
	await shot("flop")

	b.start("sleep", main.find_item("bed"))
	b.teleport(main.find_item("bed").use_point(b.position))
	b.start("sleep", main.find_item("bed"))
	await wait(1.0)
	await shot("bed_nap")
	check(b.act_t > 100 and Game.bubak.asleep, "naps last a few minutes")
	await wait(0.2)
	check(absf(main.hud._need_bars[0].energy.value - Game.energy) < 1.0, "energy bar shows his energy")

	b.start("hide_box", main.find_item("box"))
	b.teleport(main.find_item("box").use_point(b.position))
	b.start("hide_box", main.find_item("box"))
	await wait(0.2)
	check(not b.visible, "hiding in box hides Bubák")

	# High trust: drag him upwards to pick him up, then take a selfie
	Game.trust = maxf(Game.trust, Catalog.level_at(Catalog.SELFIE_TRUST + 1))   # Bonded: he never wriggles free
	Game.bubak.settle_level()
	b.start("idle", null, Vector2(640, 600))
	b.teleport(Vector2(640, 600))
	b.act_t = 30
	await wait(0.1)
	press(bunny_center(), true)
	await wait(0.05)
	var up := InputEventMouseMotion.new()
	up.position = to_screen(bunny_center() + Vector2(0, -120))
	up.global_position = up.position
	up.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(up)
	await wait(0.05)
	press(bunny_center() + Vector2(0, -120), false)
	await wait(0.5)
	check(main.mode == "selfie" and b.act == "held" and not b.visible, "dragging him up picks him up (mode=%s act=%s trust=%d)" % [main.mode, b.act, Game.trust_level()])
	await shot("selfie_view")
	var n_photos: int = Game.photos.size()
	main.hud._snap_selfie()
	await wait(0.6)
	check(Game.photos.size() == n_photos + 1 and Game.photos[-1].behaviour == "selfie", "selfie photo recorded")
	await shot("selfie_result")
	main.hud.close_top()
	await wait(b.hold_limit() + 0.5)
	check(main.mode == "" and b.act != "held", "he gets wriggly and is put down after a while")

	await close_popups()
	# Leafy branch gets eaten down, then disappears
	var br: Node2D = main.find_item("branch")
	main._entry(br)["bites"] = 4   # he may have snacked on it by himself earlier
	b.teleport(br.use_point(b.position))
	b.start("chew_toy", br)
	await wait(5.5)
	check(main._entry(br).get("bites", 0) == 3, "Bubák ate from the branch (act=%s room=%s bites=%s)" % [b.act, b.room_id, main._entry(br).get("bites")])
	check(br.tex_name == "branch", "branch still leafy after one meal")
	main.bite_item(br)
	await wait(0.1)
	check(br.tex_name == "branch_bare", "branch bare after half eaten")
	await shot("branch_bare")
	main.bite_item(br)
	main.bite_item(br)
	await wait(0.1)
	check(main.find_item("branch") == null and not Game.has_item("branch"), "finished branch is removed")

	# Cable chewing
	Game.cable = "ok"
	Game.needs.fun = 20
	b.teleport(main.cable.use_point(b.position))
	b.start("chew_cable", main.cable)
	await wait(0.5)
	await tap(bunny_center())
	if b.act == "chew_cable":   # a tap now and then goes missing in the scripted run; a player would tap again
		print("  (cable: second tap needed)")
		await tap(bunny_center())
	check(b.act != "chew_cable", "tapping stops cable chewing (act=%s mode=%s hit=%s, bunny=%s visible=%s phase=%s, modal=%s)" % [b.act, main.mode,
		main._hit(bunny_center()).get("id"), b == main._hit(bunny_center()), b.visible, b.phase, main.hud._modal])

	await close_popups()
	# Three quick pokes = thump
	b.start("idle", null, b.position)
	b.act_t = 30
	b._taps.clear()
	var c := bunny_center()
	await tap(c)
	await tap(c)
	await tap(c)
	check(b.act in ["thump", "hide_box", "flee"], "three quick pokes scare him (act=%s)" % b.act)

	# Journal + work screens
	main.hud.open_journal()
	await wait(0.5)
	await shot("journal")
	main.hud._journal_tab = "Photos"
	main.hud.open_journal()
	await wait(0.5)
	await shot("journal_photos")
	main.hud.close_top()

	# Remote work career: menu, every job, pay, XP and a promotion
	Game.career_xp = 0
	Game.work_ready_at = 0
	main.hud.open_work()
	await wait(0.3)
	var w = main.hud._modal.find_children("*", "VBoxContainer", true, false).filter(func(x): return x.has_method("_show_menu"))[0]
	await shot("work_menu_intern")
	Game.career_xp = 140
	w._start("inbox")
	await wait(1.5)
	w._earned = 20
	w._t = 0.01
	await wait(0.3)
	check(Game.career_level() == 1, "a good shift gets you promoted (career %d)" % Game.career_level())
	await shot("work_promotion")
	Game.career_xp = 2500
	for job in Catalog.JOBS:
		w._start(job)
		await wait(2.2)
		var g = w._game
		match job:
			"inbox", "bugs":
				var tapped := false
				for i in 30:   # only ladybugs may be out yet
					for node in g.get_children():
						if node is TextureButton and not node.get_meta("lady", false) and not node.get_meta("hit", false) \
								and node.get_meta("kind", "") not in ["paw", "spam"]:
							node.pressed.emit()
							tapped = true
							break
					if tapped:
						break
					await wait(0.1)
			"memory":
				var cards: Array = g._grid.get_children()
				var first = cards[0]
				for card in cards.slice(1):
					if card.get_meta("face") == first.get_meta("face"):
						first.pressed.emit()
						card.pressed.emit()
						break
			"call":
				for i in 20:
					if g._prompt != "":
						break
					await wait(0.1)
				g._answer(g._prompt, g)
			"stack":
				for i in 3:
					g._mx = g._stack[-1][0]
					g._mover.position.x = g._mx
					g.drop()
					await wait(0.4)
				check(g._stack.size() == 4 and is_equal_approx(g._stack[-1][1], g._stack[0][1]), "stack: perfect drops keep the crate width")
				g._mx = g._stack[-1][0] + 60
				g._mover.position.x = g._mx
				g.drop()
				await wait(0.4)
				check(g._stack.size() == 5 and g._stack[-1][1] < g._stack[0][1], "stack: overhang is sliced off")
		await wait(0.4)
		await shot("work_" + job)
		check(w._earned > 0, "job %s: playing scores points (%d)" % [job, w._earned])
		var coins_before: int = Game.coins
		w._t = 0.01
		await wait(0.2)
		check(Game.coins > coins_before and not w._running, "job %s: shift ends and pays" % job)
		check(Game.job_best.has(job), "job %s: best shift remembered" % job)
		if job == "stack":
			await shot("work_results")
		w._show_menu()
	await shot("work_menu")
	main.hud.close_top()
	# the same job again and again pays less; time (or another job) fixes it
	Game.job_tired.erase("inbox")
	var fresh_cut := Game.job_repeat_mult("inbox")
	Game.note_shift("inbox")
	Game.note_shift("inbox")
	var tired_cut := Game.job_repeat_mult("inbox")
	for _i in 10:
		Game.note_shift("inbox")
	var floor_cut := Game.job_repeat_mult("inbox")
	Game.job_tired.inbox.t -= Catalog.JOB_REST * 20
	check(fresh_cut == 1.0 and is_equal_approx(tired_cut, 0.6) and is_equal_approx(floor_cut, Catalog.JOB_REPEAT_FLOOR)
		and Game.job_repeat_mult("inbox") == 1.0 and Game.job_repeat_mult("bugs") < 1.0,
		"repeating a job pays less (%.2f, %.2f, floor %.2f) and wears off" % [fresh_cut, tired_cut, floor_cut])
	Game.job_tired.clear()

	# Save / load round trip
	Game.save_game()
	var coins_saved := Game.coins
	Game.coins = 0
	Game.load_game()
	check(Game.coins == coins_saved, "save/load round trip")

	# Czech translation (switched without touching the player's settings file)
	_lang("cs")
	await wait(0.3)
	check(tr("Shop") == "Obchod" and TranslationServer.get_locale().begins_with("cs"), "Czech translation loaded")
	check(tr_n("%d like", "%d likes", 1) == "%d lajk" and tr_n("%d like", "%d likes", 3) == "%d lajky"
		and tr_n("%d like", "%d likes", 7) == "%d lajků", "Czech plural forms (1 / 2-4 / 5+)")
	main.hud.open_shop()
	await wait(0.4)
	await shot("cs_shop")
	main.hud._journal_tab = "Behaviours"
	main.hud.open_journal()
	await wait(0.4)
	await shot("cs_journal")
	main.hud.close_top()
	await wait(0.3)
	await shot("cs_room")
	main.hud.open_settings()
	await wait(0.4)
	await shot("cs_settings")
	main.hud.close_top()
	_lang("en")
	await wait(0.2)
	check(tr("Shop") == "Shop", "switched back to English")

	# ---- show club: unlocks step by step -------------------------------------------
	close_popups()
	await wait(0.2)
	var hud = main.hud
	Game.trust = 5.0
	Game.club_stage = 0
	await wait(1.2)
	check(Game.club_stage == 0 and not hud._club_button.visible, "club hidden at the start")
	hud.open_shop()
	await wait(0.2)
	check(not "Club" in hud._modal.find_children("*", "Button", true, false).map(func(x): return x.text), "no Club tab in the shop yet")
	hud.close_top()
	Game.trust = 20.0
	Game.coins += 500
	for id in ["ball", "box", "rug", "plant", "flowers"]:
		Game.buy(id)
	await wait(1.3)
	check(Game.club_stage == 1 and hud._modal != null, "club opens with trust + coziness, with a pop-up (cozy %d)" % Game.cozy_level())
	await shot("club_unlock")
	await close_popups()
	hud._refresh()
	check(hud._club_button.visible, "Club button appears")
	check(Game.goal_visible({"stage": 1}) and not Game.goal_visible({"stage": 2}), "only stage-1 club goals visible")

	# training: cue a trick, reward him at the right moment
	hud.open_club("Training")
	await wait(0.4)
	var tr_panel = hud.club_panel
	check(tr_panel != null and tr_panel._stage != null, "training panel open")
	var got_good := false
	for i in 15:
		Game.focus = 6.0
		tr_panel.cue("come")
		var rewarded := false
		for j in 40:
			await wait(0.05)
			if tr_panel._stage.in_window() and not rewarded:
				await wait(0.5)
				await shot("club_training")
				tr_panel._reward.pressed.emit()
				rewarded = true
			if not tr_panel._stage.attempting():
				break
		while tr_panel._stage.attempting():
			await wait(0.05)
		if rewarded:
			got_good = true
			break
	check(got_good and Game.tricks.get("come", 0.0) > 0, "rewarding a trick in time teaches it (%.0f)" % Game.tricks.get("come", 0.0))
	Game.focus = 0.0
	var before: float = Game.tricks.get("come", 0.0)
	tr_panel.cue("come")
	await wait(0.1)
	check(not tr_panel._stage.attempting() and Game.tricks.come == before, "no focus left: no training")
	check(Game.trick_lock("spin") != "" and Game.trick_lock("hoop") != "", "spin and hoop locked at low trust")
	hud.close_top()

	# first star -> grooming
	Game.tricks.come = 100.0
	await wait(1.3)
	check(Game.club_stage == 2 and hud._modal != null, "first trick star unlocks grooming")
	await close_popups()
	Game.coins += 500
	check(Game.buy("brush") == "" and "brush" in Game.gear, "buy a soft brush")
	Game.coat = 40.0
	hud.open_club("Grooming")
	await wait(0.6)
	var gp = hud.club_panel
	check(gp._tufts.size() >= 3, "loose fur on his coat (%d tufts)" % gp._tufts.size())
	await shot("club_grooming")
	for t in gp._tufts.duplicate():
		var p: Vector2 = t.position + Vector2(23, 23) + gp._stage.position
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = true
		e.position = p
		gp._on_input(e)
	await wait(0.6)
	check(gp._done and Game.coat > 60 and Game.stats.grooms == 1, "brushing all the fur grooms him (coat %d)" % Game.coat)
	Game.buy("clippers")
	Game.nails = 60.0
	var trust_nails: float = Game.trust
	gp._trim()
	check(Game.nails == 60.0 and Game.trust < trust_nails, "nail trim fails at low trust")
	Game.trust = 40.0
	gp._trim()
	check(Game.nails == 0.0, "nail trim works once he trusts you")
	hud.close_top()

	# 3 stars + a grooming -> shows
	Game.tricks.come = 250.0
	Game.tricks.stand = 100.0
	await wait(1.3)
	check(Game.club_stage == 3, "3 trick stars + grooming unlock shows")
	await close_popups()
	hud.open_club("Shows")
	await wait(0.3)
	await shot("club_shows")
	check(Game.show_unlocked(0) and not Game.show_unlocked(1), "only the Neighbourhood show is open")
	var coins_show: int = Game.coins
	Engine.time_scale = 4.0
	hud._enter_show(0, "looks")
	var ring = hud.club_panel
	for i in 400:   # timers run 4x faster too
		await wait(0.1)
		if ring._button.text == tr("Continue"):
			break
	await shot("show_looks")
	check(ring._button.text == tr("Continue"), "Best in Show is judged to the end")
	check(Game.coins != coins_show and Game.show_wait(0) > 0 and Game.stats.shows == 1, "entry fee paid, next show scheduled")
	var ribbons: int = Game.trophies.size()
	ring._on_button()
	await wait(0.2)
	check(hud._modal == null and main.shelf.visible == (ribbons > 0), "show closes; shelf shows ribbons (%d)" % ribbons)
	check(Game.enter_show(0, "tricks") != "", "can't enter again before the next show")
	Game.show_ready_at = {}
	hud._enter_show(0, "tricks")
	ring = hud.club_panel
	for i in 1000:
		await wait(0.05)
		if ring._stage.in_window():
			ring._on_button()
		if ring._button.text == tr("Continue"):
			break
	await shot("show_tricks")
	check(ring._button.text == tr("Continue") and Game.stats.shows == 2, "tricks routine performed and judged")
	ring._on_button()
	Engine.time_scale = 1.0
	await wait(0.2)
	# win twice to open the regional show; trophies go on the shelf
	Game.trophies.append({"tier": 0, "cat": "looks", "place": 1, "time": 0.0})
	Game.trophies.append({"tier": 0, "cat": "photo", "place": 1, "time": 0.0})
	Game.trophies.append({"tier": 2, "cat": "tricks", "place": 1, "time": 0.0})
	main.update_trophies()
	check(Game.show_unlocked(1) and main.shelf.visible and main.shelf.get_child_count() > 3, "wins open the Regional show, shelf filled")
	await wait(0.2)
	await shot("trophy_shelf")
	await close_popups()   # the wins may have brought a fame title, whose pop-up would take the tap
	await tap(main.shelf.position + Vector2(0, -10))
	await wait(0.3)
	check(hud._modal != null and hud._club_tab == "Trophies", "tapping the shelf opens the trophies")
	await shot("club_trophies")
	hud.close_top()
	await wait(0.2)
	# a queued pop-up waits while one window opens another, instead of replacing it
	hud.open_shop()
	var queued: Array = []
	hud._queue(func(): queued.append(1); hud._open_modal("Queued", Label.new(), Vector2(300, 200)))
	hud.open_wardrobe()
	await wait(0.2)
	var wardrobe_kept: bool = hud._modal != null and hud._wardrobe_stage != null and is_instance_valid(hud._wardrobe_stage) and queued.is_empty()
	for _i in 5:   # other pop-ups (fame, milestones) may be waiting in front of it
		hud.close_top()
		await wait(0.2)
		if not queued.is_empty():
			break
	check(wardrobe_kept and queued.size() == 1, "a waiting pop-up doesn't replace a window opened from another one")
	while hud._modal != null:
		hud.close_top()
		await wait(0.2)

	# Named saves
	Game.coins = 1234
	check(Game.save_named("Autotest save"), "save under a name")
	var found := Game.list_saves().filter(func(x): return x.name == "Autotest save")
	check(found.size() == 1, "named save is listed")
	var extra := []
	for i in 12:   # plenty of saves: the list has to scroll
		Game.save_named("Autotest extra %d" % i)
		extra.append(Game.list_saves()[0].file)
	hud.open_saves()
	await wait(1.0)
	await shot("saves_screen")
	var sc: ScrollContainer = hud.saves_scroll
	check(sc.get_v_scroll_bar().visible and sc.get_v_scroll_bar().max_value > sc.size.y, "saves list scrolls when there are many saves")
	sc.scroll_vertical = 10000
	await wait(0.3)
	check(sc.scroll_vertical > 0, "saves list scrolled down")
	await shot("saves_scrolled")
	hud.close_top()
	for f in extra:
		Game.delete_named(f)
	Game.coins = 1
	Game.club_stage = 1
	check(Game.load_named(found[0].file) and Game.coins == 1234 and Game.club_stage == 3, "load a named save")
	Game.delete_named(found[0].file)
	check(Game.list_saves().filter(func(x): return x.name == "Autotest save").is_empty(), "delete a named save")

	# ---- weight ----------------------------------------------------------------------
	var pw: Pet = Game.bubak
	pw.weight = pw.ideal_weight()
	hud._journal_tab = "Bubák"
	hud.open_journal()
	await wait(0.3)
	var jtext := str(hud._modal.find_children("*", "Label", true, false).map(func(l): return l.text))
	check(pw.weight_band() == 2 and "kg" in jtext, "weight in the journal, just right")
	await shot("journal_weight")
	hud.close_top()
	pw.needs.food = 30.0
	var w0: float = pw.weight
	pw.add_need("food", 28.0)   # a bowl when hungry
	var hungry_gain: float = pw.weight - w0
	pw.needs.food = 100.0
	w0 = pw.weight
	pw.add_need("food", 28.0)   # the same, on a full tummy
	var full_gain: float = pw.weight - w0
	check(hungry_gain > 0 and full_gain > 2.5 * hungry_gain, "eating on a full tummy puts on far more (%.1f g vs %.1f g)" % [full_gain, hungry_gain])
	pw.weight = pw.ideal_weight() * 1.13
	w0 = pw.weight
	pw.needs.food = 100.0
	pw.add_need("food", 28.0)
	check(pw.weight - w0 < full_gain * 0.6, "the heavier he is, the less sticks")
	var mood_ok: float = pw.mood()
	var cond_heavy: float = Game.condition()
	pw.weight = pw.ideal_weight()
	check(pw.mood() > mood_ok and Game.condition() > cond_heavy, "overweight: grumpier, and judges notice")
	pw.weight = pw.ideal_weight() * 1.08
	await wait(0.3)
	check(hud._toasts.get_children().any(func(c): return "chubby" in str(c.find_children("*", "Label", true, false).map(func(l): return l.text))),
		"a toast when he gets chubby")
	Game.coins += 2000
	check(Game.buy("hurdles") == "" and Game.buy("treat_ball") == "", "buy the hurdles and treat ball")
	await wait(0.3)
	var hurdles: Node2D = main.find_item("hurdles")
	w0 = pw.weight
	b.teleport(hurdles.use_point(b.position))
	b.start("hurdles", hurdles)
	await wait(0.2)
	check(b.act == "hurdles" and b.phase == 1, "he runs the hurdle course")
	await shot("hurdles")
	for i in 40:
		if b.act != "hurdles":
			break
		await wait(0.1)
	check(pw.weight < w0 - 2.0 and "hurdles" in Game.seen, "exercise burns weight (%.1f g)" % (w0 - pw.weight))
	var tb: Node2D = main.find_item("treat_ball")
	b.teleport(tb.use_point(b.position))
	b.start("roll_feeder", tb)
	await wait(1.6)
	check("treat_ball" in Game.seen, "he rolls the treat ball")
	pw.weight = pw.ideal_weight()
	await wait(0.3)
	await close_popups()

	# ---- walks with the leash -------------------------------------------------------
	var keep_walk_trust: float = Game.trust
	Game.trust = 50.0
	check(Game.lock_reason("leash") != "", "the leash needs more trust")
	Game.trust = 62.0
	Game.tricks.come = 450
	Game.tricks.stand = 250
	check(Game.lock_reason("leash") == "", "Cuddly and trained: the leash is for sale")
	check(Catalog.ITEMS.leash.req_trust < Catalog.mate_trust(), "walks come well before a friend")
	Game.coins += 2000
	check(Game.buy("leash") == "" and "leash" in Game.gear, "buy the harness and leash")
	await wait(0.3)
	check(hud._walk_button.visible, "a Walk button appears")
	Game.walk_day = ""
	Game.stats.walks = 0
	check(Game.walk_problem("park") == "" and Game.walk_problem("field") != "", "only the park at first")
	hud.open_walks()
	await wait(0.3)
	await shot("walks")
	hud.close_top()
	Game.bubak.trust_day = Time.get_date_string_from_system()
	# a lot of bonding today, but still under the day's maximum: the walk isn't slowed down
	Game.bubak.trust_today = 0.5 * Catalog.TRUST_DAY_MAX[Game.trust_level()]
	Game.bubak.weight = Game.bubak.ideal_weight()
	var t_walk: float = Game.trust
	hud.play_walk("park", true, 6.0)
	await wait(1.2)
	check(not hud.find_children("*", "WalkScene", true, false).is_empty(), "the walk cutscene plays")
	await shot("walk_scene")
	for i in 200:
		if hud.find_children("*", "WalkScene", true, false).is_empty():
			break
		await wait(0.1)
	check(hud.find_children("*", "WalkScene", true, false).is_empty(), "the cutscene ends by itself")
	check(Game.trust - t_walk > 0.5, "a walk brings trust, even after a lot of bonding today (+%.1f)" % (Game.trust - t_walk))
	check(Game.bubak.weight < Game.bubak.ideal_weight() - 10.0, "a walk burns weight")
	check(Game.walked_today() and Game.walk_problem("park") != "" and Game.stats.walks == 1, "one walk a day")
	Game.stats.walks = Catalog.WALKS.cinema.after
	check(Game.walk_open("cinema"), "more walks open more places")
	Game.walk_day = ""
	Game.trust = keep_walk_trust
	Game.bubak.settle_level()
	await close_popups()

	# ---- special days: Christmas and Bubák's birthday ----------------------------------
	main.go_to("living")
	b.teleport(Vector2(560, 600))
	b.start("idle", null, b.position)
	var year: int = Time.get_date_dict_from_system().year
	Game.presents = []
	Game.birthday = "03-14"
	Game.debug_date = "07-01"
	main.update_special_day()
	check(main.xmas_tree == null and main.present == null and Game.special_day() == "", "an ordinary day: no tree, no present")
	Game.debug_date = "12-24"
	main.update_special_day()
	await close_popups()
	check(main.xmas_tree != null and main.present != null and Game.present_waiting() == "christmas", "Christmas: a tree with a present under it")
	await wait(0.3)
	await shot("christmas")
	check(main._xmas_decor.size() == 1 and main._xmas_lights.size() > 10, "a garland and fairy lights")
	b.start("tree_gaze", main.xmas_tree, main.xmas_tree.position + Vector2(-90, 50))
	await wait(2.0)
	check(b.act == "tree_gaze", "he stands up to gaze at the tree")
	b.start("idle", null, b.position)
	var jingle_before := Game.count_item("jingle_ball")
	main._use_item(main.present)
	await wait(0.2)
	check(b.act == "unwrap", "tap the present: Bubák goes to unwrap it")
	for i in 60:
		if b.act == "unwrap" and b.phase == 1:
			break
		await wait(0.1)
	await wait(1.2)
	await shot("christmas_unwrap")
	for i in 60:
		if main.present == null:
			break
		await wait(0.1)
	await wait(0.2)
	check(main.present == null and Game.count_item("jingle_ball") == jingle_before + 1 and ("christmas-%d" % year) in Game.presents,
		"he rips it open: a jingle ball")
	check(b.act == "play_ball" and b.item != null and b.item.id == "jingle_ball", "and plays with it straight away (%s)" % b.act)
	await wait(1.0)
	await shot("christmas_gift")
	main.update_special_day()
	check(main.present == null and Game.present_waiting() == "" and main.xmas_tree != null, "one Christmas present a year")
	Game.presents.erase("christmas-%d" % year)
	check(Game._gift_for("christmas") != "jingle_ball", "next year: something he hasn't got yet (%s)" % Game._gift_for("christmas"))
	Game.presents.append("christmas-%d" % year)
	await close_popups()
	# his birthday
	var head_before: String = Game.wearing.get("head", "")
	Game.debug_date = Game.birthday
	main.update_special_day()
	await close_popups()
	check(main.xmas_tree == null and main._xmas_lights.is_empty() and main.present != null and main.present.tex_name == "present_bday",
		"his birthday: a present for him (Christmas packed away)")
	Game.bubak.trust_today = 0.0
	var t_bday: float = Game.trust
	b.teleport(Vector2(560, 600))
	main._use_item(main.present)
	for i in 80:
		if main.present == null:
			break
		await wait(0.1)
	await wait(0.4)
	check(Game.wearing.get("head", "") == "party_hat" and "party_hat" in Game.wardrobe and Game.trust > t_bday,
		"he unwraps a party hat, puts it on and is very happy")
	await shot("birthday")
	hud.open_wardrobe()
	await wait(0.4)
	await shot("wardrobe_party_hat")
	hud.close_top()
	hud._journal_tab = "Bubák"
	hud.open_journal()
	await wait(0.3)
	var btext := str(hud._modal.find_children("*", "Label", true, false).map(func(l): return l.text))
	check(tr("Birthday: %s") % HudScript.birthday_text("03-14") in btext and "14 March" in btext, "his birthday is in the journal")
	hud.close_top()
	Game.debug_date = ""
	main.update_special_day()
	if head_before == "":
		Game.wearing.erase("head")
	else:
		Game.wearing.head = head_before
	await close_popups()

	# ---- daily wishes --------------------------------------------------------------------
	await close_popups()
	Game.wish = {}
	Game.wish_streak = 0
	Game.check_wish()
	await wait(0.3)
	check(not Game.wish.is_empty() and Game.wish_text() != "" and hud._wish_label.text != "", "a daily wish, shown under the coins (%s)" % Game.wish_short())
	await shot("wish")
	Game.wish = {"day": Time.get_date_string_from_system(), "kind": "treat", "arg": "carrot", "done": false, "cuddle": 0.0}
	var coins_wish: int = Game.coins
	Game.wish_event("treat", "apple")
	check(not Game.wish.done, "the wrong treat doesn't grant it")
	Game.wish_event("treat", "carrot")
	check(Game.wish.done and Game.wish_streak == 1 and Game.coins > coins_wish, "the right treat grants the wish (+%d)" % (Game.coins - coins_wish))
	Game.wish = {"day": Time.get_date_string_from_system(), "kind": "cuddle", "done": false, "cuddle": 0.0}
	Game.wish_event("cuddle", "", 5.0)
	check(not Game.wish.done, "a short cuddle isn't enough")
	Game.wish_event("cuddle", "", 10.0)
	check(Game.wish.done and Game.wish_streak == 2, "a long cuddle is")
	Game.wish_streak = 6
	Game.wish = {"day": Time.get_date_string_from_system(), "kind": "photo", "done": false, "cuddle": 0.0}
	var petals: int = Game.inventory.get("rose_petals", 0)
	coins_wish = Game.coins
	Game.wish_event("photo")
	check(Game.wish_streak == 7 and Game.coins - coins_wish > Catalog.WISH_BONUS and Game.inventory.rose_petals == petals + 2,
		"a week of wishes: a bonus and rose petals")
	Game.wish.day = "2000-01-01"
	Game.wish_last_done = "2000-01-01"
	Game.check_wish()
	check(Game.wish_streak == 0 and Game.wish.day == Time.get_date_string_from_system(), "a missed day resets the streak")
	await close_popups()

	# ---- photo challenges, favourites, memories -------------------------------------------
	Game.photo_challenges = {}
	var pres := Game.record_photo("user://test_challenge.png", "binky", 0, {"hour": 22.0, "room": "living", "wear": 3, "wearing": ["party_hat"]})
	check("binky" in pres.challenges and "fancy" in pres.challenges and "party" in pres.challenges and not "sunset" in pres.challenges,
		"photo challenges done by a photo (%s)" % str(pres.challenges))
	var pres2 := Game.record_photo("user://test_challenge2.png", "binky", 0, {"hour": 12.0})
	check(pres2.challenges.is_empty(), "each challenge only once")
	Game.favourites = {}
	Game.fav_counts = {"toy": {}, "nap": {}, "walk": {}}
	for i in Catalog.FAV_AT.toy:
		Game.note_fav("toy", "tunnel")
	check(Game.favourites.get("toy", "") == "tunnel", "playing with one toy a lot makes it his favourite")
	check(Game.memories.any(func(m): return m.id == "fav_toy_tunnel") and Game.memories.any(func(m): return m.id == "walk1"),
		"favourites and firsts go in the scrapbook")
	await wait(1.0)
	hud._journal_tab = "Memories"
	hud.open_journal()
	await wait(0.4)
	var mtext := str(hud._modal.find_children("*", "Label", true, false).map(func(l): return l.text))
	check(tr("First walk together: %s.") % tr("Park") in mtext or "First walk together" in mtext, "the Memories tab lists them")
	await shot("journal_memories")
	hud.close_top()
	hud._journal_tab = "Photos"
	hud.open_journal()
	await wait(0.4)
	await shot("journal_challenges")
	hud.close_top()
	hud._journal_tab = "Bubák"
	hud.open_journal()
	await wait(0.3)
	var ftext2 := str(hud._modal.find_children("*", "Label", true, false).map(func(l): return l.text))
	check(tr("Favourite toy: %s") % Catalog.item_name("tunnel") in ftext2, "his favourites are in the journal")
	hud.close_top()

	# ---- the veggie patch --------------------------------------------------------------------
	Game.balcony = "open"
	Game.coins += 1000
	check(Game.buy("veg_patch") == "" and main.find_item("veg_patch", "balcony") != null, "buy a veggie patch for the balcony")
	Game.garden = []
	Game.plant(0, "carrot")
	Game.plant(1, "dandelion")
	Game._grow_garden(60.0)
	check(Game.harvest(0) == 0, "not ripe yet")
	main.go_to("balcony")
	await wait(0.5)
	await shot("garden_growing")
	Game._grow_garden(Catalog.CROPS.carrot.hours * 60.0)
	var carrots: int = Game.inventory.get("carrot", 0)
	await wait(0.3)
	await shot("garden_ripe")
	main._use_item(main.find_item("veg_patch", "balcony"))
	await wait(0.4)
	check(hud._modal != null, "tap the patch: the garden opens")
	await shot("garden")
	hud.close_top()
	check(Game.harvest(0) == Catalog.CROPS.carrot.yield and Game.inventory.carrot == carrots + Catalog.CROPS.carrot.yield,
		"pick the carrots: into the treat bag")
	main.go_to("living")
	await wait(0.3)

	# ---- the vet ------------------------------------------------------------------------------
	Game.vet_last = Time.get_unix_time_from_system() - (Catalog.VET_DAYS + 1) * 86400.0
	check(Game.vet_due(), "a check-up is due after a week")
	var coins_vet: int = Game.coins
	hud.open_vet()
	await wait(0.4)
	check(hud._modal != null and Game.coins > coins_vet and not Game.vet_due(), "the vet checks him over (+%d)" % (Game.coins - coins_vet))
	await shot("vet")
	hud.close_top()

	# ---- greeting, the cat, a playdate -----------------------------------------------------
	await close_popups()
	main.go_to("living")
	b.teleport(Vector2(400, 600))
	b.start("idle", null, b.position)
	await wait(0.2)
	Game.greet_pending = true
	await wait(0.4)
	check(b.act == "greet", "back after a while: he comes to say hello")
	await wait(1.0)
	await shot("greeting")
	await wait(2.5)
	b.teleport(Vector2(560, 600))
	b.start("idle", null, b.position)
	main._cat_arrives()
	await wait(1.5)
	check(main._cat_t > 0 and b.act in ["thump", "hide_box", "flee"], "the neighbour's cat: Bubák thumps (%s)" % b.act)
	await shot("window_cat")
	main._tap(main.WINDOW.get_center(), null)
	await wait(1.0)
	check(main._cat_t <= 0.0 or main._cat_rise < 0.5, "tap the window: shoo")
	await close_popups()
	var nb: int = main.bunnies.size()
	main._guest_arrives()
	await wait(1.5)
	check(main.guest != null and main.bunnies.size() == nb + 1 and main.guest.pet.nickname in Catalog.GUESTS, "a friend's bunny comes over to play")
	await shot("guest")
	main._guest_t = 0.0
	await wait(1.0)
	check(main.guest == null and main.bunnies.size() == nb, "and hops home again")

	# ---- Easter, Halloween, the day you met ------------------------------------------------
	var year2: int = Time.get_date_dict_from_system().year
	check(Game.easter_days(2025) == ["04-19", "04-20", "04-21"] and Game.easter_days(2026) == ["04-04", "04-05", "04-06"], "Easter dates")
	Game.presents = []
	Game.eggs_year = 0
	Game.debug_date = Game.easter_days(year2)[1]
	main.update_special_day()
	await close_popups()
	check(main.easter_decor != null and main.eggs.size() == Catalog.EASTER_EGGS and main.present == null, "Easter: eggs hidden around the flat")
	await shot("easter")
	for e in main.eggs.duplicate():
		main._use_item(e)
		await wait(0.1)
	await wait(0.3)
	check(Game.eggs_left() == 0 and main.present != null and main.present.tex_name == "present_easter", "all eggs found: a present appears")
	await close_popups()
	b.teleport(Vector2(560, 600))
	main._use_item(main.present)
	for i in 80:
		if main.present == null:
			break
		await wait(0.1)
	await wait(0.3)
	check(Game.count_item("egg_rattle") == 1, "an egg rattle for Easter")
	Game.debug_date = "10-31"
	main.update_special_day()
	await close_popups()
	check(main.pumpkin != null and main.easter_decor == null and main.present != null and main.present.tex_name == "present_halloween",
		"Halloween: a pumpkin and a present")
	main._debug_hour = 22.0
	main._update_sky()
	await wait(0.6)
	await shot("halloween")
	main._debug_hour = -1.0
	b.teleport(Vector2(560, 600))
	main._use_item(main.present)
	for i in 80:
		if main.present == null:
			break
		await wait(0.1)
	await wait(0.3)
	check(Game.wearing.get("head", "") == "witch_hat", "a witch hat for Halloween")
	Game.debug_date = ""
	main.update_special_day()
	var created_keep: float = Game.created_at
	Game.created_at = Time.get_unix_time_from_system() - 366 * 86400.0
	Game.debug_date = Game._month_day(Game.created_at)   # local time, as the game counts it
	check(Game.special_day() == "anniversary" or Game.special_day() == "birthday", "the day you met, a year on")
	Game.debug_date = ""
	Game.created_at = created_keep
	Game.wearing.erase("head")
	main.update_special_day()
	await close_popups()

	# ---- the long run: days together, makeovers, fame, souvenirs ---------------------------------
	await close_popups()
	check(Catalog.ITEMS.keys().filter(func(k): return Catalog.ITEMS[k].kind == "wear" and not b.WEAR_ANCHOR.has(k)).is_empty(),
		"every accessory has a place on him")
	Game.days_played = 6
	Game.last_play_day = ""
	Game.milestones_got = []
	var coins_days: int = Game.coins
	check(Game.lock_reason("style_mint") != "", "makeovers wait for days together")
	Game.check_day()
	await wait(0.4)
	check(Game.days_played == 7 and 3 in Game.milestones_got and 7 in Game.milestones_got and Game.coins >= coins_days + 180
		and hud._modal != null, "7 days together: milestone pop-ups and coins")
	await shot("milestone")
	await close_popups()
	check(Game.lock_reason("style_mint") == "" and Game.next_milestone().days == 14, "the mint makeover opens; next surprise at 14 days")
	Game.coins += 20000
	check(Game.buy("style_mint") == "" and Game.room_style == "mint" and main.room_bg.texture == Catalog.tex("room_mint"), "buy a makeover")
	hud._shop_tab = "Makeover"
	hud.open_shop()
	await wait(0.4)
	await shot("shop_makeover")
	hud.close_top()
	await wait(0.2)
	await shot("room_mint")
	Game.days_played = 199
	Game.last_play_day = ""
	Game.check_day()
	await close_popups()
	check("gold_bowtie" in Game.wardrobe and "gold_crown" in Game.wardrobe and Game.count_item("statue") == 1
		and Game.count_item("royal_cushion") == 1, "200 days: a golden bow tie, a crown, a cushion and a statue")
	for st in ["lavender", "sunny", "starry"]:
		check(Game.buy("style_" + st) == "", "makeover: " + st)
	await wait(0.3)
	await shot("room_starry")
	check(Game.lock_reason("style_forest") != "", "the last makeover waits for a whole year")
	Game.buy("style_cream")
	check(Game.room_style == "cream", "switch back to a makeover you own")
	Game.wearing.erase("head")
	Game.wearing.erase("neck")
	# fame
	Game.fame = -1
	Game.followers = 16000
	Game._check_fame()
	await wait(0.4)
	check(Game.fame == 2 and Game.fame_name() == tr("Bunnyfluencer") and hud._modal != null, "followers make him famous")
	for i in 6:   # the cover comes after the pop-ups for the steps before it
		if hud._modal == null or str(hud._modal.find_children("*", "Label", true, false).map(func(l): return l.text)).contains("BUNNY WEEKLY"):
			break
		hud.close_top()
		await wait(0.2)
	await wait(0.3)
	await shot("magazine")
	check(Game.cover != "" or Game.photos.all(func(x): return x.behaviour == ""), "his best photo goes on a magazine cover")
	await close_popups()
	# souvenirs
	Game.souvenirs = {}
	var sets := 0
	for i in 300:
		var r := Game._find_souvenir("beach")
		if r.get("set_done", false):
			sets += 1
	check(sets == 1 and Game.souvenirs.size() == 4, "a whole set of beach souvenirs, once")
	var all_done := false
	for place in Catalog.SOUVENIRS:
		for i in 300:
			if Game._find_souvenir(place).get("all_done", false):
				all_done = true
	check(all_done and Game.count_item("curio") == 1 and Game.goal_value({"type": "souvenirs"}) == 20, "every souvenir: the souvenir cabinet")
	hud.open_walks()
	await wait(0.4)
	await shot("walks_souvenirs")
	hud.close_top()
	# a save from before Days together gets credit for the days it shows
	var keep_state := Game.to_dict()
	var pre_days_save := Game.to_dict()
	pre_days_save.erase("days_played")
	var now_t := Time.get_unix_time_from_system()
	pre_days_save.created_at = now_t - 5 * 86400.0
	pre_days_save.photos = [{"file": "x", "behaviour": "binky", "likes": 1, "coins": 1, "time": now_t - 3 * 86400.0},
		{"file": "y", "behaviour": "binky", "likes": 1, "coins": 1, "time": now_t - 3 * 86400.0 + 60}]
	pre_days_save.memories = [{"id": "m", "time": now_t - 86400.0, "text": "x", "args": [], "file": ""}]
	Game._apply(pre_days_save)
	check(Game.days_played == 3, "an older save counts the days it was played (%d)" % Game.days_played)
	Game._apply(keep_state)
	# tapping a toy invites him over to play
	main.go_to("living")
	b.teleport(Vector2(600, 620))
	b.start("idle", null, b.position)
	var tun = main.find_item("tunnel", "living")
	if tun:
		main._use_item(tun)
		check(b.act == "tunnel", "tap a toy: he comes to play with it (%s)" % b.act)
	# everything new survives saving and loading (JSON turns numbers into floats)
	Game.wish = {"day": Time.get_date_string_from_system(), "kind": "toy", "arg": "tunnel", "done": false, "cuddle": 3.0}
	Game.garden = [{"crop": "carrot", "grow": 0.5}, {"crop": "", "grow": 0.0}, {"crop": "rose_petals", "grow": 1.0}]
	Game.room_style = "mint"
	Game.save_game()
	var saved_keys := ["wish", "wish_streak", "photo_challenges", "memories", "fav_counts", "favourites", "garden", "eggs_found",
		"vet_last", "days_played", "milestones_got", "fame", "cover", "souvenirs", "room_style", "styles", "presents", "birthday"]
	var saved_vals := {}
	for k in saved_keys:
		saved_vals[k] = JSON.parse_string(JSON.stringify(Game.to_dict()[k]))
	Game.load_game()
	var changed_keys := saved_keys.filter(func(k): return str(JSON.parse_string(JSON.stringify(Game.to_dict()[k]))) != str(saved_vals[k]))
	check(changed_keys.is_empty(), "new progress survives save and load (differs: %s)" % str(changed_keys))
	var roses_had: int = Game.inventory.get("rose_petals", 0)
	Game.wish_event("toy", "tunnel")
	Game.note_fav("walk", "park")
	Game._find_souvenir("park")
	Game._grow_garden(10.0)
	check(Game.wish.done and Game.harvest(2) == 2 and Game.inventory.rose_petals == roses_had + 2 and Game.wish_short() != ""
		and not Game.next_milestone().is_empty() and Game.days_played > 0, "and keeps working after loading")
	Game.room_style = "cream"
	# ---- the same things through the real buttons ------------------------------------------
	await close_popups()
	var nt: int = hud._toasts.get_child_count()
	var tap_wish := InputEventMouseButton.new()
	tap_wish.button_index = MOUSE_BUTTON_LEFT
	tap_wish.pressed = true
	hud._wish_label.get_parent().get_parent().gui_input.emit(tap_wish)
	await wait(0.1)
	check(hud._toasts.get_child_count() > nt or hud._toasts.get_child_count() == 3, "tap the wish bubble: it explains the wish")
	hud._shop_tab = "Makeover"
	hud.open_shop()
	await wait(0.3)
	var use_btns: Array = _buttons(tr("Use"))
	if not use_btns.is_empty():
		var style_before := Game.room_style
		use_btns[0].pressed.emit()
		await wait(0.2)
		check(Game.room_style != style_before, "Shop > Makeover > Use switches the flat's look")
	hud.close_top()
	Game.room_style = "cream"
	Game.style_changed.emit()
	Game.garden = []
	Game.watered.erase("garden")
	hud.open_garden()
	await wait(0.3)
	_buttons(tr("Water"))[0].pressed.emit()
	await wait(0.2)
	_buttons(tr("Carrots"))[0].pressed.emit()
	await wait(0.2)
	check(Game.is_watered("garden") and Game.garden[0].crop == "carrot", "garden buttons: water, then plant carrots")
	Game._grow_garden(Catalog.CROPS.carrot.hours * 60.0)
	hud.close_top()
	hud.open_garden()
	await wait(0.3)
	var carrots2: int = Game.inventory.get("carrot", 0)
	_buttons(tr("Pick"))[0].pressed.emit()
	await wait(0.2)
	check(Game.inventory.carrot == carrots2 + Catalog.CROPS.carrot.yield and Game.garden[0].crop == "", "the Pick button harvests")
	hud.close_top()
	Game.vet_last = 1.0
	hud._journal_tab = "Bubák"
	hud.open_journal()
	await wait(0.3)
	_buttons(tr("Check-up at the vet"))[0].pressed.emit()
	await wait(0.3)
	check(hud._modal != null and not Game.vet_due() and _buttons(tr("Thank you, doctor!")).size() == 1, "Journal > Bubák > vet button")
	hud.close_top()
	await close_popups()
	# midnight passes while playing: a new wish, another day together, a new walk
	var yesterday := Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) - 86400)
	Game.wish = {"day": yesterday, "kind": "cuddle", "done": true, "cuddle": 20.0}
	Game.wish_last_done = yesterday
	Game.wish_streak = 3
	Game.last_play_day = yesterday
	Game.walk_day = yesterday
	var days_before := Game.days_played
	main._sky_t = 0.0
	await wait(0.4)
	check(Game.wish.day == Time.get_date_string_from_system() and not Game.wish.done and Game.wish_streak == 3
		and Game.days_played == days_before + 1 and not Game.walked_today(), "midnight: a new wish (streak kept), a new day together, a new walk")
	await close_popups()

	# long goals unlock one after another	# long goals unlock one after another
	var g30: Dictionary = Catalog.GOALS.filter(func(x): return x.id == "days30")[0]
	Game.goals_claimed.erase("days7")
	check(not Game.goal_visible(g30), "the 30-day goal waits for the 7-day one")
	Game.claim_goal("days7")
	check(Game.goal_visible(g30), "and shows up once it's claimed")
	await close_popups()

	# ---- a mate for Bubák ---------------------------------------------------------
	Game.mate_stage = 0
	Game.trust = 90.0
	await wait(1.3)
	check(Game.mate_stage == 0, "no friend yet at Bonded")
	await close_popups()
	Game.trust = 96.0
	if Game.cozy_level() < Catalog.MATE_COZY:
		Game.coins += 5000
		for id in ["castle", "lantern", "flowers", "beanbag", "rug", "plant", "lamp"]:
			Game.buy(id)
	await wait(1.3)
	check(Game.mate_stage == 1 and hud._modal != null, "Best buds + cozy flat: the rescue opens, with a pop-up (cozy %d)" % Game.cozy_level())
	await shot("mate_unlock")
	await close_popups()
	hud.open_shop()
	await wait(0.2)
	check(tr("Adopt a friend") in hud._modal.find_children("*", "Button", true, false).map(func(x): return x.text), "shop offers adoption")
	hud.open_hutch("caramel")
	await wait(0.5)
	await shot("hutch")
	Game.coins = 50
	check(Game.adopt("caramel") != "" and Game.mate == null, "can't adopt without the coins")
	Game.coins = 2000
	check(Game.adopt("caramel") == "" and Game.mate != null and Game.pets.size() == 2 and Game.coins == 1250, "adopt Caramel")
	check(Game.adopt("luna") != "", "only one friend")
	await reload_scene()
	hud = main.hud
	b = main.bunny
	check(main.bunnies.size() == 2 and main.mate_bunny.pet == Game.mate, "the new friend is in the flat")
	check(hud._need_bars.size() == 2 and hud._mate_trust != null, "second row of needs and a trust card")
	await shot("mate_home")
	hud._journal_tab = "Friend"
	hud.open_journal()
	await wait(0.3)
	var ftext := str(hud._modal.find_children("*", "Label", true, false).map(func(l): return l.text))
	var fbuttons: Array = hud._modal.find_children("*", "Button", true, false).map(func(x): return x.text)
	check("Caramel" in fbuttons and tr("Friendship with Bubák: %d%%") % int(Game.bond) in ftext and "kg" in ftext,
		"the friend has a page in the journal")
	await shot("journal_friend")
	hud.close_top()
	# the friend dresses up too; there's one of each accessory
	if not "beanie" in Game.wardrobe:
		Game.wardrobe.append("beanie")
	Game.wearing.head = "beanie"
	Game.toggle_wear("beanie", Game.mate)
	check(Game.mate_wearing.get("head", "") == "beanie" and not "beanie" in Game.wearing.values(),
		"the friend can wear an accessory, and it comes off Bubák")
	await wait(0.3)
	check(main.mate_bunny.wear_sprites["head"].visible, "the friend shows the accessory in the room")
	hud.open_wardrobe()
	await wait(0.3)
	var wbuttons: Array = hud._modal.find_children("*", "Button", true, false).filter(func(x): return x.text == "Caramel")
	check(wbuttons.size() == 1, "the wardrobe can switch to the friend")
	if wbuttons.size() == 1:
		wbuttons[0].pressed.emit()
		await wait(0.3)
	check(hud._wardrobe_stage.who == Game.mate, "the wardrobe mirror shows the friend")
	await shot("wardrobe_friend")
	hud.close_top()
	await reload_scene()
	hud = main.hud
	b = main.bunny
	check(Game.mate_wearing.get("head", "") == "beanie", "the friend's outfit is saved")
	# each rabbit has its own needs and trust
	var mb = main.mate_bunny
	Game.mate.trust = 62.0   # Bonded: never shies away from petting
	Game.mate.needs.food = 10.0
	Game.bubak.needs.food = 90.0
	await wait(0.4)
	check(hud._need_bars[1].food.value < 20 and hud._need_bars[0].food.value > 80, "need bars per rabbit")
	mb.teleport(Vector2(700, 600))
	mb.start("idle", null, mb.position)
	b.teleport(Vector2(300, 640))
	await wait(0.2)
	Game.mate.trust_today = 0.0
	var mate_trust: float = Game.mate.trust
	var bubak_trust: float = Game.trust
	var mp: Vector2 = mb.position + Vector2(0, -40)
	press(mp, true)
	await wait(2.5)
	press(mp, false)
	await wait(0.2)
	check(Game.mate.trust > mate_trust + 0.1 and Game.trust - bubak_trust < 0.2, "petting the friend raises the friend's trust (%.1f -> %.1f)" % [mate_trust, Game.mate.trust])
	# best friends snuggle
	Game.bond = 80.0
	b.teleport(Vector2(600, 620))
	b.start("loaf", null, b.position)
	mb.teleport(Vector2(780, 620))
	await wait(0.1)
	mb.start("snuggle", b, b.position + Vector2(70, 4))
	for i in 40:
		await wait(0.1)
		if mb.act == "snuggle" and mb.phase == 1:
			break
	check(mb.act == "snuggle" and b.act == "snuggle" and Game.seen.has("snuggle"), "bonded bunnies snuggle together")
	await wait(0.6)
	await shot("snuggle")
	Game.save_game()
	Game.mate.trust = 0.0
	Game.load_game()
	check(Game.mate != null and Game.mate.id == "caramel" and Game.mate.trust > 30, "the friend is saved and loaded")

	# ---- the late game --------------------------------------------------------------------
	# Foster bunnies: once Bubák has a friend, the rescue asks you to foster shy rabbits
	await close_popups()
	Game.foster = null
	Game.fosters_done = []
	Game.foster_next = ""
	Game.foster_offer_day = ""
	Game._check_foster()
	await wait(0.3)
	var lt_take: Array = _buttons("Take them in")
	check(Game.foster_available() and lt_take.size() == 1, "with a friend at home, the rescue asks you to foster a bunny")
	await shot("foster_offer")
	if lt_take.size() == 1:
		await press_reload(lt_take[0])
	hud = main.hud
	b = main.bunny
	check(Game.foster != null and Game.foster.id == "pip" and main.foster_bunny != null and main.bunnies.size() == 3
		and Game.foster.quirk() == "hider" and hud._foster_bar != null, "Pip moves in as a foster bunny, with a quirk and a card")
	await wait(0.5)
	await shot("foster_home")
	var lt_fb = main.foster_bunny
	# a picky eater only warms up to gourmet treats
	Game.foster.id = "tofu"
	Game.foster.trust_today = 0.0
	Game.inventory["carrot"] = Game.inventory.get("carrot", 0) + 1
	Game.inventory["dried_apple"] = Game.inventory.get("dried_apple", 0) + 1
	lt_fb.teleport(Vector2(700, 630))
	lt_fb.start("idle", null, lt_fb.position)
	var lt_t0: float = Game.foster.trust
	main.treat_selected = "carrot"
	main._offer_treat(Vector2(760, 640), lt_fb)
	for i in 50:
		await wait(0.1)
		if lt_fb.act == "eat_hand":
			break
	var lt_cheap: float = Game.foster.trust - lt_t0
	await wait(0.4)
	lt_fb.start("idle", null, lt_fb.position)
	lt_t0 = Game.foster.trust
	main.treat_selected = "dried_apple"
	main._offer_treat(Vector2(760, 640), lt_fb)
	for i in 50:
		await wait(0.1)
		if lt_fb.act == "eat_hand":
			break
	check(lt_cheap == 0.0 and Game.foster.trust > lt_t0, "a picky foster only warms up to gourmet treats (+%.1f, then +%.1f)" % [lt_cheap, Game.foster.trust - lt_t0])
	# a nipper nips if the cuddle goes on too long
	Game.foster.id = "bramble"
	Game.foster.trust = 15.0   # Curious: he lets you start a cuddle most of the time
	var lt_petted := false
	for i in 20:   # a nervous bunny may still run off when you reach for him
		lt_fb.start("idle", null, lt_fb.position)
		lt_fb._pet_fatigue = 0.0
		lt_petted = lt_fb.on_pet_start()
		if lt_petted:
			break
	lt_t0 = Game.foster.trust
	var lt_held: bool = lt_fb.on_pet_hold(3.0)
	check(lt_petted and not lt_held and Game.foster.trust < lt_t0 and lt_fb.act == "flee", "a nipper nips when the cuddle goes on too long")
	Game.foster.id = "pip"
	# ready for a home: a family adopts them
	Game.foster.trust = Catalog.level_at(Catalog.FOSTER_GOAL) + 0.5
	Game.foster.settle_level()
	await wait(1.3)
	var lt_bye: Array = _buttons("Say goodbye")
	check(lt_bye.size() == 1, "once the foster bunny trusts you, a family wants to adopt them")
	await shot("foster_adopted")
	var lt_coins: int = Game.coins
	if lt_bye.size() == 1:
		await press_reload(lt_bye[0])
	hud = main.hud
	b = main.bunny
	check(Game.foster == null and Game.fosters_done.size() == 1 and Game.coins >= lt_coins + Catalog.FOSTER_REWARD
		and main.foster_bunny == null and not Game.foster_available() and Game.next_foster() == "tofu"
		and Game.memories.any(func(m): return m.id == "foster_1"), "they go to a new home: a reward, a memory, and the next one comes tomorrow")
	Game.foster_next = ""
	Game.take_foster()
	Game.save_game()
	Game.foster = null
	Game.load_game()
	check(Game.foster != null and Game.foster.id == "tofu", "the foster bunny is saved and loaded")
	hud._journal_tab = "Friend"
	hud.open_journal()
	await wait(0.4)
	await shot("journal_foster")
	await close_popups()
	Game.foster = null

	# Keeping the bond: from Bonded up, days away cost trust (never a level), only while life goes on
	var lt_life: bool = Game.life_goes_on
	var lt_trust: float = Game.bubak.trust
	Game.life_goes_on = true
	Game.bubak.trust = 80.0
	Game.bubak.settle_level()
	var lt_missed: Array = []
	var lt_on_miss := func(loss: float, days: int): lt_missed.append([loss, days])
	Game.bond_missed.connect(lt_on_miss)
	Game.last_play_day = Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) - 3 * 86400)
	Game.check_day()
	var lt_after: float = Game.bubak.trust
	Game.life_goes_on = false
	Game.bubak.trust = 90.0
	Game.last_play_day = Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) - 3 * 86400)
	Game.check_day()
	Game.bond_missed.disconnect(lt_on_miss)
	check(is_equal_approx(lt_after, Catalog.level_at(5)) and lt_missed.size() == 1 and lt_missed[0][1] == 2 and Game.bubak.trust == 90.0,
		"Bonded: two days away cost trust, but never the level; not when time stops (%.1f, %s, %.1f)" % [lt_after, lt_missed, Game.bubak.trust])
	Game.life_goes_on = lt_life
	Game.bubak.trust = lt_trust
	Game.bubak.settle_level()
	await close_popups()

	# Show league: the month's season ends with a place and a prize
	Game.club_stage = 3
	Game.league_season = "2020-01"
	Game.league_points = 2000
	Game.league_history = []
	var lt_lc: int = Game.coins
	Game._check_league()
	await wait(0.3)
	check(Game.league_history.size() == 1 and Game.league_history[0].place == 1 and Game.league_season == Game.season_now()
		and Game.league_points == 0 and Game.coins >= lt_lc + Catalog.LEAGUE_PRIZES[0].coins and _buttons("Hooray!").size() == 1,
		"the league season ends with the month: 1st place pays out")
	await shot("league_end")
	await close_popups()
	var lt_res := Game.finish_show(1, "looks", 1)
	check(Game.league_points == 20 and lt_res.league == 20, "a Regional win is worth 20 league points")
	check(Game.rival_points("pepik", "2026-10", 10) == Game.rival_points("pepik", "2026-10", 10) and Game.rival_points("pepik", "2026-10", 20) > Game.rival_points("pepik", "2026-10", 5),
		"rivals collect league points day by day, the same every time you look")
	hud.open_club("League")
	await wait(0.3)
	await shot("club_league")
	check(hud._modal != null and Game.league_table().size() == Game.active_rivals().size() + 1, "Club > League shows the standings")
	await close_popups()

	# The weekly judge and your own trick routine
	for t in Catalog.TRICK_ORDER:
		Game.tricks[t] = Catalog.TRICK_STARS[-1]
	Game.routine = ["spin", "", "come", "stand", "hoop"]
	check(Game.show_routine() == ["spin", "come", "stand", "hoop"], "the routine follows your order, up to 4 tricks")
	var lt_like: String = Game.judge_like()
	var lt_other: String = Catalog.SHOW_CATS.keys().filter(func(c): return c != Catalog.JUDGE_LIKES[lt_like].cat)[0]
	check(Catalog.JUDGE_LIKES.has(lt_like) and not Game.judge_pleased(lt_other, {"routine": Game.show_routine(), "faults": 0}),
		"this week's judge loves %s, and only in their category" % lt_like)
	hud.open_club("Shows")
	await wait(0.3)
	await shot("club_shows_judge")
	await close_popups()

	# Agility: practise on the course, then a show
	Game.coins += 2000
	if Game.count_item("hurdles") == 0:
		Game.buy("hurdles")
	Game.agility = 0.0
	Game.focus = float(Game.focus_max())
	hud.open_club("Agility")
	await wait(0.3)
	var lt_run = hud.club_panel
	var lt_go: Array = _buttons("Start a run")
	if lt_go.size() == 1:
		lt_go[0].pressed.emit()
	await wait(1.2)
	await auto_jump(lt_run, "agility_practice")
	await wait(1.2)
	check(lt_run.clears >= 3 and Game.agility > 0.0, "agility practice: he clears the bars (%d of %d) and gets better (%.1f)" % [lt_run.clears, lt_run.clears + lt_run.faults, Game.agility])
	# jumping non-stop doesn't work: a jump over nothing needs a breather
	lt_run.start()
	while lt_run.running():
		lt_run.jump()
		await get_tree().process_frame
	check(lt_run.clears <= 3, "spamming Jump doesn't clear the course (%d of %d)" % [lt_run.clears, lt_run.clears + lt_run.faults])
	await close_popups()
	Game.show_ready_at = {}
	var lt_lp: int = Game.league_points
	hud._enter_show(0, "agility")
	var lt_ring = hud.club_panel
	for i in 40:
		await wait(0.1)
		if lt_ring._run_node and lt_ring._run_node.running():
			break
	if lt_ring._run_node:
		await auto_jump(lt_ring._run_node)
	for i in 80:
		await wait(0.1)
		if lt_ring._button.text == "Continue":
			break
	await shot("agility_show")
	check(lt_ring._button.text == "Continue" and Game.league_points > lt_lp, "an Agility show: a run, a result and league points")
	await close_popups()

	# Rare moments at the top levels
	Game.bubak.trust = 100.0
	Game.bubak.settle_level()
	var lt_licked := false
	for i in 12:
		b.start("idle", null, b.position)
		b._pet_fatigue = 0.0
		if b.on_pet_start():
			b.on_pet_hold(3.2)
			lt_licked = b.data.get("lick", false)
			if lt_licked:
				check(b.current_behaviour() == "hand_lick", "while he licks your hand, photos catch it")
			b.on_pet_hold(2.0)
			var lt_nap: bool = b.data.get("dozed", false) and b.current_behaviour() == "trust_nap"
			b.on_pet_end()
			if lt_licked:
				check(lt_nap, "at Inseparable he falls asleep in your hand")
				break
	check(lt_licked and Game.seen.has("hand_lick") and Game.seen.has("trust_nap"), "Best buds and up: he licks your hand; Inseparable: he dozes off")
	b.teleport(Vector2(640, 620))
	b.start("circle", null, Vector2(640, 640))
	for i in 40:
		await wait(0.1)
		if b.act == "circle" and b.phase == 1:
			break
	await wait(0.6)
	await shot("circle")
	check(Game.seen.has("circle"), "Bonded and up: he runs circles around your feet")
	Game.bubak.trust = lt_trust
	Game.bubak.settle_level()

	# Bubák merch: opens with fame
	await close_popups()
	Game.followers = maxi(Game.followers, 6000)
	Game._check_fame()   # any new fame title first, so its pop-up isn't in the way
	await close_popups()
	Game.merch = {}
	Game.merch_told = false
	Game.merch_pending = 0.0
	Game.merch_earned = 0
	await wait(1.3)
	var lt_see: Array = _buttons("Let's see!")
	check(lt_see.size() == 1, "fame brings fans who want Bubák merch")
	if lt_see.size() == 1:
		lt_see[0].pressed.emit()
	await wait(0.4)
	var lt_order: Array = _buttons("Order 30 (120)")
	check(lt_order.size() == 1 and _buttons("Order 15 (1200)").is_empty(), "the merch screen lists the products; the plush waits for more fame")
	if lt_order.size() == 1:
		lt_order[0].pressed.emit()
	await wait(0.4)
	await shot("merch")
	var lt_m: Dictionary = Game.merch_of("stickers")
	check(int(lt_m.stock) == 30 and lt_m.photo != "", "ordering stickers puts your best photo on them")
	Game._sell_merch(10.0)
	check(int(lt_m.sold) > 0 and Game.merch_pending > 0, "merch sells by the hour (%d sold)" % int(lt_m.sold))
	hud.open_merch()
	await wait(0.3)
	var lt_coll: Array = _buttons("Collect")
	var lt_mc: int = Game.coins
	if lt_coll.size() == 1:
		lt_coll[0].pressed.emit()
	await wait(0.3)
	check(Game.coins > lt_mc and Game.merch_earned > 0, "collecting merch sales pays out")
	check(Game.merch_design("stickers") != "", "a new design needs a newer photo")
	await close_popups()
	Game.work_ready_at = 0
	hud.open_work()
	await wait(0.3)
	check(hud._modal != null and hud._modal.find_children("*", "Label", true, false).any(func(l): return l.text == "Bubák merch"),
		"the laptop has a Bubák merch card")
	await shot("work_menu_merch")
	await close_popups()
	# Wear and tear: toys get worn with use, and in the end he loves them to pieces
	Game.coins += 500
	var lt_box: Node2D = main.find_item("box")
	if lt_box == null:
		Game.buy("box")
		await wait(0.3)
		lt_box = main.find_item("box")
	var lt_entry: Dictionary = Game.placed.filter(func(e): return e.uid == lt_box.uid)[0]
	lt_entry.wear = int(Catalog.WEAR_USES.box * 0.7)
	Game.wear_item(lt_box.uid)
	await wait(0.1)
	check(Game.wear_of(lt_entry) > 0.7 and lt_box.modulate != Color.WHITE, "a well-used toy looks worn (%d%%)" % int(Game.wear_of(lt_entry) * 100))
	lt_entry.wear = Catalog.WEAR_USES.box - 1
	var lt_broken: int = Game.stats.get("broken", 0)
	b.teleport(lt_box.use_point(b.position))
	b.start("hide_box", lt_box)
	for i in 200:
		await wait(0.1)
		if main.find_item("box") == null:
			break
	await wait(0.3)
	check(main.find_item("box") == null and Game.count_item("box") == 0 and Game.stats.get("broken", 0) == lt_broken + 1
		and Game.lock_reason("box") == "", "after one last game he loves the cardboard castle to pieces: buy a new one")
	await shot("toy_broken")
	check(not Catalog.WEAR_USES.has("jingle_ball") and not Catalog.WEAR_USES.has("royal_cushion"), "presents and rewards never wear out")
	await close_popups()

	# ---- coming back for more ---------------------------------------------------------
	# Today's tasks: three a day, the same all day; done ones pay, all three give a sticker
	Game.daily = {}
	Game.check_daily()
	var nw_tasks: Array = Game.daily_tasks().map(func(t): return t.id)
	Game.daily = {}
	Game.check_daily()
	check(nw_tasks.size() == 3 and Game.daily_tasks().map(func(t): return t.id) == nw_tasks, "three daily tasks, the same ones all day (%s)" % [nw_tasks])
	Game.stickers = ["2000-01-01", "2000-01-02", "2000-01-03", "2000-01-04", "2000-01-05", "2000-01-06"]
	var nw_coins: int = Game.coins
	for t in Game.daily_tasks():
		var info: Dictionary = Game._daily_task(t.id)
		Game.stats[info.stat] = int(Game.stats.get(info.stat, 0)) + info.n
	Game._check_daily()
	check(Game.daily.done.size() == 3 and Time.get_date_string_from_system() in Game.stickers
		and Game.coins == nw_coins + 3 * Catalog.DAILY_COINS + Catalog.DAILY_ALL + Catalog.STICKER_PAGE_COINS,
		"all three tasks done: coins, a sticker, and a full sticker page (+%d)" % (Game.coins - nw_coins))
	Game._check_daily()
	check(Game.stickers.size() == 7, "one sticker a day")
	hud.open_journal()
	await wait(0.4)
	await shot("journal_daily")
	await close_popups()

	# Seasons: autumn brings a leaf pile on the balcony, and the season's find
	Game.season_finds = []
	Game.debug_date = "10-15"
	main.update_season()
	check(Game.season() == "autumn" and main.leaf_pile != null, "autumn: a leaf pile on the balcony")
	main.go_to("balcony")
	await wait(0.4)
	b.teleport(main.leaf_pile.position + Vector2(-120, 10))
	b.start("leaf_pile", main.leaf_pile, main.leaf_pile.position + Vector2(-60, 4))
	await wait(1.5)
	await shot("season_leaf_pile")
	check(Game.seen.has("leaf_pile") and "scarf" in Game.wardrobe and Game.season_key() in Game.season_finds, "a dive into the leaves: autumn's find, a scarf")
	await wait(0.5)
	await shot("season_find_popup")
	await close_popups()
	var nw_wardrobe: int = Game.wardrobe.size()
	Game.season_moment("leaf_pile")
	check(Game.wardrobe.size() == nw_wardrobe, "one find a season")
	Game.debug_date = "01-10"
	check(Game.season() == "winter" and Game.season_key() == "winter-%d" % (Time.get_date_dict_from_system().year - 1), "January is last year's winter")
	main.update_season()
	main._snowing = true
	main._snow_floor.visible = true
	b.start("snow_sniff", null, b.position)
	await wait(1.8)
	await shot("season_snow")
	check("snowflake" in Game.wardrobe, "first snow: a snowflake clip")
	await close_popups()
	Game.debug_date = "07-20"
	main.update_season()
	main.go_to("living")
	b.teleport(Vector2(640, 600))
	b.start("melt", null, b.position)
	await wait(0.5)
	check(b.current_behaviour() == "melt" and "straw_hat" in Game.wardrobe, "a hot day: a bunny puddle, and a straw hat")
	await close_popups()
	Game.debug_date = "04-20"
	main.update_season()
	check(main.leaf_pile == null, "no leaves in spring")
	Game.debug_date = ""
	main.update_season()
	quiet()
	Game.toggle_wear("scarf")
	await wait(0.2)
	await shot("wearing_scarf")

	# The dig box: finds, map pieces, and a treasure buried in the living room
	Game.coins += 500
	if Game.count_item("digbox") == 0:
		Game.buy("digbox")
	Game.treasure = {}
	Game.map_pieces = Catalog.MAP_PIECES - 1
	var nw_digs := 0
	while Game.treasure.is_empty() and nw_digs < 600:
		Game.dig_find()
		nw_digs += 1
	check(not Game.treasure.is_empty() and Game.map_pieces == 0 and Game.finds.has("map"), "digging turns things up, and the last map piece (%d digs, %d kinds)" % [nw_digs, Game.finds.size()])
	await wait(0.3)
	await shot("treasure_map")
	check(hud._modal != null, "the whole map shows where to dig")
	await close_popups()
	nw_coins = Game.coins
	main.go_to("living")
	await wait(0.4)
	await tap(Game.treasure_spot())
	await wait(0.5)
	check(Game.treasure.is_empty() and Game.coins >= nw_coins + Catalog.TREASURE_COINS and Game.count_item("treasure_chest") == 1,
		"tapping the X digs up the treasure, chest and all")
	await shot("treasure_found")
	await close_popups()

	# Postcards from adoptive families, and the Hall of Fame
	var nw_t: float = Time.get_unix_time_from_system() - 31 * 86400.0
	Game.fosters_done = Game.fosters_done.filter(func(f): return f.id != "tofu")   # an earlier foster check may have sent one home already
	Game.fosters_done.append({"id": "tofu", "time": nw_t, "level": 4})
	Game.postcards = []
	Game._check_letters()
	var nw_cards: int = Game.postcards.size()   # counted now: the game's own check may send the month-later one while we wait
	await wait(0.3)
	check(nw_cards == 1 and Game.postcards[0].id == "tofu" and hud._modal != null,
		"a postcard arrives a few days after a foster went home (%s, modal %s)" % [Game.postcards.map(func(c): return c.id), hud._modal != null])
	await shot("postcard")
	await close_popups()
	Game._check_letters()
	Game._check_letters()
	check(Game.postcards.size() >= 2 and Game.postcards.filter(func(c): return c.id == "tofu").size() == 2, "and another a month later, then no more")
	await close_popups()
	check(Game.hall_of_fame().any(func(h): return h.id == "tofu" and h.level == 4) and Game.goal_value({"type": "hall_gold"}) >= 1,
		"a foster who left Cuddly is in the Hall of Fame in gold")

	# Personality: only the two strongest traits grow all the way
	Game.traits = {}
	Game.trait_told = {}
	var nw_window := Game.agility_window()
	Game.add_trait("athlete", 500)
	Game.add_trait("showoff", 450)
	Game.add_trait("explorer", 420)
	check(Game.trait_level("athlete") == 3 and Game.trait_level("showoff") == 3 and Game.trait_level("explorer") == 1,
		"personality: the two strongest traits reach level 3, the third is held at 1")
	check(Game.agility_window() > nw_window, "an athletic bunny has more hang time")
	await close_popups()
	b.teleport(Vector2(256, 502))
	b.start("parkour", null, Vector2(250, 500))
	await wait(2.5)
	await shot("parkour")
	check(Game.seen.has("parkour"), "an athlete does sofa parkour")
	await wait(2.0)
	var nw_posed := false
	for i in 8:
		b.start("idle", null, b.position)
		b.act_t = 30
		main.set_mode("photo")
		nw_posed = b.act == "pose"
		main.set_mode("")
		if nw_posed:
			break
	check(nw_posed, "a little star poses when the camera comes out")

	# The photo album
	var nw_album := Game.album_count()
	Game.album.erase("pose")
	for nw_other in main.bunnies:   # he's the one in the middle of the shot
		if nw_other != b:
			nw_other.teleport(Vector2(1150, 680))
	main.go_to("living")
	b.teleport(Vector2(640, 600))
	b.start("pose", null, b.position)
	main.set_mode("photo")
	await wait(0.3)
	main.take_photo()
	await wait(1.0)
	main.set_mode("")
	await close_popups()
	check(Game.album.has("pose") and Game.album_count() >= nw_album, "a photo fills its album slot")
	var nw_pages: int = Game.album_pages.size()
	for sl in Catalog.ALBUM_PAGES[5].slots:
		if not Game.album.has(sl):
			Game.album[sl] = {"file": Game.album.pose.file, "likes": 1}
	Game.album_pages.erase(5)
	Game._check_album()
	check(5 in Game.album_pages and Game.album_pages.size() == nw_pages + 1, "a full album page pays out")
	hud._journal_tab = "Album"
	hud.open_journal()
	await wait(0.4)
	await shot("journal_album")
	hud._journal_tab = "Bubák"
	hud.open_journal()
	await wait(0.4)
	await shot("journal_bubak_traits")
	await close_popups()

	# Vaccination: once a year; overdue means no shows or walks
	Game.vacc_at = Time.get_unix_time_from_system() - 400 * 86400.0
	Game.show_ready_at = {}
	check(Game.vaccine_overdue() and Game.show_problem(0, "looks").contains("vaccination") and Game.walk_problem("park").contains("vaccination"),
		"an overdue vaccination: no shows or walks")
	hud.open_vet()
	await wait(0.3)
	await shot("vet_vaccine")
	check(not Game.vaccine_due() and Game.show_problem(0, "looks") == "", "vaccinated: shows are open again")
	await close_popups()

	# Visitors and weather: a storm, the neighbours' child, hide and seek
	main.go_to("living")
	b.teleport(Vector2(640, 600))
	b.start("idle", null, b.position)
	main.start_storm()
	await wait(1.5)
	check(main.storm_t > 0 and b.act == "storm_hide", "a thunderstorm: Bubák hides, trembling")
	await shot("storm")
	Game.bubak.trust_today = 0.0
	b.teleport(b.target)
	b.phase = 1
	var nw_trust: float = Game.trust
	if b.on_pet_start():
		b.on_pet_hold(2.5)
		b.on_pet_end()
	check(b.calmed and Game.trust > nw_trust, "comforting him in the storm builds trust")
	main.storm_t = 0.2
	await wait(0.6)
	check(main.storm_t <= 0 and b.act != "storm_hide", "the storm passes")
	await close_popups()
	Game.kid_day = ""
	main._kid_visits()
	await wait(0.3)
	await shot("kid_visit")
	var nw_yes: Array = _buttons("Come in, gently!")
	var nw_fol: int = Game.followers
	if nw_yes.size() == 1:
		nw_yes[0].pressed.emit()
	await wait(0.3)
	check(Game.kid_day == Time.get_date_string_from_system() and Game.followers == nw_fol + 30, "a visit from next door goes well with a trusting bunny")
	await close_popups()
	b.start("idle", null, Vector2(640, 600))
	b.teleport(Vector2(640, 600))
	main._hide_and_seek()
	await wait(0.5)
	check(b.act == "hide_seek" and not b.pivot.visible and main._peek != null, "hide and seek: only his ears show")
	await shot("hide_and_seek")
	await tap(b.position + Vector2(0, -30))
	await wait(0.3)
	check(b.act != "hide_seek" and b.pivot.visible and main._peek == null and Game.seen.has("peekaboo"), "found him! (act %s, shown %s, ears %s, hit %s, modal %s)" % [
		b.act, b.pivot.visible, main._peek != null, main._hit(b.position + Vector2(0, -30)), hud._modal != null])
	await close_popups()

	# The bigger veggie patch and golden seeds
	Game.coins += 2000
	Game.balcony = "open"
	if Game.count_item("veg_patch") == 0:
		Game.buy("veg_patch")
	check(Game.buy("garden_beds") == "" and Game.garden_beds().size() == 5, "the bigger veggie patch: five beds")
	Game.inventory.golden_seed = 1
	Game.garden[4] = {"crop": "", "grow": 0.0}
	Game.plant(4, "golden_carrot")
	Game.garden[4].grow = 1.0
	var nw_gc: int = Game.inventory.get("golden_carrot", 0)
	Game.harvest(4)
	check(Game.inventory.golden_seed == (1 if Game.seed_found else 0) and Game.inventory.golden_carrot == nw_gc + 1, "a golden seed grows a golden carrot")
	main.go_to("balcony")
	await wait(0.4)
	Game.garden[1] = {"crop": "carrot", "grow": 0.4}
	Game.garden[2] = {"crop": "rose_petals", "grow": 1.0}
	hud.open_garden()
	await wait(0.3)
	await shot("garden_five")
	check(hud._modal.get_child(0).get_child(0).get_rect().end.y <= main.get_viewport().get_visible_rect().size.y + 1,
		"the five-bed patch fits on the screen")
	await close_popups()
	main.go_to("living")

	# The daily agility course: timed, a best time, and a ghost of it the next time
	Game.agility_daily = {}
	Game.focus = float(Game.focus_max())
	hud.open_club("Agility")
	await wait(0.3)
	var nw_run = hud.club_panel
	var nw_daily: Array = _buttons("Daily course")
	if nw_daily.size() == 1:
		nw_daily[0].pressed.emit()
	await wait(0.5)
	check(nw_run.timed and nw_run.bars == 8 and nw_run._bars.any(func(o): return o.type != "bar"), "the daily course: 8 obstacles, not just bars")
	await auto_jump(nw_run, "", 40.0)
	await wait(1.0)
	var nw_best: float = Game.daily_best()
	check(nw_best > 0.0 and Game.daily_ghost().size() > 10 and Game.stats.get("agility_days", 0) >= 1,
		"a daily run sets today's best (%.1f s, %d of %d clean)" % [nw_best, nw_run.clears, nw_run.bars])
	check(nw_run.clears >= 6, "the autopilot gets round tunnels and weave poles too (%d of %d)" % [nw_run.clears, nw_run.bars])
	if nw_daily.size() == 1:
		nw_daily[0].pressed.emit()
	await wait(2.5)
	check(not nw_run.ghost.is_empty(), "the second run races today's ghost")
	await shot("agility_daily_ghost")
	await auto_jump(nw_run, "", 40.0)
	await wait(1.0)
	await shot("agility_daily_done")
	await close_popups()

	# ---- the top of the game ----------------------------------------------------------------
	# Advanced tricks: two moments to reward, and a master's certificate
	Game.tricks["stand"] = 0.0
	check(Game.trick_lock("bow") != "", "an advanced trick needs the basic one first")
	Game.tricks["stand"] = float(Catalog.TRICK_STARS[2])
	Game.tricks["come"] = float(Catalog.TRICK_STARS[2])
	Game.tricks["spin"] = float(Catalog.TRICK_STARS[2])
	check(Game.trick_lock("bow") == "" and Game.trick_chance("bow") < Game.trick_chance("stand"), "then it can be taught, and goes wrong more often")
	Game.focus = float(Game.focus_max())
	hud.open_club("Training")
	await wait(0.4)
	await shot("training_advanced")
	var tp_stage: StageBunny = hud.club_panel._stage
	var tp_res := [""]
	tp_stage.attempt_done.connect(func(r): tp_res[0] = r, CONNECT_ONE_SHOT)
	tp_stage.attempt("bow", 1.0)
	var tp_hits := 0
	for i in 120:
		await wait(0.05)
		if tp_stage.in_window():
			tp_stage.reward()
			tp_hits += 1
		if tp_res[0] != "":
			break
	check(tp_res[0] == "good" and tp_hits == 2, "a bow: both moments rewarded in time is perfect (%s, %d treats)" % [tp_res[0], tp_hits])
	tp_res[0] = ""
	tp_stage.attempt_done.connect(func(r): tp_res[0] = r, CONNECT_ONE_SHOT)
	tp_stage.attempt("high_five", 1.0)
	var tp_once := false
	for i in 120:
		await wait(0.05)
		if tp_stage.in_window() and not tp_once:
			tp_stage.reward()
			tp_once = true
		if tp_res[0] != "":
			break
	await shot("trick_high_five")
	check(tp_res[0] == "late", "only one of the two moments rewarded: not perfect (%s)" % tp_res[0])
	await close_popups()
	var tp_coins: int = Game.coins
	Game.tricks["bow"] = float(Catalog.TRICK_STARS[2]) - 1.0
	Game.train("bow", "good")
	await wait(0.3)
	check("bow" in Game.certificates and Game.coins >= tp_coins + Catalog.CERTIFICATE_COINS, "three stars on an advanced trick: a master's certificate")
	await shot("certificate")
	await close_popups()

	# Rivals keep up: they get better as Bubák wins, and a newcomer turns up after the National title
	var tp_base: float = Catalog.RIVALS.baron.tricks
	Game.trophies.append({"tier": 2, "cat": "looks", "place": 1, "time": Time.get_unix_time_from_system()})
	Game.trophies.append({"tier": 2, "cat": "photo", "place": 1, "time": Time.get_unix_time_from_system()})
	check(Game.rival_skill("baron", "tricks") > tp_base and Game.rival_growth() <= Catalog.RIVAL_GROWTH_MAX, "rivals train harder as Bubák wins (+%.1f)" % Game.rival_growth())
	Game.newcomer_told = false
	Game._check_rivals()
	await wait(0.3)
	check("velvet" in Game.active_rivals() and Game.newcomer_told, "a national champion: a new rival from abroad")
	await shot("newcomer")
	await close_popups()
	check(Game.league_table().size() == Catalog.RIVALS.size() + 1 and Catalog.LEAGUE_PRIZES.size() >= Game.league_table().size(), "the newcomer joins the league too")
	# a duel: one on one with a rival Bubák beat
	Game.duel = {}
	var tp_offered := false
	for i in 40:
		if Game.offer_duel(["pepik"], 0, "looks"):
			tp_offered = true
			break
	check(tp_offered and Game.duel.rival == "pepik", "a beaten rival asks for a rematch")
	await close_popups()
	hud.open_club("Shows")
	await wait(0.4)
	await shot("duel_card")
	await close_popups()
	var tp_duels: int = Game.stats.get("duels", 0)
	hud._enter_special("duel", 0, "looks")
	var tp_ring = hud.club_panel
	for i in 160:
		await wait(0.1)
		if tp_ring._button.text == "Continue":
			break
	await shot("duel_result")
	check(Game.stats.get("duels", 0) == tp_duels + 1 and Game.duel.is_empty() and tp_ring._rivals.size() == 1, "a duel: one rival, one result")
	await close_popups()

	# The Bunny Games: qualify, then four rounds, one a day
	Game.debug_date = "06-25"
	Game.games = {}
	Game._check_league()
	Game.league_points = 0
	check(Game.games_on() and Game.games_problem("looks").begins_with("Qualifying"), "the Games are on, but you need to qualify")
	Game.league_points = Catalog.GAMES_QUALIFY
	hud.open_club("League")
	await wait(0.4)
	for tp_sc in hud._modal.find_children("*", "ScrollContainer", true, false):
		tp_sc.scroll_vertical = 100000
	await wait(0.2)
	await shot("games_panel")
	await close_popups()
	hud._enter_special("games", 2, "looks")
	tp_ring = hud.club_panel
	for i in 200:
		await wait(0.1)
		if tp_ring._button.text == "Continue":
			break
	await shot("games_round")
	check(Game.games.rounds.has("looks") and Game.games_problem("tricks").begins_with("One round"), "a round of the Games, then one a day")
	await close_popups()
	var tp_hist: int = Game.games_history.size()
	var tp_apples: int = Game.inventory.get("best_apples", 0)
	for cat in ["tricks", "agility", "photo"]:
		Game.games.last_day = ""
		Game.games_round(cat, 95.0)
	await wait(0.3)
	check(Game.games.done and Game.games_history.size() == tp_hist + 1, "all four rounds: the final standings (%s.)" % Game.games_history[-1].place)
	check(Game.inventory.get("best_apples", 0) - tp_apples == (Catalog.GAMES_APPLES if Game.games_history[-1].place == 1 else 0),
		"a Games win brings the special dried apples, and only a win")
	if Game.games_history[-1].place == 1:
		check("best_apples" in Game.treats_in_inventory(), "the special dried apples are with the treats")
	await shot("games_result")
	await close_popups()
	# a month's Games left half-done are scored when the month turns, and the next month has its own
	Game.debug_date = "07-27"
	Game.league_points = Catalog.GAMES_QUALIFY
	check(Game.games_on() and Game.games_problem("looks") == "" and not Game.games.done, "next month: new Games")
	Game.games_round("looks", 90.0)
	tp_hist = Game.games_history.size()
	Game.debug_date = "08-02"
	Game._check_games()
	await wait(0.3)
	check(Game.games_history.size() == tp_hist + 1 and Game.games_history[-1].month.ends_with("-07") and not Game.games_on(),
		"an unfinished Games is scored when the month ends")
	await close_popups()
	Game.debug_date = ""

	# Challenge weeks
	Game.challenge = {}
	Game.challenge_week = -1
	check(Game.challenge_offers().size() == 2 and Game.challenge_offers()[0] != Game.challenge_offers()[1], "two challenges to pick from each week")
	Game.start_challenge("no_sweets")
	check(Game.challenge_offers().is_empty(), "one challenge a week")
	Game.challenge_event("treat", "parsley")
	check(not Game.challenge.is_empty(), "parsley is fine in a no sweets week")
	Game.challenge_event("treat", "carrot")
	await wait(0.2)
	check(Game.challenge.is_empty() and not Game.challenge_last.ok, "a carrot ends the no sweets week")
	Game.start_challenge("budget")
	check(is_equal_approx(Game.work_pay_mult(), (1.0 + 0.15 * Game.career_level() + 0.25 * Game.tier("monitor") + 0.25 * Game.tier("headphones")) * 0.5), "budget week: work pays half")
	Game.challenge.start = Time.get_unix_time_from_system() - 8 * 86400.0
	tp_coins = Game.coins
	Game._check_challenge()
	check(Game.challenge_last.ok and Game.coins == tp_coins + Catalog.CHALLENGES.budget.reward, "made it through the week: the reward")
	Game.challenge_week = -1
	Game.start_challenge("showtime")
	hud._journal_tab = "Goals"
	hud.open_journal()
	await wait(0.4)
	await shot("journal_challenge_ladder")
	await close_popups()
	Game.challenge = {}

	# The seasonal ladder: ten steps, then the season's decoration
	Game.ladder = {}
	var tp_gift: String = Catalog.LADDERS[Game.season()].gift
	var tp_had: int = Game.count_item(tp_gift)
	for i in 10:
		var st := Game.ladder_step()
		Game.stats[st.stat] = int(Game.stats.get(st.stat, 0)) + st.n
		Game._check_ladder()
	await wait(0.3)
	check(Game.ladder_step().is_empty() and Game.count_item(tp_gift) == mini(tp_had + 1, 1), "ten steps up the ladder: %s" % tp_gift)
	await close_popups()

	# The advent calendar
	Game.debug_date = "12-05"
	Game.advent = {}
	main.update_special_day()
	await wait(0.3)
	check(main.advent_cal != null, "December: an advent calendar on the wall")
	await close_popups()
	main._use_item(main.advent_cal)
	await wait(0.3)
	await shot("advent")
	tp_coins = Game.coins
	var tp_door := Game.open_advent()
	check(tp_door.day == 5 and Game.coins >= tp_coins and Game.open_advent().is_empty(), "today's door opens once")
	await close_popups()
	Game.advent.opened = range(1, 24)
	Game.debug_date = "12-24"
	var tp_last := Game.open_advent()
	check(tp_last.gift == "santa_hat" and tp_last.all and "santa_hat" in Game.wardrobe and Game.count_item("snow_globe") == 1,
		"the 24th door: a Santa hat, and a snow globe for opening them all")
	Game.debug_date = ""
	main.update_special_day()
	await close_popups()

	# Bubák's book
	Game.book_written = []
	Game.book_published = false
	Game.write_chapter("meet")
	hud.open_book(0)
	await wait(0.3)
	await shot("book_page")
	await close_popups()
	check(Game.publish_book() != "" and not Game.merch_unlocked("book"), "the book needs every chapter first")
	Game.book_written = Catalog.BOOK.map(func(c): return c.id)
	Game.coins += Catalog.BOOK_COST
	var tp_fans: int = Game.followers
	check(Game.publish_book() == "" and Game.book_published and Game.merch_unlocked("book") and Game.followers == tp_fans + Catalog.BOOK_FANS
		and Game.count_item("bubak_book") == 1, "publishing the book: fans, merch and a copy for the flat")
	await close_popups()

	# ---- the friend does it all too --------------------------------------------------------
	# Bubák's friend trains, grooms, shows, runs agility, walks and grows a personality of their own
	await close_popups()
	var fr: Pet = Game.mate
	check(fr != null and Game.performer == Game.bubak, "a friend at home, and Bubák performs by default")
	fr.trust = 62.0
	fr.settle_level()
	var fr_b_stars: int = Game.trick_stars_total()
	var fr_b_coat: float = Game.coat
	var fr_b_nails: float = Game.nails
	var fr_b_agility: float = Game.agility
	var fr_b_traits: Dictionary = Game.traits.duplicate()
	hud._club_pet = null
	hud.open_club("Training")
	await wait(0.3)
	var fr_pick: Array = _buttons(fr.display_name())
	check(fr_pick.size() == 1, "the club has a button for the friend")
	if fr_pick.size() == 1:
		fr_pick[0].pressed.emit()
		await wait(0.3)
	var fr_stage: StageBunny = hud.club_panel._stage
	check(Game.performer == fr and Game.trick_stars_total() == 0 and fr_stage.body.texture == Catalog.tex("bunny_%s_body_%s" % [fr_stage.pose, fr.id]),
		"the friend's turn: no tricks yet, and the friend on the stage (%s, %d stars)" % [Game.performer.id, Game.trick_stars_total()])
	await shot("club_friend_training")
	Game.focus = float(Game.focus_max())
	for i in 20:
		if Game.trick_stars("come") >= 2:
			break
		Game.train("come", "good")
	check(Game.trick_stars("come") >= 2 and Game.trick_stars("come", fr) == Game.trick_stars("come"),
		"the friend learns a trick (%d stars)" % Game.trick_stars("come"))
	check(Game.for_pet(Game.bubak, Game.trick_stars_total) == fr_b_stars, "Bubák's own tricks stay as they were")
	var fr_d := Game.to_dict()
	check(int(fr_d.mate_skills.tricks.size()) > 0 and absf(float(fr_d.coat) - fr_b_coat) < 1.0, "saving mid-session keeps each rabbit's skills apart (%s, %s / %s)" % [
		fr_d.mate_skills.tricks, fr_d.coat, fr_b_coat])
	# grooming
	hud._club_tab = "Grooming"
	hud.open_club()
	await wait(0.3)
	check(Game.performer == fr, "the club remembers who was picked")
	await shot("club_friend_grooming")
	Game.coat = 30.0
	Game.nails = 80.0
	Game.finish_grooming(40.0)
	check(Game.trim_nails() == "" and Game.nails < 0.5 and absf(Game.coat - 70.0) < 1.0, "the friend gets brushed and the nails trimmed")
	check(absf(float(Game.skill(Game.bubak, "coat")) - fr_b_coat) < 1.0 and absf(float(Game.skill(Game.bubak, "nails")) - fr_b_nails) < 1.0,
		"Bubák's coat and nails are his own (%s/%s, %s/%s)" % [Game.skill(Game.bubak, "coat"), fr_b_coat, Game.skill(Game.bubak, "nails"), fr_b_nails])
	# agility
	var fr_ag: float = Game.practice_agility(6)
	check(fr_ag > 0.0 and is_equal_approx(float(Game.skill(Game.bubak, "agility")), fr_b_agility), "agility practice for the friend only")
	check(Game.trait_points("athlete") > 0.0 and Game.skill(Game.bubak, "traits").get("athlete", 0.0) == fr_b_traits.get("athlete", 0.0),
		"the friend's personality grows from it, not Bubák's")
	# a show: the friend's name in the ring, the ribbon is the friend's, and the wait is the friend's
	Game.coins += 500
	var fr_trophies: int = Game.trophies.size()
	hud._enter_show(0, "looks")
	var fr_ring = hud.club_panel
	await wait(0.4)
	var fr_ring_text := str(hud._modal.find_children("*", "Label", true, false).map(func(l): return l.text))
	check(fr.display_name() in fr_ring_text and not "Bubák" in fr_ring_text, "the friend's name at the judges' table (%s)" % fr_ring_text.left(300))
	await shot("show_friend")
	for i in 200:
		await wait(0.1)
		if fr_ring._button.text == "Continue":
			break
	check(Game.show_wait(0) > 0 and Game.for_pet(Game.bubak, func(): return Game.show_wait(0)) <= 0,
		"the friend's show wait doesn't hold Bubák back")
	if Game.trophies.size() > fr_trophies:
		check(Game.trophies[-1].get("pet", "") == fr.id, "the friend's ribbon is marked as the friend's")
	await close_popups()
	check(Game.performer == Game.bubak, "closing the club brings Bubák back")
	# traits from the room, while Bubák performs
	var fr_told: int = int(Game.skill(fr, "trait_told").get("explorer", 0))
	Game.add_trait("explorer", 200.0, fr)
	check(Game.trait_level("explorer", fr) > fr_told and Game.trait_level("explorer", fr) >= 1, "the friend's personality grows at home too")
	await close_popups()
	# a walk with the friend
	Game.walk_day = "2000-01-01"
	hud.open_walks()
	await wait(0.3)
	check(Game.performer == fr and _buttons("Go!").size() > 0, "walks: the friend picked last time goes")
	await shot("walks_friend")
	var fr_wt: float = fr.trust
	var fr_btrust: float = Game.trust
	hud.close_top()
	hud.play_walk("park", true, 6.0, fr)
	await wait(1.0)
	check(Game.performer == fr and hud.find_children("*", "WalkScene", true, false).size() == 1, "the friend on the walk")
	await shot("walk_friend")
	for i in 200:
		if hud.find_children("*", "WalkScene", true, false).is_empty():
			break
		await wait(0.1)
	check(Game.performer == Game.bubak and str(Game.skill(fr, "walk_day")) == Time.get_date_string_from_system() and Game.walk_day == "2000-01-01",
		"the friend's walk counts for the friend")
	check(fr.trust > fr_wt and is_equal_approx(Game.trust, fr_btrust), "the walk builds the friend's trust")
	await close_popups()
	# the friend's page in the journal
	hud._journal_tab = "Friend"
	hud.open_journal()
	await wait(0.3)
	var fr_jt := str(hud._modal.find_children("*", "Label", true, false).map(func(l): return l.text))
	check(tr("Trick stars: %d of %d") % [Game.for_pet(fr, Game.trick_stars_total), Catalog.TRICKS.size() * 3] in fr_jt and tr("Personality") in fr_jt,
		"the friend's page shows their tricks and personality")
	await shot("journal_friend_club")
	await close_popups()
	# goals count whoever does better, and everything is saved
	check(Game.goal_value({"type": "stars"}) >= Game.for_pet(fr, Game.trick_stars_total), "goals count the friend's stars too")
	var fr_stars: int = Game.for_pet(fr, Game.trick_stars_total)
	await reload_scene()
	hud = main.hud
	b = main.bunny
	fr = Game.mate
	check(Game.for_pet(fr, Game.trick_stars_total) == fr_stars and float(Game.skill(fr, "coat")) > 60.0
		and Game.trait_level("explorer", fr) >= 1 and Game.for_pet(Game.bubak, Game.trick_stars_total) == fr_b_stars,
		"after loading: each rabbit's skills are still their own")
	# the friend's personality shows in the room: a show-off poses for the camera
	Game.add_trait("showoff", 500.0, fr)
	Game.add_trait("cuddler", 450.0, fr)
	var fr_mb = main.mate_bunny
	fr_mb.teleport(Vector2(760, 610))
	fr_mb.start("idle", null, fr_mb.position)
	await wait(0.1)
	main.set_mode("photo")
	for i in 10:   # 6 times in 10 they strike a pose
		if fr_mb.act == "pose":
			break
		fr_mb.start("idle", null, fr_mb.position)
		await wait(0.05)
		fr_mb.on_camera()
	await wait(0.1)
	check(Game.trait_level("showoff", fr) >= 3 and fr_mb.act == "pose", "the friend, a little star now, poses for the camera (%s)" % fr_mb.act)
	main.set_mode("")
	await close_popups()

	# Journal screens in Czech
	_lang("cs")
	hud = main.hud
	for nw_tab in ["Goals", "Album", "Bubák", "Friend"]:
		hud._journal_tab = nw_tab
		hud.open_journal()
		await wait(0.4)
		await shot("cs_journal_" + nw_tab.to_lower())
		for nw_sc in hud._modal.find_children("*", "ScrollContainer", true, false):
			nw_sc.scroll_vertical = 100000
		await wait(0.2)
		await shot("cs_journal_" + nw_tab.to_lower() + "_end")
		await close_popups()
	hud._postcard_popup(Game.postcards[0])
	await wait(0.3)
	await shot("cs_postcard")
	await close_popups()
	hud.kid_popup("Ema")
	await wait(0.3)
	await shot("cs_kid")
	await close_popups()
	_lang("en")
	hud = main.hud
	hud._journal_tab = "Goals"

	# the late-game screens in Czech (longer words: do they fit?)
	_lang("cs")
	hud = main.hud
	for lt_tab in ["Shows", "Agility", "League"]:
		hud.open_club(lt_tab)
		await wait(0.4)
		await shot("cs_club_" + lt_tab.to_lower())
		await close_popups()
	hud.open_merch()
	await wait(0.4)
	await shot("cs_merch")
	await close_popups()
	Game.foster_next = ""
	Game.foster_offer_day = ""
	hud._foster_offer_popup(Game.next_foster())
	await wait(0.4)
	await shot("cs_foster_offer")
	await close_popups()
	_lang("en")
	hud = main.hud

	Game.new_game()
	check(Game.club_stage == 0 and Game.trophies.is_empty() and Game.coins == 40 and Game.mate == null, "start a new game")
	await reload_scene()
	hud = main.hud
	b = main.bunny
	check(main.bunnies.size() == 1, "new game: just Bubák")
	await close_popups()

	# Test play: a sandbox with everything unlocked; the real game is kept
	Game.coins = 77
	Game.start_test_play()
	await reload_scene()
	hud = main.hud
	b = main.bunny
	check(Game.test_mode and Game.coins >= 10000 and Game.club_stage == 3 and Game.mate_stage == 1 and Game.balcony == "open",
		"test play: everything unlocked, 10000 coins")
	check(Game.lock_reason("castle") == "" and Game.show_unlocked(2) and Game.show_wait(0) == 0, "test play: no level requirements or waits")
	hud.open_settings()
	await wait(0.3)
	await shot("testplay_settings")
	hud.close_top()
	await shot("testplay_room")
	Game.end_test_play()
	await reload_scene()
	hud = main.hud
	b = main.bunny
	check(not Game.test_mode and Game.coins == 77 and Game.save_path == "user://autotest_save.json", "back to the real game, untouched")

	# Sounds: every sound the game asks for exists, the music loops, and playtests stay silent
	var wanted: Array = ["tap", "notify", "coin", "buy", "shutter", "fanfare", "pellets", "hay", "water", "scrape",
		"pluck", "drip", "seeds", "chime", "chirp", "door", "ball", "purr", "good", "bad", "streak", "star", "music"]
	wanted.append_array(main.FX_SOUND.values())
	wanted.append_array(b.ACT_SOUND.values())
	var missing_snd := wanted.filter(func(n): return Sfx._stream(n) == null)
	check(missing_snd.is_empty(), "all sounds load (missing: %s)" % [missing_snd])
	check((Sfx._stream("music") as AudioStreamOggVorbis).get_length() > 30.0, "music loop loads")
	check(Sfx.muted and not Sfx._music.playing, "playtest runs silently")

	# Time away: with "Time stops", nothing changes while the game is closed
	Game.life_goes_on = false
	var food_before: float = Game.needs.food
	var bowl_before: int = Game.bowl
	var groom_before: float = Game.groom_start
	Game.show_ready_at["1"] = Time.get_unix_time_from_system() + 600
	Game._time_away(3 * 3600)
	check(is_equal_approx(Game.needs.food, food_before) and Game.bowl == bowl_before
		and is_equal_approx(Game.groom_start, groom_before + 3 * 3600) and Game.show_wait(1) > 3 * 3600,
		"time stops: needs, bowls and waits frozen while away")
	Game.welcome_text = ""
	hud.open_settings()
	await shot("settings_away")
	hud.close_top()
	Game.life_goes_on = true
	Game.bowl = 3
	Game._time_away(3 * 3600)
	check(Game.bowl < 3 and Game.welcome_text != "", "life goes on: he ate while away")
	Game.welcome_text = ""

	# Let him live a while to shake out runtime errors in the AI
	b.start("idle", null, Vector2(640, 600))
	await wait(15.0)
	await shot("free_play")
	print("AUTOTEST done, %d failure(s)" % failures)
	get_tree().quit(1 if failures else 0)
