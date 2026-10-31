extends Node
## Everything that gets saved: Bubák's needs, trust, money, inventory and the room.

signal changed
signal toast(text: String)
signal trust_level_up(level: int)
signal trust_day_full   # Bubák's trust can't grow any more today
signal discovered(behaviour: String)
signal item_added(entry: Dictionary)
signal item_removed(uid: int)   # put away in the toy chest
signal balcony_milestone
signal goal_completed(id: String)
signal sponsor_paid(amount: int, streak: int)
signal welcome(text: String)   # something to say after the app comes back from the background
signal club_unlocked(stage: int)
signal mate_unlocked
signal mate_trust_up(level: int)
signal wish_new(text: String)
signal wish_granted(coins: int, streak: int, bonus: bool)
signal memory_added(entry: Dictionary, snap: bool)   # main.gd takes a snapshot for it
signal milestone(m: Dictionary)   # Days together: a milestone reached
signal fame_up(level: int)
signal style_changed
signal foster_offer(id: String)        # the rescue has a foster bunny for you
signal foster_home_found               # the foster bunny trusts you enough: a family wants them
signal foster_trust_up(level: int)
signal bond_missed(loss: float, days: int)   # trust lost to days away (Bonded and up)
signal league_ended(result: Dictionary)
signal merch_opened
signal item_worn(uid: int, wear: float)        # an item got more worn (0..1)
signal item_broken(id: String)                 # loved to pieces: gone, buy a new one
signal daily_task_done(id: String, coins: int)
signal sticker_got(count: int, page: bool)    # all of today's tasks done
signal season_found(id: String, season: String)   # this season's find (an item id)
signal dug_up(res: Dictionary)                 # something from the dig box (see dig_find)
signal postcard_arrived(card: Dictionary)
signal trait_up(id: String, level: int, who: String)
signal album_page_done(page: int)
signal duel_offered(rival: String)
signal rival_arrived(rival: String)          # the newcomer turns up
signal games_ended(result: Dictionary)
signal challenge_ended(id: String, ok: bool)
signal ladder_step_done(step: int, done: bool)
signal certificate(trick: String)             # an advanced trick mastered

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
var grass := 100.0       # wheatgrass in the balcony tray
var seeds := 0.0         # bird seed in the feeder, 0..100
var watered := {}        # "herbs" / "grass" -> unix time the watering wears off (grows 3x faster till then)
var placed: Array = []   # [{uid, id, x, y}, ...]
var stored: Array = []   # put away in the toy chest: [{uid, id, (bites)}, ...]
var next_uid := 1
var seen := {}           # behaviour -> unix time first seen
var photos: Array = []   # [{file, behaviour, likes, coins, time}, ...]
var photo_recent := {}   # behaviour -> unix time last photographed
var walk_day := ""        # the day of the last walk (one a day)
var walk_places: Array = []   # places visited on walks
var birthday := ""            # "MM-DD": Bubák's birthday (shown in the Journal)
var presents: Array = []      # presents already unwrapped, e.g. "christmas-2026"
var tree_pos: Vector2 = Catalog.TREE_SPOTS[0]   # where the Christmas tree stands this year (not saved)
var debug_date := ""
var wish := {}                # today's wish: {"day", "kind", "arg", "done", "cuddle"}
var wish_streak := 0          # days in a row with the wish granted
var wish_last_done := ""      # the day of the last granted wish
var photo_challenges := {}    # challenge id -> photo file
var memories: Array = []      # the scrapbook: {"id", "time", "text", "args", "file"}
var fav_counts := {"toy": {}, "nap": {}, "walk": {}}
var favourites := {}          # "toy" / "nap" / "walk" -> id
var garden: Array = []        # the veggie patch beds: {"crop", "grow" 0..1}
var eggs_year := 0            # Easter: the eggs found this year
var eggs_found := 0
var vet_last := 0.0           # unix time of the last check-up at the vet
var guest_day := ""           # the day a friend's bunny last came over
var greet_pending := false    # back after a while: he comes to say hello (not saved)
var days_played := 0          # Days together: the days you played
var last_play_day := ""
var milestones_got: Array = []   # days of the milestones already given
var fame := -1                # the highest Catalog.FAME step reached
var cover := ""               # the photo on the magazine cover
var souvenirs := {}           # souvenir id -> how many found
var room_style := "cream"     # the flat's wallpaper and floor
var styles: Array = ["cream"]          # "MM-DD" from --date=, to try out the special days (not saved)
var feed := 1.0           # followers' attention (0-1) at feed_time; see feed_attention()
var feed_time := 0.0
var work_ready_at := 0.0
var stats := {"pets": 0, "treats": 0, "photos": 0, "work": 0}
var created_at := 0.0
var welcome_text := ""
var life_goes_on := true   # setting: does time pass for Bubák while the game is closed?
var fast_game := false     # setting: the original quick pace (see Catalog.FAST_*)
var _paused_at := 0.0
var language := "cs"
var upgrades := {"bowl": 1, "water": 1, "hayrack": 1, "litter": 1, "chair": 0, "monitor": 0, "coffee": 0, "headphones": 0}
var wardrobe: Array = []     # accessories owned
var wearing := {}            # place (Catalog.WEAR_PLACES) -> accessory Bubák has on
var mate_wearing := {}       # the same for his friend (each accessory is on one bunny at a time)
var career_xp := 0
var job_best := {}   # job id -> {"score": best points, "stars": best stars}
var job_tired := {}  # job id -> {"n": recent shifts, "t": when the last one ended}
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
var routine: Array = []      # the trick routine for Tricks shows, in order (empty: picked for him)
var agility := 0.0           # agility skill 0..100, from practice runs
# the late game
var foster: Pet = null       # a foster bunny living with you for now
var fosters_done: Array = [] # [{id, time}] foster bunnies that found a home
var foster_next := ""        # the day the rescue can send the next one
var foster_offer_day := ""   # the day the rescue last asked
var league_season := ""      # "YYYY-MM"
var league_points := 0
var league_history: Array = []   # [{season, place, points}]
var merch := {}              # product -> {stock, photo, likes, design_at, sold, part}
var merch_pending := 0.0     # sales not collected yet (coins)
var merch_earned := 0
var merch_told := false
var daily := {}               # today's tasks: {"day", "tasks": [{"id", "base"}], "done": [ids]}
var stickers: Array = []      # the days all tasks were done
var season_finds: Array = []  # "autumn-2026"... the seasons whose find was found
var finds := {}               # dig box finds: id -> how many
var map_pieces := 0
var treasure := {}            # a complete map: {"x", "y"} where it's buried
var postcards: Array = []     # [{"id", "n", "fi" (index in fosters_done), "time"}]
var traits := {}              # personality: trait -> points
var trait_told := {}          # trait -> the level last announced
var last_exercise := 0.0
var album := {}               # album slot -> {"file", "likes"}
var album_pages: Array = []   # pages already completed (indices)
var vacc_at := 0.0            # the last vaccination (unix time)
var kid_day := ""             # the day the neighbours' child last came round
var duel := {}                # a rival's challenge: {"rival", "cat", "tier", "until"}
var last_routine: Array = []  # the routine at the last Tricks show (the nemesis studies it)
var newcomer_told := false
var games := {}               # this month's Games: {"month", "rounds": {cat: score}, "rivals": {id: {cat: score}}, "last_day", "done"}
var games_history: Array = [] # [{"month", "place"}]
var challenge := {}           # this week's challenge: {"id", "start", "days": [], "seen": [], "failed"}
var challenge_week := -1      # the week a challenge was last taken (one a week)
var challenge_last := {}      # how the last one went: {"id", "ok"}
var advent := {}              # {"year", "opened": [days]}
var ladder := {}              # this season's ladder: {"key", "step", "base"}
var certificates: Array = []  # advanced tricks mastered
var book_written: Array = []  # chapter ids
var book_published := false
var agility_daily := {}       # {"day", "best" (seconds), "ghost": [distance every GHOST_STEP s]}
var _foster_home_told := false
# Each rabbit learns and grooms on their own. The plain vars above (tricks, coat, traits...) belong to
# `performer`: Bubák, or his friend while the club or a walk is busy with the friend. The other
# rabbit's are kept in _other_skills meanwhile (set_performer swaps them).
const PET_SKILLS := ["tricks", "focus", "certificates", "coat", "nails", "agility", "traits", "trait_told",
	"last_exercise", "walk_day", "routine", "last_routine", "show_ready_at"]
var performer: Pet = bubak    # not saved: always Bubák outside the club and walks
var _other_skills := {}
var _skip_days_away := false   # a named save was just loaded, or a save from before days away counted: no trust lost for the gap
var _merch_t := 0.0
var seed_found := false        # the last pick turned up a golden seed (not saved)
var _cozy_points := 0
var _defaults := {}
var save_path := SAVE_PATH   # the playtest, demo and test play keep their own save
var test_mode := false       # test play: everything unlocked, no waiting
var _home_path := SAVE_PATH  # the save test play returns to
var photo_dir := PHOTO_DIR    # scratch games (playtest, demo...) keep their photos and named saves apart
var saves_dir := SAVES_DIR
var _slow_t := 0.0

var _save_timer := 0.0


func _ready() -> void:
	bubak.trust_level_up.connect(func(l): trust_level_up.emit(l))
	bubak.trust_day_full.connect(func(): trust_day_full.emit())
	trust_level_up.connect(func(l): remember("trust_%d" % l, "%s now feels %s with you.", ["Bubák", Catalog.TRUST_LEVELS[l].name]))
	_defaults = to_dict().duplicate(true)
	_load_settings()
	DirAccess.make_dir_recursive_absolute(photo_dir)
	DirAccess.make_dir_recursive_absolute(saves_dir)
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
	birthday = _pick_birthday()
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
		_watch_weight(p)
	if mate and bubak.mood(cozy) > 50 and mate.mood(cozy) > 50:
		bond = minf(100, bond + 0.5 * m)   # about 3 hours of contented living to bond fully
	herbs = minf(100, herbs + 4.0 * m * _growth("herbs"))
	_grow_garden(m * _growth("garden"))
	grass = minf(100, grass + 2.5 * m * _growth("grass"))
	if balcony == "locked" and trust_level() >= Catalog.BALCONY_TRUST and followers >= Catalog.BALCONY_FOLLOWERS:
		balcony = "available"
		balcony_milestone.emit()
		save_game()
	_age_skills(m, delta * (60.0 if test_mode else 1.0))

	_slow_t += delta
	if _slow_t > 1.0:
		_slow_t = 0.0
		_recount_cozy()
		_check_club()
		_check_mate()
		_check_fame()
		_check_foster()
		_check_league()
		_check_daily()
		_check_letters()
		_check_album()
		_check_rivals()
		_check_games()
		_check_challenge()
		_check_ladder()
		if not merch_told and merch_open():
			merch_told = true
			save_game()
			merch_opened.emit()
	_merch_t += delta
	if _merch_t > 10.0:
		_sell_merch(_merch_t / 3600.0)
		_merch_t = 0.0
		for g in Catalog.GOALS:
			if not g.id in goals_notified and goal_done(g):
				goals_notified.append(g.id)
				goal_completed.emit(g.id)
	for p in pets:
		if trait_level("athlete", p) >= 2 and Time.get_unix_time_from_system() - float(skill(p, "last_exercise")) > 3 * 3600.0:
			p.needs.fun = maxf(0, p.needs.fun - 0.4 * m)   # restless: an athlete needs a run
	_save_timer += delta
	if _save_timer > 20.0:
		_save_timer = 0.0
		save_game()
	changed.emit()


## Coats dull and nails grow (from when grooming opens up), and focus comes back, for both rabbits.
## mins: time passed in minutes; focus_secs: seconds of focus refill.
func _age_skills(mins: float, focus_secs: float, coat_rate := -1.0) -> void:
	var rate := coat_rate if coat_rate >= 0.0 else (6.0 if molting() else 2.0)   # per hour
	for p in pets:
		var s := {"coat": skill(p, "coat"), "nails": skill(p, "nails"), "focus": skill(p, "focus")}
		if club_stage >= 2:
			s.coat = maxf(0, s.coat - rate * mins / 60.0)
			s.nails = minf(100, s.nails + 12.0 * mins / (24 * 60))
		s.focus = minf(focus_max(), s.focus + focus_secs / Catalog.FOCUS_REFILL) if s.focus < focus_max() else s.focus
		for k in s:
			if _is_performer(p):
				set(k, s[k])
			else:
				_other_skills[k] = s[k]


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
	if Catalog.MEMORY_FIRSTS.has(behaviour):
		remember("b_" + behaviour, Catalog.MEMORY_FIRSTS[behaviour])


func has_item(id: String) -> bool:
	for e in placed:
		if e.id == id:
			return true
	return false


# ---- balcony garden -----------------------------------------------------------

func _growth(what: String) -> float:
	return 3.0 if watered.get(what, 0.0) > Time.get_unix_time_from_system() else 1.0


func is_watered(what: String) -> bool:
	return _growth(what) > 1.0


## Waters the planter or the grass tray: it grows back three times as fast for 15 minutes.
func water_plant(what: String) -> void:
	watered[what] = Time.get_unix_time_from_system() + 15 * 60
	save_game()


## Picks herbs from the planter for treats. Returns what was picked, or {} if there wasn't enough.
func harvest_herbs() -> Dictionary:
	if herbs < 60:
		return {}
	var got := {"parsley": 2}
	if herbs >= 95:
		got.dandelion = 1   # a full planter has a dandelion or two in it too
	herbs -= 45
	for id in got:
		inventory[id] = inventory.get(id, 0) + got[id]
	stats.harvests = stats.get("harvests", 0) + 1
	save_game()
	changed.emit()
	return got


func fill_feeder() -> void:
	seeds = 100.0
	save_game()


## How many balcony-only things are set up out there.
func outdoor_count() -> int:
	var n := 0
	for e in placed:
		if Catalog.ITEMS[e.id].get("outdoor", false):
			n += 1
	return n


## Owned, whether out in the flat or in the toy chest.
func count_item(id: String) -> int:
	var n := 0
	for e in placed + stored:
		if e.id == id:
			n += 1
	return n


# ---- toy chest and clutter -------------------------------------------------------

## How much floor space the things in a room take up.
func room_clutter(room: String) -> int:
	var n := 0
	for e in placed:
		if room_at(Vector2(e.x, e.y)) == room:
			n += Catalog.ITEMS[e.id].get("space", 1)
	return n


func room_space(room: String) -> int:
	return Catalog.ROOM_SPACE.get(room, 16)


## Space units over the limit in a room (0 = tidy enough).
func clutter_over(room: String) -> int:
	return maxi(0, room_clutter(room) - room_space(room))


## Cozy points lost to clutter, all rooms together.
func clutter_penalty() -> int:
	return Catalog.CLUTTER_COZY * (clutter_over("living") + clutter_over("balcony"))


func _clutter_warning(room: String) -> void:
	if clutter_over(room) > 0:
		toast.emit(tr("It's getting cluttered in here! Too much stuff makes it less cozy (-%d). Put a few things away in the toy chest.") % (Catalog.CLUTTER_COZY * clutter_over(room)))


func put_away(uid: int) -> bool:
	for e in placed:
		if e.uid == uid:
			placed.erase(e)
			var keep := {"uid": e.uid, "id": e.id}
			if e.has("bites"):
				keep.bites = e.bites
			if e.has("wear"):
				keep.wear = e.wear
			stored.append(keep)
			_recount_cozy()
			save_game()
			item_removed.emit(uid)
			changed.emit()
			return true
	return false


func take_out(uid: int, room := "living") -> bool:
	for e in stored:
		if e.uid == uid:
			if Catalog.ITEMS[e.id].get("outdoor", false):
				room = "balcony"
			stored.erase(e)
			var spot := _free_spot(room)
			e.x = spot.x
			e.y = spot.y
			placed.append(e)
			_recount_cozy()
			save_game()
			item_added.emit(e)
			changed.emit()
			_clutter_warning(room)
			return true
	return false


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
	_cozy_points = maxi(0, pts - clutter_penalty())


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


## How many recent shifts of this job still count against its pay (wears off over time).
func job_fatigue(job: String) -> float:
	var t: Dictionary = job_tired.get(job, {"n": 0.0, "t": 0.0})
	return maxf(0.0, float(t.n) - (Time.get_unix_time_from_system() - float(t.t)) / Catalog.JOB_REST)


## Pay factor for doing this job now: 1.0 when fresh, less after repeating it.
func job_repeat_mult(job: String) -> float:
	return maxf(Catalog.JOB_REPEAT_FLOOR, 1.0 - Catalog.JOB_REPEAT_CUT * job_fatigue(job))


func note_shift(job: String) -> void:
	job_tired[job] = {"n": job_fatigue(job) + 1.0, "t": Time.get_unix_time_from_system()}


func work_pay_mult() -> float:
	return (1.0 + 0.15 * career_level() + 0.25 * tier("monitor") + 0.25 * tier("headphones")) \
		* (0.5 if challenge_on("budget") else 1.0)


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
	if g.n < 0:
		return Catalog.PHOTO_CHALLENGES.size() if g.type == "challenges" else Catalog.BEHAVIOUR_ORDER.size()
	return g.n


func goal_value(g: Dictionary) -> int:
	match g.type:
		"photos": return stats.photos
		"seen": return seen.size()
		"days": return days_played
		"treats": return stats.treats
		"wishes": return stats.get("wishes", 0)
		"challenges": return photo_challenges.size()
		"memories": return memories.size()
		"vet": return stats.get("vet", 0)
		"crops": return stats.get("crops", 0)
		"guests": return stats.get("guests", 0)
		"souvenirs": return souvenirs.size()
		"styles": return styles.size()
		"work": return stats.work
		"followers": return followers
		"trust": return trust_level()
		"walks": return stats.get("walks", 0)
		"places": return walk_places.size()
		"cozy": return cozy_level()
		"upgrades": return upgrades_count()
		"wardrobe": return wardrobe.size()
		"outfit": return wearing.size()
		"career": return career_level()
		"jobstars": return job_best.values().filter(func(b): return int(b.stars) >= 3).size()
		"balcony": return 1 if balcony == "open" else 0
		"outdoor": return outdoor_count()
		"harvests": return stats.get("harvests", 0)
		"stars": return _best_of_pets(trick_stars_total)
		"mate": return 1 if mate else 0
		"bond": return int(bond)
		"grooms": return stats.get("grooms", 0)
		"ribbons": return trophies.size()
		"won": return best_win() + 1
		"fosters": return fosters_done.size()
		"league_top3": return league_history.filter(func(h): return int(h.place) <= 3).size()
		"league_wins": return league_history.filter(func(h): return int(h.place) == 1).size()
		"agility_wins": return trophies.filter(func(x): return x.cat == "agility" and x.place == 1).size()
		"agility": return _best_of_pets(func(): return int(agility))
		"routine": return stats.get("routine_max", 0)
		"merch": return merch_earned
		"stickers": return stickers.size()
		"basic_stars": return _best_of_pets(func(): return Catalog.BASIC_TRICKS.reduce(func(a, id): return a + trick_stars(id), 0))
		"certificates": return _best_of_pets(func(): return certificates.size())
		"duel_wins": return stats.get("duels_won", 0)
		"games_top3": return games_history.filter(func(h): return int(h.place) <= 3).size()
		"games_wins": return games_history.filter(func(h): return int(h.place) == 1).size()
		"challenges": return stats.get("challenges", 0)
		"ladders": return stats.get("ladders", 0)
		"book": return 1 if book_published else 0
		"album_pages": return album_pages.size()
		"finds": return finds.size()
		"treasures": return stats.get("treasures", 0)
		"seasons": return seasons_found()
		"trait_top": return _best_of_pets(func(): return Catalog.TRAIT_ORDER.map(trait_level).max())
		"postcards": return postcards.size()
		"hall_gold": return hall_of_fame().filter(func(h): return h.level >= Catalog.HALL_GOLD).size()
		"agility_days": return stats.get("agility_days", 0)
		"cats":
			var cats := {}
			for t in trophies:
				if t.place == 1:
					cats[t.cat] = true
			return cats.size()
	return 0


## Goals for parts of the game the player hasn't reached yet stay out of sight.
func goal_visible(g: Dictionary) -> bool:
	return club_stage >= g.get("stage", 0) and mate_stage >= g.get("mate", 0) and fame >= g.get("fame", -1) \
		and (not g.has("after") or g.after in goals_claimed)


func goal_done(g: Dictionary) -> bool:
	return goal_visible(g) and goal_value(g) >= goal_target(g)


func claimable_goals() -> int:
	var n := 1 if can_see_vet() else 0
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
	amount = int(mini(amount, 400) * (1.0 + 0.15 * (fame + 1)))   # famous bunnies get bigger deals
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
	if item.get("outdoor", false) and balcony != "open":
		return tr("For the balcony, once it's open")
	if days_played < item.get("req_days", 0):
		return tr("Opens after %d days together") % item.req_days
	if cozy_level() < item.get("req_cozy", 0):
		return tr("Needs Cozy level %d") % item.req_cozy
	if trust_level() < item.get("req_trust", 0):
		return tr("Needs trust: %s") % Catalog.level_name(item.req_trust)
	if trick_stars_total() < item.get("req_stars", 0):
		return tr("Needs %d trick stars") % item.req_stars
	if career_level() < item.get("req_career", 0):
		return tr("Needs career: %s") % Catalog.career_title(item.req_career)
	if item.has("slot") and item.tier > 1 and tier(item.slot) < item.tier - 1:
		return tr("Needs the previous upgrade")
	if item.has("req_item") and not has_item(item.req_item):
		return tr("Needs: %s") % Catalog.item_name(item.req_item)
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
	if item.kind == "style" and id.trim_prefix("style_") in styles:
		set_style(id.trim_prefix("style_"))
		return ""
	if coins < item.price:
		return tr("Not enough coins.")
	if item.has("slot"):
		upgrades[item.slot] = item.tier
	match item.kind:
		"wear":
			wardrobe.append(id)
			wearing[item.place] = id   # straight on
		"style":
			styles.append(id.trim_prefix("style_"))
			coins -= item.price
			set_style(id.trim_prefix("style_"))
			return ""
		"gear":
			gear.append(id)
		"food", "hay", "treat":
			inventory[id] = inventory.get(id, 0) + item.get("qty", 1)
		"toy", "decor":
			if item.get("outdoor", false):
				room = "balcony"
			if count_item(id) >= item.get("max", 1):
				return tr("You already have enough of those.")
			var spot := _free_spot(room)
			var entry := {"uid": next_uid, "id": id, "x": spot.x, "y": spot.y}
			if item.has("bites"):
				entry.bites = item.bites
			next_uid += 1
			placed.append(entry)
			item_added.emit(entry)
			_clutter_warning.call_deferred(room)   # after the purchase toast
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
	var taken: Array = [Vector2(420, 470), Vector2(1110, 470), Vector2(1040, 490), Vector2(95, 470), Vector2(905, 484)]
	if is_christmas():
		taken.append(tree_pos)
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
## ctx: what's in the shot, for the photo challenges: {"wear", "wearing", "room", "hour", "tree"}.
func record_photo(file: String, behaviour: String, decor_nearby: int, ctx := {}) -> Dictionary:
	var now := Time.get_unix_time_from_system()
	if behaviour == "":   # missed him: nothing worth posting
		var miss := {"file": file, "behaviour": "", "likes": 0, "coins": 0, "time": now}
		photos.append(miss)
		stats.photos += 1
		save_game()
		changed.emit()
		return miss.merged({"new": false, "stale": false, "followers": 0, "lost": 0, "attention": feed_attention()})
	var attention := feed_attention()
	var info: Dictionary = Catalog.BEHAVIOURS.get(behaviour, {"likes": 3})
	var likes: float = info.likes * randf_range(0.85, 1.2)
	likes *= 1.0 + 0.15 * mini(decor_nearby, 3)
	likes *= 1.0 + 0.1 * ctx.get("wear", wearing.size())   # every accessory helps a little
	likes *= minf(1.0 + followers / 400.0, 4.0)
	likes *= 1.0 + 0.08 * trait_level("showoff")   # a show-off knows his angles
	if coat_matted():
		likes *= 0.8   # a scruffy coat doesn't photograph well
	var is_new := behaviour != "" and not photo_recent.has(behaviour)
	var stale := not is_new and behaviour != "" and now - float(photo_recent[behaviour]) < 600
	if is_new:
		likes *= 1.8
	elif stale:
		likes *= 0.35
	photo_recent[behaviour] = now
	likes *= 0.15 + 0.85 * attention   # a crowded feed gets scrolled past
	feed = maxf(0.0, attention - Catalog.FEED_COST)
	feed_time = now
	var l := int(round(likes))
	var gained_coins := maxi(1, int(round(l / 5.0)))
	var gained_followers := int(l / 6.0 * (1.0 + 0.05 * (cozy_level() - 1)))
	var lost := 0
	if attention < Catalog.FEED_FLOODED and not test_mode:
		gained_followers = 0
		lost = mini(followers, maxi(1, int(followers * Catalog.FEED_UNFOLLOW * (1.5 if stale else 1.0))))
	coins += gained_coins
	followers += gained_followers - lost
	stats.photos += 1
	var done := _photo_challenges(file, behaviour, ctx)
	wish_event("photo")
	for id in done:
		coins += _challenge(id).reward
	var entry := {"file": file, "behaviour": behaviour, "likes": l, "coins": gained_coins, "time": now}
	photos.append(entry)
	if int(info.likes) >= 120:
		stats.rare_photos = stats.get("rare_photos", 0) + 1
	challenge_event("photo", behaviour)
	add_trait("showoff", 0.6)
	var new_slot := _album_put(behaviour, entry)
	var who: String = ctx.get("subject", "")
	if Catalog.FOSTERS.has(who):
		new_slot = _album_put(who, entry) or new_slot
	save_game()
	changed.emit()
	remember("photo1", "First photo posted: %s.", [Catalog.BEHAVIOURS.get(behaviour, {"name": "Blurry"}).name], false)
	if memories[-1].id == "photo1" and memories[-1].file == "":
		memories[-1].file = file
	return entry.merged({"new": is_new, "stale": stale, "followers": gained_followers, "lost": lost, "attention": attention,
		"challenges": done, "album": new_slot})


## Followers' attention right now (0-1): used up by posting, comes back over time.
func feed_attention() -> float:
	if test_mode:
		return 1.0
	return clampf(feed + (Time.get_unix_time_from_system() - feed_time) / Catalog.FEED_REFILL, 0.0, 1.0)


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


## p: whose stars (null = the performer).
func trick_stars(id: String, p: Pet = null) -> int:
	var n := 0
	var t: Dictionary = skill(p, "tricks")
	for need in Catalog.TRICK_STARS:
		if t.get(id, 0.0) >= need:
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
	if performer.trust_level() < t.level:
		return tr("Needs trust: %s") % Catalog.level_name(t.level)
	if t.has("gear") and not t.gear in gear:
		return tr("Needs: %s") % Catalog.item_name(t.gear)
	if t.has("after") and trick_stars(t.after) < Catalog.ADVANCED_AFTER:
		return tr("Needs %s with %d stars") % [Catalog.trick_name(t.after), Catalog.ADVANCED_AFTER]
	if t.has("item") and count_item(t.item) == 0:
		return tr("Needs: %s") % Catalog.item_name(t.item)
	return ""


func focus_max() -> int:
	return Catalog.FOCUS_MAX + (3 if "pouch" in gear else 0)


## Chance he gets a trick right. Shows are more nerve-racking the bigger they are.
func trick_chance(id: String, show_tier := -1) -> float:
	var s := trick_stars(id)
	var hard := 0.8 if Catalog.TRICKS[id].get("advanced", false) else 1.0   # advanced tricks go wrong more often
	if show_tier >= 0:
		return clampf((0.4 + 0.18 * s - 0.05 * show_tier) * hard, 0.1, 0.95)
	return clampf((0.35 + 0.2 * s + 0.03 * performer.trust_level()) * hard, 0.1, 0.95)


## One training try. result: "good" (rewarded in time), "late", "wrong" (rewarded a
## mistake) or "none". Returns how many stars the trick gained.
func train(id: String, result: String) -> int:
	if not Catalog.TRICKS.has(id):
		return 0
	var before := trick_stars(id)
	var amount: float = {"good": 25.0, "late": 8.0, "wrong": -6.0}.get(result, 0.0)
	if result == "good":
		amount *= 1.5 if "clicker" in gear else 1.0
		performer.add_trust(0.3)
	tricks[id] = clampf(tricks.get(id, 0.0) + amount, 0, Catalog.TRICK_STARS[-1])
	stats.training = stats.get("training", 0) + 1
	if Catalog.TRICKS[id].get("advanced", false) and trick_stars(id) == 3 and not id in certificates:
		certificates.append(id)
		coins += Catalog.CERTIFICATE_COINS
		if performer == bubak:
			remember("cert_" + id, "A master's certificate: %s!", [Catalog.TRICKS[id].name])
		else:
			remember("cert_%s_%s" % [id, performer.id], "%s earned a master's certificate: %s!", [performer.display_name(), Catalog.TRICKS[id].name])
		certificate.emit.call_deferred(id)
	add_trait("showoff", 0.5)
	performer.add_need("fun", 2)
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
	wish_event("brush")
	performer.add_trust(0.5)
	save_game()
	changed.emit()


## Returns "" when it went fine, otherwise what went wrong.
func trim_nails() -> String:
	if performer.trust_level() < 2:
		performer.add_trust(-1.5)
		return tr("%s kicks and squirms away: a nail trim needs more trust than this.\n(Trust went down.)") % performer.display_name()
	nails = 0.0
	performer.add_trust(0.2)
	save_game()
	return ""


## How show-ready he looks, 0..100: coat, nails and how content he is.
func condition() -> float:
	var fit: float = [0.65, 0.85, 1.0, 0.85, 0.65][performer.weight_band()]   # judges check the figure too
	return (coat * 0.55 + (100.0 - nails) * 0.2 + performer.mood() * 0.25) * fit


var _weight_bands := {}   # pet id -> last weight band seen


## Says so when a rabbit's weight moves into another band.
func _watch_weight(p: Pet) -> void:
	var band := p.weight_band()
	var was: int = _weight_bands.get(p.id, band)
	_weight_bands[p.id] = band
	if band == was:
		return
	var who := p.display_name()
	if band == 2:
		toast.emit(tr("%s is back to a healthy weight. Well done!") % who)
	elif band > was and band >= 3:
		toast.emit((tr("%s is getting a bit chubby. Fewer treats and more exercise: toys, playtime and walks.")
			if band == 3 else tr("%s is overweight! Fewer treats, and lots of toys and walks.")) % who)
	elif band < was and band <= 1:
		toast.emit((tr("%s is getting a bit thin. Keep the bowls and hay rack full.")
			if band == 1 else tr("%s is underweight! Full bowls and plenty of hay, please.")) % who)


## What a rabbit has on: Bubák's outfit, his friend's, or nothing (fosters don't dress up).
func wearing_of(p: Pet) -> Dictionary:
	if p == null or p.is_bubak():
		return wearing
	return mate_wearing if p == mate else {}


## Best in Show's style mark: 20 with nothing on, about 98 in the fanciest full outfit.
func style_score(who: Pet = null) -> float:
	var s := 0.0
	for id in wearing_of(who).values():
		s += Catalog.ITEMS[id].style
	return minf(100.0, 20.0 + 0.4 * s)


## What he has on, in drawing order (neck first, hat last).
func outfit() -> Array:
	var out := []
	for place in Catalog.WEAR_PLACES:
		if wearing.has(place):
			out.append(wearing[place])
	return out


## Puts an owned accessory on (replacing whatever was in its place), or takes it off.
## who: Bubák (null) or his friend; there's one of each accessory, so it comes off the other bunny.
func toggle_wear(id: String, who: Pet = null) -> void:
	var place: String = Catalog.ITEMS[id].place
	var w := wearing_of(who)
	var other := mate_wearing if is_same(w, wearing) else wearing
	if w.get(place, "") == id:
		w.erase(place)
	elif id in wardrobe:
		w[place] = id
		if other.get(place, "") == id:
			other.erase(place)
	save_game()
	changed.emit()


## His fanciest accessory (for the judges' comments), or "".
func best_accessory() -> String:
	var best := ""
	for id in wearing_of(performer).values():
		if best == "" or Catalog.ITEMS[id].style > Catalog.ITEMS[best].style:
			best = id
	return best


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
			return clampf(condition() * 0.45 + style_score(performer) * 0.25 + performer.trust * 0.3 + 2.0 * trait_level("showoff"), 0, 100)
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
	return cat_problem(cat)


## What a category needs from Bubák, at any show, duel or the Games ("" if he's ready).
func cat_problem(cat: String) -> String:
	if cat == "tricks" and trick_stars_total() == 0:
		return tr("%s doesn't know any tricks yet.") % performer.display_name()
	if cat == "photo" and best_photo().is_empty():
		return tr("Take some photos first.")
	if cat == "agility" and count_item("hurdles") == 0:
		return tr("Needs Hop hurdles (Shop) to practise on.")
	if vaccine_overdue():
		return tr("First the yearly vaccination at the vet (Journal > Bubák).")
	return ""


func enter_show(t: int, cat: String) -> String:
	var err := show_problem(t, cat)
	if err != "":
		return err
	coins -= Catalog.SHOW_TIERS[t].fee
	show_ready_at[str(t)] = Time.get_unix_time_from_system() + Catalog.SHOW_TIERS[t].wait
	stats.shows = stats.get("shows", 0) + 1
	challenge_event("show")
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
		trophies.append({"tier": t, "cat": cat, "place": place, "time": Time.get_unix_time_from_system(), "pet": performer.id})
		remember("ribbon1", "First ribbon at a show!")
	_check_league()
	res.league = Catalog.LEAGUE_POINTS[clampi(place, 1, 4) - 1] * Catalog.LEAGUE_TIER[t]
	league_points += res.league
	add_trait("showoff", 6.0)
	performer.add_trust(1.0)
	_recount_cozy()
	save_game()
	changed.emit()
	return res


func duration_text(seconds: float) -> String:
	var mins := int(ceil(seconds / 60.0))
	return tr("%d h %d min") % [mins / 60, mins % 60] if mins >= 60 else tr("%d min") % mins


# ---- a mate for Bubák -------------------------------------------------------------

func _set_mate(p: Pet) -> void:
	set_performer(bubak)
	mate = p
	pets = [bubak] if p == null else [bubak, p]
	_other_skills = fresh_skills() if p else {}
	if p:
		p.trust_level_up.connect(func(l): mate_trust_up.emit(l))
		p.settle_level()


# ---- who's performing -------------------------------------------------------------------

## A new rabbit's skills: nothing learnt yet.
static func fresh_skills() -> Dictionary:
	return {"tricks": {}, "focus": float(Catalog.FOCUS_MAX), "certificates": [], "coat": 70.0, "nails": 20.0, "agility": 0.0,
		"traits": {}, "trait_told": {}, "last_exercise": 0.0, "walk_day": "", "routine": [], "last_routine": [], "show_ready_at": {}}


## Makes p (Bubák or his friend) the one the club, the walks and the stage work with.
func set_performer(p: Pet) -> void:
	if p == null or (p != bubak and p != mate):
		p = bubak
	if p == performer:
		return
	var mine := {}
	for k in PET_SKILLS:
		mine[k] = get(k)
	var fresh := fresh_skills()
	for k in PET_SKILLS:
		set(k, _other_skills.get(k, fresh[k]))
	_other_skills = mine
	performer = p


func _is_performer(p: Pet) -> bool:
	return (p if p else performer) == performer


## One of a rabbit's own skills (PET_SKILLS), wherever it's kept right now. p: null = the performer.
func skill(p: Pet, key: String) -> Variant:
	if p and p != bubak and p != mate:
		return fresh_skills()[key]   # a foster: nothing of their own here
	return get(key) if _is_performer(p) else _other_skills.get(key, fresh_skills()[key])


## All of a rabbit's skills, for saving.
func skills_of(p: Pet) -> Dictionary:
	var out := {}
	for k in PET_SKILLS:
		out[k] = skill(p, k)
	return out


## Runs f with p as the performer for a moment (e.g. to count the friend's trick stars).
func for_pet(p: Pet, f: Callable) -> Variant:
	var was := performer
	set_performer(p)
	var r: Variant = f.call()
	set_performer(was)
	return r


## The value for whichever rabbit does better (goals count either).
func _best_of_pets(f: Callable) -> int:
	var best := 0
	for p in pets:
		best = maxi(best, int(for_pet(p, f)))
	return best


## A loaded rabbit's skills, with the numbers as numbers again.
func _clean_skills(raw: Dictionary) -> Dictionary:
	var out := fresh_skills()
	out.merge(raw, true)
	for k in ["focus", "coat", "nails", "agility", "last_exercise"]:
		out[k] = float(out[k])
	var t := {}
	for k in out.tricks:
		t[k] = float(out.tricks[k])
	out.tricks = t
	var tr_ := {}
	for k in out.traits:
		tr_[k] = float(out.traits[k])
	out.traits = tr_
	var told := {}
	for k in out.trait_told:
		told[k] = int(out.trait_told[k])
	out.trait_told = told
	out.walk_day = str(out.walk_day)
	return out


# ---- special days ------------------------------------------------------------------

## "MM-DD" of a moment, in local time.
static func _month_day(unix: float) -> String:
	var d := Time.get_date_dict_from_unix_time(int(unix) + Time.get_time_zone_from_system().bias * 60)
	return "%02d-%02d" % [d.month, d.day]


## A day some months away, so the first birthday is something to look forward to.
func _pick_birthday() -> String:
	var md := _month_day(Time.get_unix_time_from_system() + randi_range(30, 335) * 86400)
	return "02-28" if md == "02-29" else md   # a birthday every year, not every four


func today() -> String:
	return debug_date if debug_date != "" else _month_day(Time.get_unix_time_from_system())


func is_christmas() -> bool:
	return today() >= Catalog.CHRISTMAS[0] and today() <= Catalog.CHRISTMAS[1]


func is_halloween() -> bool:
	return today() >= Catalog.HALLOWEEN[0] and today() <= Catalog.HALLOWEEN[1]


## Easter Sunday this year (the Gregorian computus), as "MM-DD" for Saturday to Monday.
static func easter_days(year: int) -> Array:
	var a := year % 19
	var b := floori(year / 100.0)
	var c := year % 100
	var d := floori(b / 4.0)
	var e := b % 4
	var f := floori((b + 8) / 25.0)
	var g := floori((b - f + 1) / 3.0)
	var h := (19 * a + b - d - g + 15) % 30
	var i := floori(c / 4.0)
	var k := c % 4
	var l := (32 + 2 * e + 2 * i - h - k) % 7
	var m := floori((a + 11 * h + 22 * l) / 451.0)
	var month := floori((h + l - 7 * m + 114) / 31.0)
	var day := (h + l - 7 * m + 114) % 31 + 1
	var sunday := Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": day, "hour": 12})
	return [-1, 0, 1].map(func(o): return Time.get_date_string_from_unix_time(sunday + o * 86400).substr(5))


func is_easter() -> bool:
	return today() in easter_days(Time.get_date_dict_from_system().year)


func years_together() -> int:
	return Time.get_date_dict_from_system().year - Time.get_date_dict_from_unix_time(int(created_at)).year


## Today's special day, or "": his birthday, the day you met, Christmas, Easter or Halloween.
func special_day() -> String:
	if today() == birthday:
		return "birthday"
	if today() == _month_day(created_at) and years_together() >= 1:
		return "anniversary"
	if is_christmas():
		return "christmas"
	if is_easter():
		return "easter"
	return "halloween" if is_halloween() else ""


## Easter: the eggs still hidden around the flat this year.
func eggs_left() -> int:
	if eggs_year != Time.get_date_dict_from_system().year:
		return Catalog.EASTER_EGGS
	return maxi(0, Catalog.EASTER_EGGS - eggs_found)


func find_egg() -> int:
	var year: int = Time.get_date_dict_from_system().year
	if eggs_year != year:
		eggs_year = year
		eggs_found = 0
	eggs_found += 1
	save_game()
	return eggs_left()


func _present_key(ev: String) -> String:
	return "%s-%d" % [ev, Time.get_date_dict_from_system().year]


## The special day whose present is still wrapped, or "".
func present_waiting() -> String:
	var ev := special_day()
	if ev == "easter" and eggs_left() > 0:
		return ""   # find all the eggs first
	return ev if ev != "" and not _present_key(ev) in presents else ""


## What's in this year's present: the event's gift, or a toy he hasn't got yet, or else treats.
func _gift_for(ev: String) -> String:
	var gift: String = Catalog.EVENTS[ev].gift
	if gift != "" and not (gift in wardrobe or count_item(gift) > 0):
		return gift
	for id in Catalog.SHOP_TABS.Toys:
		if count_item(id) == 0 and lock_reason(id) == "":
			return id
	return Catalog.PRESENT_TREATS


## Bubák unwraps today's present. A toy lands at `at`, a hat goes straight on.
## Returns {"event", "id", "uid"} (uid of the new toy, or -1), or {} if there's nothing to open.
func open_present(at: Vector2) -> Dictionary:
	var ev := present_waiting()
	if ev == "":
		return {}
	presents.append(_present_key(ev))
	var id := _gift_for(ev)
	var item: Dictionary = Catalog.ITEMS[id]
	var res := {"event": ev, "id": id, "uid": -1}
	match item.kind:
		"wear":
			wardrobe.append(id)
			wearing[item.place] = id
		"toy":
			var entry := {"uid": next_uid, "id": id, "x": at.x, "y": at.y}
			res.uid = next_uid
			next_uid += 1
			placed.append(entry)
			item_added.emit(entry)
		_:
			inventory[id] = inventory.get(id, 0) + 3
	bubak.add_trust(Catalog.PRESENT_TRUST, false)
	bubak.add_need("fun", 40)
	stats.presents = stats.get("presents", 0) + 1
	var year := str(Time.get_date_dict_from_system().year)
	match ev:
		"christmas":
			remember("christmas_" + year, "Christmas %s: a %s under the tree.", [year, item.name])
		"birthday":
			remember("birthday_" + year, "Birthday %s: a %s, and lots of binkies.", [year, item.name])
		"easter":
			remember("easter_" + year, "Easter %s: all the eggs found, and a %s.", [year, item.name])
		"halloween":
			remember("halloween_" + year, "Halloween %s: a %s. Spooky!", [year, item.name])
		"anniversary":
			remember("together_" + year, "%s years together! A present: %s.", [str(years_together()), item.name])
	save_game()
	changed.emit()
	return res


# ---- daily wishes --------------------------------------------------------------------

const TOY_WISHES := ["ball", "tunnel", "box", "hut", "digbox", "puzzle", "castle", "hurdles", "treat_ball",
	"jingle_ball", "egg_rattle"]


## A new day, a new wish (called now and then by main.gd).
func check_wish() -> void:
	var day := Time.get_date_string_from_system()
	if wish.get("day", "") == day:
		return
	var yesterday := Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) - 86400)
	if wish_last_done != yesterday and wish_last_done != day:
		wish_streak = 0
	var opts := [{"kind": "cuddle"}, {"kind": "photo"}]
	for t in Catalog.WISH_TREATS:
		if lock_reason(t) == "":
			opts.append({"kind": "treat", "arg": t})
	for e in placed:
		if e.id in TOY_WISHES and room_at(Vector2(e.x, e.y)) == "living":
			opts.append({"kind": "toy", "arg": e.id})
	if "leash" in gear:
		opts.append({"kind": "walk"})
	if balcony == "open":
		opts.append({"kind": "balcony"})
	if club_stage >= 2:
		opts.append({"kind": "brush"})
	var last: String = wish.get("kind", "")
	var fresh := opts.filter(func(o): return o.kind != last)
	wish = (fresh if not fresh.is_empty() else opts).pick_random().duplicate()
	wish.day = day
	wish.done = false
	wish.cuddle = 0.0
	save_game()
	wish_new.emit(wish_text())


## What he wishes for today, in words.
func wish_text() -> String:
	var arg: String = wish.get("arg", "")
	match wish.get("kind", ""):
		"treat": return tr("Today Bubák wishes for: %s, from your hand.") % Catalog.item_name(arg)
		"toy": return tr("Today Bubák wishes for: playtime with the %s.") % Catalog.item_name(arg).to_lower()
		"cuddle": return tr("Today Bubák wishes for: a long cuddle.")
		"photo": return tr("Today Bubák wishes for: a photo shoot.")
		"walk": return tr("Today Bubák wishes for: a walk.")
		"balcony": return tr("Today Bubák wishes for: fresh air on the balcony.")
		"brush": return tr("Today Bubák wishes for: a good brushing.")
	return ""


## Short, for the wish bubble: "Carrot", "Cuddle"...
func wish_short() -> String:
	var arg: String = wish.get("arg", "")
	match wish.get("kind", ""):
		"treat", "toy": return Catalog.item_name(arg)
		"cuddle": return tr("Cuddle")
		"photo": return tr("Photo shoot")
		"walk": return tr("Walk")
		"balcony": return tr("Balcony")
		"brush": return tr("Brushing")
	return ""


## Something happened that might be today's wish: kind as in check_wish, arg the treat/toy,
## amount the seconds of cuddling.
func wish_event(kind: String, arg := "", amount := 0.0) -> void:
	if wish.is_empty() or wish.get("done", true) or wish.kind != kind:
		return
	if kind == "cuddle":
		wish.cuddle = float(wish.get("cuddle", 0.0)) + amount
		if wish.cuddle < Catalog.WISH_CUDDLE:
			return
	elif wish.get("arg", "") != "" and arg != wish.arg:
		return
	wish.done = true
	wish_streak += 1
	wish_last_done = Time.get_date_string_from_system()
	var c: int = Catalog.WISH_REWARD + 5 * mini(wish_streak - 1, 6)
	var bonus := wish_streak % Catalog.WISH_STREAK == 0
	coins += c
	if bonus:
		coins += Catalog.WISH_BONUS
		inventory["rose_petals"] = inventory.get("rose_petals", 0) + 2
		remember("wishweek_%d" % (wish_streak / Catalog.WISH_STREAK), "%s days of wishes come true in a row!", [str(wish_streak)])
	bubak.add_trust(1.0, false)
	bubak.add_need("fun", 15)
	stats.wishes = stats.get("wishes", 0) + 1
	save_game()
	wish_granted.emit(c + (Catalog.WISH_BONUS if bonus else 0), wish_streak, bonus)


# ---- the scrapbook -------------------------------------------------------------------

## A first worth keeping: once per id. text is translated when shown, with args (also translated).
func remember(id: String, text: String, args := [], snap := true) -> void:
	for m in memories:
		if m.id == id:
			return
	var e := {"id": id, "time": Time.get_unix_time_from_system(), "text": text, "args": args, "file": ""}
	memories.append(e)
	save_game()
	memory_added.emit(e, snap)


func memory_text(m: Dictionary) -> String:
	var args: Array = m.get("args", []).map(func(a): return tr(str(a)))
	return tr(m.text) % args if not args.is_empty() else tr(m.text)


# ---- photo challenges -----------------------------------------------------------------

func _challenge(id: String) -> Dictionary:
	for c in Catalog.PHOTO_CHALLENGES:
		if c.id == id:
			return c
	return {}


## The challenges this photo completes (newly), recorded with the photo.
func _photo_challenges(file: String, behaviour: String, ctx: Dictionary) -> Array:
	var done := []
	var hour: float = ctx.get("hour", 12.0)
	for c in Catalog.PHOTO_CHALLENGES:
		if photo_challenges.has(c.id):
			continue
		if c.has("behaviours") and not behaviour in c.behaviours:
			continue
		if ctx.get("wear", 0) < c.get("wear", 0):
			continue
		if c.has("wearing") and not c.wearing in ctx.get("wearing", []):
			continue
		if c.has("room") and ctx.get("room", "") != c.room:
			continue
		if c.get("night", false) and not (hour >= 21.0 or hour < 6.0):
			continue
		if c.get("evening", false) and not (hour >= 17.5 and hour < 21.0):
			continue
		if c.get("tree", false) and not ctx.get("tree", false):
			continue
		photo_challenges[c.id] = file
		done.append(c.id)
	return done


# ---- favourites ----------------------------------------------------------------------

## He picked this toy / napping spot / walk again: a favourite in the making.
func note_fav(kind: String, id: String) -> void:
	var c: Dictionary = fav_counts[kind]
	c[id] = int(c.get(id, 0)) + 1
	var best := ""
	var n := 0
	for k in c:
		if int(c[k]) > n:
			best = k
			n = int(c[k])
	if n < Catalog.FAV_AT[kind] or favourites.get(kind, "") == best:
		return
	favourites[kind] = best
	var raw: String = Catalog.WALKS[best].name if kind == "walk" else Catalog.ITEMS[best].name
	match kind:
		"toy":
			toast.emit(tr("Bubák has a favourite toy now: %s!") % tr(raw))
			remember("fav_toy_" + best, "A favourite toy: %s.", [raw])
		"nap":
			toast.emit(tr("Bubák has a favourite napping spot now: %s!") % tr(raw))
			remember("fav_nap_" + best, "A favourite napping spot: %s.", [raw])
		"walk":
			toast.emit(tr("Bubák has a favourite walk now: %s!") % tr(raw))
			remember("fav_walk_" + best, "A favourite walk: %s.", [raw])


# ---- the long run: days together, fame, souvenirs, makeovers ---------------------------------

## A day you play counts towards Days together (called with the daily checks).
func check_day() -> void:
	var day := Time.get_date_string_from_system()
	if last_play_day != day:
		if last_play_day != "" and last_play_day < day and not _skip_days_away:
			_missed_days(days_between(last_play_day, day) - 1)
		last_play_day = day
		days_played += 1
		save_game()
	_skip_days_away = false
	_check_milestones()


## Milestones reached and not given yet (also after an older save got credit for its days).
func _check_milestones() -> void:
	for m in Catalog.MILESTONES:
		if days_played >= m.days and not int(m.days) in milestones_got:
			milestones_got.append(int(m.days))
			coins += m.coins
			if m.has("gift"):
				_give(m.gift)
			remember("days_%d" % m.days, "%s days together!", [str(m.days)])
			save_game()
			milestone.emit(m)


## The next milestone to look forward to, or {}.
func next_milestone() -> Dictionary:
	for m in Catalog.MILESTONES:
		if not int(m.days) in milestones_got:
			return m
	return {}


## An item given as a reward: worn straight away, or set down in the flat.
func _give(id: String) -> void:
	var item: Dictionary = Catalog.ITEMS[id]
	if item.kind == "wear":
		if not id in wardrobe:
			wardrobe.append(id)
		wearing[item.place] = id
	elif count_item(id) < item.get("max", 1):
		var spot := _free_spot("living")
		var entry := {"uid": next_uid, "id": id, "x": spot.x, "y": spot.y}
		next_uid += 1
		placed.append(entry)
		item_added.emit(entry)


func fame_name(level := -2) -> String:
	var l := fame if level == -2 else level
	return tr(Catalog.FAME[l].name) if l >= 0 else ""


func _check_fame() -> void:
	while fame + 1 < Catalog.FAME.size() and followers >= Catalog.FAME[fame + 1].at:
		fame += 1
		remember("fame_%d" % fame, "Bubák is a %s now: %s followers!", [Catalog.FAME[fame].name, str(Catalog.FAME[fame].at)])
		if fame == Catalog.COVER_FAME:
			var best := {}
			for p in photos:
				if p.behaviour != "" and (best.is_empty() or int(p.likes) > int(best.likes)):
					best = p
			cover = best.get("file", "")
			if memories[-1].id == "fame_%d" % fame:
				memories[-1].file = cover
		save_game()
		fame_up.emit(fame)


## On a walk he may find a souvenir. Returns {"souvenir", "dupe", "set_done", "all_done"} or {}.
func _find_souvenir(place: String) -> Dictionary:
	var nose := trait_level("explorer")   # an explorer sniffs out more
	if not Catalog.SOUVENIRS.has(place) or (randf() > Catalog.SOUVENIR_CHANCE + 0.07 * nose and not test_mode):
		return {}
	var set_: Array = Catalog.SOUVENIRS[place]
	var id: String = set_[3] if randf() < Catalog.SOUVENIR_RARE + 0.03 * nose else set_.slice(0, 3).pick_random()
	var dupe := souvenirs.has(id)
	souvenirs[id] = int(souvenirs.get(id, 0)) + 1
	var res := {"souvenir": id, "dupe": dupe, "set_done": false, "all_done": false}
	if dupe:
		coins += 10
		return res
	if set_.all(func(s): return souvenirs.has(s)):
		res.set_done = true
		coins += Catalog.SET_REWARD
		remember("souv_" + place, "Every souvenir from the %s!", [Catalog.WALKS[place].name])
	if souvenirs.size() == Catalog.SOUVENIR_NAMES.size():
		res.all_done = true
		_give("curio")
		remember("souv_all", "The whole souvenir collection: a cabinet full of memories!")
	return res


func souvenir_name(id: String) -> String:
	return tr(Catalog.SOUVENIR_NAMES[id])


func set_style(s: String) -> void:
	room_style = s
	save_game()
	style_changed.emit()


# ---- the veggie patch ----------------------------------------------------------------

func garden_bed_count() -> int:
	return Catalog.GARDEN_BEDS + 2 * tier("garden")


func garden_beds() -> Array:
	while garden.size() < garden_bed_count():
		garden.append({"crop": "", "grow": 0.0})
	return garden


func _grow_garden(minutes: float) -> void:
	for b in garden:
		if b.crop != "":
			b.grow = minf(1.0, float(b.grow) + minutes / 60.0 / Catalog.CROPS[b.crop].hours)


func plant(bed: int, crop: String) -> void:
	if Catalog.CROPS[crop].get("seed", false):
		if inventory.get("golden_seed", 0) <= 0:
			return
		inventory.golden_seed -= 1
	garden_beds()[bed] = {"crop": crop, "grow": 0.0}
	save_game()


## Picks a ripe bed: returns how many were picked (0 if it isn't ripe yet).
func harvest(bed: int) -> int:
	var b: Dictionary = garden_beds()[bed]
	if b.crop == "" or b.grow < 1.0:
		return 0
	var n: int = Catalog.CROPS[b.crop].yield
	inventory[b.crop] = inventory.get(b.crop, 0) + n
	remember("harvest1", "First harvest from the veggie patch: %s!", [Catalog.ITEMS[b.crop].name])
	if b.crop == "golden_carrot":
		remember("golden_carrot", "A golden carrot from the veggie patch!")
	garden[bed] = {"crop": "", "grow": 0.0}
	stats.crops = stats.get("crops", 0) + 1
	seed_found = randf() < Catalog.SEED_CHANCE or (test_mode and stats.crops == 1)
	if seed_found:
		inventory["golden_seed"] = inventory.get("golden_seed", 0) + 1
	save_game()
	return n


# ---- the vet ----------------------------------------------------------------------------

func vet_due() -> bool:
	return Time.get_unix_time_from_system() - (vet_last if vet_last > 0 else created_at) >= Catalog.VET_DAYS * 86400.0


## The weekly check-up: [{"pet", "checks": [[ok, text]...]}], plus the fee the vet's
## "healthy bunny" sticker earns (more when all is well).
func vet_checkup() -> Dictionary:
	var report := []
	var oks := 0
	var total := 0
	for p in pets:
		var checks := []
		var band: int = p.weight_band()
		checks.append([band == 2, tr("Weight: %s kg, %s.") % [Catalog.kilos(p.weight), Catalog.weight_name(band).to_lower()]
			if band == 2 else tr("Weight: %s kg, %s. More exercise and fewer sweets, please.") % [Catalog.kilos(p.weight),
				Catalog.weight_name(band).to_lower()] if band > 2 else tr("Weight: %s kg, %s. A little more food, please.") % [
				Catalog.kilos(p.weight), Catalog.weight_name(band).to_lower()]])
		checks.append([hay > 20 or p.needs.food > 60, tr("Teeth: nice and short. Hay keeps them that way.")
			if hay > 20 or p.needs.food > 60 else tr("Teeth: needs more hay to chew on!")])
		checks.append([p.mood() > 50, tr("Mood: a happy, curious bunny.") if p.mood() > 50 else tr("Mood: a bit low. More play and cuddles!")])
		if club_stage >= 2:   # both rabbits get their nails and coat checked
			var pn: float = skill(p, "nails")
			var pc: float = skill(p, "coat")
			checks.append([pn < 70, tr("Nails: neat.") if pn < 70 else tr("Nails: too long. Time for the clippers.")])
			checks.append([pc > 40, tr("Coat: soft and shiny.") if pc > 40 else tr("Coat: needs a good brushing.")])
		checks.append([litter < 60 and droppings.size() <= 2, tr("Home: clean and fresh.") if litter < 60 and droppings.size() <= 2
			else tr("Home: the litter box needs cleaning.")])
		for c in checks:
			total += 1
			if c[0]:
				oks += 1
		report.append({"pet": p.display_name(), "checks": checks})
	vet_last = Time.get_unix_time_from_system()
	var reward := 20 + int(60.0 * oks / maxf(1, total))
	coins += reward
	var jab := vaccine_due()
	if jab:   # the yearly vaccination, paid out of the visit
		vacc_at = vet_last
		coins = maxi(0, coins - Catalog.VACCINE_COST)
		remember("vaccine_%d" % Time.get_date_dict_from_system().year, "The yearly vaccination: brave bunny!", [], false)
	stats.vet = stats.get("vet", 0) + 1
	if oks == total:
		remember("vet_healthy", "A perfect check-up at the vet: a healthy, happy bunny!")
	save_game()
	changed.emit()
	return {"report": report, "coins": reward, "all_ok": oks == total, "vaccine": jab}


# ---- walks -------------------------------------------------------------------------

func walk_open(place: String) -> bool:
	return test_mode or stats.get("walks", 0) >= Catalog.WALKS[place].after


func walked_today() -> bool:
	return not test_mode and walk_day == Time.get_date_string_from_system()


## Why a walk can't happen now ("" if it can).
func walk_problem(place: String) -> String:
	if not "leash" in gear:
		return tr("You need a harness and leash (Shop > Club).")
	if walked_today():
		return tr("%s has been out today already and is still dreaming about it. Next walk tomorrow!") % performer.display_name()
	if not walk_open(place):
		return tr_n("Opens after %d walk", "Opens after %d walks", Catalog.WALKS[place].after) % Catalog.WALKS[place].after
	if vaccine_overdue():
		return tr("First the yearly vaccination at the vet (Journal > Bubák).")
	return ""


## Off on a walk: trust (not slowed by the daily limit, within the daily maximum), lots of fun, and in the city some new fans.
## Returns {trust, followers, new}.
func go_walk(place: String) -> Dictionary:
	walk_day = Time.get_date_string_from_system()
	stats.walks = stats.get("walks", 0) + 1
	var is_new := not place in walk_places
	if is_new:
		walk_places.append(place)
	var before := performer.trust
	performer.add_trust(Catalog.WALK_TRUST, false)
	performer.add_need("fun", Catalog.WALK_FUN)
	performer.burn(Catalog.WALK_GRAMS)
	if performer == bubak:
		note_fav("walk", place)
	add_trait("athlete", 2.0)
	add_trait("explorer", 3.0)
	var found := _find_souvenir(place)
	wish_event("walk")
	if stats.walks == 1:
		remember("walk1", "First walk together: %s.", [Catalog.WALKS[place].name])
	if is_new and walk_places.size() == Catalog.WALKS.size():
		remember("walkall", "Every walk explored, from the park to the cinema!")
	var fans := 0
	if place == "city":
		fans = 10 + int(followers * 0.04)
		followers += fans
	save_game()
	changed.emit()
	return {"trust": performer.trust - before, "followers": fans, "new": is_new}.merged(found)


## Late in the game Bubák gets lonely: the rescue's hutch opens.
func _check_mate() -> void:
	if mate_stage == 0 and trust_level() >= Catalog.mate_trust() and cozy_level() >= Catalog.mate_cozy():
		mate_stage = 1
		save_game()
		mate_unlocked.emit()


## Why this rabbit can't be adopted ("" if it can).
func adopt_problem(id: String) -> String:
	if mate_stage == 0:
		return tr("Needs Bubák at trust %s and Cozy level %d") % [Catalog.level_name(Catalog.mate_trust()), Catalog.mate_cozy()]
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
	p.adopted_at = Time.get_unix_time_from_system()
	_set_mate(p)
	mate_stage = 2
	remember("mate", "%s moved in. Bubák has a friend!", [Catalog.MATES[id].name])
	bond = 0.0
	save_game()
	changed.emit()
	return ""


# ---- wear and tear ---------------------------------------------------------------

## How worn a placed item is, 0..1 (always 0 for things that don't wear out).
func wear_of(e: Dictionary) -> float:
	var uses: int = Catalog.WEAR_USES.get(e.id, 0)
	return 0.0 if uses == 0 else clampf(float(e.get("wear", 0)) / uses, 0.0, 1.0)


## A bunny used this item once more. At the end of its life it breaks (a moment later, so the
## bunny can finish what it was doing first).
func wear_item(uid: int) -> void:
	for e in placed:
		if e.uid != uid or not Catalog.WEAR_USES.has(e.id):
			continue
		var before := wear_of(e)
		e.wear = int(e.get("wear", 0)) + 1
		var now := wear_of(e)
		item_worn.emit(uid, now)
		if now >= 1.0:
			_break_item.call_deferred(uid)
		elif before < Catalog.WEAR_WARN and now >= Catalog.WEAR_WARN:
			toast.emit(tr("The %s is getting worn out. It won't last much longer.") % Catalog.item_name(e.id).to_lower())
		return


func _break_item(uid: int) -> void:
	for e in placed:
		if e.uid == uid:
			placed.erase(e)
			stats.broken = stats.get("broken", 0) + 1
			remember("broken1", "The first toy loved to pieces: %s.", [Catalog.ITEMS[e.id].name])
			_recount_cozy()
			save_game()
			item_removed.emit(uid)
			item_broken.emit(e.id)
			changed.emit()
			return


# ---- keeping the bond ------------------------------------------------------------

## Whole days between two "YYYY-MM-DD" dates.
func days_between(a: String, b: String) -> int:
	return roundi((Time.get_unix_time_from_datetime_string(b + "T12:00:00")
		- Time.get_unix_time_from_datetime_string(a + "T12:00:00")) / 86400.0)


## From Bonded up, a close bond needs keeping up: each day away costs about a day's worth of
## trust, but never a whole level. Not when time stands still while the game is closed.
func _missed_days(days: int) -> void:
	if days <= 0 or not life_goes_on or test_mode or fast_game:
		return
	var lost := 0.0
	for p in pets:
		var lvl: int = p.trust_level()
		if lvl < Catalog.BOND_KEEP_LEVEL:
			continue
		var before: float = p.trust
		p.trust = maxf(Catalog.level_at(lvl), p.trust - days * Catalog.TRUST_DAY_MAX[lvl])
		if p == bubak:
			lost = before - p.trust
	if lost > 0.0:
		bond_missed.emit(lost, days)


# ---- foster bunnies ------------------------------------------------------------------

## The rescue sends foster bunnies once Bubák has a friend.
func foster_open() -> bool:
	return mate_stage >= 2


func next_foster() -> String:
	var done := fosters_done.map(func(f): return f.id)
	for id in Catalog.FOSTER_ORDER:
		if not id in done:
			return id
	return Catalog.FOSTER_ORDER[fosters_done.size() % Catalog.FOSTER_ORDER.size()]


## A foster bunny can come today.
func foster_available() -> bool:
	return foster_open() and foster == null and Time.get_date_string_from_system() >= foster_next


func _check_foster() -> void:
	var day := Time.get_date_string_from_system()
	if foster_available() and foster_offer_day != day:
		foster_offer_day = day
		save_game()
		foster_offer.emit(next_foster())
	if foster_ready() and not _foster_home_told:
		_foster_home_told = true
		foster_home_found.emit()


func take_foster() -> String:
	if not foster_available():
		return tr("The rescue has no one for you right now.")
	var id := next_foster()
	var p := Pet.new()
	p.id = id
	p.trust = 0.0
	p.needs = {"food": 80.0, "water": 80.0, "fun": 70.0, "clean": 100.0}
	p.adopted_at = Time.get_unix_time_from_system()
	p.trust_level_up.connect(func(l): foster_trust_up.emit(l))
	foster = p
	_foster_home_told = false
	remember("foster_first", "%s came to stay as a foster bunny.", [Catalog.FOSTERS[id].name])
	save_game()
	changed.emit()
	return ""


func foster_ready() -> bool:
	return foster != null and foster.trust_level() >= Catalog.FOSTER_GOAL


## The foster bunny moves to a new family. Returns {id, coins, fans}.
func rehome_foster() -> Dictionary:
	if not foster_ready():
		return {}
	var id := foster.id
	var lvl := foster.trust_level()
	var thanks := int(Catalog.FOSTER_REWARD * (1.0 + Catalog.HALL_BONUS * (lvl - Catalog.FOSTER_GOAL)))
	coins += thanks
	followers += Catalog.FOSTER_FANS
	fosters_done.append({"id": id, "time": Time.get_unix_time_from_system(), "level": lvl})
	if lvl >= Catalog.HALL_SILVER:
		remember("hall_" + id, "%s went home at trust %s: into the Hall of Fame!", [Catalog.FOSTERS[id].name, Catalog.TRUST_LEVELS[lvl].name])
	remember("foster_%d" % fosters_done.size(), "%s found a loving home. Thank you for fostering!", [Catalog.FOSTERS[id].name])
	foster = null
	foster_next = Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) + 86400)
	save_game()
	changed.emit()
	return {"id": id, "coins": thanks, "fans": Catalog.FOSTER_FANS, "level": lvl}


# ---- show league, the judge, routines, agility ------------------------------------------

func season_now() -> String:
	return Time.get_date_string_from_system().left(7)


func _days_in_month(season: String) -> int:
	var y := int(season.left(4))
	var m := int(season.right(2))
	if m == 2:
		return 29 if (y % 4 == 0 and y % 100 != 0) or y % 400 == 0 else 28
	return 30 if m in [4, 6, 9, 11] else 31


## Points a rival has collected after `days` days of a season (the same every time you look).
func rival_points(id: String, season: String, days: int) -> int:
	var r: Dictionary = Catalog.RIVALS[id]
	var strength: float = (r.looks + r.tricks + r.photo + r.agility) / 4.0 + rival_growth()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(season + id)
	var total := 0.0
	for d in days:
		total += Catalog.LEAGUE_RIVAL_DAY * strength / 100.0 * rng.randf_range(0.3, 1.7)
	return int(total)


## This month's nemesis: the rival who's out to beat Bubák.
func nemesis(season := "") -> String:
	var ids: Array = active_rivals()
	return ids[absi(hash((season if season != "" else league_season) + "nemesis")) % ids.size()]


## The standings, best first: [{id, points}] with "bubak" for you.
func league_table(season := "", days := -1) -> Array:
	if season == "":
		season = league_season
	if days < 0:
		days = int(Time.get_date_string_from_system().right(2)) if season == season_now() else _days_in_month(season)
	var rows := [{"id": "bubak", "points": league_points}]
	for id in active_rivals():
		rows.append({"id": id, "points": rival_points(id, season, days)})
	rows.sort_custom(func(a, b): return a.points > b.points or (a.points == b.points and a.id == "bubak"))
	return rows


func league_place() -> int:
	return league_table().map(func(r): return r.id).find("bubak") + 1


func _check_league() -> void:
	var now := season_now()
	if league_season == now:
		return
	if league_season != "" and league_points > 0 and club_stage >= 3:
		var table := league_table(league_season, _days_in_month(league_season))
		var ids: Array = table.map(func(r): return r.id)
		var place: int = ids.find("bubak") + 1
		var prize: Dictionary = Catalog.LEAGUE_PRIZES[place - 1]
		var beat := ids.find(nemesis(league_season)) > ids.find("bubak")
		var result := {"season": league_season, "place": place, "points": league_points,
			"coins": prize.coins + (Catalog.NEMESIS_BONUS if beat else 0), "fans": prize.fans,
			"nemesis": nemesis(league_season), "beat": beat}
		coins += result.coins
		followers += result.fans
		league_history.append({"season": league_season, "place": place, "points": league_points})
		if place == 1:
			remember("league_%s" % league_season, "Bubák won the %s show league season!", [league_season])
		league_season = now
		league_points = 0
		save_game()
		league_ended.emit(result)
		return
	league_season = now
	league_points = 0


## What the head judge loves this week (a Catalog.JUDGE_LIKES key).
func judge_like() -> String:
	var keys: Array = Catalog.JUDGE_LIKES.keys()
	return keys[int(Time.get_unix_time_from_system() / (7 * 86400.0)) % keys.size()]


## Whether the head judge gets what they love. ctx: routine (Array), faults (int), photo (Dictionary).
func judge_pleased(cat: String, ctx := {}) -> bool:
	var like := judge_like()
	if Catalog.JUDGE_LIKES[like].cat != cat:
		return false
	match like:
		"hat": return wearing.has("head")
		"glossy": return coat >= 85.0
		"nails": return nails < 35.0
		"spin": return "spin" in ctx.get("routine", [])
		"long_routine": return ctx.get("routine", []).size() >= Catalog.ROUTINE_MAX
		"rare_photo": return Catalog.BEHAVIOURS.get(ctx.get("photo", {}).get("behaviour", ""), {}).get("likes", 0) >= 120
		"clean_run": return ctx.get("faults", 1) == 0
	return false


## The routine he performs at a Tricks show: your order (known tricks only), or three picked for him.
func show_routine() -> Array:
	var r: Array = routine.filter(func(id): return trick_stars(id) > 0)
	if not r.is_empty():
		return r.slice(0, Catalog.ROUTINE_MAX)
	var known: Array = Catalog.TRICK_ORDER.filter(func(id): return trick_stars(id) > 0)
	known.shuffle()
	var auto := []
	for i in 3:
		auto.append(known[i % known.size()])
	return auto


## How long (seconds either side) a jump still clears the bar: better with practice.
func agility_window() -> float:
	return 0.12 + 0.16 * agility / 100.0 + 0.015 * trait_level("athlete")


## A practice run: each clean jump builds skill, slower as he gets good.
func practice_agility(clears: int) -> float:
	var before := agility
	agility = minf(100.0, agility + clears * 2.0 * (1.0 - agility / 140.0))
	stats.agility_runs = stats.get("agility_runs", 0) + 1
	add_trait("athlete", 3.0)
	challenge_event("agility")
	performer.add_need("fun", 4)
	save_game()
	changed.emit()
	return agility - before


# ---- Bubák merch ------------------------------------------------------------------------

func merch_open() -> bool:
	return fame >= Catalog.MERCH_FAME or test_mode


func merch_unlocked(id: String) -> bool:
	if Catalog.MERCH[id].get("book", false):
		return book_published
	return fame >= Catalog.MERCH[id].fame or test_mode


func merch_of(id: String) -> Dictionary:
	if not merch.has(id):
		merch[id] = {"stock": 0, "photo": "", "likes": 0, "design_at": 0.0, "sold": 0, "part": 0.0}
	return merch[id]


## Units sold per hour right now.
func merch_rate(id: String) -> float:
	var m := merch_of(id)
	if int(m.stock) <= 0 or m.photo == "":
		return 0.0
	var appeal := clampf(0.5 + log(maxf(1.0, float(m.likes))) / log(2.0) / 10.0, 0.5, 1.6)
	return Catalog.MERCH[id].rate * sqrt(maxf(followers, 1) / 5000.0) * appeal * merch_freshness(id)


## 1 for a new design, down to 0.15 for a stale one.
func merch_freshness(id: String) -> float:
	var age := (Time.get_unix_time_from_system() - float(merch_of(id).design_at)) / 86400.0
	return clampf(1.0 - age / Catalog.MERCH_STALE_DAYS, 0.15, 1.0)


func _sell_merch(hours: float) -> void:
	if not merch_open():
		return
	for id in merch:
		var m: Dictionary = merch[id]
		if int(m.stock) <= 0:
			continue
		m.part = float(m.part) + merch_rate(id) * hours
		var n := mini(int(m.part), int(m.stock))
		if n > 0:
			m.part = float(m.part) - n
			m.stock = int(m.stock) - n
			m.sold = int(m.sold) + n
			merch_pending += n * Catalog.MERCH[id].price


## The newest best photo for a design: the most liked one taken since the current design.
func _design_photo(id: String) -> Dictionary:
	var since := float(merch_of(id).design_at)
	var best := {}
	for p in photos:
		if float(p.time) > since and int(p.likes) > 0 and FileAccess.file_exists(p.file) and (best.is_empty() or p.likes > best.likes):
			best = p
	return best


## Puts the newest best photo on the product. Returns "" or what's wrong.
func merch_design(id: String) -> String:
	var p := _design_photo(id)
	if p.is_empty():
		return tr("Take some new photos first: a new design needs a fresh one.")
	var m := merch_of(id)
	m.photo = p.file
	m.likes = int(p.likes)
	m.design_at = Time.get_unix_time_from_system()
	save_game()
	changed.emit()
	return ""


## Orders a batch. The first order also gets a design.
func merch_order(id: String) -> String:
	var info: Dictionary = Catalog.MERCH[id]
	if not merch_unlocked(id):
		return tr("Unlocks at fame: %s") % fame_name(info.fame)
	if coins < info.cost:
		return tr("Not enough coins.")
	var m := merch_of(id)
	if m.photo == "":
		var err := merch_design(id)
		if err != "":
			return err
	coins -= info.cost
	m.stock = int(m.stock) + int(info.batch)
	save_game()
	changed.emit()
	return ""


func collect_merch() -> int:
	var n := int(merch_pending)
	merch_pending -= n
	coins += n
	merch_earned += n
	save_game()
	changed.emit()
	return n


# ---- today's tasks -----------------------------------------------------------------

func _daily_fits(t: Dictionary) -> bool:
	match t.get("needs", ""):
		"club": return club_stage >= 1
		"grooming": return club_stage >= 2
		"shows": return club_stage >= 3
		"agility": return club_stage >= 3 and count_item("hurdles") > 0
		"veg_patch": return has_item("veg_patch")
		"leash": return "leash" in gear
		"digbox": return has_item("digbox")
		"mate": return mate != null
	return true


func _daily_task(id: String) -> Dictionary:
	for t in Catalog.DAILY_TASKS:
		if t.id == id:
			return t
	return {}


## A new day: three new tasks (the same ones however often the game restarts today).
func check_daily() -> void:
	var day := Time.get_date_string_from_system()
	if daily.get("day", "") == day:
		return
	var opts: Array = Catalog.DAILY_TASKS.filter(_daily_fits)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(day + str(int(created_at)))
	for i in range(opts.size() - 1, 0, -1):   # shuffle with today's seed
		var j := rng.randi_range(0, i)
		var tmp = opts[i]
		opts[i] = opts[j]
		opts[j] = tmp
	daily = {"day": day, "done": [], "tasks": opts.slice(0, 3).map(func(t): return {"id": t.id, "base": stats.get(t.stat, 0)})}
	save_game()


func daily_tasks() -> Array:
	check_daily()
	return daily.tasks


func daily_text(id: String) -> String:
	var t := _daily_task(id)
	var text := tr(t.text)
	return text % t.n if "%" in text else text


## How far along a task is today (0..n) and its goal.
func daily_progress(task: Dictionary) -> Vector2i:
	var t := _daily_task(task.id)
	return Vector2i(clampi(int(stats.get(t.stat, 0)) - int(task.base), 0, t.n), t.n)


func _check_daily() -> void:
	if daily.is_empty() or daily.day != Time.get_date_string_from_system():
		return
	for task in daily.tasks:
		if task.id in daily.done:
			continue
		var p := daily_progress(task)
		if p.x >= p.y:
			daily.done.append(task.id)
			coins += Catalog.DAILY_COINS
			save_game()
			daily_task_done.emit(task.id, Catalog.DAILY_COINS)
	if daily.done.size() >= daily.tasks.size() and not daily.day in stickers:
		stickers.append(daily.day)
		stats.stickers = stats.get("stickers", 0) + 1
		coins += Catalog.DAILY_ALL
		var page := stickers.size() % Catalog.STICKER_PAGE == 0
		if page:
			coins += Catalog.STICKER_PAGE_COINS
			inventory["hay_cookie"] = inventory.get("hay_cookie", 0) + 2
			remember("stickers_%d" % stickers.size(), "%s daily stickers: another page of the sticker book!", [str(stickers.size())])
		save_game()
		sticker_got.emit(stickers.size(), page)


# ---- seasons ---------------------------------------------------------------------------

func _month() -> int:
	return int(debug_date.left(2)) if debug_date != "" else Time.get_date_dict_from_system().month


func season() -> String:
	var m := _month()
	for id in Catalog.SEASONS:
		if m in Catalog.SEASONS[id].months:
			return id
	return "spring"


## The same answer all day: does today bring this weather?
func _weather(kind: String, chance: float) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind + Time.get_date_string_from_system() + debug_date)
	return rng.randf() < chance


func heatwave() -> bool:
	return season() == "summer" and _weather("heat", Catalog.HEATWAVE_CHANCE)


func snowing() -> bool:
	return is_christmas() or (season() == "winter" and _weather("snow", Catalog.SNOW_CHANCE))


## "winter-2026" for December 2026 to February 2027.
func season_key() -> String:
	var d := Time.get_date_dict_from_system()
	var year: int = d.year - (1 if season() == "winter" and _month() <= 2 else 0)
	return "%s-%d" % [season(), year]


## Bubák did this season's thing: the first time each season, he finds something.
func season_moment(behaviour: String) -> void:
	discover(behaviour)
	var id := season()
	if Catalog.SEASONS[id].behaviour != behaviour or season_key() in season_finds:
		return
	season_finds.append(season_key())
	var gift: String = Catalog.SEASONS[id].gift
	var again := gift in wardrobe
	if again:   # last year's find: some treats and coins instead
		coins += 150
		inventory["rose_petals"] = inventory.get("rose_petals", 0) + 2
	else:
		_give(gift)
	remember("season_" + season_key(), "%s: %s, and a find: %s.", [Catalog.SEASONS[id].name, Catalog.BEHAVIOURS[behaviour].name,
		Catalog.ITEMS[gift].name])
	save_game()
	changed.emit()
	season_found.emit("" if again else gift, id)


func seasons_found() -> int:
	var kinds := {}
	for k in season_finds:
		kinds[k.get_slice("-", 0)] = true
	return kinds.size()


# ---- the dig box, treasure maps ---------------------------------------------------------

## A dig in the dig box: maybe something turns up. Returns {} or {"id", "new", "pieces", "map_done", "coins"}.
func dig_find() -> Dictionary:
	stats.digs = stats.get("digs", 0) + 1
	add_trait("explorer", 1.5)
	if randf() > Catalog.DIG_CHANCE * (1.0 + 0.3 * trait_level("explorer")) and not test_mode:
		return {}
	var total := 0
	for k in Catalog.FINDS:
		total += Catalog.FINDS[k].weight
	var r := randi_range(1, total)
	var id := "cap"
	for k in Catalog.FINDS:
		r -= Catalog.FINDS[k].weight
		if r <= 0:
			id = k
			break
	if id == "map" and not treasure.is_empty():
		id = "button"   # one map at a time
	var res := {"id": id, "new": not finds.has(id), "pieces": map_pieces, "map_done": false, "coins": Catalog.FINDS[id].get("coins", 0)}
	finds[id] = finds.get(id, 0) + 1
	coins += res.coins
	if id == "map":
		map_pieces += 1
		res.pieces = map_pieces
		if map_pieces >= Catalog.MAP_PIECES:
			map_pieces = 0
			var at: Vector2 = Catalog.TREASURE_SPOTS.pick_random()
			treasure = {"x": at.x, "y": at.y}
			res.map_done = true
			remember("map_%d" % (stats.get("treasures", 0) + 1), "A whole treasure map, dug up piece by piece!")
	if res.new:
		remember("find_" + id, "Dug up in the dig box: %s.", [Catalog.FINDS[id].name])
	save_game()
	changed.emit()
	dug_up.emit(res)
	return res


func treasure_spot() -> Vector2:
	return Vector2(float(treasure.x), float(treasure.y)) if not treasure.is_empty() else Vector2(-9999, -9999)


## Dug up at the X: coins, and the first time a treasure chest for the flat. Returns {"coins", "chest"}.
func dig_treasure() -> Dictionary:
	if treasure.is_empty():
		return {}
	treasure = {}
	stats.treasures = stats.get("treasures", 0) + 1
	var res := {"coins": Catalog.TREASURE_COINS, "chest": count_item("treasure_chest") == 0}
	coins += res.coins
	if res.chest:
		_give("treasure_chest")
	else:
		inventory["golden_carrot"] = inventory.get("golden_carrot", 0) + 1
	remember("treasure_%d" % stats.treasures, "Treasure! Buried in the flat all along: %s coins.", [str(Catalog.TREASURE_COINS)])
	_recount_cozy()
	save_game()
	changed.emit()
	return res


# ---- postcards, the Hall of Fame ----------------------------------------------------------

## Postcards from adoptive families arrive a few days and a month after a foster went home.
func _check_letters() -> void:
	var now := Time.get_unix_time_from_system()
	for fi in fosters_done.size():
		var f: Dictionary = fosters_done[fi]
		if not Catalog.LETTERS.has(f.id):
			continue
		for n in Catalog.LETTER_DAYS.size():
			if float(f.time) + Catalog.LETTER_DAYS[n] * 86400.0 > now:
				continue
			if postcards.any(func(c): return int(c.fi) == fi and int(c.n) == n):
				continue
			var card := {"id": f.id, "n": n, "fi": fi, "time": now}
			postcards.append(card)
			remember("postcard1", "The first postcard from an adoptive family: %s is doing great!", [Catalog.FOSTERS[f.id].name])
			save_game()
			postcard_arrived.emit(card)
			return   # one at a time


func postcard_text(card: Dictionary) -> String:
	return tr(Catalog.LETTERS[card.id][int(card.n)].text)


## Fosters who went home, with how far they came: [{id, level, time}].
func hall_of_fame() -> Array:
	return fosters_done.map(func(f): return {"id": f.id, "level": int(f.get("level", Catalog.FOSTER_GOAL)), "time": f.time})


## Bubák, once he trusts you deeply, shows foster bunnies there's nothing to fear.
func mentor_active() -> bool:
	return foster != null and bubak.trust_level() >= Catalog.MENTOR_LEVEL


# ---- personality -------------------------------------------------------------------------

## p: whose personality (null = the performer).
func add_trait(id: String, points: float, p: Pet = null) -> void:
	var who: Pet = p if p else performer
	if who != bubak and who != mate:
		return
	var t: Dictionary = skill(who, "traits")
	t[id] = float(t.get(id, 0.0)) + points
	if id == "athlete":
		if _is_performer(who):
			last_exercise = Time.get_unix_time_from_system()
		else:
			_other_skills.last_exercise = Time.get_unix_time_from_system()
	var lvl := trait_level(id, who)
	var told: Dictionary = skill(who, "trait_told")
	if lvl > int(told.get(id, 0)):
		told[id] = lvl
		if who == bubak:
			remember("trait_%s_%d" % [id, lvl], "A new side of Bubák: %s (level %s).", [Catalog.TRAITS[id].name, str(lvl)], lvl == 3)
		else:
			remember("trait_%s_%d_%s" % [id, lvl, who.id], "A new side of %s: %s (level %s).",
				[who.display_name(), Catalog.TRAITS[id].name, str(lvl)], lvl == 3)
		trait_up.emit(id, lvl, who.display_name())


func _trait_raw(id: String, traits_: Dictionary) -> int:
	var pts := float(traits_.get(id, 0.0))
	var lvl := 0
	for at in Catalog.TRAIT_AT:
		if pts >= at:
			lvl += 1
	return lvl


## The two strongest traits can grow all the way; the others stop at level 1. p: whose (null = the performer).
func trait_level(id: String, p: Pet = null) -> int:
	var t: Dictionary = skill(p, "traits")
	var order: Array = Catalog.TRAIT_ORDER.duplicate()
	order.sort_custom(func(a, b): return float(t.get(a, 0.0)) > float(t.get(b, 0.0)))
	var raw := _trait_raw(id, t)
	return raw if id in order.slice(0, 2) else mini(raw, 1)


func trait_points(id: String, p: Pet = null) -> float:
	return float((skill(p, "traits") as Dictionary).get(id, 0.0))


# ---- the photo album ----------------------------------------------------------------------

func _album_put(slot: String, ph: Dictionary) -> bool:
	if slot == "" or ph.get("file", "") == "":
		return false
	var cur: Dictionary = album.get(slot, {})
	if not cur.is_empty() and int(cur.likes) >= int(ph.get("likes", 0)) and FileAccess.file_exists(cur.file):
		return false
	album[slot] = {"file": ph.file, "likes": int(ph.get("likes", 0))}
	return cur.is_empty()


func album_photo(slot: String) -> String:
	var e: Dictionary = album.get(slot, {})
	return e.get("file", "") if FileAccess.file_exists(e.get("file", "")) else ""


func album_count() -> int:
	var n := 0
	for page in Catalog.ALBUM_PAGES:
		for slot in page.slots:
			if album.has(slot):
				n += 1
	return n


func album_size() -> int:
	var n := 0
	for page in Catalog.ALBUM_PAGES:
		n += page.slots.size()
	return n


func _check_album() -> void:
	for i in Catalog.ALBUM_PAGES.size():
		if i in album_pages:
			continue
		if Catalog.ALBUM_PAGES[i].slots.all(func(sl): return album.has(sl)):
			album_pages.append(i)
			coins += Catalog.ALBUM_PAGE_COINS
			remember("album_%d" % i, "A full page in the photo album: %s.", [Catalog.ALBUM_PAGES[i].name])
			if album_pages.size() == Catalog.ALBUM_PAGES.size():
				coins += Catalog.ALBUM_ALL_COINS
				remember("album_all", "The whole photo album, every moment caught on camera!")
			save_game()
			album_page_done.emit(i)
			return


# ---- vaccination, grooming --------------------------------------------------------------

func vaccine_due_at() -> float:
	if vacc_at > 0:
		return vacc_at + Catalog.VACCINE_DAYS * 86400.0
	return created_at + Catalog.VACCINE_FIRST * 86400.0


func vaccine_due() -> bool:
	return Time.get_unix_time_from_system() >= vaccine_due_at()


## Long overdue: no shows, walks or playdates until he's had it.
func vaccine_overdue() -> bool:
	return not test_mode and Time.get_unix_time_from_system() >= vaccine_due_at() + Catalog.VACCINE_GRACE * 86400.0


func can_see_vet() -> bool:
	return vet_due() or vaccine_due()


## p: whose (null = the performer).
func nails_long(p: Pet = null) -> bool:
	return club_stage >= 2 and float(skill(p, "nails")) >= Catalog.NAILS_LONG


func coat_matted(p: Pet = null) -> bool:
	return club_stage >= 2 and float(skill(p, "coat")) < Catalog.COAT_MATTED


# ---- rivals who keep up --------------------------------------------------------------------

## The rivals in shows and the league: the newcomer only after Bubák has won the National championship.
func active_rivals() -> Array:
	return Catalog.RIVALS.keys().filter(func(id): return not Catalog.RIVALS[id].get("newcomer", false) or best_win() >= 2)


## Rivals train too: the more Bubák wins, the better they get.
func rival_growth() -> float:
	return minf(Catalog.RIVAL_GROWTH_MAX, Catalog.RIVAL_GROWTH * trophies.filter(func(t): return t.place == 1).size())


func rival_skill(id: String, cat: String) -> float:
	return float(Catalog.RIVALS[id][cat]) + rival_growth()


func _check_rivals() -> void:
	if not newcomer_told and best_win() >= 2:
		newcomer_told = true
		var id: String = Catalog.RIVALS.keys().filter(func(r): return Catalog.RIVALS[r].get("newcomer", false))[0]
		remember("newcomer", "A new rival: %s, a champion from abroad.", [Catalog.RIVALS[id].name], false)
		save_game()
		rival_arrived.emit(id)
	if not duel.is_empty() and Time.get_unix_time_from_system() > float(duel.until):
		duel = {}
		save_game()


## After a show: a rival Bubák beat may want a rematch. beaten: rival ids that placed below him.
func offer_duel(beaten: Array, t: int, cat: String) -> bool:
	if not duel.is_empty() or beaten.is_empty() or (randf() > Catalog.DUEL_CHANCE and not test_mode):
		return false
	duel = {"rival": beaten.pick_random(), "cat": cat, "tier": t, "until": Time.get_unix_time_from_system() + Catalog.DUEL_DAYS * 86400.0}
	save_game()
	duel_offered.emit(duel.rival)
	return true


## A duel's result: coins and followers for a win. Returns {"won", "coins", "fans"}.
func finish_duel(won: bool) -> Dictionary:
	var t: int = int(duel.get("tier", 0))
	var res := {"won": won, "coins": Catalog.DUEL_COINS[t] if won else 0, "fans": Catalog.DUEL_FANS[t] if won else 0,
		"rival": duel.get("rival", "")}
	stats.duels = stats.get("duels", 0) + 1
	if won:
		stats.duels_won = stats.get("duels_won", 0) + 1
		coins += res.coins
		followers += res.fans
		if performer == bubak:
			remember("duel1", "Bubák won a duel against %s!", [Catalog.RIVALS[res.rival].name])
		else:
			remember("duel1", "%s won a duel against %s!", [performer.display_name(), Catalog.RIVALS[res.rival].name])
	duel = {}
	performer.add_trust(0.5)
	save_game()
	changed.emit()
	return res


# ---- the Bunny Games ----------------------------------------------------------------------

## "YYYY-MM" of today (as the game sees it, so --date= works too).
func _games_month() -> String:
	return "%d-%s" % [Time.get_date_dict_from_system().year, today().left(2)]


## The Games run over the last GAMES_DAYS days of every month.
func games_on() -> bool:
	return int(today().right(2)) > _days_in_month(_games_month()) - Catalog.GAMES_DAYS


## The first day of this month's Games.
func games_start_day() -> int:
	return _days_in_month(_games_month()) - Catalog.GAMES_DAYS + 1


## Qualifying: enough league points this month.
func games_qualified() -> bool:
	return league_points >= Catalog.GAMES_QUALIFY or test_mode


func _games_now() -> Dictionary:
	var month := _games_month()
	if games.get("month", "") != month:
		if not games.get("rounds", {}).is_empty() and not games.get("done", true):
			_finish_games()   # last month's Games, scored with the rounds Bubák ran
		games = {"month": month, "rounds": {}, "rivals": {}, "last_day": "", "done": false}
	return games


## Why this round can't be run now ("" if it can).
func games_problem(cat: String) -> String:
	if not games_on():
		return tr("Next Games: from the %d.") % games_start_day()
	if not games_qualified():
		return tr("Qualifying: %d of %d league points this month.") % [league_points, Catalog.GAMES_QUALIFY]
	var g := _games_now()
	if g.done:
		return tr("This month's Games are over.")
	if g.rounds.has(cat):
		return tr("Done: %d points.") % int(g.rounds[cat])
	if g.last_day == Time.get_date_string_from_system() and not test_mode:
		return tr("One round a day. Next round tomorrow!")
	if vaccine_overdue():
		return tr("First the yearly vaccination at the vet (Journal > Bubák).")
	return ""


## A round of the Games: Bubák's score, and every rival's. Returns {"rivals": {id: score}, "done": all rounds run}.
func games_round(cat: String, score: float) -> Dictionary:
	var g := _games_now()
	g.rounds[cat] = roundi(score)
	g.last_day = Time.get_date_string_from_system()
	var out := {}
	for id in active_rivals():
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(g.month) + id + cat)
		var r := clampf(rival_skill(id, cat) + Catalog.GAMES_BOOST + rng.randf_range(-6, 6), 5, 97)
		if not g.rivals.has(id):
			g.rivals[id] = {}
		g.rivals[id][cat] = roundi(r)
		out[id] = roundi(r)
	add_trait("showoff", 6.0)
	var done: bool = g.rounds.size() >= Catalog.GAMES_ROUNDS.size()
	save_game()
	if done:
		_finish_games()
	return {"rivals": out, "done": done}


## The overall standings so far (of this month's Games, or of g): [{"id", "total"}], best first.
func games_table(g := {}) -> Array:
	if g.is_empty():
		g = _games_now()
	var rows := [{"id": "bubak", "total": g.rounds.values().reduce(func(a, x): return a + int(x), 0)}]
	for id in active_rivals():
		rows.append({"id": id, "total": g.rivals.get(id, {}).values().reduce(func(a, x): return a + int(x), 0)})
	rows.sort_custom(func(a, b): return a.total > b.total or (a.total == b.total and a.id == "bubak"))
	return rows


func _finish_games() -> void:
	var g := games
	if g.get("done", true):
		return
	# rivals who didn't get their rounds in (the Games ended early for Bubák) still compete in all of them
	for cat in Catalog.GAMES_ROUNDS:
		for id in active_rivals():
			if not g.rivals.get(id, {}).has(cat):
				var rng := RandomNumberGenerator.new()
				rng.seed = hash(str(g.month) + id + cat)
				if not g.rivals.has(id):
					g.rivals[id] = {}
				g.rivals[id][cat] = roundi(clampf(rival_skill(id, cat) + Catalog.GAMES_BOOST + rng.randf_range(-6, 6), 5, 97))
	g.done = true
	var table := games_table(g)
	var place: int = table.map(func(r): return r.id).find("bubak") + 1
	var res := {"month": g.month, "place": place, "coins": 0, "fans": 0, "cup": false, "total": table[place - 1].total}
	if place <= Catalog.GAMES_PRIZES.size():
		res.coins = Catalog.GAMES_PRIZES[place - 1].coins
		res.fans = Catalog.GAMES_PRIZES[place - 1].fans
		coins += res.coins
		followers += res.fans
	if place == 1:
		res.cup = count_item("games_cup") == 0
		if res.cup:
			_give("games_cup")
		inventory["best_apples"] = inventory.get("best_apples", 0) + Catalog.GAMES_APPLES
		res.apples = Catalog.GAMES_APPLES
		remember("games_" + g.month, "Bubák won the Bunny Games %s!", [_month_label(g.month)])
	else:
		remember("games_" + g.month, "The Bunny Games %s: Bubák came %s.", [_month_label(g.month), place_name(place)])
	games_history.append({"month": g.month, "place": place})
	_recount_cozy()
	save_game()
	changed.emit()
	games_ended.emit(res)


## "1st", "2nd"... (translated when shown), or "5." from 5th on.
static func place_name(place: int) -> String:
	return ["1st", "2nd", "3rd", "4th"][place - 1] if place >= 1 and place <= 4 else "%d." % place


## "10/2026" for "2026-10".
static func _month_label(month: String) -> String:
	return month.right(2) + "/" + month.left(4)


## A new month: last month's unfinished Games are scored with the rounds Bubák ran.
func _check_games() -> void:
	if not games.is_empty() and games.get("month", "") != _games_month():
		_games_now()


# ---- challenge weeks --------------------------------------------------------------------

func week_index() -> int:
	return int(Time.get_unix_time_from_system() / (7 * 86400.0))


## This week's two challenges to pick from (none if one was already taken this week, or one is running).
func challenge_offers() -> Array:
	if challenge_week == week_index() or not challenge.is_empty():
		return []
	var ids: Array = Catalog.CHALLENGES.keys()
	var a := absi(hash("challenge" + str(week_index()))) % ids.size()
	return [ids[a], ids[(a + 1 + absi(hash("second" + str(week_index()))) % (ids.size() - 1)) % ids.size()]]


func start_challenge(id: String) -> void:
	challenge = {"id": id, "start": Time.get_unix_time_from_system(), "days": [], "seen": [], "failed": false}
	challenge_week = week_index()
	save_game()
	changed.emit()


func challenge_on(id: String) -> bool:
	return challenge.get("id", "") == id and not challenge.get("failed", false)


func challenge_days_left() -> int:
	return ceili((float(challenge.get("start", 0.0)) + 7 * 86400.0 - Time.get_unix_time_from_system()) / 86400.0)


## Something happened that a challenge cares about: "treat" (arg: the treat), "show", "agility", "photo" (arg: behaviour).
func challenge_event(kind: String, arg := "") -> void:
	if challenge.is_empty() or challenge.failed:
		return
	var day := Time.get_date_string_from_system()
	match [challenge.id, kind]:
		["no_sweets", "treat"]:
			if float(Catalog.ITEMS[arg].get("sugar", 0.0)) > 0.0:
				challenge.failed = true
				_end_challenge(false)
		["showtime", "show"], ["fit", "agility"]:
			if not day in challenge.days:
				challenge.days.append(day)
		["diary", "photo"]:
			if arg != "" and not arg in challenge.seen:
				challenge.seen.append(arg)
				if not day in challenge.days:
					challenge.days.append(day)


func _check_challenge() -> void:
	if challenge.is_empty() or challenge_days_left() > 0:
		return
	var info: Dictionary = Catalog.CHALLENGES[challenge.id]
	var ok: bool = not challenge.failed and challenge.days.size() >= int(info.get("days", 0))
	if challenge.id == "fit":
		ok = ok and bubak.weight_band() == 2
	_end_challenge(ok)


func _end_challenge(ok: bool) -> void:
	var id: String = challenge.id
	challenge_last = {"id": id, "ok": ok}
	challenge = {}
	if ok:
		coins += Catalog.CHALLENGES[id].reward
		stats.challenges = stats.get("challenges", 0) + 1
		remember("challenge_" + id, "Challenge done: %s!", [Catalog.CHALLENGES[id].name])
	save_game()
	changed.emit()
	challenge_ended.emit(id, ok)


# ---- the advent calendar -----------------------------------------------------------------

func advent_on() -> bool:
	return today() >= "12-01" and today() <= "12-24"


func advent_opened() -> Array:
	return advent.get("opened", []) if int(advent.get("year", 0)) == Time.get_date_dict_from_system().year else []


## Opens today's door. Returns {"day", "coins", "item", "n", "gift", "all"} or {} if it's open already.
func open_advent() -> Dictionary:
	var day := int(today().right(2))
	if not advent_on() or day in advent_opened():
		return {}
	var year: int = Time.get_date_dict_from_system().year
	if int(advent.get("year", 0)) != year:
		advent = {"year": year, "opened": []}
	advent.opened.append(day)
	var prize: Dictionary = Catalog.ADVENT[day - 1]
	var res := {"day": day, "coins": int(prize.get("coins", 0)), "item": prize.get("item", ""), "n": int(prize.get("n", 0)),
		"gift": prize.get("gift", ""), "all": false}
	coins += res.coins
	if res.item != "":
		inventory[res.item] = inventory.get(res.item, 0) + res.n
	if res.gift != "":
		_give(res.gift)
	if advent.opened.size() >= Catalog.ADVENT.size():
		res.all = true
		_give(Catalog.ADVENT_ALL)
		remember("advent_%d" % year, "Every door of the advent calendar %s opened!", [str(year)])
	save_game()
	changed.emit()
	return res


# ---- seasonal ladders --------------------------------------------------------------------

func ladder_now() -> Dictionary:
	var key := season_key()
	if ladder.get("key", "") != key:
		var first: Dictionary = Catalog.LADDERS[season()].steps[0]
		ladder = {"key": key, "step": 0, "base": int(stats.get(first.stat, 0))}
	return ladder


## The current step ({} once the ladder is climbed) and how far along it is.
func ladder_step() -> Dictionary:
	var l := ladder_now()
	var steps: Array = Catalog.LADDERS[season()].steps
	return steps[l.step] if l.step < steps.size() else {}


func ladder_progress() -> Vector2i:
	var st := ladder_step()
	if st.is_empty():
		return Vector2i(1, 1)
	return Vector2i(clampi(int(stats.get(st.stat, 0)) - int(ladder.base), 0, st.n), st.n)


func ladder_text() -> String:
	var st := ladder_step()
	return tr(st.text) % st.n if not st.is_empty() else ""


func _check_ladder() -> void:
	var st := ladder_step()
	if st.is_empty():
		return
	var p := ladder_progress()
	if p.x < p.y:
		return
	ladder.step += 1
	coins += Catalog.LADDER_STEP_COINS * (1 + int(ladder.step) / 4)
	var steps: Array = Catalog.LADDERS[season()].steps
	var done: bool = ladder.step >= steps.size()
	if done:
		_give(Catalog.LADDERS[season()].gift)
		stats.ladders = stats.get("ladders", 0) + 1
		remember("ladder_" + ladder.key, "The %s ladder, all the way to the top!", [Catalog.SEASONS[season()].name])
		_recount_cozy()
	else:
		ladder.base = int(stats.get(steps[ladder.step].stat, 0))
	save_game()
	changed.emit()
	ladder_step_done.emit(ladder.step, done)


# ---- Bubák's book ---------------------------------------------------------------------------

func book_chapter_open(ch: Dictionary) -> bool:
	match ch.need:
		"binky": return seen.has("binky")
		"balcony": return balcony == "open"
		"ribbon": return not trophies.is_empty()
		"mate": return mate != null
		"foster": return not fosters_done.is_empty()
		"fame": return fame >= Catalog.COVER_FAME
		"champion": return best_win() >= 2
		"seasons": return seasons_found() >= 4
		"treasure": return stats.get("treasures", 0) >= 1
		"trait": return Catalog.TRAIT_ORDER.map(trait_level).max() >= 3
		"games": return not games_history.is_empty()
		"inseparable": return trust_level() >= 7
	return true


func write_chapter(id: String) -> void:
	if id in book_written:
		return
	book_written.append(id)
	coins += 50
	save_game()
	changed.emit()


func book_ready() -> bool:
	return book_written.size() >= Catalog.BOOK.size()


## Publishes the book: it goes on sale as merch and a book signing brings fans. Returns "" or what's wrong.
func publish_book() -> String:
	if book_published:
		return tr("Already published.")
	if not book_ready():
		return tr("Write every chapter first.")
	if coins < Catalog.BOOK_COST:
		return tr("Not enough coins.")
	coins -= Catalog.BOOK_COST
	book_published = true
	followers += Catalog.BOOK_FANS
	_give("bubak_book")
	remember("book", "Bubák's book is out! A book signing, a queue round the block and %s new followers.", [str(Catalog.BOOK_FANS)])
	_recount_cozy()
	save_game()
	changed.emit()
	return ""


# ---- the neighbours' child --------------------------------------------------------------

## A child from next door meets Bubák: lovely once he trusts people, scary before.
## Returns {"happy", "text"}.
func kid_visit(kid: String) -> Dictionary:
	stats.kids = stats.get("kids", 0) + 1
	var res := {"happy": trust_level() >= Catalog.KID_TRUST}
	if res.happy:
		followers += 30
		bubak.add_need("fun", 20)
		bubak.add_trust(1.0, false)
		res.text = tr("%s sits very still, and Bubák hops right over for a sniff and a gentle pat. +30 followers: %s told the whole school!") % [kid, kid]
		remember("kid1", "%s from next door came to meet Bubák.", [kid])
	else:
		bubak.add_trust(-1.0)
		bubak.add_need("fun", -5)
		res.text = tr("Bubák thumps and hides from %s. Too soon: he needs to trust people more first. (Trust went down a little.)") % kid
	save_game()
	changed.emit()
	return res


# ---- the daily agility course ----------------------------------------------------------

## Today's course: [{"type", "gap"}], the same all day. Bars, double bars, tunnels and weave poles.
func daily_course() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("course" + Time.get_date_string_from_system())
	var out := []
	var kinds := ["bar", "bar", "oxer", "tunnel", "weave", "bar", "oxer", "tunnel", "bar"]
	for i in 8:
		out.append({"type": "bar" if i == 0 else kinds[rng.randi_range(0, kinds.size() - 1)], "gap": rng.randf_range(320.0, 440.0)})
	return out


func daily_best() -> float:
	return float(agility_daily.get("best", 0.0)) if agility_daily.get("day", "") == Time.get_date_string_from_system() else 0.0


func daily_ghost() -> Array:
	return agility_daily.get("ghost", []) if daily_best() > 0.0 else []


## A run of today's course. Returns {"best": new best?, "first": first run today?, "coins"}.
func finish_daily_course(seconds: float, ghost: Array) -> Dictionary:
	var day := Time.get_date_string_from_system()
	var first: bool = agility_daily.get("day", "") != day
	var best := first or seconds < daily_best()
	if best:
		agility_daily = {"day": day, "best": seconds, "ghost": ghost}
	var c := 0
	if first:
		c = Catalog.AGILITY_DAILY_COINS
		coins += c
		stats.agility_days = stats.get("agility_days", 0) + 1
	save_game()
	changed.emit()
	return {"best": best, "first": first, "coins": c}


# ---- settings ------------------------------------------------------------------

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		language = cfg.get_value("general", "language", "cs")
		life_goes_on = cfg.get_value("general", "life_goes_on", true)
		fast_game = cfg.get_value("general", "fast_game", false)
	else:
		language = "cs"   # first launch: Czech (English is in Settings)
	TranslationServer.set_locale(language)


func set_fast_game(on: bool) -> void:
	fast_game = on
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("general", "fast_game", on)
	cfg.save(SETTINGS_PATH)
	bubak.settle_level()
	if mate:
		mate.settle_level()
	_check_mate()
	changed.emit()


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
		"balcony": balcony, "herbs": herbs, "grass": grass, "seeds": seeds, "watered": watered, "upgrades": upgrades, "wardrobe": wardrobe,
		"wearing": wearing, "mate_wearing": mate_wearing, "career_xp": career_xp, "job_best": job_best, "job_tired": job_tired, "goals_claimed": goals_claimed,
		"sponsor_day": sponsor_day, "sponsor_streak": sponsor_streak, "placed": placed, "stored": stored, "next_uid": next_uid, "seen": seen, "photos": photos,
		"photo_recent": photo_recent, "feed": feed, "feed_time": feed_time, "walk_day": walk_day, "walk_places": walk_places,
		"birthday": birthday, "presents": presents, "wish": wish, "wish_streak": wish_streak, "wish_last_done": wish_last_done,
		"photo_challenges": photo_challenges, "memories": memories, "fav_counts": fav_counts, "favourites": favourites,
		"days_played": days_played, "last_play_day": last_play_day, "milestones_got": milestones_got, "fame": fame,
		"cover": cover, "souvenirs": souvenirs, "room_style": room_style, "styles": styles,
		"garden": garden, "eggs_year": eggs_year, "eggs_found": eggs_found, "vet_last": vet_last, "guest_day": guest_day, "work_ready_at": work_ready_at, "stats": stats,
		"club_stage": club_stage, "gear": gear, "tricks": tricks, "focus": focus, "coat": coat, "nails": nails,
		"fur": fur, "groom_start": groom_start, "trophies": trophies, "show_ready_at": show_ready_at,
		"mate_stage": mate_stage, "mate": mate.to_dict() if mate else {}, "bond": bond, "test_mode": test_mode,
		"routine": routine, "agility": agility, "foster": foster.to_dict() if foster else {}, "fosters_done": fosters_done,
		"foster_next": foster_next, "foster_offer_day": foster_offer_day, "league_season": league_season,
		"league_points": league_points, "league_history": league_history, "merch": merch, "merch_pending": merch_pending,
		"merch_earned": merch_earned, "merch_told": merch_told, "daily": daily, "stickers": stickers,
		"season_finds": season_finds, "finds": finds, "map_pieces": map_pieces, "treasure": treasure, "postcards": postcards,
		"traits": traits, "trait_told": trait_told, "last_exercise": last_exercise, "album": album, "album_pages": album_pages,
		"vacc_at": vacc_at, "agility_daily": agility_daily, "kid_day": kid_day,
		"duel": duel, "last_routine": last_routine, "newcomer_told": newcomer_told, "games": games,
		"games_history": games_history, "challenge": challenge, "challenge_week": challenge_week,
		"challenge_last": challenge_last, "advent": advent, "ladder": ladder, "certificates": certificates,
		"book_written": book_written, "book_published": book_published,
		"created_at": created_at, "saved_at": Time.get_unix_time_from_system(),
	}.merged(skills_of(bubak), true).merged({"mate_skills": skills_of(mate) if mate else {}}, true)


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
	_skip_days_away = not data.has("league_season")   # older than keeping the bond: don't punish days before it existed
	var d := _defaults.duplicate(true)
	d.merge(data, true)
	performer = bubak   # everything below is Bubák's own (the friend's skills come with the friend)
	_other_skills = {}
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
	grass = float(d.grass)
	seeds = float(d.seeds)
	watered = d.watered.duplicate()
	upgrades = _defaults.upgrades.duplicate()
	for k in d.upgrades:
		upgrades[k] = int(d.upgrades[k])
	wardrobe = d.wardrobe
	wearing = {}
	if typeof(d.wearing) == TYPE_STRING:   # older saves: one accessory
		if d.wearing != "" and Catalog.ITEMS.has(d.wearing):
			wearing[Catalog.ITEMS[d.wearing].place] = d.wearing
	else:
		for place in d.wearing:
			if d.wearing[place] in wardrobe:
				wearing[place] = d.wearing[place]
	mate_wearing = {}
	for place in d.get("mate_wearing", {}):
		var mw: String = d.mate_wearing[place]
		if mw in wardrobe and wearing.get(place, "") != mw:
			mate_wearing[place] = mw
	career_xp = int(d.career_xp)
	job_best = d.get("job_best", {}).duplicate(true)
	job_tired = d.get("job_tired", {}).duplicate(true)
	goals_claimed = d.goals_claimed
	sponsor_day = d.sponsor_day
	sponsor_streak = int(d.sponsor_streak)
	placed = []
	for e in d.placed:
		var entry := {"uid": int(e.uid), "id": {"chew": "branch"}.get(e.id, e.id), "x": float(e.x), "y": float(e.y)}
		if e.has("bites") or entry.id == "branch":
			entry.bites = int(e.get("bites", Catalog.ITEMS.branch.bites))
		placed.append(entry)
	stored = []
	for e in d.stored:
		var entry := {"uid": int(e.uid), "id": e.id}
		if e.has("bites"):
			entry.bites = int(e.bites)
		stored.append(entry)
	next_uid = int(d.next_uid)
	seen = d.seen
	photos = d.photos
	photo_recent = d.photo_recent
	feed = float(d.get("feed", 1.0))
	walk_day = str(d.get("walk_day", ""))
	walk_places = d.get("walk_places", [])
	feed_time = float(d.get("feed_time", 0.0))
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
		trophies.append({"tier": int(t.tier), "cat": t.cat, "place": int(t.place), "time": float(t.time), "pet": str(t.get("pet", "bubak"))})
	show_ready_at = d.show_ready_at
	mate_stage = int(d.mate_stage)
	test_mode = bool(d.test_mode)
	bond = float(d.bond)
	_set_mate(Pet.from_dict(d.mate) if not d.mate.is_empty() else null)
	if mate:
		_other_skills = _clean_skills(d.get("mate_skills", {}))
	created_at = float(d.created_at)
	birthday = str(d.birthday) if str(d.birthday) != "" else _pick_birthday()
	presents = d.presents
	wish = d.wish
	wish_streak = int(d.wish_streak)
	wish_last_done = str(d.wish_last_done)
	photo_challenges = d.photo_challenges
	memories = d.memories
	fav_counts = d.fav_counts
	for k in ["toy", "nap", "walk"]:
		if not fav_counts.has(k):
			fav_counts[k] = {}
	favourites = d.favourites
	garden = d.garden
	eggs_year = int(d.eggs_year)
	eggs_found = int(d.eggs_found)
	vet_last = float(d.vet_last)
	guest_day = str(d.guest_day)
	days_played = int(d.days_played)
	last_play_day = str(d.last_play_day)
	milestones_got = d.milestones_got.map(func(x): return int(x))
	fame = int(d.fame)
	cover = str(d.cover)
	souvenirs = d.souvenirs
	room_style = str(d.room_style)
	styles = d.styles
	routine = d.routine
	agility = float(d.agility)
	foster = null
	if not d.foster.is_empty():
		foster = Pet.from_dict(d.foster)
		foster.trust_level_up.connect(func(l): foster_trust_up.emit(l))
		foster.settle_level()
	fosters_done = d.fosters_done
	foster_next = str(d.foster_next)
	foster_offer_day = str(d.foster_offer_day)
	_foster_home_told = false
	league_season = str(d.league_season)
	league_points = int(d.league_points)
	league_history = d.league_history
	merch = d.merch
	merch_pending = float(d.merch_pending)
	merch_earned = int(d.merch_earned)
	merch_told = bool(d.merch_told)
	daily = d.daily
	stickers = d.stickers
	season_finds = d.season_finds
	finds = {}
	for k in d.finds:
		finds[k] = int(d.finds[k])
	map_pieces = int(d.map_pieces)
	treasure = d.treasure
	postcards = d.postcards
	traits = {}
	for k in d.traits:
		traits[k] = float(d.traits[k])
	trait_told = {}
	for k in d.trait_told:
		trait_told[k] = int(d.trait_told[k])
	last_exercise = float(d.last_exercise)
	album = d.album
	album_pages = d.album_pages.map(func(x): return int(x))
	if not data.has("album"):   # an older save: its photos fill the album
		for ph in photos:
			_album_put(str(ph.behaviour), ph)
	vacc_at = float(d.vacc_at)
	if not data.has("vacc_at") and data.has("created_at"):   # an older save: the first jab is due in a week
		vacc_at = Time.get_unix_time_from_system() - (Catalog.VACCINE_DAYS - 7) * 86400.0
	agility_daily = d.agility_daily
	kid_day = str(d.kid_day)
	duel = d.duel
	last_routine = d.last_routine
	newcomer_told = bool(d.newcomer_told)
	games = d.games
	games_history = d.games_history
	challenge = d.challenge
	challenge_week = int(d.challenge_week)
	challenge_last = d.challenge_last
	advent = d.advent
	ladder = d.ladder
	certificates = d.certificates
	book_written = d.book_written
	book_published = bool(d.book_published)
	# Days the save shows activity on (its start, photos, memories): an older save, or one from
	# before Days together counted every day, gets credit for them.
	var played := {}
	var bias: int = Time.get_time_zone_from_system().bias * 60
	for t: Variant in [created_at] + photos.map(func(p): return p.time) + memories.map(func(m): return m.time):
		played[Time.get_date_string_from_unix_time(int(t) + bias)] = true
	if played.size() > days_played:
		days_played = played.size()
		last_play_day = str([last_play_day, played.keys().max()].max())
	welcome_text = ""


## A throwaway game in its own save file, for the playtest and demo mode.
func use_scratch_game(path: String) -> void:
	save_path = path
	_home_path = path
	photo_dir = "user://scratch_photos/"
	saves_dir = "user://scratch_saves/"
	DirAccess.make_dir_recursive_absolute(photo_dir)
	DirAccess.make_dir_recursive_absolute(saves_dir)
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
	trust = 96.0
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
	return saves_dir + "save_" + save_name.strip_edges().to_lower().md5_text().substr(0, 12) + ".json"


## Named saves, newest first: [{file, name, saved_at, coins, trust, days}, ...]
func list_saves() -> Array:
	var out := []
	for f in DirAccess.get_files_at(saves_dir):
		if not f.ends_with(".json"):
			continue
		var d := _read_json(saves_dir + f)
		if d.is_empty():
			continue
		out.append({"file": saves_dir + f, "name": d.get("save_name", f), "saved_at": float(d.get("saved_at", 0)),
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
	_skip_days_away = true
	_settle()
	welcome_text = tr("Loaded \"%s\". Welcome back!") % data.get("save_name", "")
	save_game()
	return true


func delete_named(file: String) -> void:
	if file.begins_with(saves_dir):
		DirAccess.remove_absolute(file)


## The game was closed (or in the background) for a while: either life went on,
## or time stood still and every clock waits for the player too.
func _time_away(seconds: float) -> void:
	if seconds >= 600:
		greet_pending = true   # he comes over to say hello
	if seconds < 90:
		return
	if life_goes_on:
		_catch_up(seconds)
		_sell_merch(minf(seconds / 3600.0, Catalog.MERCH_OFFLINE_HOURS))
		return
	var now := Time.get_unix_time_from_system()
	if work_ready_at > now - seconds:
		work_ready_at += seconds
	for p in pets:
		var ready: Dictionary = skill(p, "show_ready_at")
		for t in ready:
			if ready[t] > now - seconds:
				ready[t] += seconds
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
		p._check_weight()
		p.weight += (p.ideal_weight() - p.weight) * (1.0 - exp(-Catalog.METABOLISM * 0.5 * mins / 60.0))   # a quiet life while away
		p.bladder = 20.0
	var potties := int(mins / 10.0)
	litter = minf(100, litter + potties * n * 8 * [1.0, 0.67, 0.45][tier("litter") - 1])
	if litter > 85:
		for i in mini(4, potties / 3):
			droppings.append([randf_range(FLOOR.position.x, FLOOR.end.x), randf_range(FLOOR.position.y, FLOOR.end.y)])
	herbs = minf(100, herbs + mins * 4.0)
	_grow_garden(mins)
	grass = minf(100, grass + mins * 2.5)
	seeds = maxf(0, seeds - mins * 0.5)   # the birds kept coming
	_age_skills(mins, seconds, 3.0 if molting() else 1.0)
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
