extends Node
## Developer tool: plays the game sped up and logs Bubák's weight, to tune the numbers in Catalog.
##   godot --path . -- --weightsim=MODE[:HOURS]
## MODE: normal (furnished flat), bare (no toys), treats (furnished, a treat every 3 minutes),
## treats_bare, sweets_bare (dried apple rings every 3 minutes, no toys). Bowls are kept full.

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
		if _logged >= hours:
			get_tree().quit()
