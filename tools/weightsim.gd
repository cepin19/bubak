extends Node
## Developer tool: plays the game sped up and logs Bubák's weight, to tune the numbers in Catalog.
##   godot --path . -- --weightsim=MODE[:HOURS]
## MODE: normal (furnished flat), bare (no toys), treats (furnished, a treat every 3 minutes),
## treats_bare, sweets_bare (dried apple rings every 3 minutes, no toys), late (a soak test of the
## late game: top trust, a friend and a foster bunny, the balcony, merch on sale). Bowls are kept full.

const SPEED := 100.0
var mode := "normal"
var hours := 8.0
var _t := 0.0
var _logged := 0
var _treat_t := 0.0


func _ready() -> void:
	var a: String = get_meta("arg")
	mode = a.get_slice(":", 0)
	if a.contains(":"):
		hours = float(a.get_slice(":", 1))
	Sfx.muted = true
	await get_tree().process_frame
	var main := get_parent()
	main.hud.close_top()
	Game.trust = 70.0
	Game.coins = 20000
	if not mode.ends_with("bare"):
		for id in ["ball", "tunnel", "castle", "digbox", "puzzle", "hurdles", "treat_ball", "rug"]:
			Game.buy(id)
	if mode == "late":
		Game.bubak.trust = 99.95
		Game.bubak.settle_level()
		Game.balcony = "open"
		Game.club_stage = 3
		for t in Catalog.TRICK_ORDER:
			Game.tricks[t] = Catalog.TRICK_STARS[-1]
		Game.mate_stage = 1
		Game.adopt("hazel")
		Game.mate.trust = 80.0
		Game.take_foster()
		for id in ["parasol", "lookout", "bird_feeder", "grass_tray", "cool_tile", "veg_patch"]:
			Game.buy(id)
		main.mate_bunny = main._add_bunny(Game.mate, Vector2(500, 630))
		main.bunny.partner = main.mate_bunny
		main.mate_bunny.partner = main.bunny
		main.foster_bunny = main._add_bunny(Game.foster, Vector2(860, 640))
		Game.followers = 20000
		Game.fame = 2
		Game.merch_of("stickers").merge({"stock": 500, "photo": "x", "likes": 300, "design_at": Time.get_unix_time_from_system()}, true)
	Engine.time_scale = SPEED
	print("weightsim %s: %d h at %dx" % [mode, hours, SPEED])


func _process(delta: float) -> void:
	var game_dt := delta   # delta is already scaled by Engine.time_scale
	_t += game_dt
	Game.bowl = 3
	Game.hay = 100.0
	Game.water = 100.0
	Game.litter = 0.0
	if mode.begins_with("treats") or mode.begins_with("sweets"):
		_treat_t += game_dt
		if _treat_t > 180.0:
			_treat_t = 0.0
			var info: Dictionary = Catalog.ITEMS["dried_apple" if mode.begins_with("sweets") else "carrot"]
			Game.bubak.add_need("food", info.food)
			Game.bubak.sugar += info.sugar
			Game.bubak.gain(info.sugar * Catalog.SUGAR_GRAMS)
	if _t >= (_logged + 1) * 3600.0:
		_logged += 1
		var p: Pet = Game.bubak
		print("  hour %2d: %.0f g (%s), food %.0f, mood %.0f" % [_logged, p.weight, Catalog.weight_name(p.weight_band()),
			p.needs.food, p.mood()])
		if mode == "late":
			print("           seen %d, foster trust %.1f, merch sold %d (%.0f coins waiting), bond %.0f" % [Game.seen.size(),
				Game.foster.trust if Game.foster else -1.0, Game.merch_of("stickers").sold, Game.merch_pending, Game.bond])
		if _logged >= hours:
			get_tree().quit()
