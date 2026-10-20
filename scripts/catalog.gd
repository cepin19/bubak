extends Node
## Static game data: shop items, Bubák's behaviours and trust levels.

const ART := "res://assets/art/"

## Milestone that unlocks the balcony (then the netting must be bought).
const BALCONY_TRUST := 3
const BALCONY_FOLLOWERS := 300

const TRUST_LEVELS := [
	{"at": 0.0, "name": "Shy"},
	{"at": 15.0, "name": "Curious"},
	{"at": 35.0, "name": "Friendly"},
	{"at": 60.0, "name": "Bonded"},
	{"at": 85.0, "name": "Best buds"},
]

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
		"desc": "Healthy green snack.", "food": 6.0, "fun": 4.0, "trust": 2.5, "sugar": 0.0},
	"carrot": {"name": "Carrot", "kind": "treat", "price": 5, "qty": 1, "icon": "carrot",
		"desc": "Crunchy and sweet. Don't overdo it.", "food": 10.0, "fun": 6.0, "trust": 3.5, "sugar": 18.0},
	"apple": {"name": "Apple slice", "kind": "treat", "price": 7, "qty": 1, "icon": "apple",
		"desc": "His absolute favourite! Sweet, so just a slice now and then.", "food": 8.0, "fun": 12.0, "trust": 6.0, "sugar": 35.0},
	"branch": {"name": "Leafy branch", "kind": "toy", "price": 10, "icon": "branch", "tex": "branch",
		"scale": 0.85, "use": "chew_toy", "max": 2, "bites": 4,
		"desc": "Fresh branch with leaves. He eats the lot, leaves first. Keeps him off cables."},

	"ball": {"name": "Willow ball", "kind": "toy", "price": 20, "icon": "ball", "tex": "ball",
		"scale": 0.7, "use": "play_ball", "max": 2, "cozy": 1, "desc": "To nudge, toss and chase."},
	"box": {"name": "Cardboard castle", "kind": "toy", "price": 15, "icon": "box", "tex": "box",
		"scale": 0.85, "use": "hide_box", "max": 1, "cozy": 1, "desc": "A hideout. Very important bunny business."},
	"tunnel": {"name": "Play tunnel", "kind": "toy", "price": 45, "icon": "tunnel", "tex": "tunnel",
		"scale": 0.85, "use": "tunnel", "max": 1, "cozy": 2, "desc": "Zoom in one end, out the other."},

	"bed": {"name": "Cushy bed", "kind": "decor", "price": 55, "icon": "bed", "tex": "bed",
		"scale": 0.85, "use": "sleep", "max": 1, "cozy": 3, "desc": "Naps here restore energy faster."},
	"rug": {"name": "Cozy rug", "kind": "decor", "price": 35, "icon": "rug", "tex": "rug",
		"scale": 1.0, "flat": true, "max": 2, "cozy": 2, "desc": "Soft paws, happy bunny."},
	"plant": {"name": "Potted fern", "kind": "decor", "price": 25, "icon": "plant", "tex": "plant",
		"scale": 0.8, "max": 3, "cozy": 1, "desc": "Makes photos look fancier."},
	"lamp": {"name": "Floor lamp", "kind": "decor", "price": 40, "icon": "lamp", "tex": "lamp",
		"scale": 0.8, "max": 1, "cozy": 2, "desc": "Warm light in the evening."},
	"digbox": {"name": "Dig box", "kind": "toy", "price": 45, "icon": "digbox", "tex": "digbox",
		"scale": 0.8, "use": "dig", "max": 1, "cozy": 2, "desc": "A box of sand for very important digging."},
	"puzzle": {"name": "Treat puzzle", "kind": "toy", "price": 35, "icon": "puzzle", "tex": "puzzle",
		"scale": 0.8, "use": "forage", "max": 1, "cozy": 1, "desc": "Hides little snacks under the lids. Makes him think."},
	"hut": {"name": "Wooden hut", "kind": "toy", "price": 80, "icon": "hut", "tex": "hut", "req_cozy": 2,
		"scale": 0.8, "use": "hide_box", "max": 1, "cozy": 3, "desc": "A hideaway that smells like a forest."},
	"castle": {"name": "Bunny castle", "kind": "toy", "price": 260, "icon": "castle", "tex": "castle", "req_cozy": 3,
		"scale": 0.85, "use": "castle", "max": 1, "cozy": 5, "desc": "Two floors of castle. He rules from the top."},
	"teepee": {"name": "Teepee tent", "kind": "decor", "price": 110, "icon": "teepee", "tex": "teepee", "req_cozy": 2,
		"scale": 0.8, "use": "sleep", "max": 1, "cozy": 4, "desc": "A tent for very cozy naps."},
	"beanbag": {"name": "Bean bag", "kind": "decor", "price": 70, "icon": "beanbag", "tex": "beanbag",
		"scale": 0.85, "max": 1, "cozy": 3, "desc": "He flops on it like he owns it. He does."},
	"lantern": {"name": "Paper lantern", "kind": "decor", "price": 30, "icon": "lantern", "tex": "lantern",
		"scale": 0.8, "max": 2, "cozy": 1, "desc": "A soft glow for the evenings."},
	"flowers": {"name": "Flower pot", "kind": "decor", "price": 20, "icon": "flowers", "tex": "flowers",
		"scale": 0.8, "max": 3, "cozy": 1, "desc": "Pretty. Not for eating. Probably."},

	# Upgrades: "slot" + "tier". Care slots start at tier 1, desk gear at tier 0.
	"bowl2": {"name": "Big food bowl", "kind": "upgrade", "slot": "bowl", "tier": 2, "price": 70,
		"icon": "bowl_t2_full", "cozy": 2, "desc": "Holds 5 portions instead of 3."},
	"bowl3": {"name": "Royal food bowl", "kind": "upgrade", "slot": "bowl", "tier": 3, "price": 220, "req_cozy": 3,
		"icon": "bowl_t3_full", "cozy": 2, "desc": "Holds 8 portions. Fit for a bunny king."},
	"water2": {"name": "Big water bowl", "kind": "upgrade", "slot": "water", "tier": 2, "price": 60,
		"icon": "water_t2_full", "cozy": 2, "desc": "Holds more water, so it lasts longer."},
	"water3": {"name": "Water fountain", "kind": "upgrade", "slot": "water", "tier": 3, "price": 240, "req_cozy": 3,
		"icon": "water_t3_full", "cozy": 2, "desc": "Fresh running water. Lasts ages, and drinking is fun."},
	"hayrack2": {"name": "Big hay rack", "kind": "upgrade", "slot": "hayrack", "tier": 2, "price": 80,
		"icon": "hayrack_t2_full", "cozy": 2, "desc": "Holds more hay, and each refill lasts longer."},
	"hayrack3": {"name": "Hay house", "kind": "upgrade", "slot": "hayrack", "tier": 3, "price": 260, "req_cozy": 3,
		"icon": "hayrack_t3_full", "cozy": 2, "desc": "A hay rack with a roof. Holds a whole bale."},
	"litter2": {"name": "Corner litter box", "kind": "upgrade", "slot": "litter", "tier": 2, "price": 70,
		"icon": "litter_t2", "cozy": 2, "desc": "High back, less mess. Stays clean longer."},
	"litter3": {"name": "Luxury litter box", "kind": "upgrade", "slot": "litter", "tier": 3, "price": 230, "req_cozy": 3,
		"icon": "litter_t3", "cozy": 2, "desc": "Stays clean much longer. Has ears!"},
	"chair": {"name": "Comfy office chair", "kind": "upgrade", "slot": "chair", "tier": 1, "price": 90,
		"icon": "chair", "cozy": 1, "desc": "Shorter breaks between work shifts."},
	"monitor": {"name": "Second monitor", "kind": "upgrade", "slot": "monitor", "tier": 1, "price": 160, "req_career": 1,
		"icon": "monitor", "cozy": 1, "desc": "+25% pay for remote work."},
	"coffee": {"name": "Coffee machine", "kind": "upgrade", "slot": "coffee", "tier": 1, "price": 140, "req_career": 2,
		"icon": "coffee", "cozy": 1, "desc": "Work shifts last 5 seconds longer."},
	"headphones": {"name": "Noise-cancelling headphones", "kind": "upgrade", "slot": "headphones", "tier": 1, "price": 260,
		"req_career": 3, "icon": "headphones", "cozy": 1, "desc": "Another +25% pay for remote work."},

	# Things Bubák can wear (one at a time). Photos with an outfit get more likes.
	"bow": {"name": "Red bow", "kind": "wear", "price": 45, "icon": "wear_bow", "tex": "wear_bow",
		"desc": "A classic. Photos with an outfit get more likes."},
	"glasses": {"name": "Round glasses", "kind": "wear", "price": 90, "icon": "wear_glasses", "tex": "wear_glasses_side",
		"desc": "Very smart. Very scholarly."},
	"crown": {"name": "Flower crown", "kind": "wear", "price": 150, "req_cozy": 2, "icon": "wear_crown", "tex": "wear_crown",
		"desc": "Spring, all year round."},
	"tophat": {"name": "Tiny top hat", "kind": "wear", "price": 300, "req_cozy": 4, "icon": "wear_tophat", "tex": "wear_tophat",
		"desc": "For a bunny of distinction."},

	"balcony_net": {"name": "Balcony netting", "kind": "upgrade", "price": 120, "icon": "door_open", "cozy": 3,
		"desc": "Makes the balcony bunny-safe, so Bubák can go out and enjoy the fresh air."},
	"cable_cover": {"name": "Cable cover", "kind": "upgrade", "price": 60, "icon": "cable_covered", "cozy": 1,
		"desc": "Protects the laptop charger from Bubák's teeth. Forever."},

	# Show club gear (kind "gear": owned once, used in training and grooming).
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
	"Toys": ["ball", "box", "tunnel", "puzzle", "digbox", "hut", "castle"],
	"Home": ["bed", "rug", "plant", "flowers", "lantern", "lamp", "beanbag", "teepee", "cable_cover", "balcony_net"],
	"Upgrades": ["bowl2", "bowl3", "water2", "water3", "hayrack2", "hayrack3", "litter2", "litter3",
		"chair", "monitor", "coffee", "headphones"],
	"Style": ["bow", "glasses", "crown", "tophat"],
	"Club": ["clicker", "pouch", "hoop", "brush", "comb", "clippers"],
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
	"castle": {"name": "King of the castle", "likes": 140, "desc": "Surveying his kingdom from the top floor.", "needs": "castle"},
	"sleep_bed": {"name": "Cozy bed nap", "likes": 80, "desc": "Snoozing in his very own bed.", "needs": "bed"},
	"balcony": {"name": "Fresh air", "likes": 60, "desc": "His first trip out onto the balcony.", "needs": "balcony"},
	"sunbathe": {"name": "Sunbathing", "likes": 90, "desc": "Stretched out in a warm patch of sun.", "needs": "balcony"},
	"bird_watch": {"name": "Bird watching", "likes": 100, "desc": "Up on his hind legs, very interested in that pigeon.", "needs": "balcony"},
	"herb_thief": {"name": "Herb thief", "likes": 70, "desc": "Those herbs were for cooking. Were.", "needs": "balcony"},
	"thump": {"name": "THUMP!", "likes": 60, "desc": "A warning stomp. Something scared him."},
	"chew_cable": {"name": "Cable crime", "likes": 80, "desc": "Caught red-pawed. Naughty!"},
	"chin": {"name": "Chinning", "likes": 50, "desc": "Rubs his chin on things: \"this is MINE.\"", "level": 1},
	"beg": {"name": "Begging", "likes": 90, "desc": "Stands tall when he knows you have treats.", "level": 1},
	"bowl_flip": {"name": "Bowl flip", "likes": 110, "desc": "Empty bowl? Unacceptable!", "level": 1},
	"binky": {"name": "Binky!", "likes": 160, "desc": "A happy jump-twist. Pure joy.", "level": 2},
	"zoomies": {"name": "Zoomies", "likes": 120, "desc": "Sudden laps around the flat at full speed.", "level": 2},
	"flop": {"name": "Flop", "likes": 200, "desc": "Falls over on his side. Total trust.", "level": 3},
	"bonk": {"name": "Nose bonk", "likes": 150, "desc": "Boop! He only does this to his favourite people.", "level": 3},
	"selfie": {"name": "Selfie together", "likes": 220, "desc": "Cheek to cheek. Your followers can't get enough.", "level": 3},
	"snuggle": {"name": "Snuggle buddies", "likes": 260, "desc": "Two bunnies, one fluffy loaf.", "needs": "mate"},
	"show_off": {"name": "Show-off", "likes": 130, "desc": "Does a trick nobody asked for. Then waits for applause.", "needs": "tricks"},
	"purr": {"name": "Tooth purr", "likes": 120, "desc": "Soft teeth-clicking while petted. Bliss.", "level": 4},
}

const BEHAVIOUR_ORDER := ["hop", "idle", "nom", "munch", "drink", "potty", "loaf", "nap", "groom",
	"treat", "thump", "chew_cable", "hide", "ball", "tunnel", "chew", "dig", "forage", "castle", "sleep_bed",
	"balcony", "sunbathe", "bird_watch", "herb_thief", "chin", "beg",
	"bowl_flip", "binky", "zoomies", "flop", "bonk", "selfie", "purr", "show_off", "snuggle"]

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
	{"id": "up4", "type": "upgrades", "n": 4, "reward": 90, "text": "Buy %d upgrades"},
	{"id": "fol500", "type": "followers", "n": 500, "reward": 90, "text": "Reach %d followers"},
	{"id": "career4", "type": "career", "n": 4, "reward": 120, "text": "Get promoted to %s"},
	{"id": "jobstars", "type": "jobstars", "n": 3, "reward": 100, "text": "Get 3 stars in %d different jobs"},
	{"id": "cozy5", "type": "cozy", "n": 5, "reward": 150, "text": "Reach Cozy level %d"},
	{"id": "seen25", "type": "seen", "n": 25, "reward": 180, "text": "Discover %d behaviours"},
	{"id": "trust4", "type": "trust", "n": 4, "reward": 180, "text": "Reach trust: %s"},
	{"id": "wear4", "type": "wardrobe", "n": 4, "reward": 180, "text": "Collect all %d accessories"},
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
	{"id": "mate", "type": "mate", "n": 1, "reward": 150, "mate": 1, "text": "Adopt a friend for Bubák"},
	{"id": "bond", "type": "bond", "n": 100, "reward": 300, "mate": 1, "text": "Make them best friends"},
]

## Late in the game Bubák can get a friend from the rescue's hutch.
const MATE_TRUST := 3
const MATE_COZY := 4
## trust: how much the newcomer trusts you at first; trust_rate: how fast that grows.
const MATES := {
	"luna": {"name": "Luna", "price": 600, "trust": 5.0, "trust_rate": 0.8,
		"desc": "A gentle cream bunny. Shy at first, but oh so sweet."},
	"caramel": {"name": "Caramel", "price": 750, "trust": 15.0, "trust_rate": 1.3,
		"desc": "Golden, bouncy and friendly with everyone."},
	"hazel": {"name": "Hazel", "price": 650, "trust": 10.0, "trust_rate": 1.0,
		"desc": "Chocolate brown with a white nose. Loves digging."},
	"shadow": {"name": "Shadow", "price": 900, "trust": 0.0, "trust_rate": 0.7,
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


func trust_level_for(trust: float) -> int:
	var lvl := 0
	for i in TRUST_LEVELS.size():
		if trust >= TRUST_LEVELS[i].at:
			lvl = i
	return lvl
