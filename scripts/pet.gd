class_name Pet
extends RefCounted
## One rabbit's own state: needs, energy and how much he or she trusts you.
## Bubák is Game.pets[0]; a mate can join him late in the game.

signal trust_level_up(level: int)

const FOOD_DECAY := 1.1
const WATER_DECAY := 1.4
const FUN_DECAY := 1.6
const ENERGY_DECAY := 1.0
const BLADDER_RATE := 9.0
const SUGAR_DECAY := 4.0

var id := "bubak"            # "bubak" or a Catalog.MATES id
var needs := {"food": 75.0, "water": 80.0, "fun": 65.0, "clean": 100.0}
var energy := 80.0
var bladder := 30.0
var sugar := 0.0
var trust := 0.0
var asleep := false          # set by the bunny's AI; changes the energy rate
var in_bed := false
var _last_level := 0
var weight := -1.0            # grams (set to his ideal weight on first use)
var trust_day := ""          # the day trust_today and treats_today count
var trust_today := 0.0
var treats_today := 0


func is_bubak() -> bool:
	return id == "bubak"


func display_name() -> String:
	return "Bubák" if is_bubak() else Catalog.mate_name(id)


## Texture name suffix for this rabbit's colours ("" for Bubák).
func skin() -> String:
	return "" if is_bubak() else "_" + id


## Passing time. clean: how clean the flat is (shared by everyone).
func tick(delta: float, clean: float, cozy: int) -> void:
	var m := delta / 60.0
	needs.food = clampf(needs.food - FOOD_DECAY * m, 0, 100)
	needs.water = clampf(needs.water - WATER_DECAY * m, 0, 100)
	needs.fun = clampf(needs.fun - FUN_DECAY * m, 0, 100)
	needs.clean = clean
	if asleep:
		energy = clampf(energy + (13.0 if in_bed else 8.0) * m, 0, 100)
	else:
		energy = clampf(energy - ENERGY_DECAY * m * (1.25 if weight_band() == 4 else 1.0), 0, 100)
	bladder += BLADDER_RATE * m
	sugar = maxf(0, sugar - SUGAR_DECAY * m)
	_check_weight()
	weight += (ideal_weight() - weight) * Catalog.METABOLISM * m / 60.0
	if needs.food < 15:
		burn(0.08 * m)   # going hungry
	var md := mood(cozy)
	if md > 65:
		add_trust(0.15 * m * trust_rate())
	elif md < 30:
		# Neglect costs trust, but never a whole level.
		var floor_at: float = Catalog.level_at(trust_level())
		trust = maxf(floor_at, trust - 0.4 * m)


func mood(cozy := -1) -> float:
	var m: float = (needs.food + needs.water + needs.fun + needs.clean) / 4.0
	if sugar > 60:
		m -= 20  # tummy ache
	m -= [12.0, 5.0, 0.0, 5.0, 12.0][weight_band()]   # too heavy or too thin: not quite himself
	return m + ((Game.cozy_level() if cozy < 0 else cozy) - 1) * 2.0   # a cozy home makes a happy bunny


## Some rabbits warm up to people faster than others.
func trust_rate() -> float:
	return 1.0 if is_bubak() else Catalog.MATES[id].get("trust_rate", 1.0)


func trust_level() -> int:
	return Catalog.trust_level_for(trust)


func trust_progress() -> float:
	var lvl := trust_level()
	if lvl >= Catalog.TRUST_LEVELS.size() - 1:
		return 1.0
	var a: float = Catalog.level_at(lvl)
	var b: float = Catalog.level_at(lvl + 1)
	return (trust - a) / (b - a)


## Trust gained (positive amounts) comes slower at higher levels and after a lot of bonding today.
## daily = false: a special treat (a walk) that the daily limit doesn't slow down.
func add_trust(amount: float, daily := true) -> void:
	if amount > 0 and not Game.test_mode and not Game.fast_game:
		_new_day()
		amount *= Catalog.TRUST_PACE[trust_level()] / (1.0 + (trust_today / Catalog.TRUST_DAILY if daily else 0.0))
		trust_today += amount
	trust = clampf(trust + amount, 0, 100)
	settle_level(true)


## Remembers the trust level; with notify, says so when it went up.
func settle_level(notify := false) -> void:
	var lvl := trust_level()
	if notify and lvl > _last_level:
		trust_level_up.emit(lvl)
	_last_level = lvl


## How much a treat still counts for trust: each one already had today counts less.
func treat_trust() -> float:
	_new_day()
	treats_today += 1
	return 1.0 if Game.fast_game else pow(Catalog.TREAT_REPEAT, treats_today - 1)


func _new_day() -> void:
	var today := Time.get_date_string_from_system()
	if today != trust_day:
		trust_day = today
		trust_today = 0.0
		treats_today = 0


func ideal_weight() -> float:
	return Catalog.IDEAL_WEIGHT if is_bubak() else float(Catalog.MATES[id].get("weight", Catalog.IDEAL_WEIGHT))


func weight_band() -> int:
	_check_weight()
	return Catalog.weight_band(weight, ideal_weight())


## A new rabbit starts at their ideal weight.
func _check_weight() -> void:
	if weight <= 0:
		weight = ideal_weight()


## Grams put on. The heavier he already is, the less sticks (it's hard to make him fat).
func gain(grams: float) -> void:
	_check_weight()
	var off := (weight - ideal_weight()) / ideal_weight()   # a thin bunny makes the most of food
	weight = clampf(weight + grams * clampf(1.0 - 4.0 * off, 0.3, 1.4), ideal_weight() * 0.7, ideal_weight() * 1.4)


## Grams burnt by exercise. A skinny bunny's body holds on to what it has.
func burn(grams: float) -> void:
	_check_weight()
	var under := maxf(0.0, (ideal_weight() - weight) / ideal_weight())
	weight = clampf(weight - grams * clampf(1.0 - 8.0 * under, 0.3, 1.0), ideal_weight() * 0.7, ideal_weight() * 1.4)


func add_need(need: String, amount: float) -> void:
	if need == "food" and amount > 0:
		var overflow := maxf(0.0, needs.food + amount - 100.0)   # eaten on a full tummy
		gain(amount * Catalog.FOOD_GRAMS + overflow * Catalog.OVEREAT_GRAMS)
	needs[need] = clampf(needs[need] + amount, 0, 100)


func to_dict() -> Dictionary:
	return {"id": id, "needs": needs, "energy": energy, "bladder": bladder, "sugar": sugar, "trust": trust, "weight": weight,
		"trust_day": trust_day, "trust_today": trust_today, "treats_today": treats_today}


static func from_dict(d: Dictionary) -> Pet:
	var p := Pet.new()
	p.id = d.get("id", "bubak")
	for k in p.needs:
		p.needs[k] = float(d.get("needs", {}).get(k, 70))
	p.energy = float(d.get("energy", 80))
	p.bladder = float(d.get("bladder", 30))
	p.sugar = float(d.get("sugar", 0))
	p.trust = float(d.get("trust", 0))
	p.weight = float(d.get("weight", -1.0))
	if p.weight <= 0:
		p.weight = p.ideal_weight()
	p.trust_day = str(d.get("trust_day", ""))
	p.trust_today = float(d.get("trust_today", 0))
	p.treats_today = int(d.get("treats_today", 0))
	return p
