extends Node
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
	await RenderingServer.frame_post_draw
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


## Reloads the game scene (as loading a save does) without losing the test, which lives in it.
func reload_scene() -> void:
	reparent(get_tree().root)
	main.reload()
	await wait(0.6)
	main = get_tree().current_scene
	await close_popups()


func bunny_center() -> Vector2:
	return main.bunny.position + Vector2(0, -40)


func _run() -> void:
	var b = main.bunny
	await wait(0.5)
	main.hud.close_top()
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
	check(Game.seeds < 100.0 and main.fx.get_child_count() > fx_before, "a bird comes to the feeder")
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
	var trust_before: float = Game.trust
	press(bunny_center(), true)
	await wait(2.0)
	check(b.act == "petted", "holding on bunny starts petting (act=%s)" % b.act)
	await shot("petting")
	press(bunny_center(), false)
	await wait(0.2)
	check(Game.stats.pets == pets + 1, "petting session counted")
	check(Game.trust > trust_before, "petting raised trust")

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
				for node in g.get_children():
					if node is TextureButton and not node.get_meta("lady", false) and not node.get_meta("hit", false) \
							and node.texture_normal != Catalog.icon("paw"):
						node.pressed.emit()
						break
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

	# Save / load round trip
	Game.save_game()
	var coins_saved := Game.coins
	Game.coins = 0
	Game.load_game()
	check(Game.coins == coins_saved, "save/load round trip")

	# Czech translation, switched in Settings
	Game.set_language("cs")
	main.apply_language()
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
	Game.set_language("en")
	main.apply_language()
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
	await tap(main.shelf.position + Vector2(0, -10))
	await wait(0.3)
	check(hud._modal != null and hud._club_tab == "Trophies", "tapping the shelf opens the trophies")
	await shot("club_trophies")
	hud.close_top()

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
	var mate_trust: float = Game.mate.trust
	var bubak_trust: float = Game.trust
	var mp: Vector2 = mb.position + Vector2(0, -40)
	press(mp, true)
	await wait(2.5)
	press(mp, false)
	await wait(0.2)
	check(Game.mate.trust > mate_trust + 0.2 and Game.trust - bubak_trust < 0.2, "petting the friend raises the friend's trust (%.1f -> %.1f)" % [mate_trust, Game.mate.trust])
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
