# Bubák

A cozy caretaker game for Linux and Android. You look after Bubák, a cheeky lilac-grey bunny
with one perky ear and one floppy ear, who lives in your apartment. (`bubak_photos/` holds photos
of the real Bubák; a `.gdignore` keeps them out of the build.)

## How to play

- **Bowls, hay rack, litter box:** tap them to refill or clean them.
- **Pet Bubák:** hold your finger on him. Poking him quickly scares him. He's shy at first.
  Petting builds trust only once an hour; in between it's just a cuddle (fun, no trust).
- **Trust takes weeks.** Each level grows slower than the last, and from Friendly up there's a
  daily maximum (counting everything, walks and presents too) that shrinks at every level. When
  it's reached, a message says so and more trust comes tomorrow. Roughly: Trusting in 4 days,
  Cuddly 9, Bonded 15, Best buds 25 (Normal game; Fast game is unchanged). The final level,
  **Inseparable**, takes about 40 more days of play after Best buds (at most 0.15 trust a day).
- **Treats:** pick one, then tap the floor. He comes over and eats from your hand. Too many
  sweet ones give him a tummy ache. Cheap treats (parsley, carrot, apple) build trust slowly; the
  pricey Gourmet tab (dandelions, hay cookie, banana chips, rose petals and dried apple rings, his
  favourite, which make him binky) wins him over faster.
- **Pick him up:** drag him upwards (or tap Selfie in Photo mode) to cuddle him and snap a selfie
  together. This only works once he trusts you (Cuddly). Try earlier and he bolts, and trust drops.
- **Photo:** catch him doing cute things. Rare moments sparkle and pay the most coins.
  New behaviours pay double; repeating the same shot pays less. Don't overdo it:
  - **Followers' attention** (the bar in Photo mode) drops with every post and comes back over
    about 40 minutes. A busy feed gets fewer likes, and once it's flooded, followers unfollow.
  - **Bubák and the flash:** after 3 photos of him within 2 minutes he gets tired of the camera;
    one more and he runs off (trust drops) and turns his back on the camera for 3 minutes. A
    second flash in a row wakes him from a nap.
  - A missed shot isn't posted and earns nothing.
  The numbers are in `scripts/catalog.gd` (`FEED_*`, `CAMERA_*`).
- **Desk / laptop:** remote work. Shifts earn coins and career XP, and promotions (Intern →
  Director of Carrots) raise pay, pay a bonus and unlock new jobs: Inbox zero, Bug hunt, Pair
  programming (memory), Video call and Crate stacking. Streaks raise a points multiplier (up to x4),
  the last 5 seconds count double, and each shift is rated 1–3 stars (more stars, more pay; best
  scores are kept). One job a day is the boss's pick, with double XP. There's a coffee break between shifts.
  Repeating the same job pays less each time (down to 30%); it wears off over time (about 30 min per
  shift), so switching jobs or taking a break keeps the pay up.
- **Prices:** home things and upgrades are an investment (60–680 coins), and balcony things more so
  (180–750, plus 400 for the netting).
- **Upgrades:** each care item has 3 tiers (bigger bowl, fountain, hay house, luxury litter box), and
  desk gear makes work pay better.
- **Coziness:** furniture, toys and upgrades raise the Cozy level (shown under the trust bar). It
  makes Bubák happier, brings more followers and unlocks fancier items.
- **Toy chest** (by the desk): tap it to put toys and furniture away or take them out
  again. Each thing takes up 1–3 space; the living room holds 25 and the balcony 16. Past that,
  the room is cluttered: every point over costs 2 cozy points, the cozy label says "Cluttered!"
  and the chest rattles its lid. Things in the chest take no space but add no coziness either.
- **Wardrobe** (the little cabinet on the wall above the sofa): Bubák up close in his outfit. One accessory per
  place (head, ears, eyes, neck), three of each; buy them in the Shop's Style tab or right in the
  wardrobe, and they go straight on. Every accessory adds photo likes and show style. With a
  friend, a switch at the top dresses the friend instead; there's one of each accessory, so it
  moves from one bunny to the other.
- **Work** is ready when the laptop jiggles.
- **Goals** (Journal) give coin rewards. Once Bubák has 25 followers, a **sponsor** pays every
  day, with a bonus for consecutive days.
- **Shop:** food, leafy branches he eats, toys (ball, box, tunnel) and home items (bed, rug, plant,
  lamp, cable cover).
- **Move:** drag furniture around.
- **Eye button** (bottom left): hides all the controls, so droppings and things behind them
  can be tapped or dragged. Tap it again (or press Back) to bring them back.
- **Balcony:** the door on the left is locked at first. Once Bubák trusts you (Trusting) and he has
  300 followers, buy Balcony netting in the shop to open it. He then goes out on his own to
  sunbathe, watch birds and raid the herb planter, and comes back in for food, water and the
  litter box. Tap the door to follow him. The milestone is set in `scripts/catalog.gd`.
  Out there:
  - **Herb planter:** tap it to pick parsley (and a dandelion when it's full) for treats. When
    there's not much left, a tap waters it so it grows back three times as fast for 15 minutes.
  - **Balcony shop tab** (once the balcony is open): wheatgrass tray (he grazes it; water it to
    regrow), bird feeder (tap to fill; sparrows visit, and sometimes one hops right up to him),
    cool stone tile (he stretches out on it on warm afternoons), wind chime (tap it: ears up),
    sun umbrella (he can nap outside in the shade) and the lookout deck (he watches the street
    from the top, and neighbours who spot him bring followers).
  - Butterflies come by on sunny days when there are herbs or flowers out, and he chases them.
  - Goals: set up 3 balcony things, and pick herbs 3 times.
- **Journal:** the behaviours you've discovered, your photo album, and stats.
- **Show club** (Club button). It opens in stages, so new players aren't swamped:
  1. **Training**, once Bubák is Curious and the flat reaches Cozy level 2. Pick a trick
     (Come, Stand up, Spin, Hoop jump). When he pulls it off, stars and a big "Now!" pop up and he
     holds the pose: tap Reward before the bar under him runs out (about 1.7 s). Don't reward him
     when he gets distracted. Each try uses focus (8 tries, one back every ~4 minutes). Tricks earn up
     to 3 stars. The clicker, treat pouch and hoop are on the shop's Club tab.
  2. **Grooming**, after his first trick star. Swipe the loose fur off his coat before his
     patience runs out, and trim his nails (needs trust). Every couple of weeks he molts for a
     few days: his coat dulls faster and he leaves tufts of fur around the flat.
  3. **Shows**, after 3 trick stars and a first grooming. The categories are Best in Show
     (coat, nails, outfit, calmness), Tricks (a live routine) and Photogenic (your best photo).
     Bubák competes against rival bunnies. There are Neighbourhood, Regional and National
     shows; two wins open the next level. Ribbons and the championship cup go on a shelf on
     the wall.
  4. **Agility** (with the shows): a course in the Club's Agility tab. Obstacles come in from the
     right. **Bars:** the gold zone on the ground ahead of him shows when to take off, and a bar
     inside it lights up with "JUMP!" (tap Jump, the course, or press Space). **Double bars** are
     wider, so the zone is shorter. **Tunnels:** don't jump, he runs through. **Weave poles:** tap
     as each pole reaches him. A take-off mid-zone is "Perfect!" and a burst of speed; a fault
     costs a moment. A jump at thin air (or a tap at no pole) leaves him puffed out for a moment,
     so tapping non-stop doesn't work. Practice runs (a try of focus each, needs the Hop hurdles)
     raise his agility skill up to 100, which gives him more hang time and a wider zone. The
     **daily course** is the same all day: a clock runs (each fault adds 4 s), the first run of
     the day pays 40 coins, and later runs race a see-through **ghost** of today's best. Agility is
     also a fourth show category (tunnels from Neighbourhood, double bars from Regional, weave
     poles at National).
  - **Your trick routine:** on the Shows tab, pick up to 4 tricks in your own order for Tricks
    shows. Longer routines and perfect tricks in a row score more.
  - **The head judge** loves something different every week (a hat, a glossy coat, a Spin, a
    clear round...), shown on the Shows tab: matching it is worth +10 points.
  - **Show league:** every month is a season. Shows earn league points (10/6/3/1 for 1st-4th,
    ×2 at Regional, ×4 at National) against the five rivals, who collect theirs day by day. The
    Club's League tab shows the standings and this month's nemesis. At the end of the month the
    season pays out by place (1,500 coins and 2,000 followers for 1st), with a bonus for finishing
    above the nemesis.
  - **Advanced tricks:** Take a bow, High five, Fetch (needs a ball) and Leg slalom, from Cuddly
    trust up and once the basic trick they build on has 2 stars. Each has two moments to reward
    (both on time for a perfect), goes wrong more often, scores more at shows, and at 3 stars
    earns a master's certificate (+300 coins).
  - **Rivals keep up:** every show Bubák wins makes the rivals a little better (up to +8). Once
    he's National champion, a newcomer from abroad (Velvet) joins the shows and the league. A
    rival he just beat may demand a **duel**: a one-on-one rematch in Club > Shows within 3 days.
    And the month's nemesis studies your routine: use the same one twice in a row and they score
    8 more.
  - **The Bunny Games:** every month, in its last 7 days. Qualify with 60 league points that
    month, then four rounds (Best in Show, Tricks, Agility, Photogenic), one a day, against
    every rival at their very best. The top 3 win coins and followers; the first win brings the
    Games cup for the flat, and every win 3 bags of special dried apples (from the best apples
    in the world: a gift treat, his favourite, worth more than any treat in the shop). A Games left half-done is scored when the month ends. Club > League.
- **Foster bunnies:** once Bubák has a friend, the rescue asks you to foster shy rabbits, one at
  a time (six in all, then they come round again). Each has a quirk: very shy (often runs off
  when petted), nips (keep cuddles short) or picky (only gourmet treats count). Win their trust up
  to Friendly and a family adopts them: coins, followers, a scrapbook memory, and the next one
  comes the following day. They show on Bubák's card and in Journal > (the friend's tab).
  You can let them stay longer: each level of trust past Friendly makes the rescue's thanks half
  as big again, and fosters who leave Trusting (silver frame) or Cuddly (gold) join the **Hall of
  Fame**. Once Bubák is Bonded he's a **big brother** to them: they settle in 30% faster, and he
  sometimes washes their ears. A few days and a month after they leave, their family sends a
  **postcard** (a drawing of their new home and a few lines), pinned to the fridge in the Journal.
- **Rare moments at the top:** Circling your feet (Bonded: he laps around you, honking), Grooming
  you (Best buds: he licks your hand while petted) and Asleep in your hand (Inseparable: he dozes
  off while you stroke him).
- **Wear and tear:** toys and amenities wear out with use (by any of the bunnies): the cardboard
  castle after about 30 games, the ball 70, the tunnel 60, the bed 120 naps, the castle 140...
  A worn one looks faded, the toy chest shows how worn it is, a message warns you at 75%, and in
  the end he loves it to pieces: it's gone and you buy a new one in the Shop. Presents and rewards
  never wear out. The numbers are `WEAR_USES` in `scripts/catalog.gd`.
- **Keeping the bond:** from Bonded up, every whole day you don't visit costs about a day's worth
  of trust (never a whole level). Not when time stands still while the game is closed.
- **Bubák merch** (on the laptop, once he's a Rising star): order batches of stickers, mugs,
  calendars, plushies and hoodies (the bigger ones need more fame). Each carries your best recent
  photo and sells by the hour, even while the game is closed (up to 12 hours), faster with more
  followers and a well-liked photo. Designs go stale over three weeks: refresh them with a newer
  photo. Collect the takings on the merch screen.
- **Weight:** Bubák's healthy weight is about 4 kg (the Journal's Bubák tab shows it). Every
  bite adds a little, food eaten on an already full tummy (piles of treats) adds a lot more, and
  sugar a bit extra. Exercise burns it off: zoomies, binkies, the ball, tunnel, dig box and castle,
  the new **hop hurdles** (a jumping course) and **treat ball** (he rolls it around for kibble),
  and walks most of all. His metabolism slowly pulls him back towards 4 kg, and it does so while the
  game is closed too, so he only gets chubby if he's fed lots of treats for hours. A chubby or thin
  bunny is a bit grumpier, a heavy one binkies less, and show judges mark down his figure. The
  numbers are in `scripts/catalog.gd` (`IDEAL_WEIGHT`, `*_GRAMS`, `EXERCISE`, `METABOLISM`), and
  `-- --weightsim=normal|bare|treats|treats_bare|sweets_bare[:hours]` plays a sped-up day and logs
  his weight, for tuning them.
- **Walks:** once Bubák is Cuddly and has 4 trick stars, the Shop's Club tab sells a harness and
  leash. Then the Walk button takes him out once a day: the park first, then the meadow (after 2
  walks), the beach (4), the city (7) and the cinema (10). Each walk is a half-minute cutscene (no
  buttons) with a string of little adventures: a butterfly on his nose in the park, binkies,
  zoomies and a dandelion in the meadow, a wave, a crab, a seagull and a sunset at the beach, a
  pigeon, a café carrot and a crowd of fans in town, and popcorn, a scary bit and a nap in the
  cinema; it brings trust (within the daily maximum) and lots of
  fun, and the city brings new followers. Goals: a first walk, and all 5 places.
- **Special days:** from 20 to 26 December the flat is decorated for Christmas: a tree with
  twinkling fairy lights and a glowing star, a garland over the window and snow falling outside.
  Bubák sometimes stands up on his hind legs to gaze at the tree. There's a present under it, and on Bubák's birthday (a date one to eleven months after you start, shown in the Journal)
  there's a present too. Tap it: he rips the paper off and uses the gift at once (a jingle ball at
  Christmas, a party hat on his birthday; later years bring a toy he hasn't got yet). One present
  per special day a year. `-- --date=12-24` pretends it's that day, for trying it out.
- **More special days:** at Easter (Saturday to Monday) painted eggs are hidden around the flat;
  find them all and a present appears (an egg rattle). Around Halloween (29-31 October) a
  jack-o'-lantern glows, bats flit past the window at night and he gets spooked now and then; the
  present is a witch hat. On the day you met (from the first year on) there's a present too.
  `-- --date=MM-DD` tries any of these.
- **Daily wishes:** every day Bubák wishes for one little thing (shown under the coins): a treat from
  your hand, a game with a toy he has, a long cuddle, a photo, a walk, the balcony or a brushing.
  Granting it pays coins, more for every day in a row, and every 7 days a bonus and rose petals.
- **Scrapbook:** the Journal's Memories tab keeps his firsts with a snapshot of the moment: the first
  binky, flop and nose bonk, each trust level, the first walk, presents, the friend moving in, a
  ribbon, the first harvest, favourites...
- **Photo challenges** (Journal > Photos): twelve shots to collect, like mid-binky, asleep at night,
  sunset on the balcony, three accessories or by the Christmas tree. Each pays once.
- **Favourites:** he grows fond of what he picks most: a toy, a napping spot, a walk. Favourites are
  in the Journal and he goes for them more often.
- **Veggie patch** (Shop > Balcony): three beds for parsley (1.5 h), carrots (4 h), dandelions (3 h)
  and roses (6 h); watering makes them grow three times faster. Ripe crops go into the treat bag.
  Picking sometimes turns up a **golden seed**: it takes a whole day to grow a golden carrot, the
  best treat there is. The **bigger veggie patch** (Shop > Balcony) adds two beds.
- **Visitors and weather:** the neighbour's cat sometimes peeks in at the window (Bubák thumps; tap
  the window to shoo it), and once a day a friend may drop by with their bunny for a playdate. Once
  a day the neighbours' child may ring: a lovely visit with a trusting bunny (Trusting and up,
  +followers), a scary one before. Now and then a **thunderstorm** rolls in (more often in summer):
  the bunnies hide, trembling, and comforting one (hold your finger on them) builds trust. And
  sometimes Bubák wants to play **hide and seek**: he hides behind the furniture with only his ears
  showing; tap him to find him.
- **The vet:** a weekly check-up (Journal > Bubák) looks at weight, teeth, mood, nails, coat and the
  litter box, and pays more when everything is fine. Once a year (first a month after you meet) he
  also needs his **vaccination** (90 coins); two weeks overdue, no shows, walks or playdates until
  he's had it. Neglected grooming shows too: very long nails make him skid (fewer binkies), a
  matted coat gets fewer likes.
- **Today's tasks** (Journal > Goals): three small tasks a day, picked to fit how far you are (take
  photos, a rare moment, cuddles, treats, a shift, training, a show, agility, picking crops, a walk,
  letting him dig...). Each pays 25 coins; all three put a sticker on the month's calendar (+60),
  and every 7 stickers fill a page (+250 and two hay cookies). Missed days don't cost anything.
- **Seasons:** spring blossom drifts past and he chases the petals; summer brings heatwave days
  when he melts flat on the cool floor; autumn puts a leaf pile on the balcony to dive into;
  winter has snowy days to sniff (and sneeze at). The first time each season he finds something:
  a blossom clip, a straw hat, a knitted scarf, a snowflake clip.
- **The dig box:** digging sometimes turns things up: buttons, marbles, bottle caps, an old coin, a
  tiny ring, and pieces of a treasure map. Eight pieces make the whole map, a sketch of the living
  room with an X: tap that spot on the floor to dig up 1,500 coins (and the first time, a treasure
  chest for the flat). Collection and map: Journal > Bubák.
- **Personality:** what you do together shapes him: Athletic (agility, walks, exercise toys), Lap
  bunny (cuddles), Little star (shows, photos, tricks) and Explorer (walks, the balcony, digging).
  Each has three levels, but only his two strongest traits can go past level 1. Each level helps
  (more hang time, happier cuddles, more likes and show points, better finds), an athletic bunny
  gets restless without exercise, and at level 3 each has its own behaviour: sofa parkour,
  melting in your hands, posing for the camera, sniffing out every corner. Journal > Bubák.
- **Challenge of the week** (Journal > Goals): two to pick from each week, one at a time, for 7
  days: no sweet treats, a budget week (work pays half), a show on 5 of the 7 days, a fit week
  (agility 5 days and a healthy weight), a photo diary. 500-900 coins.
- **Seasonal ladders** (Journal > Goals): ten steps a season, one after another, with coins on
  the way and the season's decoration at the top: a tulip bed, a paddling pool, a hay bale, a
  little snowman.
- **Advent calendar:** 1-24 December, a calendar on the living room wall with a door a day
  (coins, treats, a golden seed...), a Santa hat behind the 24th, and a snow globe for opening
  them all.
- **Bubák's book** (Journal > Memories): a chapter for each big moment, from meeting him to the
  Bunny Games and Inseparable. Write the ones that have happened; with all 13 written, publish it
  (2,000 coins): a book signing (+3,000 followers), a copy for the flat, and the book on sale
  with the merch.
- **Photo album** (Journal > Album): pages of moments (everyday, playtime, outdoors, feelings,
  seasons, personality, friends and every foster bunny). Your best photo of each fills its slot; a
  full page pays 200 coins, the whole album 2,500.
- **The long run:** every day you play counts as a Day together (shown in Journal > Goals with the
  next surprise). Milestones at 3, 7, 14, 30, 60, 100, 150, 200 and 365 days bring coins and things
  you can't buy: a golden bow tie, a royal cushion, a golden crown, a statue of Bubák, plus new
  makeovers.
- **Makeovers** (Shop > Makeover): new wallpaper and floor for the whole flat (mint, lavender, sunny,
  starry night, enchanted forest), each opening after so many days together, from 1,500 to 12,000
  coins. Switch freely between the ones you own.
- **Fame:** followers bring titles (Local cutie at 1,000 up to Superstar at 100,000), each with
  bigger sponsor deals. At Bunnyfluencer your best photo makes a magazine cover.
- **Souvenirs:** walks often bring back a keepsake: three common ones and a rare one per place, 20 in
  all, shown on the walk screen. A full set pays 250 coins; all of them bring a souvenir cabinet.
- **Long goals:** goal ladders that open one after another, up to 365 days played, 1,000 photos and
  treats, 100,000 followers, 365 wishes, a year of vet check-ups, 200 walks, 30 ribbons and all six
  makeovers.
- **Hello again:** after 10 minutes or more away, he hops over to the front, stands up and gives the
  screen a nose boop (and a binky once he's Friendly).
- **A friend for Bubák:** at the end of the game (Best buds and Cozy level 5) the bunny rescue opens.
  Pick a rabbit from the hutch and take it home. The newcomer has their own needs, trust and
  card, and a page of their own in the Journal. Happy rabbits slowly bond, and close friends
  snuggle together.
  The friend can do everything Bubák does: a Bubák / friend switch at the top of the Club and
  the Walk screen picks who trains, grooms, enters shows, runs agility or goes for a walk. Each
  rabbit has their own trick stars, focus, master's certificates, coat, nails, agility skill,
  personality, show waits and daily walk. League points, the Games, duels and ribbons are the
  household's (each ribbon says who won it), and goals count whichever rabbit does better. The
  friend's personality shows at home too (a little star poses for the camera, a lap bunny melts).
- **Settings:** language, sound effects and music on/off, whether time passes while the game is closed, **game pace** (Normal,
  or Fast: the original quick game where Bubák bonds within a session or two), **named saves** (save, load, delete, start a new game) and
  **Test play**, a sandbox with everything unlocked and 10000 coins that leaves your real game
  alone. "Back to my game" returns to it.

Trust is the main progression (Shy → Curious → Friendly → Trusting → Cuddly → Bonded → Best
buds → Inseparable; the hearts next to his name show it, one per level), and it takes many days: the balcony opens at Trusting, selfies and the leash for walks at Cuddly,
and the friend at Best buds; Inseparable is the long final stretch. Each level is slower to fill than the last, and the more he has warmed up
to you today, the less each extra bit counts, so a little every day beats one long session. Each
treat he already had today counts less too. Each level unlocks new behaviours: chinning, begging
and bowl flipping; binkies and zoomies; flops and nose bonks; tooth purring. The pace is set in
`scripts/catalog.gd` (`TRUST_LEVELS`, `TRUST_PACE`, `TRUST_DAILY`, `TREAT_REPEAT`); Settings > Game
pace > Fast uses the `FAST_*` values instead. If he's bored he chews the laptop cable. Time of day follows your
clock: he's most active at dawn and dusk, and naps for a few minutes when his energy (the moon bar) runs low, mostly around midday and at night. Life goes on (gently) while the game is closed, unless Settings is switched to "Time stops".

## Languages

English and Czech, switched with the gear button (Settings). The game starts in Czech;
English is one tap away in Settings. Texts in the code are English and go through `tr()` / `tr_n()`. The
Czech text is in `locale/cs.po` (gettext, with Czech plural forms). After adding or changing
text, run `python3 tools/i18n.py`: it lists anything missing from `cs.po` and refreshes
`locale/messages.pot`, the template for adding another language.

## Running and building

A self-contained Godot 4.5.1 lives in `.tools/` (its settings stay in `.tools/editor_data/`).

```sh
G=.tools/Godot_v4.5.1-stable_linux.x86_64
$G --path .                       # play
$G --path . --editor              # open in the Godot editor
$G --path . -- --autotest         # scripted playtest in its own save (adds =<dir> to save screenshots)
$G --path . -- --hour=21          # pretend it's 21:00
$G --path . -- --demo --view=balcony   # furnished flat in its own save, start on the balcony (also: --fps)
$G --path . -- --safe=80,0,80,34   # simulate a phone notch / home bar (left,top,right,bottom insets)
$G --path . -- --testplay          # start in Test play (everything unlocked, 10000 coins)

$G --headless --path . --export-release "Linux"   build/linux/bubak.x86_64
$G --headless --path . --export-debug   "Android" build/android/bubak.apk
$G --headless --path . --export-release "Windows Desktop" build/windows/bubak.exe
adb install -r build/android/bubak.apk            # phone with USB debugging on
```

The Android build is signed with `~/.android/debug.keystore`. Publishing to a store needs a
release keystore set in the Android export preset.

Saves are kept in `~/.local/share/godot/app_userdata/Bubák/` (`%APPDATA%\Godot\app_userdata\Bubák\`
on Windows, and the app's private storage on Android).

Only the Linux, Android and Windows export templates are installed in `.tools/editor_data/`
(the Windows ones were pulled out of the official template archive on their own, to save disk space).

## Project layout

```
scripts/game_state.gd   money, inventory, progression, club, saves, offline catch-up
scripts/pet.gd          one rabbit's needs and trust (Bubák, and his friend)
scripts/catalog.gd      shop items, behaviours, trust levels (tweak balance here)
scripts/bunny.gd        a bunny's AI, animations and reactions
scripts/stage_bunny.gd  big Bubák for training, grooming and shows
scripts/training.gd     show club: tricks
scripts/grooming.gd     show club: brushing and nails
scripts/show_ring.gd    a show: performance, judging, rivals
scripts/main.gd         room, input, day/night, photos
scripts/hud.gd          HUD, shop, journal, club, rescue hutch, settings, pop-ups
scripts/work_game.gd    remote-work mini-game
scripts/walk_scene.gd   the walk cutscene
scripts/sfx.gd          sound effects and music
tools/gen_art.py        generates all placeholder art in assets/art/ (SVG)
tools/gen_sounds.py     generates all sounds and music in assets/sounds/ (Ogg)
tools/autotest.gd       scripted playtest
```

Sounds and the music loop (a music-box lullaby, softer at night) are synthesized by
`tools/gen_sounds.py` (numpy + scipy, encoded to Ogg with ffmpeg) into `assets/sounds/`, and played
through the `Sfx` autoload (`scripts/sfx.gd`, where each sound's loudness is set). Replace any .ogg
with a recording of the same name to use real sounds. Playtests and screenshot runs are silent.

All art is generated by `tools/gen_art.py` (outlined shapes get soft shading automatically). It is
imported at 2x (backgrounds 1.5x) with mipmaps and shown at design size, so it stays sharp on big
screens. Bubák's perky ear and nose are separate sprites so they can twitch. To use hand-drawn art, replace any SVG/PNG in
`assets/art/`, keeping the same size and with the feet or base at the bottom centre.
Font: Fredoka (SIL Open Font License, `assets/fonts/OFL.txt`).
