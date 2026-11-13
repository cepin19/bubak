extends Node
## Static game data: shop items, Bubák's behaviours and trust levels.

const ART := "res://assets/art/"

## Milestone that unlocks the balcony (then the netting must be bought).
const BALCONY_TRUST := 3
const BALCONY_FOLLOWERS := 300

# Photos: followers only have so much attention. Every post uses some up and it comes back slowly,
# so a flood of posts gets fewer likes and, once attention runs low, people unfollow.
const FEED_COST := 0.2          # attention one post uses (out of 1)
const FEED_REFILL := 2400.0     # seconds for attention to come back from empty to full
const FEED_FLOODED := 0.3       # below this, a post loses followers instead of gaining them
const FEED_UNFOLLOW := 0.02     # share of followers lost per post into a flooded feed
# Bubák and the flash: more than this many photos of him in CAMERA_WINDOW seconds and he's had enough.
const CAMERA_PATIENCE := 3
const CAMERA_WINDOW := 120.0
const CAMERA_SHY_TIME := 180.0  # how long he then turns away from the camera

const TRUST_LEVELS := [
	{"at": 0.0, "name": "Shy"},
	{"at": 10.0, "name": "Curious"},
	{"at": 25.0, "name": "Friendly"},
	{"at": 42.0, "name": "Trusting"},   # the balcony
	{"at": 60.0, "name": "Cuddly"},     # he lets you pick him up for a selfie
	{"at": 78.0, "name": "Bonded"},
	{"at": 94.0, "name": "Best buds"},  # then, after a long game, a friend for him
	{"at": 99.9, "name": "Inseparable"},  # the very top: about 40 days of play after Best buds
]
## Trust is slow to earn: each level gains it slower than the last (TRUST_PACE[level]), and the more
## he has warmed up today, the less each extra bit counts: gains are divided by 1 + today / TRUST_DAILY.
## From Friendly up there's also a hard daily maximum (TRUST_DAY_MAX[level], counting everything,
## walks and presents too), so the top levels take weeks however long you play each day:
## roughly Trusting in 4 days, Cuddly 9, Bonded 15, Best buds 25, and Inseparable only after
## about 40 more days of play (0.15 a day at Best buds, so every day you visit counts).
const TRUST_PACE := [1.0, 0.9, 0.75, 0.55, 0.35, 0.2, 0.15, 0.15]
const TRUST_DAY_MAX := [99.0, 99.0, 8.0, 4.0, 2.5, 1.5, 0.15, 0.15]
## Settings > Game pace > Fast: the original quick game. Bubák bonds within a session or two:
## lower thresholds, no slowdown per level or per day, treats count fully every time and are
## worth what they used to be, and the friend comes at Cuddly in a Cozy level 4 flat.
const FAST_TRUST_AT := [0.0, 15.0, 35.0, 50.0, 60.0, 72.0, 85.0, 99.9]
const FAST_TREAT_TRUST := {"parsley": 1.0, "carrot": 1.5, "apple": 2.0, "dandelion": 5.0, "hay_cookie": 6.5,
	"banana_chips": 7.5, "rose_petals": 9.0, "dried_apple": 12.0, "best_apples": 15.0}
const FAST_MATE := {"trust": 4, "cozy": 4}
const TRUST_DAILY := 6.0
const TREAT_REPEAT := 0.7       # every treat already had today counts this much less for trust
const SELFIE_TRUST := 4         # level at which he can be picked up

## kind:
##   food   - goes into the bowl          hay   - goes into the hay rack
##   treat  - hand-fed to Bubák           toy / decor - placed in the room
##   care   - starter furniture, not sold upgrade - one-off improvement
## Placed items: tex (texture name), scale, flat (drawn under everything),
## use (activity Bubák does with it), max (how many you can own).
const ITEMS := {
	"pellets": {"name": "Pellets", "kind": "food", "price": 6, "qty": 5, "icon": "pellets",
		"desc": "5 bowls of crunchy pellets."},
	"hay": {"name": "Meadow hay", "kind": "hay", "price": 8, "qty": 5, "icon": "hay",
		"desc": "5 armfuls of hay. Bunnies should always have hay!"},
	"parsley": {"name": "Parsley", "kind": "treat", "price": 3, "qty": 1, "icon": "parsley",
		"desc": "Healthy green snack.", "food": 6.0, "fun": 4.0, "trust": 0.8, "sugar": 0.0},
	"carrot": {"name": "Carrot", "kind": "treat", "price": 5, "qty": 1, "icon": "carrot",
		"desc": "Crunchy and sweet. Don't overdo it.", "food": 10.0, "fun": 6.0, "trust": 1.2, "sugar": 18.0},
	"apple": {"name": "Apple slice", "kind": "treat", "price": 7, "qty": 1, "icon": "apple",
		"desc": "Sweet and juicy, so just a slice now and then.", "food": 8.0, "fun": 8.0, "trust": 1.5, "sugar": 30.0},
	# Gourmet treats: pricey, but they win his heart much faster.
	"dandelion": {"name": "Dandelion bouquet", "kind": "treat", "price": 28, "qty": 1, "icon": "dandelion", "fancy": true,
		"desc": "Fresh dandelion leaves and flowers. A healthy feast.", "food": 12.0, "fun": 10.0, "trust": 3.0, "sugar": 0.0},
	"hay_cookie": {"name": "Hay cookie", "kind": "treat", "price": 36, "qty": 1, "icon": "hay_cookie", "fancy": true,
		"desc": "Baked hay and herbs, shaped like a heart.", "food": 10.0, "fun": 12.0, "trust": 3.5, "sugar": 8.0},
	"banana_chips": {"name": "Banana chips", "kind": "treat", "price": 42, "qty": 1, "icon": "banana_chips", "fancy": true,
		"desc": "Crispy and very sweet. A rare indulgence.", "food": 6.0, "fun": 16.0, "trust": 4.0, "sugar": 32.0},
	"rose_petals": {"name": "Dried rose petals", "kind": "treat", "price": 55, "qty": 1, "icon": "rose_petals", "fancy": true,
		"desc": "Fragrant petals for a bunny of refined taste.", "food": 4.0, "fun": 14.0, "trust": 4.5, "sugar": 0.0},
	"dried_apple": {"name": "Dried apple rings", "kind": "treat", "price": 75, "qty": 1, "icon": "dried_apple", "fancy": true,
		"favourite": true, "desc": "His absolute favourite! He'll do a happy binky for one.",
		"food": 8.0, "fun": 22.0, "trust": 6.0, "sugar": 28.0},
	"branch": {"name": "Leafy branch", "kind": "toy", "price": 10, "icon": "branch", "tex": "branch",
		"scale": 0.85, "use": "chew_toy", "max": 2, "bites": 4,
		"space": 1, "desc": "Fresh branch with leaves. He eats the lot, leaves first. Keeps him off cables."},

	"ball": {"name": "Rainbow ball", "kind": "toy", "price": 20, "icon": "ball", "tex": "ball",
		"scale": 0.7, "use": "play_ball", "max": 2, "cozy": 1, "space": 1, "desc": "To nudge, toss and chase."},
	"box": {"name": "Cardboard castle", "kind": "toy", "price": 15, "icon": "box", "tex": "box",
		"scale": 0.85, "use": "hide_box", "max": 1, "cozy": 1, "space": 2, "desc": "A hideout. Very important bunny business."},
	"tunnel": {"name": "Play tunnel", "kind": "toy", "price": 45, "icon": "tunnel", "tex": "tunnel",
		"scale": 0.85, "use": "tunnel", "max": 1, "cozy": 2, "space": 2, "desc": "Zoom in one end, out the other."},

	"bed": {"name": "Cushy bed", "kind": "decor", "price": 160, "icon": "bed", "tex": "bed",
		"scale": 0.85, "use": "sleep", "max": 1, "cozy": 3, "space": 2, "desc": "Naps here restore energy faster."},
	"rug": {"name": "Cozy rug", "kind": "decor", "price": 100, "icon": "rug", "tex": "rug",
		"scale": 1.0, "flat": true, "max": 2, "cozy": 2, "space": 2, "desc": "Soft paws, happy bunny."},
	"plant": {"name": "Potted fern", "kind": "decor", "price": 80, "icon": "plant", "tex": "plant",
		"scale": 0.8, "max": 3, "cozy": 1, "space": 1, "desc": "Makes photos look fancier."},
	"lamp": {"name": "Floor lamp", "kind": "decor", "price": 120, "icon": "lamp", "tex": "lamp",
		"scale": 0.8, "max": 1, "cozy": 2, "space": 1, "desc": "Warm light in the evening."},
	"digbox": {"name": "Dig box", "kind": "toy", "price": 45, "icon": "digbox", "tex": "digbox",
		"scale": 0.8, "use": "dig", "max": 1, "cozy": 2, "space": 2, "desc": "A box of sand for very important digging."},
	"puzzle": {"name": "Treat puzzle", "kind": "toy", "price": 35, "icon": "puzzle", "tex": "puzzle",
		"scale": 0.8, "use": "forage", "max": 1, "cozy": 1, "space": 1, "desc": "Hides little snacks under the lids. Makes him think."},
	"hut": {"name": "Wooden hut", "kind": "toy", "price": 80, "icon": "hut", "tex": "hut", "req_cozy": 2,
		"scale": 0.8, "use": "hide_box", "max": 1, "cozy": 3, "space": 3, "desc": "A hideaway that smells like a forest."},
	"hurdles": {"name": "Hop hurdles", "kind": "toy", "price": 300, "icon": "hurdles", "tex": "hurdles", "req_cozy": 2,
		"scale": 0.85, "use": "hurdles", "max": 1, "cozy": 2, "space": 3,
		"desc": "A little jumping course. The best exercise there is: he clears it again and again for fun."},
	"treat_ball": {"name": "Treat ball", "kind": "toy", "price": 90, "icon": "treat_ball", "tex": "treat_ball",
		"scale": 0.6, "use": "roll_feeder", "max": 1, "cozy": 1, "space": 1,
		"desc": "He rolls it all over the room to shake out a bite of kibble. Keeps him moving."},
	"castle": {"name": "Bunny castle", "kind": "toy", "price": 260, "icon": "castle", "tex": "castle", "req_cozy": 3,
		"scale": 0.85, "use": "castle", "max": 1, "cozy": 5, "space": 3, "desc": "Two floors of castle. He rules from the top."},
	"teepee": {"name": "Teepee tent", "kind": "decor", "price": 350, "icon": "teepee", "tex": "teepee", "req_cozy": 2,
		"scale": 0.8, "use": "sleep", "max": 1, "cozy": 4, "space": 3, "desc": "A tent for very cozy naps."},
	"beanbag": {"name": "Bean bag", "kind": "decor", "price": 220, "icon": "beanbag", "tex": "beanbag",
		"scale": 0.85, "max": 1, "cozy": 3, "space": 2, "desc": "He flops on it like he owns it. He does."},
	"lantern": {"name": "Paper lantern", "kind": "decor", "price": 90, "icon": "lantern", "tex": "lantern",
		"scale": 0.8, "max": 2, "cozy": 1, "space": 1, "desc": "A soft glow for the evenings."},
	"flowers": {"name": "Flower pot", "kind": "decor", "price": 60, "icon": "flowers", "tex": "flowers",
		"scale": 0.8, "max": 3, "cozy": 1, "space": 1, "desc": "Pretty. Not for eating. Probably."},

	# balcony only ("outdoor"): bought straight onto the balcony
	"grass_tray": {"name": "Wheatgrass tray", "kind": "toy", "price": 240, "icon": "grass_tray", "tex": "grass_tray",
		"outdoor": true, "scale": 0.85, "use": "graze", "max": 1, "cozy": 2, "space": 2,
		"desc": "Fresh grass to graze. Water it and it grows back."},
	"bird_feeder": {"name": "Bird feeder", "kind": "decor", "price": 320, "icon": "bird_feeder", "tex": "bird_feeder",
		"outdoor": true, "scale": 0.8, "max": 1, "cozy": 2, "space": 1,
		"desc": "Fill it with seeds and the birds drop by. Bubák is fascinated."},
	"cool_tile": {"name": "Cool stone tile", "kind": "decor", "price": 260, "icon": "cool_tile", "tex": "cool_tile",
		"outdoor": true, "flat": true, "scale": 0.9, "use": "chill", "max": 1, "cozy": 1, "space": 1,
		"desc": "Rabbits don't like the heat. On warm afternoons he stretches out on it."},
	"wind_chime": {"name": "Wind chime", "kind": "decor", "price": 180, "icon": "wind_chime", "tex": "wind_chime",
		"outdoor": true, "scale": 0.8, "max": 1, "cozy": 1, "space": 1,
		"desc": "Tinkles in the breeze. Tap it and watch his ears."},
	"parasol": {"name": "Sun umbrella", "kind": "decor", "price": 480, "icon": "parasol", "tex": "parasol",
		"outdoor": true, "scale": 0.85, "max": 1, "cozy": 3, "space": 2,
		"desc": "A shady spot, so he can nap outside."},
	"veg_patch": {"name": "Veggie patch", "kind": "decor", "price": 280, "icon": "veg_patch", "tex": "veg_patch", "outdoor": true,
		"scale": 0.85, "max": 1, "cozy": 1, "space": 2, "desc": "Three little beds to grow carrots, dandelions and roses for treats."},
	# Makeover: wallpaper and floor for the whole flat. Each opens up after so many Days together.
	"style_cream": {"name": "Cosy cream", "kind": "style", "price": 0, "icon": "style_cream", "desc": "The flat as it was when Bubák moved in."},
	"style_mint": {"name": "Mint garden", "kind": "style", "price": 1500, "req_days": 7, "icon": "style_mint",
		"desc": "Fresh mint stripes and a pale birch floor."},
	"style_lavender": {"name": "Lavender dreams", "kind": "style", "price": 3000, "req_days": 30, "icon": "style_lavender",
		"desc": "Soft lilac with little hearts, the colour of Bubák's fur."},
	"style_sunny": {"name": "Sunny meadow", "kind": "style", "price": 5000, "req_days": 60, "icon": "style_sunny",
		"desc": "Butter-yellow walls with daisies, like summer all year."},
	"style_starry": {"name": "Starry night", "kind": "style", "price": 8000, "req_days": 150, "icon": "style_starry",
		"desc": "Deep blue walls full of golden stars and a dark walnut floor."},
	"style_forest": {"name": "Enchanted forest", "kind": "style", "price": 12000, "req_days": 365, "icon": "style_forest",
		"desc": "Leafy green walls and a mossy floor: a whole year together."},
	"lookout": {"name": "Lookout deck", "kind": "toy", "price": 750, "icon": "lookout", "tex": "lookout", "req_cozy": 3,
		"outdoor": true, "scale": 0.85, "use": "lookout", "max": 1, "cozy": 3, "space": 2,
		"desc": "Up the ramp and over the railing: the whole street to watch. The neighbours wave back."},

	# Upgrades: "slot" + "tier". Care slots start at tier 1, desk gear at tier 0.
	"bowl2": {"name": "Big food bowl", "kind": "upgrade", "slot": "bowl", "tier": 2, "price": 180,
		"icon": "bowl_t2_full", "cozy": 2, "desc": "Holds 5 portions instead of 3."},
	"bowl3": {"name": "Royal food bowl", "kind": "upgrade", "slot": "bowl", "tier": 3, "price": 600, "req_cozy": 3,
		"icon": "bowl_t3_full", "cozy": 2, "desc": "Holds 8 portions. Fit for a bunny king."},
	"water2": {"name": "Big water bowl", "kind": "upgrade", "slot": "water", "tier": 2, "price": 160,
		"icon": "water_t2_full", "cozy": 2, "desc": "Holds more water, so it lasts longer."},
	"water3": {"name": "Water fountain", "kind": "upgrade", "slot": "water", "tier": 3, "price": 640, "req_cozy": 3,
		"icon": "water_t3_full", "cozy": 2, "desc": "Fresh running water. Lasts ages, and drinking is fun."},
	"hayrack2": {"name": "Big hay rack", "kind": "upgrade", "slot": "hayrack", "tier": 2, "price": 200,
		"icon": "hayrack_t2_full", "cozy": 2, "desc": "Holds more hay, and each refill lasts longer."},
	"hayrack3": {"name": "Hay house", "kind": "upgrade", "slot": "hayrack", "tier": 3, "price": 680, "req_cozy": 3,
		"icon": "hayrack_t3_full", "cozy": 2, "desc": "A hay rack with a roof. Holds a whole bale."},
	"litter2": {"name": "Corner litter box", "kind": "upgrade", "slot": "litter", "tier": 2, "price": 180,
		"icon": "litter_t2", "cozy": 2, "desc": "High back, less mess. Stays clean longer."},
	"litter3": {"name": "Luxury litter box", "kind": "upgrade", "slot": "litter", "tier": 3, "price": 620, "req_cozy": 3,
		"icon": "litter_t3", "cozy": 2, "desc": "Stays clean much longer. Has ears!"},
	"chair": {"name": "Comfy office chair", "kind": "upgrade", "slot": "chair", "tier": 1, "price": 220,
		"icon": "chair", "cozy": 1, "desc": "Shorter breaks between work shifts."},
	"monitor": {"name": "Second monitor", "kind": "upgrade", "slot": "monitor", "tier": 1, "price": 400, "req_career": 1,
		"icon": "monitor", "cozy": 1, "desc": "+25% pay for remote work."},
	"coffee": {"name": "Coffee machine", "kind": "upgrade", "slot": "coffee", "tier": 1, "price": 350, "req_career": 2,
		"icon": "coffee", "cozy": 1, "desc": "Work shifts last 5 seconds longer."},
	"headphones": {"name": "Noise-cancelling headphones", "kind": "upgrade", "slot": "headphones", "tier": 1, "price": 650,
		"req_career": 3, "icon": "headphones", "cozy": 1, "desc": "Another +25% pay for remote work."},

	# Things Bubák can wear: one per slot (head, ear, eyes, neck), all at once.
	# style: points towards the shows' Best in Show; photos with an outfit get more likes.
	"beanie": {"name": "Knitted beanie", "kind": "wear", "place": "head", "style": 25, "price": 70, "icon": "wear_beanie",
		"tex": "wear_beanie", "desc": "Warm, soft and a little bit cool."},
	"crown": {"name": "Flower crown", "kind": "wear", "place": "head", "style": 40, "price": 150, "req_cozy": 2,
		"icon": "wear_crown", "tex": "wear_crown", "desc": "Spring, all year round."},
	"tophat": {"name": "Tiny top hat", "kind": "wear", "place": "head", "style": 60, "price": 300, "req_cozy": 4,
		"icon": "wear_tophat", "tex": "wear_tophat", "desc": "For a bunny of distinction."},
	# Rewards for playing a long time (Days together, see MILESTONES) and for the souvenir collection.
	"gold_bowtie": {"name": "Golden bow tie", "kind": "wear", "place": "neck", "style": 70, "price": 0, "gift": true,
		"icon": "wear_gold_bowtie", "tex": "wear_gold_bowtie", "desc": "Two weeks together. Only for very good bunnies."},
	"gold_crown": {"name": "Golden crown", "kind": "wear", "place": "head", "style": 100, "price": 0, "gift": true,
		"icon": "wear_gold_crown", "tex": "wear_gold_crown", "desc": "100 days together. Long live King Bubák!"},
	"royal_cushion": {"name": "Royal cushion", "kind": "decor", "price": 0, "gift": true, "icon": "royal_cushion", "tex": "royal_cushion",
		"scale": 0.8, "max": 1, "cozy": 3, "space": 1, "desc": "A velvet cushion with golden tassels. A month together."},
	"statue": {"name": "Bubák statue", "kind": "decor", "price": 0, "gift": true, "icon": "statue", "tex": "statue",
		"scale": 0.8, "max": 1, "cozy": 3, "space": 1, "desc": "A little golden statue of Bubák. 200 days together!"},
	"curio": {"name": "Souvenir cabinet", "kind": "decor", "price": 0, "gift": true, "icon": "curio", "tex": "curio",
		"scale": 0.8, "max": 1, "cozy": 3, "space": 1, "desc": "A glass cabinet with every souvenir from your walks."},
	# Presents on special days (not sold in the shop).
	"party_hat": {"name": "Party hat", "kind": "wear", "place": "head", "style": 35, "price": 0, "gift": true,
		"icon": "wear_party_hat", "tex": "wear_party_hat", "desc": "A birthday present. Every day is a party in it."},
	"egg_rattle": {"name": "Egg rattle", "kind": "toy", "price": 0, "gift": true, "icon": "egg_rattle", "tex": "egg_rattle",
		"scale": 0.7, "use": "play_ball", "max": 1, "cozy": 1, "space": 1, "desc": "A painted wooden egg that rattles when it rolls. An Easter present."},
	"witch_hat": {"name": "Witch hat", "kind": "wear", "place": "head", "style": 40, "price": 0, "gift": true,
		"icon": "wear_witch_hat", "tex": "wear_witch_hat", "desc": "A Halloween present. Spooky, but mostly cute."},
	"jingle_ball": {"name": "Jingle ball", "kind": "toy", "price": 0, "gift": true, "icon": "jingle_ball", "tex": "jingle_ball",
		"scale": 0.7, "use": "play_ball", "max": 1, "cozy": 1, "space": 1, "desc": "A red ball with a little bell inside. A Christmas present."},
	# Seasonal finds (one each season, see SEASONS), and the treasure at the end of a map.
	"blossom": {"name": "Blossom clip", "kind": "wear", "place": "ear", "style": 35, "price": 0, "gift": true,
		"icon": "wear_blossom", "tex": "wear_blossom", "desc": "Cherry blossom behind the ear. A spring find."},
	"straw_hat": {"name": "Straw hat", "kind": "wear", "place": "head", "style": 40, "price": 0, "gift": true,
		"icon": "wear_straw_hat", "tex": "wear_straw_hat", "desc": "Shade for long summer days. A summer find."},
	"scarf": {"name": "Knitted scarf", "kind": "wear", "place": "neck", "style": 35, "price": 0, "gift": true,
		"icon": "wear_scarf", "tex": "wear_scarf", "desc": "Cosy stripes for chilly days. An autumn find."},
	"snowflake": {"name": "Snowflake clip", "kind": "wear", "place": "ear", "style": 40, "price": 0, "gift": true,
		"icon": "wear_snowflake", "tex": "wear_snowflake", "desc": "A snowflake that never melts. A winter find."},
	"treasure_chest": {"name": "Treasure chest", "kind": "decor", "price": 0, "gift": true, "icon": "treasure_chest",
		"tex": "treasure_chest", "scale": 0.75, "max": 1, "cozy": 3, "space": 1,
		"desc": "Found with a treasure map Bubák dug up, piece by piece. Full of gold!"},
	"best_apples": {"name": "Special dried apples", "kind": "treat", "price": 0, "qty": 1, "icon": "best_apples", "fancy": true,
		"gift": true, "favourite": true, "desc": "Dried from the best apples in the world. Only for the very greatest days.",
		"food": 8.0, "fun": 40.0, "trust": 10.0, "sugar": 20.0},
	"golden_carrot": {"name": "Golden carrot", "kind": "treat", "price": 0, "qty": 1, "icon": "golden_carrot", "fancy": true,
		"gift": true, "desc": "Grown from a rare golden seed. He goes wild for it.",
		"food": 12.0, "fun": 30.0, "trust": 8.0, "sugar": 10.0},
	# The top of the game: the Bunny Games cup, the advent calendar, the seasonal ladders, the book.
	"games_cup": {"name": "Bunny Games cup", "kind": "decor", "price": 0, "gift": true, "icon": "games_cup", "tex": "games_cup",
		"scale": 0.75, "max": 1, "cozy": 3, "space": 1, "desc": "Champion of the Bunny Games. The biggest cup there is."},
	"santa_hat": {"name": "Santa hat", "kind": "wear", "place": "head", "style": 45, "price": 0, "gift": true,
		"icon": "wear_santa_hat", "tex": "wear_santa_hat", "desc": "Behind the 24th door of the advent calendar."},
	"snow_globe": {"name": "Snow globe", "kind": "decor", "price": 0, "gift": true, "icon": "snow_globe", "tex": "snow_globe",
		"scale": 0.7, "max": 1, "cozy": 2, "space": 1, "desc": "A tiny Bubák in a snowstorm. For opening every door of the advent calendar."},
	"tulip_bed": {"name": "Tulip bed", "kind": "decor", "price": 0, "gift": true, "icon": "tulip_bed", "tex": "tulip_bed",
		"scale": 0.8, "max": 1, "cozy": 2, "space": 1, "desc": "The top of the spring ladder."},
	"paddling_pool": {"name": "Paddling pool", "kind": "decor", "price": 0, "gift": true, "icon": "paddling_pool", "tex": "paddling_pool",
		"outdoor": true, "scale": 0.8, "max": 1, "cozy": 2, "space": 2, "desc": "The top of the summer ladder. (He only dips a paw.)"},
	"hay_bale": {"name": "Hay bale", "kind": "decor", "price": 0, "gift": true, "icon": "hay_bale", "tex": "hay_bale",
		"scale": 0.8, "max": 1, "cozy": 2, "space": 1, "desc": "The top of the autumn ladder. Also a snack."},
	"snowman": {"name": "Little snowman", "kind": "decor", "price": 0, "gift": true, "icon": "snowman", "tex": "snowman",
		"outdoor": true, "scale": 0.8, "max": 1, "cozy": 2, "space": 1, "desc": "The top of the winter ladder. A carrot nose he keeps eyeing."},
	"bubak_book": {"name": "Bubák's book", "kind": "decor", "price": 0, "gift": true, "icon": "bubak_book", "tex": "bubak_book",
		"scale": 0.7, "max": 1, "cozy": 2, "space": 1, "desc": "His life story, in print. Signed with a paw."},
	"golden_seed": {"name": "Golden seed", "kind": "seed", "price": 0, "gift": true, "icon": "golden_seed",
		"desc": "Turned up in the veggie patch. Plant it and wait a whole day."},
	"garden_beds": {"name": "Bigger veggie patch", "kind": "upgrade", "slot": "garden", "tier": 1, "price": 520,
		"icon": "garden_beds", "req_item": "veg_patch", "cozy": 1, "desc": "Two more beds on the veggie patch."},
	"bow": {"name": "Red bow", "kind": "wear", "place": "ear", "style": 20, "price": 45, "icon": "wear_bow", "tex": "wear_bow",
		"desc": "A classic. Photos with an outfit get more likes."},
	"daisy": {"name": "Daisy clip", "kind": "wear", "place": "ear", "style": 25, "price": 60, "icon": "wear_daisy",
		"tex": "wear_daisy", "desc": "A little daisy behind the ear."},
	"starclip": {"name": "Star clip", "kind": "wear", "place": "ear", "style": 40, "price": 160, "req_cozy": 3,
		"icon": "wear_starclip", "tex": "wear_starclip", "desc": "A sparkly gold star. Born for the spotlight."},
	"glasses": {"name": "Round glasses", "kind": "wear", "place": "eyes", "style": 30, "price": 90, "icon": "wear_glasses",
		"tex": "wear_glasses_side", "desc": "Very smart. Very scholarly."},
	"sunglasses": {"name": "Sunglasses", "kind": "wear", "place": "eyes", "style": 35, "price": 130, "req_cozy": 2,
		"icon": "wear_sunglasses", "tex": "wear_sunglasses_side", "desc": "Too cool for the litter box."},
	"heartglasses": {"name": "Heart glasses", "kind": "wear", "place": "eyes", "style": 45, "price": 220, "req_cozy": 3,
		"icon": "wear_heartglasses", "tex": "wear_heartglasses_side", "desc": "He sees the world through heart-shaped glasses."},
	"bandana": {"name": "Bandana", "kind": "wear", "place": "neck", "style": 20, "price": 50, "icon": "wear_bandana",
		"tex": "wear_bandana", "desc": "A blue bandana for an adventurous bunny."},
	"bowtie": {"name": "Bow tie", "kind": "wear", "place": "neck", "style": 30, "price": 95, "icon": "wear_bowtie",
		"tex": "wear_bowtie", "desc": "Dressed for a very important meeting."},
	"pearls": {"name": "Pearl necklace", "kind": "wear", "place": "neck", "style": 50, "price": 350, "req_cozy": 4,
		"icon": "wear_pearls", "tex": "wear_pearls", "desc": "Utterly glamorous."},

	"balcony_net": {"name": "Balcony netting", "kind": "upgrade", "price": 400, "icon": "door_open", "cozy": 3,
		"desc": "Makes the balcony bunny-safe, so Bubák can go out and enjoy the fresh air."},
	"cable_cover": {"name": "Cable cover", "kind": "upgrade", "price": 150, "icon": "cable_covered", "cozy": 1,
		"desc": "Protects the laptop charger from Bubák's teeth. Forever."},

	# Show club gear (kind "gear": owned once, used in training and grooming).
	"leash": {"name": "Harness & leash", "kind": "gear", "price": 650, "icon": "leash", "stage": 1, "req_trust": 4, "req_stars": 4,
		"desc": "A comfy harness and a soft leash. Take Bubák out once a day: to the park, and further as you go."},
	"clicker": {"name": "Clicker", "kind": "gear", "price": 40, "icon": "clicker", "stage": 1,
		"desc": "Click at just the right moment so he knows what he did right. Tricks are learned 50% faster."},
	"pouch": {"name": "Treat pouch", "kind": "gear", "price": 90, "icon": "pouch", "stage": 1,
		"desc": "Tiny training treats on your belt: 3 more tries in every training session."},
	"hoop": {"name": "Agility hoop", "kind": "gear", "price": 120, "icon": "hoop", "stage": 1, "req_cozy": 2,
		"desc": "Teaches the Hoop jump trick. Judges love it."},
	"brush": {"name": "Soft brush", "kind": "gear", "price": 35, "icon": "brush", "stage": 2,
		"desc": "Brushes out loose fur. Needed for grooming."},
	"comb": {"name": "Fine comb", "kind": "gear", "price": 140, "icon": "comb", "stage": 2, "req_cozy": 3,
		"desc": "Gets twice as much loose fur with every stroke."},
	"clippers": {"name": "Nail clippers", "kind": "gear", "price": 55, "icon": "clippers", "stage": 2,
		"desc": "Keeps his nails short. Long nails cost points at shows."},

	"bowl": {"name": "Food bowl", "kind": "care", "tex": "bowl", "scale": 0.75, "use": "eat_bowl"},
	"water": {"name": "Water bowl", "kind": "care", "tex": "water", "scale": 0.75, "use": "drink"},
	"hayrack": {"name": "Hay rack", "kind": "care", "tex": "hayrack", "scale": 0.8, "use": "eat_hay"},
	"litter": {"name": "Litter box", "kind": "care", "tex": "litter", "scale": 0.85, "use": "potty"},
	"planter": {"name": "Herb planter", "kind": "care", "tex": "planter", "scale": 0.9, "use": "herb_thief"},
	"sunspot": {"name": "Sunny spot", "kind": "care", "tex": "sunspot", "flat": true},
}

const SHOP_TABS := {
	"Food": ["pellets", "hay", "branch", "parsley", "carrot", "apple"],
	"Gourmet": ["dandelion", "hay_cookie", "banana_chips", "rose_petals", "dried_apple"],
	"Toys": ["ball", "box", "tunnel", "puzzle", "treat_ball", "digbox", "hut", "hurdles", "castle"],
	"Balcony": ["grass_tray", "veg_patch", "garden_beds", "bird_feeder", "cool_tile", "wind_chime", "parasol", "lookout"],
	"Home": ["bed", "rug", "plant", "flowers", "lantern", "lamp", "beanbag", "teepee", "cable_cover", "balcony_net"],
	"Makeover": ["style_cream", "style_mint", "style_lavender", "style_sunny", "style_starry", "style_forest"],
	"Upgrades": ["bowl2", "bowl3", "water2", "water3", "hayrack2", "hayrack3", "litter2", "litter3",
		"chair", "monitor", "coffee", "headphones"],
	"Style": ["beanie", "crown", "tophat", "bow", "daisy", "starclip", "glasses", "sunglasses", "heartglasses",
		"bandana", "bowtie", "pearls"],
	"Club": ["clicker", "pouch", "hoop", "brush", "comb", "clippers", "leash"],
}

## likes: how much a photo of it is worth. level: trust level needed.
## needs: item that must be in the room.
const BEHAVIOURS := {
	"hop": {"name": "Hop hop", "likes": 12, "desc": "Just getting around."},
	"idle": {"name": "Sitting pretty", "likes": 10, "desc": "Nose going a mile a minute."},
	"nom": {"name": "Nom nom", "likes": 22, "desc": "Pellets from the bowl. Every last one."},
	"munch": {"name": "Hay muncher", "likes": 20, "desc": "Hay keeps teeth and tummy healthy."},
	"drink": {"name": "Slurp", "likes": 15, "desc": "Staying hydrated."},
	"potty": {"name": "Litter pro", "likes": 8, "desc": "Good bunny, uses the litter box!"},
	"loaf": {"name": "Bunny loaf", "likes": 40, "desc": "Paws tucked in. Perfectly baked."},
	"nap": {"name": "Nap time", "likes": 35, "desc": "Rabbits nap a lot in the middle of the day."},
	"groom": {"name": "Face wash", "likes": 45, "desc": "Licks paws, washes ears. Very thorough."},
	"treat": {"name": "Treat time", "likes": 50, "desc": "Eating a treat from your hand."},
	"hide": {"name": "Box fort", "likes": 40, "desc": "Somewhere in there is a bunny.", "needs": "box"},
	"ball": {"name": "Ball toss", "likes": 60, "desc": "Nudge, flip, chase!", "needs": "ball"},
	"tunnel": {"name": "Tunnel dash", "likes": 70, "desc": "In one end, out the other.", "needs": "tunnel"},
	"chew": {"name": "Branch muncher", "likes": 35, "desc": "Leaves first, then the bark. Great for his teeth.", "needs": "branch"},
	"dig": {"name": "Digging", "likes": 70, "desc": "Sand everywhere. Worth it.", "needs": "digbox"},
	"forage": {"name": "Puzzle solver", "likes": 80, "desc": "Flips the lids with his nose to find the snacks.", "needs": "puzzle"},
	"hurdles": {"name": "Show jumper", "likes": 140, "desc": "Clears the whole course without touching a bar.", "needs": "hurdles"},
	"xmas_tree": {"name": "Christmas wonder", "likes": 110, "desc": "Up on his hind legs, eyes full of twinkling lights."},
	"present": {"name": "Present ripper", "likes": 150, "desc": "Paper everywhere, and one very proud bunny."},
	"treat_ball": {"name": "Snack roller", "likes": 80, "desc": "Roll, roll, kibble! Roll, roll, kibble!", "needs": "treat_ball"},
	"castle": {"name": "King of the castle", "likes": 140, "desc": "Surveying his kingdom from the top floor.", "needs": "castle"},
	"sleep_bed": {"name": "Cozy bed nap", "likes": 80, "desc": "Snoozing in his very own bed.", "needs": "bed"},
	"balcony": {"name": "Fresh air", "likes": 60, "desc": "His first trip out onto the balcony.", "needs": "balcony"},
	"sunbathe": {"name": "Sunbathing", "likes": 90, "desc": "Stretched out in a warm patch of sun.", "needs": "balcony"},
	"bird_watch": {"name": "Bird watching", "likes": 100, "desc": "Up on his hind legs, very interested in that pigeon.", "needs": "balcony"},
	"graze": {"name": "Grazing", "likes": 60, "desc": "Munching fresh wheatgrass, one blade at a time.", "needs": "grass_tray"},
	"lookout": {"name": "On the lookout", "likes": 110, "desc": "Keeping an eye on the street from the top of the deck.", "needs": "lookout"},
	"chill": {"name": "Cooling off", "likes": 90, "desc": "Belly down on the cool stone. Ahh.", "needs": "cool_tile"},
	"shade_nap": {"name": "Shady nap", "likes": 100, "desc": "A snooze under the sun umbrella.", "needs": "parasol"},
	"bird_friend": {"name": "Feathered friend", "likes": 180, "desc": "A sparrow from the feeder hops right up to him. Nose to beak!", "needs": "bird_feeder"},
	"butterfly": {"name": "Butterfly chase", "likes": 150, "desc": "Hop, hop, pounce... missed. Again!", "needs": "balcony"},
	"herb_thief": {"name": "Herb thief", "likes": 70, "desc": "Those herbs were for cooking. Were.", "needs": "balcony"},
	"thump": {"name": "THUMP!", "likes": 60, "desc": "A warning stomp. Something scared him."},
	"chew_cable": {"name": "Cable crime", "likes": 80, "desc": "Caught red-pawed. Naughty!"},
	"chin": {"name": "Chinning", "likes": 50, "desc": "Rubs his chin on things: \"this is MINE.\"", "level": 1},
	"beg": {"name": "Begging", "likes": 90, "desc": "Stands tall when he knows you have treats.", "level": 1},
	"bowl_flip": {"name": "Bowl flip", "likes": 110, "desc": "Empty bowl? Unacceptable!", "level": 1},
	"binky": {"name": "Binky!", "likes": 160, "desc": "A happy jump-twist. Pure joy.", "level": 2},
	"zoomies": {"name": "Zoomies", "likes": 120, "desc": "Sudden laps around the flat at full speed.", "level": 2},
	"flop": {"name": "Flop", "likes": 200, "desc": "Falls over on his side. Total trust.", "level": 4},
	"bonk": {"name": "Nose bonk", "likes": 150, "desc": "Boop! He only does this to his favourite people.", "level": 4},
	"selfie": {"name": "Selfie together", "likes": 220, "desc": "Cheek to cheek. Your followers can't get enough.", "level": 4},
	"snuggle": {"name": "Snuggle buddies", "likes": 260, "desc": "Two bunnies, one fluffy loaf.", "needs": "mate"},
	"show_off": {"name": "Show-off", "likes": 130, "desc": "Does a trick nobody asked for. Then waits for applause.", "needs": "tricks"},
	"purr": {"name": "Tooth purr", "likes": 120, "desc": "Soft teeth-clicking while petted. Bliss.", "level": 5},
	"circle": {"name": "Circling your feet", "likes": 230, "desc": "Honk honk! Laps around you: rabbit for \"you're the best\".", "level": 5},
	"hand_lick": {"name": "Grooming you", "likes": 260, "desc": "He licks your hand while you pet him. You're family now.", "level": 6},
	"trust_nap": {"name": "Asleep in your hand", "likes": 320, "desc": "Dozes off while you stroke him. The ultimate trust.", "level": 7},
	# the seasons (on the balcony; the heatwave indoors)
	"petal_chase": {"name": "Petal chase", "likes": 130, "desc": "Blossom petals drifting down. He has to catch them all.", "season": "spring"},
	"melt": {"name": "Bunny puddle", "likes": 120, "desc": "Too hot to hop. Stretched out flat on the cool floor.", "season": "summer"},
	"leaf_pile": {"name": "Leaf pile dive", "likes": 150, "desc": "Straight into the crunchy leaves. Again!", "season": "autumn"},
	"snow_sniff": {"name": "First snow", "likes": 160, "desc": "Sniffs the snow, sneezes, shakes his ears. Snow is weird.", "season": "winter"},
	"peekaboo": {"name": "Hide and seek", "likes": 110, "desc": "Two ears sticking out from behind the furniture. Found you!"},
	# personality: what he becomes depends on how you play (TRAITS, level 3)
	"parkour": {"name": "Sofa parkour", "likes": 170, "desc": "Up onto the sofa, along the back and off again in one big leap.", "trait": "athlete"},
	"puddle": {"name": "Melting in your hands", "likes": 170, "desc": "Petted until he goes completely floppy.", "trait": "cuddler"},
	"pose": {"name": "Strike a pose", "likes": 170, "desc": "Sees the camera and holds his best angle. A natural.", "trait": "showoff"},
	"inspect": {"name": "Nose to the ground", "likes": 170, "desc": "Sniffing out every corner, one square at a time.", "trait": "explorer"},
	"big_brother": {"name": "Big brother", "likes": 200, "desc": "Bubák grooms the shy foster bunny: you're safe here.", "needs": "foster"},
}

const BEHAVIOUR_ORDER := ["hop", "idle", "nom", "munch", "drink", "potty", "loaf", "nap", "groom",
	"treat", "thump", "chew_cable", "hide", "ball", "tunnel", "chew", "dig", "forage", "treat_ball", "hurdles", "castle", "sleep_bed",
	"balcony", "sunbathe", "bird_watch", "herb_thief", "graze", "chill", "lookout", "shade_nap", "butterfly", "bird_friend", "chin", "beg",
	"bowl_flip", "binky", "zoomies", "flop", "bonk", "selfie", "purr", "circle", "hand_lick", "trust_nap", "show_off", "snuggle",
	"peekaboo", "petal_chase", "melt", "leaf_pile", "snow_sniff", "parkour", "puddle", "pose", "inspect", "big_brother"]

## Floor space per room for toys and furniture (each item has a "space" of 1-3). Over it,
## the room is cluttered and loses CLUTTER_COZY cozy points per unit over.
const ROOM_SPACE := {"living": 25, "balcony": 16}
const CLUTTER_COZY := 2

const COZY_LEVELS := [
	{"at": 0, "name": "Bare"},
	{"at": 5, "name": "Homey"},
	{"at": 12, "name": "Comfy"},
	{"at": 22, "name": "Cozy"},
	{"at": 35, "name": "Snug"},
	{"at": 50, "name": "Bunny paradise"},
]

## Remote-work career. XP = points scored in shifts.
const CAREER := [
	{"xp": 0, "title": "Intern"},
	{"xp": 150, "title": "Junior assistant"},
	{"xp": 450, "title": "Specialist"},
	{"xp": 1000, "title": "Senior specialist"},
	{"xp": 2000, "title": "Team lead"},
	{"xp": 4000, "title": "Director of Carrots"},
]

## Remote-work mini-games, unlocked by career level.
## stars: points for 1/2/3 stars in a 25 s shift (scaled to the shift length).
const JOBS := {
	"inbox": {"name": "Inbox zero", "level": 0, "icon": "task", "stars": [20, 45, 80],
		"desc": "Tap the tasks before they vanish. Urgent ones count double; leave the spam alone!"},
	"bugs": {"name": "Bug hunt", "level": 1, "icon": "bug", "stars": [20, 45, 80],
		"desc": "Squash the bugs, and tap big ones until they pop. Spare the ladybugs!"},
	"memory": {"name": "Pair programming", "level": 2, "icon": "card_back", "stars": [15, 35, 60],
		"desc": "Match the pairs as fast as you can. Each board gets bigger."},
	"call": {"name": "Video call", "level": 3, "icon": "laugh", "stars": [15, 35, 60],
		"desc": "React in the meeting. Bubák may photobomb."},
	"stack": {"name": "Crate stacking", "level": 4, "icon": "crate", "stars": [15, 35, 65],
		"desc": "Drop the carrot crates neatly on the stack. Perfect drops keep it wide."},
}
const PROMOTION_BONUS := 60   # coins per career level, paid once on promotion
## Doing the same job again and again pays less: each recent shift of it cuts the pay,
## down to a floor. It wears off with time (one shift's worth every JOB_REST seconds).
const JOB_REPEAT_CUT := 0.2
const JOB_REPEAT_FLOOR := 0.3
const JOB_REST := 1800.0

## Where accessories go, in the order they're drawn (later ones on top).
const WEAR_PLACES := ["neck", "eyes", "ear", "head"]
const WEAR_PLACE_NAMES := {"head": "Head", "ear": "Ears", "eyes": "Eyes", "neck": "Neck"}

## Long-term goals. type: what is counted, n: target, reward: coins.
const GOALS := [
	{"id": "photo3", "type": "photos", "n": 3, "reward": 10, "text": "Take %d photos"},
	{"id": "seen5", "type": "seen", "n": 5, "reward": 15, "text": "Discover %d behaviours"},
	{"id": "work3", "type": "work", "n": 3, "reward": 20, "text": "Work %d shifts"},
	{"id": "fol50", "type": "followers", "n": 50, "reward": 20, "text": "Reach %d followers"},
	{"id": "trust1", "type": "trust", "n": 1, "reward": 20, "text": "Reach trust: %s"},
	{"id": "cozy2", "type": "cozy", "n": 2, "reward": 25, "text": "Reach Cozy level %d"},
	{"id": "up1", "type": "upgrades", "n": 1, "reward": 25, "text": "Buy your first upgrade"},
	{"id": "trust2", "type": "trust", "n": 2, "reward": 35, "text": "Reach trust: %s"},
	{"id": "fol150", "type": "followers", "n": 150, "reward": 35, "text": "Reach %d followers"},
	{"id": "wear1", "type": "wardrobe", "n": 1, "reward": 30, "text": "Buy an accessory for Bubák"},
	{"id": "seen12", "type": "seen", "n": 12, "reward": 50, "text": "Discover %d behaviours"},
	{"id": "career2", "type": "career", "n": 2, "reward": 50, "text": "Get promoted to %s"},
	{"id": "cozy3", "type": "cozy", "n": 3, "reward": 60, "text": "Reach Cozy level %d"},
	{"id": "photo30", "type": "photos", "n": 30, "reward": 60, "text": "Take %d photos"},
	{"id": "trust3", "type": "trust", "n": 3, "reward": 70, "text": "Reach trust: %s"},
	{"id": "balcony", "type": "balcony", "n": 1, "reward": 70, "text": "Open the balcony"},
	{"id": "patio", "type": "outdoor", "n": 3, "reward": 90, "text": "Set up %d things on the balcony"},
	{"id": "harvest", "type": "harvests", "n": 3, "reward": 60, "text": "Pick herbs from the balcony planter %d times"},
	{"id": "up4", "type": "upgrades", "n": 4, "reward": 90, "text": "Buy %d upgrades"},
	{"id": "fol500", "type": "followers", "n": 500, "reward": 90, "text": "Reach %d followers"},
	{"id": "career4", "type": "career", "n": 4, "reward": 120, "text": "Get promoted to %s"},
	{"id": "jobstars", "type": "jobstars", "n": 3, "reward": 100, "text": "Get 3 stars in %d different jobs"},
	{"id": "cozy5", "type": "cozy", "n": 5, "reward": 150, "text": "Reach Cozy level %d"},
	{"id": "seen25", "type": "seen", "n": 25, "reward": 180, "text": "Discover %d behaviours"},
	{"id": "trust4", "type": "trust", "n": 4, "reward": 120, "text": "Reach trust: %s"},
	{"id": "trust5", "type": "trust", "n": 5, "reward": 180, "text": "Reach trust: %s"},
	{"id": "trust6", "type": "trust", "n": 6, "reward": 260, "text": "Reach trust: %s"},
	{"id": "trust7", "type": "trust", "n": 7, "reward": 1500, "after": "trust6", "text": "Reach trust: %s"},
	{"id": "foster1", "type": "fosters", "n": 1, "reward": 300, "mate": 2, "text": "Find a foster bunny a new home"},
	{"id": "foster3", "type": "fosters", "n": 3, "reward": 600, "after": "foster1", "text": "Find %d foster bunnies new homes"},
	{"id": "foster6", "type": "fosters", "n": 6, "reward": 1500, "after": "foster3", "text": "Find %d foster bunnies new homes"},
	{"id": "league1", "type": "league_top3", "n": 1, "reward": 400, "stage": 3, "text": "Finish a league season in the top 3"},
	{"id": "league_win", "type": "league_wins", "n": 1, "reward": 1000, "stage": 3, "after": "league1", "text": "Win a league season"},
	{"id": "league_win3", "type": "league_wins", "n": 3, "reward": 3000, "stage": 3, "after": "league_win", "text": "Win %d league seasons"},
	{"id": "agility1", "type": "agility_wins", "n": 1, "reward": 250, "stage": 3, "text": "Win an Agility show"},
	{"id": "agility_skill", "type": "agility", "n": 100, "reward": 600, "stage": 3, "after": "agility1", "text": "Train his agility to %d"},
	{"id": "routine4", "type": "routine", "n": 4, "reward": 300, "stage": 3, "text": "Perform a routine of %d tricks at a show"},
	{"id": "merch1", "type": "merch", "n": 500, "reward": 200, "fame": 1, "text": "Earn %d coins from Bubák merch"},
	{"id": "merch2", "type": "merch", "n": 10000, "reward": 1000, "fame": 1, "after": "merch1", "text": "Earn %d coins from Bubák merch"},
	{"id": "merch3", "type": "merch", "n": 100000, "reward": 5000, "fame": 1, "after": "merch2", "text": "Earn %d coins from Bubák merch"},
	{"id": "outfit", "type": "outfit", "n": 4, "reward": 90, "text": "Dress Bubák in a full outfit: something on all %d places"},
	{"id": "wear4", "type": "wardrobe", "n": 12, "reward": 300, "text": "Collect all %d accessories"},
	{"id": "fol1500", "type": "followers", "n": 1500, "reward": 240, "text": "Reach %d followers"},
	{"id": "career5", "type": "career", "n": 5, "reward": 240, "text": "Get promoted to %s"},
	{"id": "cozy6", "type": "cozy", "n": 6, "reward": 300, "text": "Turn the flat into a bunny paradise"},
	{"id": "seenall", "type": "seen", "n": -1, "reward": 300, "text": "Discover every behaviour"},
	# show club, added as it unlocks (stage)
	{"id": "star1", "type": "stars", "n": 1, "reward": 25, "stage": 1, "text": "Teach Bubák his first trick"},
	{"id": "star6", "type": "stars", "n": 6, "reward": 80, "stage": 1, "text": "Earn %d trick stars"},
	{"id": "starall", "type": "basic_stars", "n": 12, "reward": 250, "stage": 1, "text": "Master the four basic tricks"},
	{"id": "groom5", "type": "grooms", "n": 5, "reward": 40, "stage": 2, "text": "Groom Bubák %d times"},
	{"id": "groom30", "type": "grooms", "n": 30, "reward": 150, "stage": 2, "text": "Groom Bubák %d times"},
	{"id": "show1", "type": "ribbons", "n": 1, "reward": 30, "stage": 3, "text": "Win a ribbon at a show"},
	{"id": "win0", "type": "won", "n": 1, "reward": 60, "stage": 3, "text": "Win the Neighbourhood show"},
	{"id": "allcats", "type": "cats", "n": 3, "reward": 120, "stage": 3, "text": "Win in all %d categories"},
	{"id": "win1", "type": "won", "n": 2, "reward": 200, "stage": 3, "text": "Win the Regional show"},
	{"id": "win2", "type": "won", "n": 3, "reward": 500, "stage": 3, "text": "Become National champion"},
	{"id": "walk1", "type": "walks", "n": 1, "reward": 60, "stage": 1, "text": "Take Bubák out on a walk"},
	{"id": "walkall", "type": "places", "n": 5, "reward": 300, "stage": 1, "text": "Go on walks to all %d places"},
	{"id": "mate", "type": "mate", "n": 1, "reward": 150, "mate": 1, "text": "Adopt a friend for Bubák"},
	# the long run: each appears once the one before it is claimed (after)
	{"id": "days7", "type": "days", "n": 7, "reward": 80, "text": "Play on %d different days"},
	{"id": "days30", "type": "days", "n": 30, "reward": 300, "after": "days7", "text": "Play on %d different days"},
	{"id": "days100", "type": "days", "n": 100, "reward": 1000, "after": "days30", "text": "Play on %d different days"},
	{"id": "days365", "type": "days", "n": 365, "reward": 3000, "after": "days100", "text": "Play on %d different days"},
	{"id": "photo100", "type": "photos", "n": 100, "reward": 150, "after": "photo30", "text": "Take %d photos"},
	{"id": "photo300", "type": "photos", "n": 300, "reward": 400, "after": "photo100", "text": "Take %d photos"},
	{"id": "photo1000", "type": "photos", "n": 1000, "reward": 1200, "after": "photo300", "text": "Take %d photos"},
	{"id": "treats50", "type": "treats", "n": 50, "reward": 80, "text": "Give Bubák %d treats"},
	{"id": "treats250", "type": "treats", "n": 250, "reward": 300, "after": "treats50", "text": "Give Bubák %d treats"},
	{"id": "treats1000", "type": "treats", "n": 1000, "reward": 1000, "after": "treats250", "text": "Give Bubák %d treats"},
	{"id": "work50", "type": "work", "n": 50, "reward": 200, "after": "work3", "text": "Work %d shifts"},
	{"id": "work200", "type": "work", "n": 200, "reward": 600, "after": "work50", "text": "Work %d shifts"},
	{"id": "fol5000", "type": "followers", "n": 5000, "reward": 400, "after": "fol1500", "text": "Reach %d followers"},
	{"id": "fol15000", "type": "followers", "n": 15000, "reward": 800, "after": "fol5000", "text": "Reach %d followers"},
	{"id": "fol40000", "type": "followers", "n": 40000, "reward": 1500, "after": "fol15000", "text": "Reach %d followers"},
	{"id": "fol100000", "type": "followers", "n": 100000, "reward": 3000, "after": "fol40000", "text": "Reach %d followers"},
	{"id": "wish7", "type": "wishes", "n": 7, "reward": 60, "text": "Grant %d of Bubák's wishes"},
	{"id": "wish30", "type": "wishes", "n": 30, "reward": 250, "after": "wish7", "text": "Grant %d of Bubák's wishes"},
	{"id": "wish100", "type": "wishes", "n": 100, "reward": 800, "after": "wish30", "text": "Grant %d of Bubák's wishes"},
	{"id": "wish365", "type": "wishes", "n": 365, "reward": 2500, "after": "wish100", "text": "Grant %d of Bubák's wishes"},
	{"id": "challenges", "type": "challenges", "n": -1, "reward": 500, "text": "Complete every photo challenge"},
	{"id": "memories25", "type": "memories", "n": 25, "reward": 200, "text": "Fill the scrapbook with %d memories"},
	{"id": "memories60", "type": "memories", "n": 60, "reward": 600, "after": "memories25", "text": "Fill the scrapbook with %d memories"},
	{"id": "vet10", "type": "vet", "n": 10, "reward": 300, "text": "Take Bubák to %d check-ups"},
	{"id": "vet52", "type": "vet", "n": 52, "reward": 1500, "after": "vet10", "text": "Take Bubák to %d check-ups: a whole year"},
	{"id": "crops20", "type": "crops", "n": 20, "reward": 200, "text": "Pick %d crops from the veggie patch"},
	{"id": "crops100", "type": "crops", "n": 100, "reward": 700, "after": "crops20", "text": "Pick %d crops from the veggie patch"},
	{"id": "guests10", "type": "guests", "n": 10, "reward": 300, "text": "Have %d playdates"},
	{"id": "souv5", "type": "souvenirs", "n": 5, "reward": 100, "stage": 1, "text": "Find %d souvenirs on walks"},
	{"id": "souvall", "type": "souvenirs", "n": 20, "reward": 1000, "stage": 1, "after": "souv5", "text": "Find all %d souvenirs"},
	{"id": "walk50", "type": "walks", "n": 50, "reward": 500, "stage": 1, "after": "walkall", "text": "Go on %d walks"},
	{"id": "walk200", "type": "walks", "n": 200, "reward": 1500, "stage": 1, "after": "walk50", "text": "Go on %d walks"},
	{"id": "ribbons10", "type": "ribbons", "n": 10, "reward": 400, "stage": 3, "after": "show1", "text": "Win %d ribbons at shows"},
	{"id": "ribbons30", "type": "ribbons", "n": 30, "reward": 1200, "stage": 3, "after": "ribbons10", "text": "Win %d ribbons at shows"},
	{"id": "groom100", "type": "grooms", "n": 100, "reward": 500, "stage": 2, "after": "groom30", "text": "Groom Bubák %d times"},
	{"id": "styles", "type": "styles", "n": 6, "reward": 2000, "text": "Give the flat all %d makeovers"},
	{"id": "bond", "type": "bond", "n": 100, "reward": 300, "mate": 1, "text": "Make them best friends"},
	# coming back for more
	{"id": "stickers7", "type": "stickers", "n": 7, "reward": 150, "text": "Collect %d daily stickers"},
	{"id": "stickers30", "type": "stickers", "n": 30, "reward": 600, "after": "stickers7", "text": "Collect %d daily stickers"},
	{"id": "stickers100", "type": "stickers", "n": 100, "reward": 2000, "after": "stickers30", "text": "Collect %d daily stickers"},
	{"id": "album1", "type": "album_pages", "n": 1, "reward": 150, "text": "Fill a page of the photo album"},
	{"id": "album4", "type": "album_pages", "n": 4, "reward": 600, "after": "album1", "text": "Fill %d pages of the photo album"},
	{"id": "finds5", "type": "finds", "n": 5, "reward": 120, "text": "Find %d different things in the dig box"},
	{"id": "treasure", "type": "treasures", "n": 1, "reward": 300, "text": "Find a buried treasure"},
	{"id": "seasons4", "type": "seasons", "n": 4, "reward": 800, "text": "Find something in all %d seasons"},
	{"id": "trait3", "type": "trait_top", "n": 3, "reward": 400, "text": "Shape Bubák's personality: one trait at its highest"},
	{"id": "postcards3", "type": "postcards", "n": 3, "reward": 200, "mate": 2, "text": "Get %d postcards from adoptive families"},
	{"id": "hall_gold", "type": "hall_gold", "n": 1, "reward": 700, "mate": 2, "text": "Get a foster bunny into the Hall of Fame in gold"},
	{"id": "cert1", "type": "certificates", "n": 1, "reward": 300, "stage": 1, "text": "Earn a master's certificate"},
	{"id": "cert4", "type": "certificates", "n": 4, "reward": 1200, "stage": 1, "after": "cert1", "text": "Earn all %d master's certificates"},
	{"id": "duel3", "type": "duel_wins", "n": 3, "reward": 400, "stage": 3, "text": "Win %d duels"},
	{"id": "games3", "type": "games_top3", "n": 1, "reward": 800, "stage": 3, "text": "Finish the Bunny Games in the top 3"},
	{"id": "games_win", "type": "games_wins", "n": 1, "reward": 3000, "stage": 3, "after": "games3", "text": "Win the Bunny Games"},
	{"id": "challenge3", "type": "challenges", "n": 3, "reward": 500, "text": "Complete %d weekly challenges"},
	{"id": "ladder1", "type": "ladders", "n": 1, "reward": 400, "text": "Climb a seasonal ladder to the top"},
	{"id": "ladder4", "type": "ladders", "n": 4, "reward": 1500, "after": "ladder1", "text": "Climb %d seasonal ladders to the top"},
	{"id": "book", "type": "book", "n": 1, "reward": 1000, "text": "Publish Bubák's book"},
	{"id": "agility_daily7", "type": "agility_days", "n": 7, "reward": 400, "stage": 3, "text": "Run the daily agility course on %d days"},
]

## Weight, in grams. Each food point he eats adds FOOD_GRAMS, food eaten when he's already full adds
## OVEREAT_GRAMS more, and sugar adds a little. Activities burn EXERCISE grams (walks WALK_GRAMS), and
## his metabolism slowly pulls him back towards his ideal weight. So only lots of extra food (treats
## piled on a full tummy) with little exercise makes him chubby.
const IDEAL_WEIGHT := 4000.0
const FOOD_GRAMS := 1.1
const OVEREAT_GRAMS := 2.0
const SUGAR_GRAMS := 0.13
const METABOLISM := 0.1     # share of the gap to his ideal weight closed per hour
const WALK_GRAMS := 65.0
const EXERCISE := {"wander": 0.1, "zoomies": 9.0, "binky": 2.2, "play_ball": 3.3, "roll_feeder": 3.3,
	"tunnel": 4.4, "dig": 3.3, "castle": 4.4, "butterfly": 6.6, "hurdles": 9.0, "forage": 1.1,
	"lookout": 2.2, "show_off": 1.1, "bowl_flip": 0.7, "come": 0.7}
## Weight bands, as a share above (or below) his ideal weight.
const WEIGHT_BANDS := [-0.12, -0.06, 0.06, 0.12]
const WEIGHT_NAMES := [{"name": "Underweight"}, {"name": "Slim"}, {"name": "Just right"}, {"name": "Chubby"},
	{"name": "Overweight"}]


## 0 underweight, 1 slim, 2 just right, 3 chubby, 4 overweight.
func weight_band(weight: float, ideal: float) -> int:
	var r := (weight - ideal) / ideal
	var band := 0
	for b in WEIGHT_BANDS:
		if r >= b:
			band += 1
	return band


func weight_name(band: int) -> String:
	return tr(WEIGHT_NAMES[band].name)


## Walks with the leash: once a day, each place opening after so many walks (after).
const WALKS := {
	"park": {"name": "Park", "after": 0},
	"field": {"name": "Meadow", "after": 2},
	"beach": {"name": "Beach", "after": 4},
	"city": {"name": "City", "after": 7},
	"cinema": {"name": "Cinema", "after": 10},
}
const WALK_TRUST := 5.0     # trust a walk brings (not slowed down by the daily limit)
const WALK_FUN := 40.0


## 4012 -> "4.01" ("4,01" in Czech).
func kilos(grams: float) -> String:
	var s := "%.2f" % (grams / 1000.0)
	return s.replace(".", ",") if TranslationServer.get_locale().begins_with("cs") else s


func walk_name(id: String) -> String:
	return tr(WALKS[id].name)


## Late in the game Bubák can get a friend from the rescue's hutch.
## Special days: over Christmas a tree stands in the flat with a present under it; on Bubák's
## birthday (the day you met) there's a present too. He unwraps it himself, once a year each.
## gift: what's inside (if he has it already, a toy he hasn't got yet, or else a bag of treats).
const CHRISTMAS := ["12-20", "12-26"]   # "MM-DD", both days included
const HALLOWEEN := ["10-29", "10-31"]
## Easter runs from Saturday to Monday; the present appears once all the eggs are found.
const EASTER_EGGS := 5
## Hiding spots on the floor, clear of the buttons along the bottom right of the screen.
const EGG_SPOTS := [Vector2(255, 560), Vector2(600, 500), Vector2(1010, 560), Vector2(1190, 520), Vector2(140, 650),
	Vector2(330, 690), Vector2(470, 640), Vector2(780, 560), Vector2(880, 520), Vector2(60, 560)]
const EVENTS := {
	"christmas": {"gift": "jingle_ball", "present": "present_xmas"},
	"birthday": {"gift": "party_hat", "present": "present_bday"},
	"anniversary": {"gift": "", "present": "present_bday"},   # the day you met: a toy he hasn't got
	"easter": {"gift": "egg_rattle", "present": "present_easter"},
	"halloween": {"gift": "witch_hat", "present": "present_halloween"},
}
const TREE_SPOTS := [Vector2(700, 474), Vector2(650, 474), Vector2(745, 474)]   # between the sofa and the toy chest
const BIRTHDAY_POS := Vector2(640, 540)
const PRESENT_TRUST := 3.0     # not slowed down by the daily limit
const PRESENT_TREATS := "dried_apple"

## ---- playing for a long time ----------------------------------------------------------
## Days together: every day you play counts. Milestones bring coins and things you can't buy.
## unlocks: shop items that open up (see req_days); gift: an item given straight away.
const MILESTONES := [
	{"days": 3, "coins": 60},
	{"days": 7, "coins": 120, "unlocks": "style_mint"},
	{"days": 14, "coins": 200, "gift": "gold_bowtie"},
	{"days": 30, "coins": 300, "gift": "royal_cushion", "unlocks": "style_lavender"},
	{"days": 60, "coins": 500, "unlocks": "style_sunny"},
	{"days": 100, "coins": 800, "gift": "gold_crown"},
	{"days": 150, "coins": 1000, "unlocks": "style_starry"},
	{"days": 200, "coins": 1500, "gift": "statue"},
	{"days": 365, "coins": 3000, "unlocks": "style_forest"},
]

## Fame: followers make Bubák famous. Each step brings bigger sponsor deals (+15% each).
## At "Bunnyfluencer" a magazine puts your best photo on its cover.
const FAME := [
	{"at": 1000, "name": "Local cutie"},
	{"at": 5000, "name": "Rising star"},
	{"at": 15000, "name": "Bunnyfluencer"},
	{"at": 40000, "name": "Celebrity"},
	{"at": 100000, "name": "Superstar"},
]
const COVER_FAME := 2   # index in FAME

## Souvenirs Bubák finds on walks: three common ones per place and a rare one. A whole set
## pays SET_REWARD; all of them bring the souvenir cabinet.
const SOUVENIRS := {
	"park": ["acorn", "feather", "conker", "clover"],
	"field": ["poppy", "wheat", "pebble", "horseshoe"],
	"beach": ["shell", "starfish", "seaglass", "pearl"],
	"city": ["postcard", "ticket", "badge", "key"],
	"cinema": ["stub", "reel", "glasses3d", "autograph"],
}
const SOUVENIR_NAMES := {"acorn": "Acorn", "feather": "Feather", "conker": "Conker", "clover": "Four-leaf clover",
	"poppy": "Poppy", "wheat": "Ear of wheat", "pebble": "Smooth pebble", "horseshoe": "Lucky horseshoe",
	"shell": "Seashell", "starfish": "Starfish", "seaglass": "Sea glass", "pearl": "Pearl",
	"postcard": "Postcard", "ticket": "Tram ticket", "badge": "Café badge", "key": "Golden key",
	"stub": "Ticket stub", "reel": "Film reel", "glasses3d": "3D glasses", "autograph": "Star's autograph"}
const SOUVENIR_CHANCE := 0.75   # chance to find something on a walk
const SOUVENIR_RARE := 0.08     # of which the rare one
const SET_REWARD := 250

## ---- daily wishes ----------------------------------------------------------------
## Every day Bubák wishes for one little thing; granting it pays, and a streak of days pays more.
## kind: treat (from your hand), toy (he plays with it), cuddle, photo, walk, balcony, brush.
const WISH_TREATS := ["parsley", "carrot", "apple", "dandelion", "hay_cookie", "banana_chips"]
const WISH_CUDDLE := 12.0      # seconds of petting
## Petting builds trust in one session per this many seconds; in between it only adds fun.
const PET_TRUST_EVERY := 3600.0
const WISH_REWARD := 15        # coins, +5 for every day of the streak (up to +30)
const WISH_STREAK := 7         # every 7 days in a row: a bonus and a gourmet treat
const WISH_BONUS := 120

## ---- photo challenges --------------------------------------------------------------
## behaviours: any of these; wear: at least this many accessories; wearing: this one on;
## night / evening: the time of day; room; tree: by the Christmas tree.
const PHOTO_CHALLENGES := [
	{"id": "dressed", "text": "Dressed up", "reward": 30, "wear": 1},
	{"id": "binky", "text": "Caught mid-binky", "reward": 40, "behaviours": ["binky"]},
	{"id": "zoomies", "text": "Zoomies in action", "reward": 40, "behaviours": ["zoomies"]},
	{"id": "flop", "text": "The big flop", "reward": 40, "behaviours": ["flop"]},
	{"id": "night_nap", "text": "Fast asleep at night", "reward": 50, "behaviours": ["nap", "sleep_bed"], "night": true},
	{"id": "sunset", "text": "Sunset on the balcony", "reward": 60, "room": "balcony", "evening": true},
	{"id": "trick", "text": "Showing off a trick", "reward": 60, "behaviours": ["show_off"]},
	{"id": "butterfly", "text": "Chasing a butterfly", "reward": 60, "behaviours": ["butterfly"]},
	{"id": "fancy", "text": "Dressed to the nines (3 accessories)", "reward": 80, "wear": 3},
	{"id": "friends", "text": "Snuggled up with a friend", "reward": 80, "behaviours": ["snuggle"]},
	{"id": "festive", "text": "By the Christmas tree", "reward": 80, "tree": true},
	{"id": "party", "text": "Party hat on!", "reward": 60, "wearing": "party_hat"},
]

## ---- the scrapbook ----------------------------------------------------------------
## Firsts that go in the Journal's Memories, when he first does these (behaviour -> text).
const MEMORY_FIRSTS := {"binky": "First binky! Pure joy.", "zoomies": "First zoomies around the flat.",
	"flop": "First flop: totally relaxed with you.", "bonk": "First nose bonk. You're one of his favourite people now.",
	"snuggle": "The two bunnies snuggled up for the first time.", "selfie": "First selfie together.",
	"balcony": "First time out on the balcony.", "sleep_bed": "First nap in a proper bed."}

## ---- favourites -------------------------------------------------------------------------
## He gets fond of what he does most: a toy, a napping spot, a walk. One becomes a favourite
## once it has been his pick this many times (and more than anything else).
const FAV_AT := {"toy": 6, "nap": 4, "walk": 3}

## ---- garden -------------------------------------------------------------------------------
## The veggie patch on the balcony: hours to grow (watered: 3x faster) and how many you pick.
## seed: grown only from a seed found while picking (SEED_CHANCE).
const CROPS := {"parsley": {"name": "Parsley", "hours": 1.5, "yield": 3}, "carrot": {"name": "Carrots", "hours": 4.0, "yield": 3},
	"dandelion": {"name": "Dandelions", "hours": 3.0, "yield": 2}, "rose_petals": {"name": "Roses", "hours": 6.0, "yield": 2},
	"golden_carrot": {"name": "Golden carrot", "hours": 24.0, "yield": 1, "seed": true}}
const GARDEN_BEDS := 3          # +2 with the bigger veggie patch
const SEED_CHANCE := 0.12       # a golden seed turns up when you pick a crop

## ---- visitors -------------------------------------------------------------------------------
const GUESTS := ["Pepper", "Clover", "Mochi", "Biscuit"]   # a friend's bunny dropping by
const GUEST_STAY := 150.0      # seconds
const VET_DAYS := 7            # a check-up once a week
const VISIT_EVERY := [240.0, 480.0]   # seconds between chances of a visitor

## A friend for Bubák comes near the end of the game: best buds and a really cozy home
## (the leash comes earlier, at Cuddly).
const MATE_TRUST := 6
const MATE_COZY := 5


## The mate requirements for the chosen game pace.
func mate_trust() -> int:
	return FAST_MATE.trust if Game.fast_game else MATE_TRUST


func mate_cozy() -> int:
	return FAST_MATE.cozy if Game.fast_game else MATE_COZY

## trust: how much the newcomer trusts you at first; trust_rate: how fast that grows.
const MATES := {
	"luna": {"name": "Luna", "weight": 3600, "price": 600, "trust": 5.0, "trust_rate": 0.8,
		"desc": "A gentle cream bunny. Shy at first, but oh so sweet.",
		"personality": "gentle, dreamy, loves a quiet cuddle."},
	"caramel": {"name": "Caramel", "weight": 4300, "price": 750, "trust": 15.0, "trust_rate": 1.3,
		"desc": "Golden, bouncy and friendly with everyone.",
		"personality": "bouncy, chatty, first to every bowl."},
	"hazel": {"name": "Hazel", "weight": 4000, "price": 650, "trust": 10.0, "trust_rate": 1.0,
		"desc": "Chocolate brown with a white nose. Loves digging.",
		"personality": "busy, clever, always digging somewhere."},
	"shadow": {"name": "Shadow", "weight": 4500, "price": 900, "trust": 0.0, "trust_rate": 0.7,
		"desc": "Sleek, black and a little mysterious. Bubák can't stop staring.",
		"personality": "cool, curious, secretly a big softie."},
}

## The show club opens up step by step, so a new player isn't swamped:
## 1 training (some trust and a homey flat), 2 grooming (first trick star),
## 3 shows (3 trick stars and a first grooming).
const CLUB_TRAINING_TRUST := 1
const CLUB_TRAINING_COZY := 2
const CLUB_GROOMING_STARS := 1
const CLUB_SHOWS_STARS := 3

## Tricks Bubák can learn. level: trust level needed, gear: item needed.
const TRICKS := {
	"come": {"name": "Come", "level": 0, "icon": "bunny_hop", "desc": "Hops over when called."},
	"stand": {"name": "Stand up", "level": 1, "icon": "bunny_stand", "desc": "Up on his hind legs, paws tucked."},
	"spin": {"name": "Spin", "level": 2, "icon": "spin", "desc": "A full twirl on the spot."},
	"hoop": {"name": "Hoop jump", "level": 2, "gear": "hoop", "icon": "hoop", "desc": "Sails through the hoop."},
	# advanced tricks: two moments to reward in one go (both must be on time), and a master's certificate
	"bow": {"name": "Take a bow", "level": 4, "after": "stand", "advanced": true, "icon": "trick_bow",
		"desc": "Down on his front paws, then back up. Reward the bow and the finish."},
	"high_five": {"name": "High five", "level": 5, "after": "stand", "advanced": true, "icon": "trick_high_five",
		"desc": "Up on his hind legs, then a paw against your hand."},
	"fetch": {"name": "Fetch", "level": 5, "after": "come", "item": "ball", "advanced": true, "icon": "trick_fetch",
		"desc": "After the ball, and back with it. Needs a rainbow ball."},
	"slalom": {"name": "Leg slalom", "level": 6, "after": "spin", "advanced": true, "icon": "trick_slalom",
		"desc": "Weaves in and out between your feet, there and back."},
}
const TRICK_ORDER := ["come", "stand", "spin", "hoop", "bow", "high_five", "fetch", "slalom"]
const BASIC_TRICKS := ["come", "stand", "spin", "hoop"]
const ADVANCED_AFTER := 2        # stars the basic trick needs before an advanced one can be taught
const CERTIFICATE_COINS := 300   # a master's certificate for each advanced trick at 3 stars
## Training progress needed for each star (3 stars = mastered).
const TRICK_STARS := [100, 250, 450]
const FOCUS_MAX := 8          # tries per training session (+3 with the treat pouch)
const FOCUS_REFILL := 225.0   # seconds per try to come back

## Show categories and tiers. Tiers unlock with first places in the tier below.
const SHOW_CATS := {
	"looks": {"name": "Best in Show", "icon": "condition", "desc": "Coat, nails, outfit and how calm he is with the judge."},
	"tricks": {"name": "Tricks", "icon": "spin", "desc": "Perform a routine. Reward him at the right moment!"},
	"photo": {"name": "Photogenic", "icon": "camera", "desc": "Your best photo goes in front of the judges."},
	"agility": {"name": "Agility", "icon": "agility", "desc": "A jumping course. Tap Jump as he reaches each bar!"},
}
const SHOW_TIERS := [
	{"name": "Neighbourhood show", "fee": 15, "wait": 2 * 3600, "prize": [70, 40, 20], "fans": [30, 15, 8], "rivals": -18, "wins": 0},
	{"name": "Regional show", "fee": 60, "wait": 6 * 3600, "prize": [240, 130, 60], "fans": [110, 55, 25], "rivals": 0, "wins": 2},
	{"name": "National championship", "fee": 200, "wait": 20 * 3600, "prize": [900, 450, 200], "fans": [450, 220, 100], "rivals": 14, "wins": 2},
]
## Rival bunnies. Strengths per category (0-100 before the tier adjustment).
## A newcomer (newcomer: true) only turns up once Bubák has won the National championship.
## Rivals get better as he does: +RIVAL_GROWTH per show he has won, up to RIVAL_GROWTH_MAX.
const RIVALS := {
	"duchess": {"name": "Duchess Fluffington", "looks": 78, "tricks": 52, "photo": 70, "agility": 48, "desc": "A snooty white lop. Has never been seen without a bow."},
	"pepik": {"name": "Pepík", "looks": 55, "tricks": 76, "photo": 58, "agility": 80, "desc": "A scrappy little dwarf with a mighty jump."},
	"pusinka": {"name": "Marshmallow", "looks": 70, "tricks": 50, "photo": 80, "agility": 55, "desc": "Fluffy, sweet, and the internet adores her."},
	"baron": {"name": "Baron von Hop", "looks": 64, "tricks": 70, "photo": 62, "agility": 68, "desc": "Dapper and serious. Takes every show personally."},
	"clover": {"name": "Clover", "looks": 60, "tricks": 64, "photo": 66, "agility": 72, "desc": "A cheerful ginger lop. Everyone's friend."},
	"velvet": {"name": "Velvet", "looks": 76, "tricks": 74, "photo": 76, "agility": 74, "newcomer": true,
		"desc": "A silver champion from abroad. Unbeaten in three countries, until now?"},
}

## Wear and tear: how many times Bubák (or a friend) can play with, nap in or climb on these
## before they fall apart and a new one has to be bought. Presents and rewards never break.
const WEAR_USES := {"box": 30, "ball": 70, "tunnel": 60, "puzzle": 60, "digbox": 80, "treat_ball": 80, "hut": 90,
	"hurdles": 120, "castle": 140, "bed": 120, "teepee": 160, "lookout": 200}
const WEAR_WARN := 0.75   # past this, a heads-up that it won't last much longer

## ---- the late game ---------------------------------------------------------------------

## Keeping the bond: from Bonded up, every whole day you don't visit costs about a day's worth
## of trust (never a whole level). Only while "life goes on" when the game is closed.
const BOND_KEEP_LEVEL := 5

## Foster bunnies: after Bubák has a friend, the rescue asks you to foster shy rabbits. Win
## one's trust up to FOSTER_GOAL and a family adopts them. quirk: what makes each one hard.
const FOSTER_GOAL := 2          # Friendly
const FOSTER_REWARD := 350      # coins from the rescue's thank-you (plus followers)
const FOSTER_FANS := 250
const FOSTERS := {
	"pip": {"name": "Pip", "weight": 2600, "trust_rate": 0.8, "quirk": "hider",
		"desc": "A tiny grey dwarf who hides from everything."},
	"bramble": {"name": "Bramble", "weight": 4800, "trust_rate": 0.7, "quirk": "nipper",
		"desc": "A big agouti buck who nips when he's nervous."},
	"tofu": {"name": "Tofu", "weight": 3400, "trust_rate": 0.75, "quirk": "picky",
		"desc": "White as snow, and only the finest treats will do."},
	"poppy": {"name": "Ruby", "weight": 3000, "trust_rate": 0.65, "quirk": "hider",
		"desc": "A red-eyed rex who jumps at the slightest sound."},
	"ziggy": {"name": "Ziggy", "weight": 3900, "trust_rate": 0.6, "quirk": "nipper",
		"desc": "A spotted English bunny with strong opinions."},
	"maple": {"name": "Maple", "weight": 4100, "trust_rate": 0.7, "quirk": "picky",
		"desc": "An orange lop who turns her nose up at cheap snacks."},
}
const FOSTER_ORDER := ["pip", "tofu", "bramble", "poppy", "maple", "ziggy"]
const QUIRKS := {
	"hider": {"name": "Very shy", "desc": "Often runs off when you try to pet them. Keep trying, gently."},
	"nipper": {"name": "Nips", "desc": "Long petting makes them nervous: keep cuddles short or get nipped."},
	"picky": {"name": "Picky eater", "desc": "Only gourmet treats build their trust."},
}

## Show league: every month is a season. Shows earn league points by place and tier; the
## rivals collect theirs day by day. Your place at the end of the month pays out.
const LEAGUE_POINTS := [10, 6, 3, 1]          # 1st..4th, times LEAGUE_TIER
const LEAGUE_TIER := [1, 2, 4]
const LEAGUE_RIVAL_DAY := 32.0                # a rival's points a day at strength 100
const LEAGUE_PRIZES := [{"coins": 1500, "fans": 2000}, {"coins": 800, "fans": 900}, {"coins": 400, "fans": 400},
	{"coins": 150, "fans": 100}, {"coins": 80, "fans": 50}, {"coins": 50, "fans": 20}, {"coins": 30, "fans": 10}]
const NEMESIS_BONUS := 300                    # for finishing above this month's nemesis

## The head judge's weekly wish: matching it adds JUDGE_BONUS to the score.
const JUDGE_BONUS := 10.0
const JUDGE_LIKES := {
	"hat": {"cat": "looks", "text": "a bunny in a hat"},
	"glossy": {"cat": "looks", "text": "a glossy, freshly brushed coat"},
	"nails": {"cat": "looks", "text": "neatly trimmed nails"},
	"spin": {"cat": "tricks", "text": "a Spin in the routine"},
	"long_routine": {"cat": "tricks", "text": "a routine of 4 tricks"},
	"rare_photo": {"cat": "photo", "text": "a photo of a rare moment"},
	"clean_run": {"cat": "agility", "text": "a clear round, no bars down"},
}

## Trick routines: up to 4 tricks in your order; longer routines and streaks of perfect tricks score more.
const ROUTINE_MAX := 4
const ROUTINE_COMBO := 5.0      # extra points per perfect trick in a row

## Agility: a course of AGILITY_BARS jumps. Practice (a try of focus) builds his skill (0-100),
## which widens the moment to jump.
const AGILITY_BARS := 6
const AGILITY_PRACTICE_BARS := 5

## Bubák merch: opens with fame (Rising star). Order a batch, put your best photo on it and it
## sells by the hour; designs go stale after a while, so refresh them. rate: units sold an hour
## at 5,000 followers with an average photo (stickers: about 10 a day).
const MERCH_FAME := 1
const MERCH := {
	"book": {"name": "Bubák's book", "fame": 0, "batch": 25, "cost": 500, "price": 45, "rate": 0.2, "book": true},
	"stickers": {"name": "Sticker sheet", "fame": 1, "batch": 30, "cost": 120, "price": 8, "rate": 0.42},
	"mug": {"name": "Mug", "fame": 1, "batch": 20, "cost": 300, "price": 22, "rate": 0.25},
	"calendar": {"name": "Calendar", "fame": 2, "batch": 20, "cost": 550, "price": 40, "rate": 0.17},
	"plush": {"name": "Plush Bubák", "fame": 3, "batch": 15, "cost": 1200, "price": 120, "rate": 0.12},
	"hoodie": {"name": "Hoodie", "fame": 4, "batch": 10, "cost": 1800, "price": 260, "rate": 0.06},
}
const MERCH_ORDER := ["stickers", "mug", "calendar", "plush", "hoodie", "book"]
const MERCH_STALE_DAYS := 21.0   # a design sells less and less over this many days
const MERCH_OFFLINE_HOURS := 12.0

## ---- the top of the game: rivals, the Bunny Games, challenges, the book -----------------

const RIVAL_GROWTH := 0.4
const RIVAL_GROWTH_MAX := 8.0
const NEMESIS_COPY := 8.0       # the nemesis studied your routine: the same one as last time scores them this much more
## Duels: a rival Bubák just beat may challenge him to a one-on-one rematch (DUEL_CHANCE), for DUEL_DAYS.
const DUEL_CHANCE := 0.35
const DUEL_DAYS := 3
const DUEL_COINS := [120, 300, 700]   # by show level
const DUEL_FANS := [40, 150, 500]

## The Bunny Games: the last GAMES_DAYS days of every month, for bunnies with GAMES_QUALIFY league
## points that month. Four rounds, one a day, against every rival at their best (their strength
## plus GAMES_BOOST; the overall winner has the best total, so it takes four strong rounds).
const GAMES_DAYS := 7
const GAMES_QUALIFY := 60
const GAMES_ROUNDS := ["looks", "tricks", "agility", "photo"]
const GAMES_APPLES := 3         # bags of the special dried apples for winning the Games
const GAMES_BOOST := 10.0       # on top of the rivals' strength (their best: around 90)
const GAMES_PRIZES := [{"coins": 2000, "fans": 3000}, {"coins": 1000, "fans": 1500}, {"coins": 500, "fans": 700}]

## Challenge weeks: sign up for one of this week's two challenges; it lasts 7 days from then.
## days: on how many of the 7 days its daily part must be done.
const CHALLENGES := {
	"no_sweets": {"name": "No sweets week", "reward": 600, "icon": "parsley",
		"desc": "No sugary treats for 7 days: no carrots, apples, banana chips, dried apple or golden carrots. One and it's over."},
	"budget": {"name": "Budget week", "reward": 700, "icon": "coin",
		"desc": "Work pays half for 7 days. Make it through."},
	"showtime": {"name": "Show every day", "reward": 900, "icon": "rosette_1", "days": 5,
		"desc": "Enter a show on 5 of the 7 days."},
	"fit": {"name": "Fit week", "reward": 700, "icon": "agility", "days": 5,
		"desc": "An agility run on 5 of the 7 days, and his weight just right at the end."},
	"diary": {"name": "Photo diary", "reward": 500, "icon": "camera", "days": 5,
		"desc": "Photograph something he hasn't done yet this week on 5 of the 7 days."},
}

## December: an advent calendar on the wall, a door a day. ADVENT[d - 1] is behind door d.
const ADVENT := [{"coins": 30}, {"item": "parsley", "n": 3}, {"coins": 40}, {"item": "carrot", "n": 2}, {"coins": 50},
	{"item": "hay_cookie", "n": 1}, {"coins": 60}, {"item": "dandelion", "n": 2}, {"coins": 50}, {"item": "apple", "n": 2},
	{"coins": 70}, {"item": "banana_chips", "n": 1}, {"coins": 60}, {"item": "rose_petals", "n": 1}, {"coins": 80},
	{"item": "hay_cookie", "n": 2}, {"coins": 80}, {"item": "dried_apple", "n": 1}, {"coins": 90}, {"item": "golden_seed", "n": 1},
	{"coins": 100}, {"item": "rose_petals", "n": 2}, {"coins": 120}, {"gift": "santa_hat"}]
const ADVENT_ALL := "snow_globe"   # every door opened

## Seasonal ladders: ten steps a season, one after another (stat goes up by n during the step).
## The top brings the season's decoration.
const LADDERS := {
	"spring": {"gift": "tulip_bed", "steps": [
		{"stat": "seasonal", "n": 2, "text": "Watch him chase blossom petals %d times"}, {"stat": "photos", "n": 12, "text": "Take %d photos"},
		{"stat": "crops", "n": 4, "text": "Pick %d crops"}, {"stat": "pets", "n": 8, "text": "Cuddle him %d times"},
		{"stat": "seasonal", "n": 4, "text": "Watch him chase blossom petals %d times"}, {"stat": "walks", "n": 3, "text": "Go for %d walks"},
		{"stat": "treats", "n": 15, "text": "Give %d treats"}, {"stat": "shows", "n": 3, "text": "Enter %d shows"},
		{"stat": "stickers", "n": 4, "text": "Collect %d daily stickers"}, {"stat": "seasonal", "n": 6, "text": "Watch him chase blossom petals %d times"}]},
	"summer": {"gift": "paddling_pool", "steps": [
		{"stat": "seasonal", "n": 2, "text": "Find him melted flat on a hot day %d times"}, {"stat": "photos", "n": 12, "text": "Take %d photos"},
		{"stat": "agility_runs", "n": 3, "text": "Do %d agility runs"}, {"stat": "walks", "n": 3, "text": "Go for %d walks"},
		{"stat": "crops", "n": 6, "text": "Pick %d crops"}, {"stat": "pets", "n": 10, "text": "Cuddle him %d times"},
		{"stat": "shows", "n": 3, "text": "Enter %d shows"}, {"stat": "seasonal", "n": 4, "text": "Find him melted flat on a hot day %d times"},
		{"stat": "stickers", "n": 4, "text": "Collect %d daily stickers"}, {"stat": "work", "n": 10, "text": "Work %d shifts"}]},
	"autumn": {"gift": "hay_bale", "steps": [
		{"stat": "seasonal", "n": 2, "text": "Watch him dive into the leaves %d times"}, {"stat": "photos", "n": 12, "text": "Take %d photos"},
		{"stat": "digs", "n": 4, "text": "Let him dig %d times"}, {"stat": "walks", "n": 3, "text": "Go for %d walks"},
		{"stat": "seasonal", "n": 4, "text": "Watch him dive into the leaves %d times"}, {"stat": "treats", "n": 15, "text": "Give %d treats"},
		{"stat": "grooms", "n": 3, "text": "Groom him %d times"}, {"stat": "shows", "n": 3, "text": "Enter %d shows"},
		{"stat": "stickers", "n": 4, "text": "Collect %d daily stickers"}, {"stat": "seasonal", "n": 6, "text": "Watch him dive into the leaves %d times"}]},
	"winter": {"gift": "snowman", "steps": [
		{"stat": "seasonal", "n": 2, "text": "Watch him sniff the snow %d times"}, {"stat": "photos", "n": 12, "text": "Take %d photos"},
		{"stat": "pets", "n": 10, "text": "Cuddle him %d times"}, {"stat": "training", "n": 10, "text": "Practise tricks %d times"},
		{"stat": "treats", "n": 15, "text": "Give %d treats"}, {"stat": "seasonal", "n": 4, "text": "Watch him sniff the snow %d times"},
		{"stat": "work", "n": 8, "text": "Work %d shifts"}, {"stat": "shows", "n": 3, "text": "Enter %d shows"},
		{"stat": "stickers", "n": 4, "text": "Collect %d daily stickers"}, {"stat": "seasonal", "n": 6, "text": "Watch him sniff the snow %d times"}]},
}
const LADDER_STEP_COINS := 60

## Bubák's book: a chapter for each big moment (need: what has to have happened), written in the
## Journal. With every chapter written you can publish it: it becomes merch, and a book signing
## brings new fans.
const BOOK := [
	{"id": "meet", "title": "Meet Bubák", "need": "", "text": "It started with a shy lilac bunny who hid behind the hay rack and wouldn't come out for anyone."},
	{"id": "binky", "title": "The first binky", "need": "binky", "text": "One day he jumped, twisted in the air and landed looking very pleased with himself. That was the day we knew he was happy."},
	{"id": "balcony", "title": "Fresh air", "need": "balcony", "text": "The balcony door opened, and a whole new world of birds, sunshine and stolen herbs opened with it."},
	{"id": "ribbon", "title": "Show business", "need": "ribbon", "text": "Our first ribbon. He ate a corner of it, but it still counts."},
	{"id": "friend", "title": "A friend for Bubák", "need": "mate", "text": "Two bunnies, one loaf. He was never lonely again."},
	{"id": "foster", "title": "Little guests", "need": "foster", "text": "The rescue sent us scared little bunnies, and Bubák showed every one of them that people are kind."},
	{"id": "fame", "title": "Bunnyfluencer", "need": "fame", "text": "Thousands of people now wait for his next photo. He mostly waits for his next carrot."},
	{"id": "champion", "title": "Champion", "need": "champion", "text": "The National championship. Under the lights, in front of the judges, he did it."},
	{"id": "seasons", "title": "A year of seasons", "need": "seasons", "text": "Petals in spring, puddle naps in summer, leaf piles in autumn, the first snow in winter."},
	{"id": "treasure", "title": "The treasure", "need": "treasure", "text": "He dug up a map, piece by piece, and the X was in our own living room."},
	{"id": "self", "title": "Who he is", "need": "trait", "text": "Every bunny becomes someone. This is who Bubák became."},
	{"id": "games", "title": "The Bunny Games", "need": "games", "text": "The biggest stage of all, and our little bunny right in the middle of it."},
	{"id": "inseparable", "title": "Inseparable", "need": "inseparable", "text": "He falls asleep in my hand now. Some things are worth every day it took."},
]
const BOOK_COST := 2000          # to publish
const BOOK_FANS := 3000          # from the book signing

## ---- coming back for more -------------------------------------------------------------

## Today's tasks: three a day, picked from these (the ones that fit how far you are). stat: a
## Game.stats counter that has to go up by n today; needs: what has to be there for it.
const DAILY_TASKS := [
	{"id": "photos", "stat": "photos", "n": 4, "text": "Take %d photos"},
	{"id": "rare", "stat": "rare_photos", "n": 1, "text": "Photograph a rare moment (a sparkly one)"},
	{"id": "treats", "stat": "treats", "n": 3, "text": "Give Bubák %d treats"},
	{"id": "pets", "stat": "pets", "n": 3, "text": "Cuddle Bubák %d times"},
	{"id": "work", "stat": "work", "n": 2, "text": "Work %d shifts"},
	{"id": "train", "stat": "training", "n": 3, "needs": "club", "text": "Practise tricks %d times"},
	{"id": "groom", "stat": "grooms", "n": 1, "needs": "grooming", "text": "Give Bubák a grooming"},
	{"id": "show", "stat": "shows", "n": 1, "needs": "shows", "text": "Enter a show"},
	{"id": "agility", "stat": "agility_runs", "n": 2, "needs": "agility", "text": "Do %d agility runs"},
	{"id": "crops", "stat": "crops", "n": 2, "needs": "veg_patch", "text": "Pick %d crops"},
	{"id": "walk", "stat": "walks", "n": 1, "needs": "leash", "text": "Go for a walk"},
	{"id": "dig", "stat": "digs", "n": 2, "needs": "digbox", "text": "Let Bubák dig %d times"},
	{"id": "brush_mate", "stat": "mate_pets", "n": 2, "needs": "mate", "text": "Cuddle Bubák's friend %d times"},
]
const DAILY_COINS := 25        # per task
const DAILY_ALL := 60          # all three: a sticker on the calendar and this bonus
const STICKER_PAGE := 7        # every 7 stickers: a page of the sticker book is full
const STICKER_PAGE_COINS := 250

## Seasons, by month. Each brings something to the balcony and, once a year, a find.
const SEASONS := {
	"spring": {"name": "Spring", "months": [3, 4, 5], "gift": "blossom", "behaviour": "petal_chase"},
	"summer": {"name": "Summer", "months": [6, 7, 8], "gift": "straw_hat", "behaviour": "melt"},
	"autumn": {"name": "Autumn", "months": [9, 10, 11], "gift": "scarf", "behaviour": "leaf_pile"},
	"winter": {"name": "Winter", "months": [12, 1, 2], "gift": "snowflake", "behaviour": "snow_sniff"},
}
const HEATWAVE_CHANCE := 0.3    # of summer days
const SNOW_CHANCE := 0.5        # of winter days

## Things that just happen now and then (alongside the cat and playdates, see VISIT_EVERY).
const STORM_LENGTH := 75.0      # seconds
const STORM_COMFORT := 1.5      # trust for comforting him in a storm (once a storm)
const KIDS := ["Ema", "Kuba", "Lucie", "Tom"]   # the neighbours' children
const KID_TRUST := 3            # at Trusting and up he enjoys the visit
const HIDE_SEEK_TIME := 60.0    # then he comes out on his own

## Things Bubák digs up in the dig box. One of MAP_PIECES pieces makes a treasure map.
const DIG_CHANCE := 0.35        # of a dig turning something up
const FINDS := {
	"button": {"name": "Shiny button", "weight": 6},
	"marble": {"name": "Glass marble", "weight": 5},
	"cap": {"name": "Bottle cap", "weight": 6},
	"coin": {"name": "Old coin", "weight": 3, "coins": 40},
	"ring": {"name": "Tiny ring", "weight": 1},
	"map": {"name": "Treasure map piece", "weight": 5},
}
const MAP_PIECES := 8
const TREASURE_COINS := 1500
## Where a treasure can be buried (in the living room, clear of the buttons along the bottom).
const TREASURE_SPOTS := [Vector2(230, 610), Vector2(560, 560), Vector2(760, 640), Vector2(980, 600), Vector2(160, 670),
	Vector2(420, 660), Vector2(860, 540), Vector2(1180, 600)]
const TREASURE_RADIUS := 70.0

## Postcards from the families who adopted your foster bunnies: a few days after, then a month.
const LETTER_DAYS := [4, 30]
const LETTERS := {
	"pip": [{"text": "Pip has a whole cardboard village now and visits every house twice a day. Still hides from the vacuum, but who doesn't?"},
		{"text": "Big news: Pip hopped onto the sofa all by himself and fell asleep next to us. We cried a little."}],
	"tofu": [{"text": "Tofu inspects every salad leaf like a food critic. Five stars for coriander, one star for lettuce."},
		{"text": "Tofu now has her own little garden box. She guards it like a dragon guards gold."}],
	"bramble": [{"text": "Bramble only nipped once this week, and it was the newspaper. We think he's proud of it."},
		{"text": "Bramble lets the kids brush him now. He pretends not to like it, then flops."}],
	"poppy": [{"text": "Ruby jumped at the doorbell only twice today. A record! She loves her tunnel."},
		{"text": "Ruby did her first binky in the garden. Thank you for teaching her that people are kind."}],
	"maple": [{"text": "Maple has opinions about which bowl is hers (all of them). Doing great!"},
		{"text": "Maple has a best friend now: our old cat. They nap in the sun together."}],
	"ziggy": [{"text": "Ziggy has rearranged the living room twice. We let him. He has taste."},
		{"text": "Ziggy comes running when we say his name. Well, when we open the treat jar."}],
}
## The Hall of Fame: fosters who stayed until they trusted you a lot more than they had to.
const HALL_SILVER := 3          # Trusting
const HALL_GOLD := 4            # Cuddly
const HALL_BONUS := 0.5         # extra share of the rescue's thank-you per level above FOSTER_GOAL
const MENTOR_LEVEL := 5         # Bubák at Bonded helps foster bunnies settle in
const MENTOR_RATE := 1.3

## Personality: what he does most shapes who he becomes. Points come from playing; each trait
## has levels at TRAIT_AT points, but only his two strongest traits can go past level 1.
const TRAITS := {
	"athlete": {"name": "Athletic", "icon": "trait_athlete", "behaviour": "parkour",
		"desc": "From agility, walks and exercise toys. More hang time on the course, and restless without exercise."},
	"cuddler": {"name": "Lap bunny", "icon": "trait_cuddler", "behaviour": "puddle",
		"desc": "From cuddles and snuggles. Petting brings more joy, and a long cuddle turns into a floppy puddle."},
	"showoff": {"name": "Little star", "icon": "trait_showoff", "behaviour": "pose",
		"desc": "From shows, photos and tricks. More likes on photos and points at shows, and a pose for every camera."},
	"explorer": {"name": "Explorer", "icon": "trait_explorer", "behaviour": "inspect",
		"desc": "From walks, the balcony and digging. More finds on walks and in the dig box."},
}
const TRAIT_ORDER := ["athlete", "cuddler", "showoff", "explorer"]
const TRAIT_AT := [40.0, 160.0, 400.0]
const TRAIT_NAMES := ["a little", "quite", "very"]

## The photo album: a page per kind of moment; a photo of each fills its slot.
const ALBUM_PAGES := [
	{"name": "Everyday", "slots": ["hop", "idle", "nom", "munch", "drink", "potty", "loaf", "nap", "groom", "treat", "chin", "beg"]},
	{"name": "Playtime", "slots": ["hide", "ball", "tunnel", "chew", "dig", "forage", "treat_ball", "hurdles", "castle", "sleep_bed", "show_off", "peekaboo"]},
	{"name": "Outdoors", "slots": ["balcony", "sunbathe", "bird_watch", "herb_thief", "graze", "chill", "lookout", "shade_nap", "butterfly", "bird_friend"]},
	{"name": "Feelings", "slots": ["thump", "bowl_flip", "binky", "zoomies", "flop", "bonk", "selfie", "purr", "circle", "hand_lick", "trust_nap"]},
	{"name": "Seasons", "slots": ["petal_chase", "melt", "leaf_pile", "snow_sniff", "xmas_tree", "present"]},
	{"name": "Personality", "slots": ["parkour", "puddle", "pose", "inspect"]},
	{"name": "Friends", "slots": ["snuggle", "big_brother", "pip", "tofu", "bramble", "poppy", "maple", "ziggy"]},
]
const ALBUM_PAGE_COINS := 200
const ALBUM_ALL_COINS := 2500

## Yearly vaccination at the vet; overdue (after a grace period) means no shows, walks or playdates.
const VACCINE_DAYS := 365
const VACCINE_FIRST := 30       # days after you met
const VACCINE_GRACE := 14
const VACCINE_COST := 90
## Neglected grooming has small effects: long nails make him skid (fewer binkies), a matted coat
## gets fewer likes.
const NAILS_LONG := 85.0
const COAT_MATTED := 15.0

## The daily agility course: the same for everyone today. Faults add seconds to your time.
const AGILITY_FAULT_TIME := 4.0
const AGILITY_DAILY_COINS := 40

var _tex_cache := {}
var _soft: GradientTexture2D


## Art is rasterised at 2x (backgrounds 1.5x, see the .import files / [importer_defaults])
## so it stays sharp on big screens; this reports it at its design size, so game code
## can use plain sizes and positions.
const ART_SCALE := 2.0
const BG_SCALE := 1.5


func tex(name: String) -> Texture2D:
	if not _tex_cache.has(name):
		var t: Texture2D = load(ART + name + ".svg")
		var s := BG_SCALE if name in ["room", "balcony"] else ART_SCALE
		var img := t.get_image()
		var it := ImageTexture.create_from_image(img)
		it.set_size_override(Vector2i(roundi(img.get_width() / s), roundi(img.get_height() / s)))
		_tex_cache[name] = it
	return _tex_cache[name]


## A soft white blob (opaque centre, fading edge) for shadows, glows and puffs; tint with modulate.
func soft_circle() -> Texture2D:
	if _soft == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.55))
		_soft = GradientTexture2D.new()
		_soft.gradient = g
		_soft.fill = GradientTexture2D.FILL_RADIAL
		_soft.fill_from = Vector2(0.5, 0.5)
		_soft.fill_to = Vector2(1.0, 0.5)
		_soft.width = 128
		_soft.height = 128
	return _soft


func icon(name: String) -> Texture2D:
	if ResourceLoader.exists(ART + "icon_" + name + ".svg"):
		return tex("icon_" + name)
	return tex(name)


func item_name(id: String) -> String:
	return tr(ITEMS[id].name)


func behaviour_name(id: String) -> String:
	return tr(BEHAVIOURS[id].name) if BEHAVIOURS.has(id) else tr("Blurry")


func level_name(lvl: int) -> String:
	return tr(TRUST_LEVELS[lvl].name)


func cozy_name(lvl: int) -> String:
	return tr(COZY_LEVELS[lvl - 1].name)


func career_title(lvl: int) -> String:
	return tr(CAREER[lvl].title)


func goal_text(g: Dictionary) -> String:
	var text := tr(g.text)
	if not "%" in text:
		return text
	match g.type:
		"trust": return text % level_name(g.n)
		"career": return text % career_title(g.n)
	return text % g.n


func trick_name(id: String) -> String:
	return tr(TRICKS[id].name)


func cat_name(id: String) -> String:
	return tr(SHOW_CATS[id].name)


func tier_name(t: int) -> String:
	return tr(SHOW_TIERS[t].name)


## A rosette for 1st-3rd place; the National championship's winner gets a cup.
func trophy_tex(t: Dictionary) -> String:
	return "trophy" if t.tier == 2 and t.place == 1 else "rosette_%d" % t.place


func mate_name(id: String) -> String:
	return tr(rabbit(id).get("name", id))


## A rescue rabbit's details: a friend for Bubák or a foster bunny.
func rabbit(id: String) -> Dictionary:
	return MATES.get(id, FOSTERS.get(id, {}))


func quirk_name(id: String) -> String:
	return tr(QUIRKS[id].name)


func merch_name(id: String) -> String:
	return tr(MERCH[id].name)


func season_name(id: String) -> String:
	return tr(SEASONS[id].name)


func find_name(id: String) -> String:
	return tr(FINDS[id].name)


func trait_name(id: String) -> String:
	return tr(TRAITS[id].name)


func rival_name(id: String) -> String:
	return tr(RIVALS[id].name)


## Trust needed for level `i` (lower in a fast game).
func level_at(i: int) -> float:
	return FAST_TRUST_AT[i] if Game.fast_game else TRUST_LEVELS[i].at


## How much trust a treat wins (it was worth more in the original, fast game).
func treat_trust(id: String) -> float:
	return FAST_TREAT_TRUST.get(id, ITEMS[id].trust) if Game.fast_game else ITEMS[id].trust


func trust_level_for(trust: float) -> int:
	var lvl := 0
	for i in TRUST_LEVELS.size():
		if trust >= level_at(i):
			lvl = i
	return lvl
