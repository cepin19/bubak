extends Node2D
## Bubák: decides what to do from his needs, trust and mood, hops around and
## reacts to the player. Position is the point between his feet on the floor.

signal message(text: String)
signal cable_alert(active: bool)

const HOP_TIME := 0.34
const AIR_PART := 0.72        # share of a hop cycle spent in the air
## Activities that make him sparkle: the rare, valuable photo moments.
const RARE := ["binky", "zoomies", "flop", "bonk", "beg", "bowl_flip", "show_off", "snuggle"]
const BEHAVIOUR_OF := {
	"idle": "idle", "wander": "hop", "eat_bowl": "nom", "eat_hay": "munch", "drink": "drink",
	"potty": "potty", "loaf": "loaf", "groom": "groom", "play_ball": "ball", "hide_box": "hide",
	"tunnel": "tunnel", "chew_toy": "chew", "chew_cable": "chew_cable", "chin": "chin",
	"binky": "binky", "zoomies": "zoomies", "flop": "flop", "beg": "beg", "bowl_flip": "bowl_flip",
	"bonk": "bonk", "thump": "thump", "eat_hand": "treat", "come": "idle", "petted": "loaf",
	"held": "selfie", "door": "hop", "sunbathe": "sunbathe", "bird_watch": "bird_watch",
	"herb_thief": "herb_thief", "dig": "dig", "forage": "forage", "castle": "castle",
	"show_off": "show_off", "snuggle": "snuggle",
}
## What the other bunny can be doing and still be up for a snuggle.
const SNUGGLY := ["idle", "loaf", "groom", "sunbathe", "snuggle"]

## Head centre (x, y) and rotation (degrees) in each pose's sprite, matching tools/gen_art.py.
const HEADS := {"sit": [146, 92, 0], "blink": [146, 92, 0], "hop": [156, 88, -10], "loaf": [148, 132, 4],
	"sleep": [148, 132, 4], "eat": [150, 134, 24], "flop": [160, 160, 30], "stand": [124, 58, -6]}
## Angle of the perky ear in each pose (it is a separate sprite so it can twitch).
const EAR_ANGLE := {"sit": -12, "blink": -12, "hop": -35, "loaf": -48, "sleep": -48, "eat": -28,
	"flop": -100, "stand": 4}
## Where each accessory sits relative to the head, and the sprite's own offset.
const WEAR_ANCHOR := {"bow": [Vector2(-18, -30), Vector2.ZERO], "glasses": [Vector2(14, -4), Vector2(-13, 0)],
	"crown": [Vector2(-2, -32), Vector2(0, -10)], "tophat": [Vector2(4, -36), Vector2(0, -24)]}

var room: Node   # main.gd: finds items, spawns effects, tells the time
var pet: Pet = Game.bubak   # whose needs and trust this bunny lives by
var partner: Node2D = null  # the other bunny, once Bubák has a friend
var wear_sprite: Sprite2D
var ear: Sprite2D
var nose: Sprite2D
var ear_extra := 0.0       # twitches and perks, added to the pose's ear angle
var _ear_base := 0.0
var _ear_rest := 0.0
var _ear_t := 3.0
var _nose_t := 1.0
var _breath := 0.0
var _was_airborne := false
var _wear_shown := ""
var pivot: Node2D
var body: Sprite2D

var facing := 1.0
var pose := ""
var lift := 0.0
var air := 0.0
var squash := Vector2.ONE
var twist := 0.0
var hidden_inside := false
var rare := false

var act := "idle"
var phase := 1             # 0 = travelling to target, 1 = performing
var act_t := 2.0
var target := Vector2.ZERO
var item: Node2D = null
var data := {}
var speed := 150.0
var hop_phase := 0.0
var petting := false
var room_id := "living"    # "living" or "balcony"
var _outside_since := 0.0
var _visit_length := 120.0

var _tw: Tween
var _fx_t := 0.0
var _blink_t := 3.0
var _taps: Array = []
var _pet_time := 0.0
var _pet_fatigue := 0.0
var _hearts_t := 0.0


func _ready() -> void:
	pivot = Node2D.new()
	add_child(pivot)
	body = Sprite2D.new()
	body.centered = false
	pivot.add_child(body)
	nose = Sprite2D.new()
	nose.texture = Catalog.tex("bunny_nose")
	nose.centered = false
	nose.offset = Vector2(-9.5, -10)
	pivot.add_child(nose)
	ear = Sprite2D.new()
	ear.texture = Catalog.tex("bunny_ear" + pet.skin())
	ear.centered = false
	ear.offset = Vector2(-30, -104)
	pivot.add_child(ear)
	wear_sprite = Sprite2D.new()
	pivot.add_child(wear_sprite)
	_set_pose("sit")


func _set_pose(p: String) -> void:
	if p == pose:
		return
	pose = p
	body.texture = Catalog.tex("bunny_" + p + "_body" + pet.skin())
	body.offset = Vector2(-100, -194)
	var h: Array = HEADS[p]
	var rot := deg_to_rad(h[2])
	var c := Vector2(h[0], h[1]) - Vector2(100, 194)
	ear.position = c + Vector2(-8, -26).rotated(rot)
	_ear_base = deg_to_rad(h[2] + EAR_ANGLE[p])
	nose.position = c + Vector2(40.5, 6).rotated(rot)
	nose.rotation = rot
	_place_wear()


## [point in the pose's sprite, rotation, sprite offset] for an accessory.
static func wear_transform(p: String, wear: String) -> Array:
	var h: Array = HEADS[p]
	var rot := deg_to_rad(h[2])
	var a: Array = WEAR_ANCHOR[wear]
	return [Vector2(h[0], h[1]) + (a[0] as Vector2).rotated(rot), rot, a[1]]


## Only Bubák dresses up.
func _wearing() -> String:
	return Game.wearing if pet.is_bubak() else ""


func _place_wear() -> void:
	_wear_shown = _wearing()
	wear_sprite.visible = _wear_shown != ""
	if _wear_shown == "":
		return
	var t := wear_transform(pose, _wear_shown)
	wear_sprite.texture = Catalog.tex(Catalog.ITEMS[_wear_shown].tex)
	wear_sprite.position = t[0] - Vector2(100, 194)
	wear_sprite.rotation = t[1]
	wear_sprite.offset = t[2]


func scale_factor() -> float:
	var t := clampf((position.y - Game.FLOOR.position.y) / Game.FLOOR.size.y, 0, 1)
	return lerpf(0.6, 0.74, t)


func head_pos() -> Vector2:
	var s := scale_factor()
	return position + Vector2(facing * 45 * s, -150 * s - lift - air)


# ---- main loop --------------------------------------------------------------

func _process(delta: float) -> void:
	_pet_fatigue = maxf(0, _pet_fatigue - delta * 0.04)
	if phase == 0:
		_travel(delta)
	else:
		_perform(delta)
	_update_visual(delta)


func _travel(delta: float) -> void:
	var to := target - position
	var hop_time := HOP_TIME * (0.6 if speed > 250 else 1.0)
	hop_phase = fmod(hop_phase + delta / hop_time, 1.0)
	if hop_phase < AIR_PART:
		var step := speed * delta / AIR_PART
		if absf(to.x) > 2:
			facing = signf(to.x)
		_set_pose("hop")
		air = sin(hop_phase / AIR_PART * PI) * (26.0 if speed > 250 else 18.0)
		_was_airborne = true
		if to.length() <= step:
			position = target
			air = 0
			_arrive()
		else:
			position += to.normalized() * step
	else:
		air = 0
		_set_pose("sit")
		if _was_airborne:   # just landed: little puffs of dust
			_was_airborne = false
			room.spawn_fx("dust", position + Vector2(-facing * 22, -2))
			if speed > 250:
				room.spawn_fx("dust", position + Vector2(facing * 14, -2))


func _arrive() -> void:
	if act == "zoomies" and data.get("laps", 0) > 0:
		data.laps -= 1
		target = _random_point()
		return
	if act == "play_ball" and data.get("chasing", false):
		data.chasing = false
	phase = 1
	_begin()


func _perform(delta: float) -> void:
	act_t -= delta
	match act:
		"sleep":
			pet.asleep = true
			_fx_t -= delta
			if _fx_t <= 0:
				_fx_t = 1.6
				emote("z")
			if pet.energy >= 98:
				act_t = 0
		"chew_cable":
			data.chew = data.get("chew", 0.0) + delta
			if data.chew > 9.0 and Game.cable == "ok":
				Game.cable = "chewed"
				Game.add_coins(-25)
				Game.discover("chew_cable")
				message.emit(tr("The laptop charger is chewed through! Culprit: %s. A new one cost 25 coins.\nA cable cover from the shop would stop this for good.") % pet.display_name())
				act_t = 0
		"eat_bowl", "eat_hay", "chew_toy", "eat_hand", "drink", "forage":
			body.position.y = absf(sin(act_t * 14.0)) * 2.5
		"dig":
			body.position.y = absf(sin(act_t * 22.0)) * 4.0
			_fx_t -= delta
			if _fx_t <= 0:
				_fx_t = 0.15
				room.spawn_fx("dirt", position + Vector2(-facing * 20, -10))
		"petted":
			pass
	if rare:
		_fx_t -= delta
		if _fx_t <= 0:
			_fx_t = 0.28
			room.spawn_fx("star", position + Vector2(randf_range(-60, 60), randf_range(-110, -10)))
	if act_t <= 0:
		_finish()


func _update_visual(delta: float) -> void:
	var s := scale_factor()
	# gentle breathing while on the ground; slow and deep when asleep
	_breath += delta * (1.3 if pose == "sleep" else 2.4)
	var b := 0.0 if air > 0.5 else sin(_breath) * (0.022 if pose == "sleep" else 0.012)
	pivot.position = Vector2(0, -air - lift)
	pivot.scale = Vector2(facing * s * squash.x * (1.0 - b * 0.5), s * squash.y * (1.0 + b))
	_animate_face(delta)
	pivot.rotation = twist
	visible = not hidden_inside
	if _wear_shown != _wearing():
		_place_wear()
	if pose == "sit" or pose == "blink":
		_blink_t -= delta
		if _blink_t <= 0:
			if pose == "sit":
				_set_pose("blink")
				_blink_t = 0.14
			else:
				_set_pose("sit")
				_blink_t = randf_range(2.0, 5.0)
	queue_redraw()


func _draw() -> void:
	var s := scale_factor()
	var r := 62.0 * s * (1.0 - clampf(air / 120.0, 0, 0.5))
	draw_texture_rect(Catalog.soft_circle(), Rect2(6 - r, -3 - r * 0.28, r * 2, r * 0.56), false,
		Color(0.28, 0.16, 0.1, 0.4 * (1.0 - clampf(air / 160.0, 0, 0.6))))


## Ear twitches and perks, nose wiggles: small things that make him feel alive.
func _animate_face(delta: float) -> void:
	var asleep := pose in ["sleep", "flop"]
	_ear_rest = lerpf(_ear_rest, 0.4 if act == "petted" else 0.0, delta * 3.0)   # ears relax when petted
	ear.rotation = _ear_base + ear_extra + _ear_rest
	_ear_t -= delta
	if _ear_t <= 0:
		_ear_t = randf_range(2.5, 6.0)
		if not asleep:
			var t := create_tween()
			t.tween_property(self, "ear_extra", -0.22, 0.06)
			t.tween_property(self, "ear_extra", 0.08, 0.08)
			t.tween_property(self, "ear_extra", 0.0, 0.12)
	_nose_t -= delta
	if _nose_t <= 0:
		_nose_t = randf_range(1.2, 3.5)
		if not asleep:
			var t := create_tween().set_loops(3)
			t.tween_property(nose, "scale", Vector2(1.25, 0.82), 0.05)
			t.tween_property(nose, "scale", Vector2.ONE, 0.06)


func perk_ears() -> void:
	var t := create_tween()
	t.tween_property(self, "ear_extra", -0.4, 0.08)
	t.tween_interval(0.6)
	t.tween_property(self, "ear_extra", 0.0, 0.3)


# ---- activities -------------------------------------------------------------

func start(name: String, it: Node2D = null, at = null) -> void:
	_end_current()
	act = name
	item = it
	data = {}
	speed = 150.0
	var dest: Vector2 = position
	if at != null:
		dest = at
	elif it != null:
		dest = it.use_point(position)
	target = _clamp(dest)
	if position.distance_to(target) < 6:
		phase = 1
		_begin()
	else:
		phase = 0
		hop_phase = 0.0


func _begin() -> void:
	if act == "snuggle" and (item == null or item.position.distance_to(position) > 150 or not item.act in SNUGGLY):
		act = "idle"   # the other one wandered off
	var b: String = BEHAVIOUR_OF.get(act, "")
	if b != "" and b != "chew_cable":
		Game.discover(b)
	if act in RARE:
		rare = true
		_fx_t = 0
	match act:
		"idle", "come":
			act_t = randf_range(1.5, 3.5)
			_set_pose("sit")
			if act == "come":
				emote("?")
		"wander":
			act_t = randf_range(0.3, 1.2)
			_set_pose("sit")
		"eat_bowl", "eat_hay", "drink":
			var empty: bool = (act == "eat_bowl" and Game.bowl <= 0) or (act == "eat_hay" and Game.hay < 5) \
				or (act == "drink" and Game.water < 5)
			_face(item)
			if empty:
				data.fail = true
				act_t = 1.2
				_set_pose("sit")
				emote("?")
			else:
				act_t = {"eat_bowl": 5.0, "eat_hay": 6.0, "drink": 3.5}[act]
				_set_pose("eat")
		"potty":
			act_t = 3.0
			_set_pose("loaf")
		"floor_potty":
			act_t = 2.0
			_set_pose("loaf")
		"sleep":
			act_t = randf_range(150, 240)   # a proper nap: a few minutes, or until fully rested
			_set_pose("sleep")
			pet.asleep = true
			pet.in_bed = item != null
			if item:
				lift = 16
				Game.discover("sleep_bed")
			else:
				Game.discover("nap")
			_fx_t = 0.8
		"loaf", "petted":
			act_t = randf_range(6, 11)
			_set_pose("loaf")
		"groom":
			act_t = 4.0
			_set_pose("eat")
			_tw = create_tween().set_loops(6)
			_tw.tween_property(self, "twist", -0.12, 0.17)
			_tw.tween_property(self, "twist", 0.05, 0.17)
		"play_ball":
			act_t = 1.2
			_face(item)
			_set_pose("eat")
			_nudge_ball()
		"hide_box":
			act_t = randf_range(6, 10)
			hidden_inside = true
			item.wiggle(1.5)
		"tunnel":
			act_t = 1.1
			hidden_inside = true
			item.wiggle(0.6)
		"chew_toy":
			act_t = 5.0
			_face(item)
			_set_pose("eat")
		"chew_cable":
			act_t = 12.0
			_set_pose("eat")
			facing = 1.0
			cable_alert.emit(true)
		"chin":
			act_t = 2.4
			_face(item)
			_set_pose("eat")
			_tw = create_tween().set_loops(4)
			_tw.tween_property(self, "squash", Vector2(1.08, 0.94), 0.15)
			_tw.tween_property(self, "squash", Vector2.ONE, 0.15)
		"binky":
			act_t = 1.0
			_set_pose("hop")
			_tw = create_tween()
			_tw.tween_property(self, "air", 80.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_tw.parallel().tween_property(self, "twist", -0.55 * facing, 0.28)
			_tw.tween_callback(func(): facing = -facing)
			_tw.tween_property(self, "air", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_tw.parallel().tween_property(self, "twist", 0.0, 0.3)
			_tw.tween_callback(_set_pose.bind("sit"))
			_tw.tween_property(self, "squash", Vector2(1.2, 0.8), 0.07)
			_tw.tween_property(self, "squash", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)
			emote("heart")
		"zoomies":
			act_t = 0.8
			_set_pose("sit")
			_boing()
		"flop":
			act_t = randf_range(10, 16)
			_set_pose("loaf")
			_tw = create_tween()
			_tw.tween_interval(0.6)
			_tw.tween_property(self, "twist", 0.25 * facing, 0.15)
			_tw.tween_callback(_set_pose.bind("flop"))
			_tw.tween_property(self, "twist", 0.0, 0.12)
			_tw.tween_property(self, "squash", Vector2(1.15, 0.85), 0.08)
			_tw.tween_property(self, "squash", Vector2.ONE, 0.2)
		"beg":
			act_t = 3.5
			_set_pose("stand")
			facing = 1.0 if position.x < 640 else -1.0
			emote("heart")
		"bowl_flip":
			act_t = 2.0
			_face(item)
			_set_pose("eat")
			var t := create_tween()
			t.tween_interval(0.4)
			t.tween_property(item.sprite, "rotation", -0.7, 0.12)
			t.tween_property(item.sprite, "rotation", 0.0, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			emote("!")
		"bonk":
			act_t = 1.4
			_set_pose("sit")
			_tw = create_tween()
			_tw.tween_property(self, "squash", Vector2(1.3, 1.3), 0.12)
			_tw.tween_callback(emote_text.bind(tr("boop!")))
			_tw.tween_property(self, "squash", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			pet.add_trust(0.4)
		"thump":
			act_t = 0.9
			_set_pose("sit")
			_tw = create_tween().set_loops(2)
			_tw.tween_property(self, "squash", Vector2(1.12, 0.84), 0.09)
			_tw.tween_property(self, "squash", Vector2.ONE, 0.12)
			emote_text(tr("THUMP!"))
			room.shake()
		"flee":
			act_t = 0.3
			_set_pose("sit")
		"dig":
			act_t = 5.0
			_set_pose("eat")
			_fx_t = 0.0
		"forage":
			act_t = 6.0
			_face(item)
			_set_pose("eat")
			item.wiggle()
		"castle":
			act_t = randf_range(8, 14)
			lift = 118.0
			_set_pose("loaf" if randf() < 0.5 else "sit")
			emote("star")
		"door":
			act_t = 0.6
			hidden_inside = true
			item.wiggle()
		"sunbathe":
			act_t = randf_range(12, 20)
			_set_pose("flop" if pet.trust_level() >= 3 else "loaf")
			emote("heart")
		"bird_watch":
			act_t = 3.8
			_set_pose("stand")
			facing = 1.0
			room.spawn_bird()
			emote("!")
		"herb_thief":
			act_t = 5.0
			_face(item)
			_set_pose("eat")
		"snuggle":
			act_t = randf_range(10, 16)
			_face(item)
			_set_pose("loaf")
			emote("heart")
			item.join_snuggle(self, act_t)
			Game.bond = minf(100, Game.bond + 3)
		"show_off":   # a trick he's good at, unasked
			act_t = 1.8
			var known: Array = ["stand", "spin"].filter(func(id): return Game.trick_stars(id) >= 2)
			match (known + ["jump"]).pick_random():
				"stand":
					_set_pose("stand")
				"spin":
					_set_pose("hop")
					_tw = create_tween()
					_tw.tween_property(self, "air", 24.0, 0.12)
					for i in 4:
						_tw.tween_callback(func(): facing = -facing)
						_tw.tween_interval(0.1)
					_tw.tween_property(self, "air", 0.0, 0.12)
					_tw.tween_callback(_set_pose.bind("sit"))
				_:
					_set_pose("hop")
					_tw = create_tween()
					_tw.tween_property(self, "air", 60.0, 0.25).set_ease(Tween.EASE_OUT)
					_tw.tween_property(self, "air", 0.0, 0.25).set_ease(Tween.EASE_IN)
					_tw.tween_callback(_set_pose.bind("sit"))
			emote("star")
		"approach_hand":
			if not room.hand_active():
				act = "idle"
				act_t = 1.0
				emote("?")
				return
			_eat_from_hand()


func _finish() -> void:
	var done := act
	match done:
		"eat_bowl":
			if not data.get("fail", false):
				Game.bowl = maxi(0, Game.bowl - 1)
				pet.add_need("food", 28)
		"eat_hay":
			if not data.get("fail", false):
				Game.hay = maxf(0, Game.hay - [12, 10, 8][Game.tier("hayrack") - 1])
				pet.add_need("food", 12)
				pet.add_need("fun", 2)
		"drink":
			if not data.get("fail", false):
				Game.water = maxf(0, Game.water - 18 * [1.0, 0.7, 0.45][Game.tier("water") - 1])
				pet.add_need("water", 35)
				if Game.tier("water") >= 3:
					pet.add_need("fun", 3)   # the fountain is fun
		"potty":
			Game.litter = minf(100, Game.litter + [9.0, 6.0, 4.0][Game.tier("litter") - 1])
			pet.bladder = 0
		"floor_potty":
			pet.bladder = 0
			room.add_dropping(position + Vector2(-facing * 30, 4))
		"loaf", "groom", "chin":
			pet.add_need("fun", 3)
		"play_ball":
			pet.add_need("fun", 7)
			if data.get("nudges", 0) < 2:
				var n: int = data.get("nudges", 0) + 1
				var ball := item
				start("play_ball", ball)
				data.nudges = n
				return
		"hide_box":
			pet.add_need("fun", 8)
		"chew_toy":
			pet.add_need("fun", 8)
			pet.add_need("food", 6)
			room.bite_item(item)
		"tunnel":
			pet.add_need("fun", 12)
			position = _clamp(item.position + Vector2(item.size().x / 2.0 + 30, 4))
			facing = 1.0
			hidden_inside = false
			_boing()
		"binky":
			pet.add_need("fun", 5)
			pet.energy -= 2
		"zoomies":
			pet.add_need("fun", 10)
			pet.energy -= 6
		"flop":
			pet.add_need("fun", 6)
		"dig":
			pet.add_need("fun", 12)
		"forage":
			pet.add_need("fun", 12)
			pet.add_need("food", 5)
		"castle":
			pet.add_need("fun", 8)
			lift = 0.0
			_boing()
		"door":
			var to := "balcony" if room_id == "living" else "living"
			room_id = to
			position = _clamp(room.door_of(to).use_point(position))
			facing = -1.0 if to == "balcony" else 1.0
			if to == "balcony":
				_outside_since = _now()
				_visit_length = randf_range(90, 200)
				Game.discover("balcony")
			room.on_bunny_room_changed(self, to)
			_boing()
		"sunbathe":
			pet.add_need("fun", 6)
			pet.energy = minf(100, pet.energy + 6)
		"bird_watch":
			pet.add_need("fun", 4)
		"show_off":
			pet.add_need("fun", 4)
		"snuggle":
			pet.add_need("fun", 8)
		"herb_thief":
			Game.herbs = maxf(0, Game.herbs - 25)
			pet.add_need("food", 10)
			pet.add_need("fun", 5)
		"thump":
			var box = room.find_item("box", room_id)
			if box:
				start("hide_box", box)
			else:
				start("flee", null, _far_point(320))
			speed = 330.0
			return
	_end_current()
	_choose_next()


func _end_current() -> void:
	if _tw and _tw.is_valid():
		_tw.kill()
	air = 0.0
	twist = 0.0
	squash = Vector2.ONE
	lift = 0.0
	body.position = Vector2.ZERO
	rare = false
	if act == "sleep":
		pet.asleep = false
		pet.in_bed = false
	if act == "chew_cable":
		cable_alert.emit(false)
	if act in ["hide_box", "tunnel", "held", "door"]:
		hidden_inside = false


func _choose_next() -> void:
	var lvl := pet.trust_level()
	var mood := pet.mood()
	var n: Dictionary = pet.needs
	var hour: float = room.hour()
	var outside := room_id == "balcony"
	var daytime: bool = room.is_daytime()

	if pet.bladder >= 100:
		var lb = room.find_item("litter", room_id)
		if lb and Game.litter < 75:
			start("potty", lb)
		else:
			start("floor_potty", null, position + Vector2(randf_range(-80, 80), randf_range(-30, 30)))
		return
	# The balcony is for fun; food, water and the litter box are inside.
	if outside and (n.food < 45 or n.water < 45 or pet.bladder >= 85 or pet.energy < 30
			or Game.balcony != "open" or _now() - _outside_since > _visit_length):
		start("door", room.door_of("balcony"))
		return

	var opts := {}   # activity -> [weight, item]
	if not outside:
		var sleepy_time := (hour > 10.5 and hour < 16.0) or hour > 23.0 or hour < 5.0
		if pet.energy < 30 or (sleepy_time and pet.energy < 45):
			var bed = room.find_item("bed", room_id)
			var tent = room.find_item("teepee", room_id)
			if tent and (bed == null or randf() < 0.5):
				bed = tent
			opts.sleep = [90.0 if pet.energy < 15 else 30.0, bed]
		var bowl = room.find_item("bowl", room_id)
		if bowl and n.food < 70 and Game.bowl > 0:
			opts.eat_bowl = [(100 - n.food) * 1.5, bowl]
		var rack = room.find_item("hayrack", room_id)
		if rack and n.food < 92 and Game.hay > 5:
			opts.eat_hay = [(100 - n.food) * 0.9 + 6, rack]
		if bowl and n.food < 45 and Game.bowl == 0 and lvl >= 1:
			opts.bowl_flip = [30.0, bowl]
		var wb = room.find_item("water", room_id)
		if wb and n.water < 75 and Game.water > 5:
			opts.drink = [(100 - n.water) * 1.5, wb]
		if Game.cable == "ok" and n.fun < 50:
			opts.chew_cable = [(55 - n.fun) * (0.25 if Game.has_item("branch") else 0.9), room.cable]
		if lvl >= 1 and not Game.treats_in_inventory().is_empty():
			opts.beg = [5.0, null]
		if Game.balcony == "open" and pet.energy > 40 and n.food > 50 and n.water > 50 and pet.bladder < 70:
			opts.go_out = [6.0 + (10.0 if daytime else 0.0), room.door_of("living")]
	else:
		if daytime:
			opts.sunbathe = [24.0, room.sunspot]
			opts.bird_watch = [12.0, null]
		if Game.herbs > 25:
			opts.herb_thief = [10.0 + (100 - n.food) * 0.3, room.planter]
	for toy in [["ball", "play_ball"], ["box", "hide_box"], ["hut", "hide_box"], ["tunnel", "tunnel"],
			["branch", "chew_toy"], ["digbox", "dig"], ["puzzle", "forage"], ["castle", "castle"]]:
		var it = room.find_item(toy[0], room_id)
		if it and (not opts.has(toy[1]) or randf() < 0.5):
			opts[toy[1]] = [(100 - n.fun) * 0.45 + 5, it]
	if opts.has("chew_toy"):
		opts.chew_toy[0] += (100 - n.food) * 0.4   # branches are food too
	opts.wander = [26.0, null]
	opts.idle = [10.0, null]
	opts.loaf = [10.0 + maxf(0, mood - 50) * 0.3, null]
	opts.groom = [8.0, null]
	if lvl >= 1:
		opts.chin = [7.0, room.random_furniture(room_id)]
	var crepuscular := (hour > 5.5 and hour < 9.0) or (hour > 17.5 and hour < 22.0)
	if lvl >= 2 and mood > 60 and pet.energy > 35:
		opts.binky = [9.0 * (1.6 if outside else 1.0), null]   # fresh air makes him bouncy
		opts.zoomies = [5.0 + (6.0 if crepuscular else 0.0), null]
	if pet.is_bubak() and mood > 55 and Catalog.TRICK_ORDER.any(func(id): return Game.trick_stars(id) >= 2):
		opts.show_off = [5.0, null]
	if partner and Game.bond >= 30 and partner.room_id == room_id and partner.phase == 1 and partner.act in SNUGGLY \
			and not partner.hidden_inside:
		opts.snuggle = [6.0 + Game.bond * 0.15, partner]
	if lvl >= 3 and mood > 60:
		opts.flop = [8.0, null]
		opts.bonk = [3.0, null]

	var total := 0.0
	for k in opts:
		total += opts[k][0]
	var r := randf() * total
	var pick := "idle"
	for k in opts:
		r -= opts[k][0]
		if r <= 0:
			pick = k
			break
	var it = opts[pick][1]
	var f := Game.floor_of(room_id)
	match pick:
		"wander":
			start("wander", null, position + Vector2(randf_range(-320, 320), randf_range(-120, 120)))
		"idle", "loaf", "groom", "binky", "beg", "bird_watch", "show_off":
			start(pick, null, position)
		"sleep":
			if it:
				start("sleep", it)
			else:
				start("sleep", null, position)
		"flop":
			var rug = room.find_item("beanbag", room_id) if randf() < 0.5 else null
			if rug == null:
				rug = room.find_item("rug", room_id)
			start("flop", null, rug.position + Vector2(randf_range(-60, 60), 0) if rug else position)
		"bonk":
			start("bonk", null, Vector2(f.position.x + randf_range(370, 750), f.end.y - 2))
		"zoomies":
			start("zoomies", null, _random_point())
			data.laps = 5
			speed = 380.0
		"go_out":
			start("door", it)
		"snuggle":
			start("snuggle", it, it.position + Vector2(-70 if position.x < it.position.x else 70, 4))
		"sunbathe":
			start("sunbathe", null, it.position + Vector2(randf_range(-90, 90), randf_range(-12, 12)))
		_:
			start(pick, it)


## The other bunny came over for a cuddle: settle down together.
func join_snuggle(other: Node2D, length: float) -> void:
	_end_current()
	act = "snuggle"
	phase = 1
	act_t = length
	item = other
	data = {}
	rare = true
	_face(other)
	_set_pose("loaf")
	emote("heart")


## Puts him somewhere instantly (keeps track of which room that is).
func teleport(p: Vector2) -> void:
	position = p
	room_id = Game.room_at(p)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


# ---- player interaction -------------------------------------------------------

func on_tap() -> void:
	if act in ["thump", "flee"]:
		return
	var now := Time.get_ticks_msec() / 1000.0
	_taps.append(now)
	_taps = _taps.filter(func(t): return now - t < 1.6)
	if _taps.size() >= 3:
		_taps.clear()
		pet.add_trust(-1.5)
		message.emit(tr("Too many pokes! %s is scared now.\nTry gently holding your finger on the bunny instead.") % pet.display_name())
		start("thump", null, position)
		return
	match act:
		"chew_cable":
			message.emit(tr("Hey! No chewing cables!"))
			emote("!")
			start("flee", null, _far_point(260))
			speed = 300.0
			return
		"sleep":
			emote("!")
			start("idle", null, position)
			return
		"hide_box", "tunnel":
			if item:
				item.wiggle()
			return
	if phase == 1 and pet.trust_level() >= 3 and randf() < 0.35:
		start("bonk", null, position)
	else:
		emote("?")
		_boing()


func on_floor_tap(pos: Vector2) -> void:
	if act in ["sleep", "hide_box", "tunnel", "chew_cable", "eat_hand", "approach_hand"]:
		return
	if pet.trust_level() >= 1 and randf() < 0.6:
		start("come", null, pos + Vector2(-40 if position.x < pos.x else 40, 0))
	else:
		emote("?")


## Returns true if Bubák accepts being petted.
func on_pet_start() -> bool:
	if hidden_inside or act in ["thump", "flee", "approach_hand"] or (act == "zoomies" and phase == 0):
		return false
	if _pet_fatigue > 1.0:
		message.emit(tr("%s has had enough cuddles for now.") % pet.display_name())
		start("wander", null, _far_point(200))
		return false
	var shy: float = [0.55, 0.25, 0.08, 0.0, 0.0][pet.trust_level()]
	if act == "sleep":
		shy += 0.25
	if randf() < shy:
		emote("!")
		start("flee", null, _far_point(220))
		speed = 260.0
		if randf() < 0.5:
			message.emit(tr("%s doesn't quite trust you yet...") % pet.display_name())
		return false
	_end_current()
	act = "petted"
	phase = 1
	act_t = 999.0
	data = {}
	_set_pose("loaf")
	petting = true
	_pet_time = 0.0
	_hearts_t = 0.0
	return true


## Returns false when Bubák has had enough and hops away.
func on_pet_hold(delta: float) -> bool:
	if not petting:
		return false
	_pet_time += delta
	_pet_fatigue += delta * 0.07
	_hearts_t -= delta
	if _hearts_t <= 0:
		_hearts_t = 0.45
		emote("heart")
	pet.add_trust(0.25 * delta / (1.0 + _pet_fatigue))
	pet.add_need("fun", 1.2 * delta)
	var lvl := pet.trust_level()
	if lvl >= 4 and _pet_time > 2.5 and not data.get("purr", false):
		data.purr = true
		emote_text(tr("purr~"))
		Game.discover("purr")
	if _pet_time > 5.0 + lvl * 3.0:
		on_pet_end()
		return false
	return true


func on_pet_end() -> void:
	if not petting:
		return
	petting = false
	Game.stats.pets += 1
	if act == "petted":
		if pet.trust_level() >= 2 and _pet_time > 3.0 and randf() < 0.35:
			start("binky", null, position)
		else:
			act_t = 0.4


## Picking him up only works once he trusts you. Returns "ok", "fail" or "no" (out of reach).
func try_pick_up() -> String:
	if hidden_inside:
		message.emit(tr("%s is hiding out of reach.") % pet.display_name())
		return "no"
	if act in ["thump", "flee"]:
		return "no"
	var lvl := pet.trust_level()
	var chance: float = [0.0, 0.0, 0.4, 0.95, 1.0][lvl]
	if randf() < chance:
		_end_current()
		act = "held"
		phase = 1
		act_t = 9999.0
		data = {}
		hidden_inside = true
		pet.add_trust(0.5)
		return "ok"
	if lvl >= 2:
		pet.add_trust(-2.5)
		message.emit(tr("%s wriggles free and runs off. Almost! Build a bit more trust first.\n(Trust went down.)") % pet.display_name())
	else:
		pet.add_trust(-5.0)
		message.emit(tr("%s panics, kicks and bolts! Too soon to be picked up.\n(Trust went down.)") % pet.display_name())
	start("thump", null, position)
	return "fail"


## How long he tolerates being held, in seconds.
func hold_limit() -> float:
	return 25.0 if pet.trust_level() >= 4 else 14.0


func put_down() -> void:
	if act != "held":
		return
	_end_current()
	_boing()
	if pet.trust_level() >= 4 and randf() < 0.5:
		start("binky", null, position)
	else:
		start("idle", null, position)


func offer_treat() -> void:
	var hp: Vector2 = room.hand_pos
	start("approach_hand", null, hp + Vector2(-56 if position.x < hp.x else 56, 4))
	speed = 220.0 if pet.trust_level() >= 1 else 130.0


func _eat_from_hand() -> void:
	var treat: String = room.take_hand_treat()
	var info: Dictionary = Catalog.ITEMS[treat]
	act = "eat_hand"
	facing = signf(room.hand_pos.x - position.x) if room.hand_pos.x != position.x else facing
	Game.discover("treat")
	_set_pose("eat")
	var shy := pet.trust_level() == 0
	act_t = 0.8 if shy else 2.6
	pet.add_need("food", info.food)
	pet.add_need("fun", info.fun)
	pet.sugar += info.sugar
	pet.add_trust(info.trust * (0.6 if shy else 1.0))
	Game.stats.treats += 1
	emote("heart")
	if pet.sugar > 60:
		message.emit(tr("Too many sweets... %s has a tummy ache.\nParsley and hay are kinder to a bunny's tummy.") % pet.display_name())
	elif shy:
		message.emit(tr("Snatched it and ran! %s will get braver.") % pet.display_name())


# ---- helpers ---------------------------------------------------------------

func current_behaviour() -> String:
	if act in ["tunnel", "door"] and phase == 1:
		return ""
	if phase == 0:
		return "zoomies" if act == "zoomies" else "hop"
	if act == "sleep":
		return "sleep_bed" if item else "nap"
	if act == "flop" and pose != "flop":
		return "loaf"
	return BEHAVIOUR_OF.get(act, "idle")


func emote(kind: String) -> void:
	if kind in ["!", "?"]:
		perk_ears()
	room.spawn_fx(kind, head_pos())


func emote_text(text: String) -> void:
	room.spawn_fx("text", head_pos(), text)


func _boing() -> void:
	var t := create_tween()
	t.tween_property(self, "squash", Vector2(0.88, 1.14), 0.08)
	t.tween_property(self, "squash", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _face(it: Node2D) -> void:
	if it and absf(it.position.x - position.x) > 4:
		facing = signf(it.position.x - position.x)


func _nudge_ball() -> void:
	var ball := item
	var dir := Vector2(facing, randf_range(-0.6, 0.6)).normalized()
	var dest := _clamp(ball.position + dir * randf_range(110, 200))
	var t := ball.create_tween()
	t.tween_interval(0.3)
	t.tween_property(ball, "position", dest, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(ball.sprite, "rotation", ball.sprite.rotation + TAU * facing, 0.7)
	t.tween_callback(room.save_item_position.bind(ball))


func _clamp(p: Vector2) -> Vector2:
	var f := Game.floor_of(room_id)
	return Vector2(clampf(p.x, f.position.x, f.end.x), clampf(p.y, f.position.y, f.end.y))


func _random_point() -> Vector2:
	var f := Game.floor_of(room_id)
	return Vector2(randf_range(f.position.x, f.end.x), randf_range(f.position.y, f.end.y))


func _far_point(min_dist: float) -> Vector2:
	var best := _random_point()
	for i in 12:
		var p := _random_point()
		if p.distance_to(position) > min_dist:
			return p
		if p.distance_to(position) > best.distance_to(position):
			best = p
	return best
