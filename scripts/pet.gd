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
		energy = clampf(energy - ENERGY_DECAY * m, 0, 100)
	bladder += BLADDER_RATE * m
	sugar = maxf(0, sugar - SUGAR_DECAY * m)
	var md := mood(cozy)
	if md > 65:
		add_trust(0.15 * m * trust_rate())
	elif md < 30:
		# Neglect costs trust, but never a whole level.
		var floor_at: float = Catalog.TRUST_LEVELS[trust_level()].at
		trust = maxf(floor_at, trust - 0.4 * m)


func mood(cozy := -1) -> float:
	var m: float = (needs.food + needs.water + needs.fun + needs.clean) / 4.0
	if sugar > 60:
		m -= 20  # tummy ache
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
	var a: float = Catalog.TRUST_LEVELS[lvl].at
	var b: float = Catalog.TRUST_LEVELS[lvl + 1].at
	return (trust - a) / (b - a)


func add_trust(amount: float) -> void:
	trust = clampf(trust + amount, 0, 100)
	settle_level(true)


## Remembers the trust level; with notify, says so when it went up.
func settle_level(notify := false) -> void:
	var lvl := trust_level()
	if notify and lvl > _last_level:
		trust_level_up.emit(lvl)
	_last_level = lvl


func add_need(need: String, amount: float) -> void:
	needs[need] = clampf(needs[need] + amount, 0, 100)


func to_dict() -> Dictionary:
	return {"id": id, "needs": needs, "energy": energy, "bladder": bladder, "sugar": sugar, "trust": trust}


static func from_dict(d: Dictionary) -> Pet:
	var p := Pet.new()
	p.id = d.get("id", "bubak")
	for k in p.needs:
		p.needs[k] = float(d.get("needs", {}).get(k, 70))
	p.energy = float(d.get("energy", 80))
	p.bladder = float(d.get("bladder", 30))
	p.sugar = float(d.get("sugar", 0))
	p.trust = float(d.get("trust", 0))
	return p
