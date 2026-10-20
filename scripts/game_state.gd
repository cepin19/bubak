extends Node
## Everything that gets saved: Bubák's needs, trust, money, inventory and the room.

signal changed
signal toast(text: String)
signal trust_level_up(level: int)
signal discovered(behaviour: String)
signal item_added(entry: Dictionary)
signal balcony_milestone
signal goal_completed(id: String)
signal sponsor_paid(amount: int, streak: int)
signal welcome(text: String)   # something to say after the app comes back from the background
signal club_unlocked(stage: int)
signal mate_unlocked
signal mate_trust_up(level: int)

const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.cfg"
const LANGUAGES := {"en": "English", "cs": "Čeština"}
const PHOTO_DIR := "user://photos/"
const SAVES_DIR := "user://saves/"
## Where Bubák (and anything placed) may stand, in world coordinates.
const FLOOR := Rect2(80, 486, 1120, 204)
## The balcony is laid out to the left of the living room, this far along x.
const BALCONY_X := -2000.0
const BALCONY_FLOOR := Rect2(-1920, 486, 1120, 204)

var coins := 40
var followers := 0
# The rabbits. Bubák's needs and trust are also reachable directly (Game.needs, Game.trust...).
var bubak := Pet.new()
var mate: Pet = null
var pets: Array = [bubak]
var mate_stage := 0          # 0 not yet, 1 can adopt, 2 adopted
var bond := 0.0              # how close Bubák and his mate are, 0..100
var needs: Dictionary:
	get: return bubak.needs
	set(v): bubak.needs = v
var energy: float:
	get: return bubak.energy
	set(v): bubak.energy = v
var bladder: float:
	get: return bubak.bladder
	set(v): bubak.bladder = v
var sugar: float:
	get: return bubak.sugar
	set(v): bubak.sugar = v
var trust: float:
	get: return bubak.trust
	set(v): bubak.trust = v
var asleep: bool:
	get: return bubak.asleep
	set(v): bubak.asleep = v
var in_bed: bool:
	get: return bubak.in_bed
	set(v): bubak.in_bed = v
var inventory := {"pellets": 3, "hay": 3, "carrot": 2, "parsley": 2}
var bowl := 1            # pellet portions in the bowl
var hay := 60.0          # hay in the rack, 0..100
var water := 100.0       # water in the bowl, 0..100
var litter := 0.0        # litter box dirtiness, 0..100
var droppings: Array = []    # [[x, y], ...]
var cable := "ok"        # ok / chewed / covered
var balcony := "locked"  # locked / available (milestone reached) / open
var herbs := 100.0       # herbs in the balcony planter, regrow over time
var placed: Array = []   # [{uid, id, x, y}, ...]
var next_uid := 1
var seen := {}           # behaviour -> unix time first seen
var photos: Array = []   # [{file, behaviour, likes, coins, time}, ...]
var photo_recent := {}   # behaviour -> unix time last photographed
var work_ready_at := 0.0
var stats := {"pets": 0, "treats": 0, "photos": 0, "work": 0}
var created_at := 0.0
var welcome_text := ""
var life_goes_on := true   # setting: does time pass for Bubák while the game is closed?
var _paused_at := 0.0
var language := "en"
var upgrades := {"bowl": 1, "water": 1, "hayrack": 1, "litter": 1, "chair": 0, "monitor": 0, "coffee": 0, "headphones": 0}
var wardrobe: Array = []     # accessories owned
var wearing := ""            # accessory Bubák has on
var career_xp := 0
var job_best := {}   # job id -> {"score": best points, "stars": best stars}
var goals_claimed: Array = []
var goals_notified: Array = []
var sponsor_day := ""
var sponsor_streak := 0
# show club
var club_stage := 0          # 0 locked, 1 training, 2 + grooming, 3 + shows
var gear: Array = []         # training / grooming gear owned
var tricks := {}             # trick -> training progress
var focus := float(Catalog.FOCUS_MAX)   # training tries left
var coat := 70.0             # 0..100, brushing keeps it glossy
var nails := 20.0            # 0..100, grows; clipping resets it
var fur: Array = []          # shed fur on the floor: [[x, y], ...]
var groom_start := 0.0       # when grooming unlocked; molting follows from it
var trophies: Array = []     # [{tier, cat, place, time}, ...]
var show_ready_at := {}      # tier (as string) -> unix time of the next show
var _cozy_points := 0
var _defaults := {}
var save_path := SAVE_PATH   # the playtest, demo and test play keep their own save
var test_mode := false       # test play: everything unlocked, no waiting
var _home_path := SAVE_PATH  # the save test play returns to
var _slow_t := 0.0

var _save_timer := 0.0


func _ready() -> void:
	bubak.trust_level_up.connect(func(l): trust_level_up.emit(l))
	_defaults = to_dict().duplicate(true)
	_load_settings()
	DirAccess.make_dir_recursive_absolute(PHOTO_DIR)
	DirAccess.make_dir_recursive_absolute(SAVES_DIR)
	if not load_game():
		_new_game()
	_settle()


## After a game is started or loaded: things already reached don't pop up again.
func _settle() -> void:
	for p in pets:
		p.settle_level()
	_recount_cozy()
	goals_notified = []
	for g in Catalog.GOALS:   # finished before this session: no toast, just claimable
		if goal_done(g):
			goals_notified.append(g.id)


func _new_game() -> void:
	created_at = Time.get_unix_time_from_system()
	placed = [
		{"uid": 1, "id": "litter", "x": 170.0, "y": 600.0},
		{"uid": 2, "id": "hayrack", "x": 300.0, "y": 560.0},
		{"uid": 3, "id": "bowl", "x": 520.0, "y": 655.0},
		{"uid": 4, "id": "water", "x": 640.0, "y": 668.0},
	]
	next_uid = 5
	welcome_text = tr("Meet Bubák!\n\nHe's new here and a little shy. Keep his bowls full, clean his litter box and hold your finger on him to pet him gently.\n\nTake photos of the cute things he does to earn coins.")


func _process(delta: float) -> void:
	delta = minf(delta, 1.0)   # a long stall (e.g. the app in the background) is handled by _time_away
	var m := delta / 60.0
	var clean := clampf(100.0 - maxf(0, litter - 30) * 0.9 - droppings.size() * 10.0 - fur.size() * 4.0, 0, 100)
	var cozy := cozy_level()
	for p in pets:
		p.tick(delta, clean, cozy)
	if mate and bubak.mood(cozy) > 50 and mate.mood(cozy) > 50:
		bond = minf(100, bond + 0.5 * m)   # about 3 hours of contented living to bond fully
	herbs = minf(100, herbs + 4.0 * m)
	if balcony == "locked" and trust_level() >= Catalog.BALCONY_TRUST and followers >= Catalog.BALCONY_FOLLOWERS:
		balcony = "available"
		balcony_milestone.emit()
		save_game()
	if club_stage >= 2:
		coat = maxf(0, coat - (6.0 if molting() else 2.0) * m / 60.0)   # per hour
		nails = minf(100, nails + 12.0 * m / (24 * 60))
	var fmax := focus_max()
	if focus < fmax:
		focus = minf(fmax, focus + delta / Catalog.FOCUS_REFILL * (60.0 if test_mode else 1.0))

	_slow_t += delta
	if _slow_t > 1.0:
		_slow_t = 0.0
		_recount_cozy()
		_check_club()
		_check_mate()
		for g in Catalog.GOALS:
			if not g.id in goals_notified and goal_done(g):
				goals_notified.append(g.id)
				goal_completed.emit(g.id)
	_save_timer += delta
	if _save_timer > 20.0:
		_save_timer = 0.0
		save_game()
	changed.emit()


func mood() -> float:
	return bubak.mood()


func room_at(p: Vector2) -> String:
	return "balcony" if p.x < BALCONY_X / 5.0 else "living"


func floor_of(room: String) -> Rect2:
	return BALCONY_FLOOR if room == "balcony" else FLOOR


func trust_level() -> int:
	return bubak.trust_level()


func trust_progress() -> float:
	return bubak.trust_progress()


func add_trust(amount: float) -> void:
	bubak.add_trust(amount)


func add_need(need: String, amount: float) -> void:
	bubak.add_need(need, amount)


func add_coins(amount: int) -> void:
	coins = maxi(0, coins + amount)
	changed.emit()


func discover(behaviour: String) -> void:
	if behaviour == "" or seen.has(behaviour):
		return
	seen[behaviour] = Time.get_unix_time_from_system()
	discovered.emit(behaviour)


func has_item(id: String) -> bool:
	for e in placed:
		if e.id == id:
			return true
	return false


func count_item(id: String) -> int:
	var n := 0
	for e in placed:
		if e.id == id:
			n += 1
	return n


func treats_in_inventory() -> Array:
	var out := []
	for id in inventory:
		if inventory[id] > 0 and Catalog.ITEMS[id].kind == "treat":
			out.append(id)
	return out


# ---- progression ---------------------------------------------------------------

func tier(slot: String) -> int:
	return upgrades.get(slot, 0)


func _recount_cozy() -> void:
	var pts := 0
	for e in placed:
		pts += Catalog.ITEMS[e.id].get("cozy", 0)
	for id in Catalog.ITEMS:
		var item: Dictionary = Catalog.ITEMS[id]
		if item.has("slot") and tier(item.slot) >= item.tier:
			pts += item.get("cozy", 0)
	if cable == "covered":
		pts += 1
	if balcony == "open":
		pts += 3
	pts += mini(trophies.size(), 8)   # rosettes on the shelf
	_cozy_points = pts


func cozy_points() -> int:
	return _cozy_points


## 1 = Bare ... 6 = Bunny paradise
func cozy_level() -> int:
	var lvl := 1
	for i in Catalog.COZY_LEVELS.size():
		if _cozy_points >= Catalog.COZY_LEVELS[i].at:
			lvl = i + 1
	return lvl


func cozy_progress() -> float:
	var lvl := cozy_level()
	if lvl >= Catalog.COZY_LEVELS.size():
		return 1.0
	var a: float = Catalog.COZY_LEVELS[lvl - 1].at
	var b: float = Catalog.COZY_LEVELS[lvl].at
	return (_cozy_points - a) / (b - a)


func career_level() -> int:
	var lvl := 0
	for i in Catalog.CAREER.size():
		if career_xp >= Catalog.CAREER[i].xp:
			lvl = i
	return lvl


func career_progress() -> float:
	var lvl := career_level()
	if lvl >= Catalog.CAREER.size() - 1:
		return 1.0
	var a: float = Catalog.CAREER[lvl].xp
	var b: float = Catalog.CAREER[lvl + 1].xp
	return (career_xp - a) / (b - a)


## Today's job the boss cares about most: double XP. Changes every day.
func boss_pick() -> String:
	var open: Array = Catalog.JOBS.keys().filter(func(id): return career_level() >= Catalog.JOBS[id].level)
	if open.size() < 2:
		return ""
	var day := int(Time.get_unix_time_from_system() / 86400.0)
	return open[(day * 7 + 3) % open.size()]


## Stars for a shift: how the score compares with the job's targets.
func job_stars(job: String, score: int) -> int:
	var k := work_duration() / 25.0
	var n := 0
	for target in Catalog.JOBS[job].stars:
		if score >= target * k:
			n += 1
	return n


## Remembers the best shift for a job. Returns true for a new record.
func record_shift(job: String, score: int, stars: int) -> bool:
	var best: Dictionary = job_best.get(job, {"score": 0, "stars": 0})
	var record := score > int(best.score) and int(best.score) > 0
	job_best[job] = {"score": maxi(score, int(best.score)), "stars": maxi(stars, int(best.stars))}
	return record


func work_pay_mult() -> float:
	return 1.0 + 0.15 * career_level() + 0.25 * tier("monitor") + 0.25 * tier("headphones")


func work_cooldown() -> float:
	if test_mode:
		return 5.0
	return 120.0 if tier("chair") > 0 else 180.0


func work_duration() -> float:
	return 30.0 if tier("coffee") > 0 else 25.0


## Number of upgrades bought (care tiers above the basic one, plus desk gear).
func upgrades_count() -> int:
	var n := 0
	for slot in upgrades:
		n += upgrades[slot] - (1 if slot in ["bowl", "water", "hayrack", "litter"] else 0)
	return n


func goal_target(g: Dictionary) -> int:
	return Catalog.BEHAVIOUR_ORDER.size() if g.n < 0 else g.n


func goal_value(g: Dictionary) -> int:
	match g.type:
		"photos": return stats.photos
		"seen": return seen.size()
		"work": return stats.work
		"followers": return followers
		"trust": return trust_level()
		"cozy": return cozy_level()
		"upgrades": return upgrades_count()
		"wardrobe": return wardrobe.size()
		"career": return career_level()
		"jobstars": return job_best.values().filter(func(b): return int(b.stars) >= 3).size()
		"balcony": return 1 if balcony == "open" else 0
		"stars": return trick_stars_total()
		"mate": return 1 if mate else 0
		"bond": return int(bond)
		"grooms": return stats.get("grooms", 0)
		"ribbons": return trophies.size()
		"won": return best_win() + 1
		"cats":
			var cats := {}
			for t in trophies:
				if t.place == 1:
					cats[t.cat] = true
			return cats.size()
	return 0


## Goals for parts of the game the player hasn't reached yet stay out of sight.
func goal_visible(g: Dictionary) -> bool:
	return club_stage >= g.get("stage", 0) and mate_stage >= g.get("mate", 0)


func goal_done(g: Dictionary) -> bool:
	return goal_visible(g) and goal_value(g) >= goal_target(g)


func claimable_goals() -> int:
	var n := 0
	for g in Catalog.GOALS:
		if goal_done(g) and not g.id in goals_claimed:
			n += 1
	return n


func claim_goal(id: String) -> int:
	for g in Catalog.GOALS:
		if g.id == id and goal_done(g) and not id in goals_claimed:
			goals_claimed.append(id)
			coins += g.reward
			save_game()
			changed.emit()
			return g.reward
	return 0


## Once a day, sponsors pay for Bubák's posts. Consecutive days pay more.
func check_sponsor() -> void:
	if followers < 25:
		return
	var today := Time.get_date_string_from_system()
	if sponsor_day == today:
		return
	var yesterday := Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) - 86400)
	sponsor_streak = sponsor_streak + 1 if sponsor_day == yesterday else 1
	sponsor_day = today
	var amount := int((15 + followers / 20.0 + cozy_level() * 5) * (1.0 + 0.1 * mini(sponsor_streak - 1, 6)))
	amount = mini(amount, 400)
	coins += amount
	save_game()
	sponsor_paid.emit(amount, sponsor_streak)


## Why an item can't be bought yet ("" if it can).
func lock_reason(id: String) -> String:
	var item: Dictionary = Catalog.ITEMS[id]
	if club_stage < item.get("stage", 0):
		return tr("Unlocks later in the show club")
	if test_mode:
		return ""
	if cozy_level() < item.get("req_cozy", 0):
		return tr("Needs Cozy level %d") % item.req_cozy
	if career_level() < item.get("req_career", 0):
		return tr("Needs career: %s") % Catalog.career_title(item.req_career)
	if item.has("slot") and item.tier > 1 and tier(item.slot) < item.tier - 1:
		return tr("Needs the previous upgrade")
	return ""


## Returns "" on success, otherwise a reason it can't be bought.
func buy(id: String, room := "living") -> String:
	var item: Dictionary = Catalog.ITEMS[id]
	var locked := lock_reason(id)
	if locked != "":
		return locked
	if item.has("slot") and tier(item.slot) >= item.tier:
		return tr("Already installed.")
	if item.kind in ["wear", "gear"] and (id in wardrobe or id in gear):
		return tr("Already installed.")
	if coins < item.price:
		return tr("Not enough coins.")
	if item.has("slot"):
		upgrades[item.slot] = item.tier
	match item.kind:
		"wear":
			wardrobe.append(id)
			wearing = id
		"gear":
			gear.append(id)
		"food", "hay", "treat":
			inventory[id] = inventory.get(id, 0) + item.get("qty", 1)
		"toy", "decor":
			if count_item(id) >= item.get("max", 1):
				return tr("You already have enough of those.")
			var spot := _free_spot(room)
			var entry := {"uid": next_uid, "id": id, "x": spot.x, "y": spot.y}
			if item.has("bites"):
				entry.bites = item.bites
			next_uid += 1
			placed.append(entry)
			item_added.emit(entry)
		"upgrade":
			if id == "cable_cover":
				if cable == "covered":
					return tr("Already installed.")
				cable = "covered"
			if id == "balcony_net":
				if balcony == "locked":
					return tr("Not yet! Bubák needs to trust you more and get more followers.")
				if balcony == "open":
					return tr("Already installed.")
				balcony = "open"
	coins -= item.price
	_recount_cozy()
	save_game()
	changed.emit()
	return ""


## The candidate floor spot furthest from everything already placed.
func _free_spot(room: String) -> Vector2:
	var f := floor_of(room)
	var ox := BALCONY_X if room == "balcony" else 0.0
	var taken: Array = [Vector2(420, 470), Vector2(1110, 470), Vector2(710, 470), Vector2(95, 470)]
	if room == "balcony":
		taken = [Vector2(ox + 300, 520), Vector2(ox + 1150, 470), Vector2(ox + 640, 600)]
	for e in placed:
		if room_at(Vector2(e.x, e.y)) == room:
			taken.append(Vector2(e.x, e.y))
	var best := Vector2.ZERO
	var best_d := -1.0
	for i in 40:
		var p := Vector2(randf_range(f.position.x + 90, f.end.x - 90),
			randf_range(f.position.y + 20, f.end.y - 30))
		var d := INF
		for t in taken:
			d = minf(d, (p - t).length())
		if p.x - ox > 760 and p.y > 600:
			d *= 0.3   # keep clear of the on-screen buttons
		if d > best_d:
			best_d = d
			best = p
	return best


func use_inventory(id: String) -> bool:
	if inventory.get(id, 0) <= 0:
		return false
	inventory[id] -= 1
	return true


## Scores a photo of `behaviour`, records it and pays out.
func record_photo(file: String, behaviour: String, decor_nearby: int) -> Dictionary:
	var now := Time.get_unix_time_from_system()
	var info: Dictionary = Catalog.BEHAVIOURS.get(behaviour, {"likes": 3})
	var likes: float = info.likes * randf_range(0.85, 1.2)
	likes *= 1.0 + 0.15 * mini(decor_nearby, 3)
	if wearing != "":
		likes *= 1.2
	likes *= minf(1.0 + followers / 400.0, 4.0)
	var is_new := behaviour != "" and not photo_recent.has(behaviour)
	var stale := not is_new and behaviour != "" and now - float(photo_recent[behaviour]) < 600
	if is_new:
		likes *= 1.8
	elif stale:
		likes *= 0.35
	if behaviour != "":
		photo_recent[behaviour] = now
	var l := int(round(likes))
	var gained_coins := maxi(1, int(round(l / 5.0)))
	var gained_followers := int(l / 6.0 * (1.0 + 0.05 * (cozy_level() - 1)))
	coins += gained_coins
	followers += gained_followers
	stats.photos += 1
	var entry := {"file": file, "behaviour": behaviour, "likes": l, "coins": gained_coins, "time": now}
	photos.append(entry)
	save_game()
	changed.emit()
	return entry.merged({"new": is_new, "stale": stale, "followers": gained_followers})


# ---- show club -----------------------------------------------------------------

## Opens the next part of the show club once its milestone is reached.
func _check_club() -> void:
	var stage := club_stage
	if stage == 0 and trust_level() >= Catalog.CLUB_TRAINING_TRUST and cozy_level() >= Catalog.CLUB_TRAINING_COZY:
		stage = 1
	elif stage == 1 and trick_stars_total() >= Catalog.CLUB_GROOMING_STARS:
		stage = 2
	elif stage == 2 and trick_stars_total() >= Catalog.CLUB_SHOWS_STARS and stats.get("grooms", 0) >= 1:
		stage = 3
	if stage == club_stage:
		return
	club_stage = stage
	if stage == 2:
		groom_start = Time.get_unix_time_from_system()
	save_game()
	club_unlocked.emit(stage)


func trick_stars(id: String) -> int:
	var n := 0
	for need in Catalog.TRICK_STARS:
		if tricks.get(id, 0.0) >= need:
			n += 1
	return n


func trick_stars_total() -> int:
	var n := 0
	for id in Catalog.TRICKS:
		n += trick_stars(id)
	return n


## Progress towards the next star, 0..1 (1 when mastered).
func trick_progress(id: String) -> float:
	var s := trick_stars(id)
	if s >= Catalog.TRICK_STARS.size():
		return 1.0
	var from: float = 0.0 if s == 0 else Catalog.TRICK_STARS[s - 1]
	return (tricks.get(id, 0.0) - from) / (Catalog.TRICK_STARS[s] - from)


## Why a trick can't be trained yet ("" if it can).
func trick_lock(id: String) -> String:
	var t: Dictionary = Catalog.TRICKS[id]
	if trust_level() < t.level:
		return tr("Needs trust: %s") % Catalog.level_name(t.level)
	if t.has("gear") and not t.gear in gear:
		return tr("Needs: %s") % Catalog.item_name(t.gear)
	return ""


func focus_max() -> int:
	return Catalog.FOCUS_MAX + (3 if "pouch" in gear else 0)


## Chance he gets a trick right. Shows are more nerve-racking the bigger they are.
func trick_chance(id: String, show_tier := -1) -> float:
	var s := trick_stars(id)
	if show_tier >= 0:
		return clampf(0.4 + 0.18 * s - 0.05 * show_tier, 0.1, 0.95)
	return clampf(0.35 + 0.2 * s + 0.03 * trust_level(), 0.1, 0.95)


## One training try. result: "good" (rewarded in time), "late", "wrong" (rewarded a
## mistake) or "none". Returns how many stars the trick gained.
func train(id: String, result: String) -> int:
	var before := trick_stars(id)
	var amount: float = {"good": 25.0, "late": 8.0, "wrong": -6.0}.get(result, 0.0)
	if result == "good":
		amount *= 1.5 if "clicker" in gear else 1.0
		add_trust(0.3)
	tricks[id] = clampf(tricks.get(id, 0.0) + amount, 0, Catalog.TRICK_STARS[-1])
	stats.training = stats.get("training", 0) + 1
	add_need("fun", 2)
	save_game()
	changed.emit()
	return trick_stars(id) - before


## Bubák sheds heavily for 3 days in every 14, starting a few days after grooming opens up.
func molting() -> bool:
	if club_stage < 2:
		return false
	var d := int((Time.get_unix_time_from_system() - groom_start) / 86400.0) % 14
	return d >= 4 and d < 7


func finish_grooming(brushed: float) -> void:
	coat = minf(100, coat + brushed)
	stats.grooms = stats.get("grooms", 0) + 1
	add_trust(0.5)
	save_game()
	changed.emit()


## Returns "" when it went fine, otherwise what went wrong.
func trim_nails() -> String:
	if trust_level() < 2:
		add_trust(-1.5)
		return tr("Bubák kicked and squirmed away. He needs to trust you more for this.\n(Trust went down.)")
	nails = 0.0
	add_trust(0.2)
	save_game()
	return ""


## How show-ready he looks, 0..100: coat, nails and how content he is.
func condition() -> float:
	return coat * 0.55 + (100.0 - nails) * 0.2 + mood() * 0.25


func style_score() -> float:
	return {"": 20.0, "bow": 55.0, "glasses": 65.0, "crown": 80.0, "tophat": 95.0}.get(wearing, 40.0)


func wins_at(t: int) -> int:
	return trophies.filter(func(x): return x.tier == t and x.place == 1).size()


## Highest tier with a first place (-1 for none).
func best_win() -> int:
	var best := -1
	for x in trophies:
		if x.place == 1:
			best = maxi(best, x.tier)
	return best


func show_unlocked(t: int) -> bool:
	if club_stage < 3:
		return false
	return test_mode or t == 0 or wins_at(t - 1) >= Catalog.SHOW_TIERS[t].wins


func show_wait(t: int) -> float:
	if test_mode:
		return 0.0
	return float(show_ready_at.get(str(t), 0.0)) - Time.get_unix_time_from_system()


## The best photo not yet shown to judges (or {}).
func best_photo() -> Dictionary:
	var best := {}
	for p in photos:
		if not p.get("judged", false) and FileAccess.file_exists(p.file) and (best.is_empty() or p.likes > best.likes):
			best = p
	return best


## Score for the categories judged without a live performance.
func show_score(cat: String) -> float:
	match cat:
		"looks":
			return clampf(condition() * 0.45 + style_score() * 0.25 + trust * 0.3, 0, 100)
		"photo":
			var p := best_photo()
			return 0.0 if p.is_empty() else clampf(14.0 * log(maxf(1, p.likes)) / log(2.0) - 30.0, 0, 100)
	return 0.0


## Why Bubák can't enter this show and category right now ("" if he can).
func show_problem(t: int, cat: String) -> String:
	if not show_unlocked(t):
		return tr("Locked")
	if show_wait(t) > 0:
		return tr("Next show in %s") % duration_text(show_wait(t))
	if coins < Catalog.SHOW_TIERS[t].fee:
		return tr("Not enough coins.")
	if cat == "tricks" and trick_stars_total() == 0:
		return tr("He doesn't know any tricks yet.")
	if cat == "photo" and best_photo().is_empty():
		return tr("Take some photos first.")
	return ""


func enter_show(t: int, cat: String) -> String:
	var err := show_problem(t, cat)
	if err != "":
		return err
	coins -= Catalog.SHOW_TIERS[t].fee
	show_ready_at[str(t)] = Time.get_unix_time_from_system() + Catalog.SHOW_TIERS[t].wait
	stats.shows = stats.get("shows", 0) + 1
	if cat == "photo":
		best_photo().judged = true
	save_game()
	changed.emit()
	return ""


## Pays out a show result. place: 1..4. Returns {coins, fans}.
func finish_show(t: int, cat: String, place: int) -> Dictionary:
	var res := {"coins": 0, "fans": 0}
	if place <= 3:
		res.coins = Catalog.SHOW_TIERS[t].prize[place - 1]
		res.fans = Catalog.SHOW_TIERS[t].fans[place - 1]
		coins += res.coins
		followers += res.fans
		trophies.append({"tier": t, "cat": cat, "place": place, "time": Time.get_unix_time_from_system()})
	add_trust(1.0)
	_recount_cozy()
	save_game()
	changed.emit()
	return res


func duration_text(seconds: float) -> String:
	var mins := int(ceil(seconds / 60.0))
	return tr("%d h %d min") % [mins / 60, mins % 60] if mins >= 60 else tr("%d min") % mins


# ---- a mate for Bubák -------------------------------------------------------------

func _set_mate(p: Pet) -> void:
	mate = p
	pets = [bubak] if p == null else [bubak, p]
	if p:
		p.trust_level_up.connect(func(l): mate_trust_up.emit(l))
		p.settle_level()


## Late in the game Bubák gets lonely: the rescue's hutch opens.
func _check_mate() -> void:
	if mate_stage == 0 and trust_level() >= Catalog.MATE_TRUST and cozy_level() >= Catalog.MATE_COZY:
		mate_stage = 1
		save_game()
		mate_unlocked.emit()


## Why this rabbit can't be adopted ("" if it can).
func adopt_problem(id: String) -> String:
	if mate_stage == 0:
		return tr("Needs Bubák at trust %s and Cozy level %d") % [Catalog.level_name(Catalog.MATE_TRUST), Catalog.MATE_COZY]
	if mate != null:
		return tr("Bubák already has a friend.")
	if coins < Catalog.MATES[id].price:
		return tr("Not enough coins.")
	return ""


func adopt(id: String) -> String:
	var err := adopt_problem(id)
	if err != "":
		return err
	coins -= Catalog.MATES[id].price
	var p := Pet.new()
	p.id = id
	p.trust = Catalog.MATES[id].trust
	p.needs = needs.duplicate()
	_set_mate(p)
	mate_stage = 2
	bond = 0.0
	save_game()
	changed.emit()
	return ""


# ---- settings ------------------------------------------------------------------

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		language = cfg.get_value("general", "language", "en")
		life_goes_on = cfg.get_value("general", "life_goes_on", true)
	else:
		# First launch: follow the phone / OS language.
		language = "cs" if OS.get_locale_language() in ["cs", "sk"] else "en"
	TranslationServer.set_locale(language)


func set_life_goes_on(on: bool) -> void:
	life_goes_on = on
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("general", "life_goes_on", on)
	cfg.save(SETTINGS_PATH)


func set_language(code: String) -> void:
	language = code
	TranslationServer.set_locale(code)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("general", "language", code)
	cfg.save(SETTINGS_PATH)


# ---- saving ------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"version": 1, "coins": coins, "followers": followers, "needs": needs, "energy": energy,
		"bladder": bladder, "sugar": sugar, "trust": trust, "inventory": inventory, "bowl": bowl,
		"hay": hay, "water": water, "litter": litter, "droppings": droppings, "cable": cable,
		"balcony": balcony, "herbs": herbs, "upgrades": upgrades, "wardrobe": wardrobe,
		"wearing": wearing, "career_xp": career_xp, "job_best": job_best, "goals_claimed": goals_claimed,
		"sponsor_day": sponsor_day, "sponsor_streak": sponsor_streak, "placed": placed, "next_uid": next_uid, "seen": seen, "photos": photos,
		"photo_recent": photo_recent, "work_ready_at": work_ready_at, "stats": stats,
		"club_stage": club_stage, "gear": gear, "tricks": tricks, "focus": focus, "coat": coat, "nails": nails,
		"fur": fur, "groom_start": groom_start, "trophies": trophies, "show_ready_at": show_ready_at,
		"mate_stage": mate_stage, "mate": mate.to_dict() if mate else {}, "bond": bond, "test_mode": test_mode,
		"created_at": created_at, "saved_at": Time.get_unix_time_from_system(),
	}


func save_game() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(to_dict()))


func load_game() -> bool:
	var data := _read_json(save_path)
	if data.is_empty():
		return false
	_apply(data)
	_time_away(Time.get_unix_time_from_system() - float(data.saved_at))
	return true


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if typeof(data) == TYPE_DICTIONARY else {}


## Replaces the whole game state with a saved one (older saves lack newer fields).
func _apply(data: Dictionary) -> void:
	data = data.duplicate(true)
	var d := _defaults.duplicate(true)
	d.merge(data, true)
	coins = int(d.coins)
	followers = int(d.followers)
	for k in needs:
		needs[k] = float(d.needs.get(k, 70))
	energy = float(d.energy)
	bladder = float(d.bladder)
	sugar = float(d.sugar)
	trust = float(d.trust)
	inventory = {}
	for k in d.inventory:
		var id: String = {"banana": "apple"}.get(k, k)   # renamed items in older saves
		inventory[id] = inventory.get(id, 0) + int(d.inventory[k])
	bowl = int(d.bowl)
	hay = float(d.hay)
	water = float(d.water)
	litter = float(d.litter)
	droppings = d.droppings
	cable = d.cable
	balcony = d.balcony
	herbs = float(d.herbs)
	upgrades = _defaults.upgrades.duplicate()
	for k in d.upgrades:
		upgrades[k] = int(d.upgrades[k])
	wardrobe = d.wardrobe
	wearing = d.wearing
	career_xp = int(d.career_xp)
	job_best = d.get("job_best", {}).duplicate(true)
	goals_claimed = d.goals_claimed
	sponsor_day = d.sponsor_day
	sponsor_streak = int(d.sponsor_streak)
	placed = []
	for e in d.placed:
		var entry := {"uid": int(e.uid), "id": {"chew": "branch"}.get(e.id, e.id), "x": float(e.x), "y": float(e.y)}
		if e.has("bites") or entry.id == "branch":
			entry.bites = int(e.get("bites", Catalog.ITEMS.branch.bites))
		placed.append(entry)
	next_uid = int(d.next_uid)
	seen = d.seen
	photos = d.photos
	photo_recent = d.photo_recent
	work_ready_at = float(d.work_ready_at)
	stats = {}
	for k in d.stats:
		stats[k] = int(d.stats[k])
	club_stage = int(d.club_stage)
	gear = d.gear
	tricks = {}
	for k in d.tricks:
		tricks[k] = float(d.tricks[k])
	focus = float(d.focus)
	coat = float(d.coat)
	nails = float(d.nails)
	fur = d.fur
	groom_start = float(d.groom_start)
	trophies = []
	for t in d.trophies:
		trophies.append({"tier": int(t.tier), "cat": t.cat, "place": int(t.place), "time": float(t.time)})
	show_ready_at = d.show_ready_at
	mate_stage = int(d.mate_stage)
	test_mode = bool(d.test_mode)
	bond = float(d.bond)
	_set_mate(Pet.from_dict(d.mate) if not d.mate.is_empty() else null)
	created_at = float(d.created_at)
	welcome_text = ""


## A throwaway game in its own save file, for the playtest and demo mode.
func use_scratch_game(path: String) -> void:
	save_path = path
	new_game()


## Test play: a sandbox game (in its own save) with everything unlocked and 10000 coins,
## for trying out the mechanics. The real game is saved first and left untouched.
func start_test_play() -> void:
	if not test_mode:
		save_game()
		_home_path = save_path
	save_path = "user://testplay_save.json"
	new_game()
	test_mode = true
	coins = 10000
	followers = 1000
	trust = 92.0
	career_xp = Catalog.CAREER[-1].xp
	balcony = "open"
	club_stage = 3
	groom_start = Time.get_unix_time_from_system()
	mate_stage = 1
	coat = 60.0
	nails = 50.0
	for k in inventory:
		inventory[k] = 20
	welcome_text = tr("Test play! Everything is unlocked and you have 10000 coins. Nothing here touches your real game.\n\nSettings > Back to my game returns to it.")
	_settle()
	save_game()


func end_test_play() -> void:
	save_path = _home_path
	if not load_game():
		new_game()
	test_mode = false
	welcome_text = tr("Back to your own game.")
	_settle()


## Starts over with a brand new Bubák (the current game is not kept unless saved by name).
func new_game() -> void:
	_apply(_defaults)
	_new_game()
	_settle()
	save_game()


# ---- named saves ----------------------------------------------------------------

func _save_file(save_name: String) -> String:
	return SAVES_DIR + "save_" + save_name.strip_edges().to_lower().md5_text().substr(0, 12) + ".json"


## Named saves, newest first: [{file, name, saved_at, coins, trust, days}, ...]
func list_saves() -> Array:
	var out := []
	for f in DirAccess.get_files_at(SAVES_DIR):
		if not f.ends_with(".json"):
			continue
		var d := _read_json(SAVES_DIR + f)
		if d.is_empty():
			continue
		out.append({"file": SAVES_DIR + f, "name": d.get("save_name", f), "saved_at": float(d.get("saved_at", 0)),
			"coins": int(d.get("coins", 0)), "trust": Catalog.trust_level_for(float(d.get("trust", 0))),
			"days": int((float(d.get("saved_at", 0)) - float(d.get("created_at", 0))) / 86400.0) + 1})
	out.sort_custom(func(a, b): return a.saved_at > b.saved_at)
	return out


func save_exists(save_name: String) -> bool:
	return FileAccess.file_exists(_save_file(save_name))


func save_named(save_name: String) -> bool:
	save_name = save_name.strip_edges()
	if save_name == "":
		return false
	var data := to_dict()
	data.save_name = save_name
	var f := FileAccess.open(_save_file(save_name), FileAccess.WRITE)
	if not f:
		return false
	f.store_string(JSON.stringify(data))
	save_game()
	return true


## Continues exactly where the named save left off (no time passes in between).
func load_named(file: String) -> bool:
	var data := _read_json(file)
	if data.is_empty():
		return false
	_apply(data)
	_settle()
	welcome_text = tr("Loaded \"%s\". Welcome back!") % data.get("save_name", "")
	save_game()
	return true


func delete_named(file: String) -> void:
	if file.begins_with(SAVES_DIR):
		DirAccess.remove_absolute(file)


## The game was closed (or in the background) for a while: either life went on,
## or time stood still and every clock waits for the player too.
func _time_away(seconds: float) -> void:
	if seconds < 90:
		return
	if life_goes_on:
		_catch_up(seconds)
		return
	var now := Time.get_unix_time_from_system()
	if work_ready_at > now - seconds:
		work_ready_at += seconds
	for t in show_ready_at:
		if show_ready_at[t] > now - seconds:
			show_ready_at[t] += seconds
	groom_start += seconds   # the molting calendar waits too
	welcome_text = tr("Welcome back! Time stood still while you were away, so everything is just as you left it.")


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			_paused_at = Time.get_unix_time_from_system()
		NOTIFICATION_APPLICATION_RESUMED:
			if _paused_at > 0:
				_time_away(Time.get_unix_time_from_system() - _paused_at)
				_paused_at = 0.0
				if welcome_text != "":
					welcome.emit(welcome_text)
					welcome_text = ""
				save_game()


## Life went on while the game was closed: a gentler version of what would have happened.
func _catch_up(seconds: float) -> void:
	if seconds < 90:
		return
	var mins := minf(seconds / 60.0, 12 * 60)
	var notes := []
	var n := pets.size()   # two rabbits eat twice as much
	var bowls_eaten := mini(bowl, (int(mins / 40.0) + 1) * n)
	bowl -= bowls_eaten
	var hay_eaten := minf(hay, mins * 0.6 * n)
	hay -= hay_eaten
	var drunk := minf(water, mins * 0.7 * n)
	water -= drunk
	for p in pets:
		p.needs.food = clampf(p.needs.food - mins * Pet.FOOD_DECAY * 0.35 + (bowls_eaten * 25 + hay_eaten * 0.7) / n, 20, 100)
		p.needs.water = clampf(p.needs.water - mins * Pet.WATER_DECAY * 0.35 + drunk * 0.8 / n, 20, 100)
		p.needs.fun = clampf(p.needs.fun - mins * Pet.FUN_DECAY * 0.35, 20, 100)
		p.energy = 100.0
		p.sugar = 0.0
		p.bladder = 20.0
	var potties := int(mins / 10.0)
	litter = minf(100, litter + potties * n * 8 * [1.0, 0.67, 0.45][tier("litter") - 1])
	if litter > 85:
		for i in mini(4, potties / 3):
			droppings.append([randf_range(FLOOR.position.x, FLOOR.end.x), randf_range(FLOOR.position.y, FLOOR.end.y)])
	focus = minf(focus_max(), focus + seconds / Catalog.FOCUS_REFILL)
	if club_stage >= 2:
		coat = maxf(0, coat - mins / 60.0 * (3.0 if molting() else 1.0))
		nails = minf(100, nails + 12.0 * mins / (24 * 60))
	if bowls_eaten > 0:
		notes.append(tr_n("ate %d bowl of pellets", "ate %d bowls of pellets", bowls_eaten) % bowls_eaten)
	if hay_eaten > 5:
		notes.append(tr("munched through some hay"))
	if potties > 0:
		notes.append(tr_n("used the litter box %d time", "used the litter box %d times", potties) % potties)
	notes.append(tr("had a good long nap"))
	var hours := int(mins / 60)
	var away := (tr("%d h %d min") % [hours, int(mins) % 60]) if hours > 0 else (tr("%d min") % int(mins))
	welcome_text = tr("Welcome back! You were away %s.\n\nMeanwhile Bubák %s.") % [away, ", ".join(PackedStringArray(notes))]
	if hay < 15 or bowl == 0 or water < 20:
		welcome_text += "\n\n" + tr("He's looking at his empty bowls rather pointedly...")
