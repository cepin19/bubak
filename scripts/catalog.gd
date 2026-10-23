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
]
## Trust is slow to earn: each level gains it slower than the last (TRUST_PACE[level]), and the more
## he has warmed up today, the less each extra bit counts: gains are divided by 1 + today / TRUST_DAILY.
const TRUST_PACE := [1.0, 0.9, 0.75, 0.6, 0.5, 0.4, 0.35]
## Settings > Game pace > Fast: the original quick game. Bubák bonds within a session or two:
## lower thresholds, no slowdown per level or per day, treats count fully every time and are
## worth what they used to be, and the friend comes at Cuddly in a Cozy level 4 flat.
const FAST_TRUST_AT := [0.0, 15.0, 35.0, 50.0, 60.0, 72.0, 85.0]
const FAST_TREAT_TRUST := {"parsley": 1.0, "carrot": 1.5, "apple": 2.0, "dandelion": 5.0, "hay_cookie": 6.5,
	"banana_chips": 7.5, "rose_petals": 9.0, "dried_apple": 12.0}
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
	"leash": {"name": "Harness & leash", "kind": "gear", "price": 650, "icon": "leash", "stage": 1, "req_trust": 5, "req_stars": 6,
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
	"Balcony": ["grass_tray", "bird_feeder", "cool_tile", "wind_chime", "parasol", "lookout"],
	"Home": ["bed", "rug", "plant", "flowers", "lantern", "lamp", "beanbag", "teepee", "cable_cover", "balcony_net"],
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
}

const BEHAVIOUR_ORDER := ["hop", "idle", "nom", "munch", "drink", "potty", "loaf", "nap", "groom",
	"treat", "thump", "chew_cable", "hide", "ball", "tunnel", "chew", "dig", "forage", "treat_ball", "hurdles", "castle", "sleep_bed",
	"balcony", "sunbathe", "bird_watch", "herb_thief", "graze", "chill", "lookout", "shade_nap", "butterfly", "bird_friend", "chin", "beg",
	"bowl_flip", "binky", "zoomies", "flop", "bonk", "selfie", "purr", "show_off", "snuggle"]

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
	{"id": "outfit", "type": "outfit", "n": 4, "reward": 90, "text": "Dress Bubák in a full outfit: something on all %d places"},
	{"id": "wear4", "type": "wardrobe", "n": 12, "reward": 300, "text": "Collect all %d accessories"},
	{"id": "fol1500", "type": "followers", "n": 1500, "reward": 240, "text": "Reach %d followers"},
	{"id": "career5", "type": "career", "n": 5, "reward": 240, "text": "Get promoted to %s"},
	{"id": "cozy6", "type": "cozy", "n": 6, "reward": 300, "text": "Turn the flat into a bunny paradise"},
	{"id": "seenall", "type": "seen", "n": -1, "reward": 300, "text": "Discover every behaviour"},
	# show club, added as it unlocks (stage)
	{"id": "star1", "type": "stars", "n": 1, "reward": 25, "stage": 1, "text": "Teach Bubák his first trick"},
	{"id": "star6", "type": "stars", "n": 6, "reward": 80, "stage": 1, "text": "Earn %d trick stars"},
	{"id": "starall", "type": "stars", "n": 12, "reward": 250, "stage": 1, "text": "Master every trick"},
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
	{"id": "bond", "type": "bond", "n": 100, "reward": 300, "mate": 1, "text": "Make them best friends"},
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


func walk_name(id: String) -> String:
	return tr(WALKS[id].name)


## Late in the game Bubák can get a friend from the rescue's hutch.
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
		"desc": "A gentle cream bunny. Shy at first, but oh so sweet."},
	"caramel": {"name": "Caramel", "weight": 4300, "price": 750, "trust": 15.0, "trust_rate": 1.3,
		"desc": "Golden, bouncy and friendly with everyone."},
	"hazel": {"name": "Hazel", "weight": 4000, "price": 650, "trust": 10.0, "trust_rate": 1.0,
		"desc": "Chocolate brown with a white nose. Loves digging."},
	"shadow": {"name": "Shadow", "weight": 4500, "price": 900, "trust": 0.0, "trust_rate": 0.7,
		"desc": "Sleek, black and a little mysterious. Bubák can't stop staring."},
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
}
const TRICK_ORDER := ["come", "stand", "spin", "hoop"]
## Training progress needed for each star (3 stars = mastered).
const TRICK_STARS := [100, 250, 450]
const FOCUS_MAX := 6          # tries per training session (+3 with the treat pouch)
const FOCUS_REFILL := 300.0   # seconds per try to come back

## Show categories and tiers. Tiers unlock with first places in the tier below.
const SHOW_CATS := {
	"looks": {"name": "Best in Show", "icon": "condition", "desc": "Coat, nails, outfit and how calm he is with the judge."},
	"tricks": {"name": "Tricks", "icon": "spin", "desc": "Perform a routine. Reward him at the right moment!"},
	"photo": {"name": "Photogenic", "icon": "camera", "desc": "Your best photo goes in front of the judges."},
}
const SHOW_TIERS := [
	{"name": "Neighbourhood show", "fee": 15, "wait": 2 * 3600, "prize": [70, 40, 20], "fans": [30, 15, 8], "rivals": -18, "wins": 0},
	{"name": "Regional show", "fee": 60, "wait": 6 * 3600, "prize": [240, 130, 60], "fans": [110, 55, 25], "rivals": 0, "wins": 2},
	{"name": "National championship", "fee": 200, "wait": 20 * 3600, "prize": [900, 450, 200], "fans": [450, 220, 100], "rivals": 14, "wins": 2},
]
## Rival bunnies. Strengths per category (0-100 before the tier adjustment).
const RIVALS := {
	"duchess": {"name": "Duchess Fluffington", "looks": 78, "tricks": 52, "photo": 70, "desc": "A snooty white lop. Has never been seen without a bow."},
	"pepik": {"name": "Pepík", "looks": 55, "tricks": 76, "photo": 58, "desc": "A scrappy little dwarf with a mighty jump."},
	"pusinka": {"name": "Marshmallow", "looks": 70, "tricks": 50, "photo": 80, "desc": "Fluffy, sweet, and the internet adores her."},
	"baron": {"name": "Baron von Hop", "looks": 64, "tricks": 70, "photo": 62, "desc": "Dapper and serious. Takes every show personally."},
	"clover": {"name": "Clover", "looks": 60, "tricks": 64, "photo": 66, "desc": "A cheerful ginger lop. Everyone's friend."},
}

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
	return tr(MATES[id].name)


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
