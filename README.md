# Bubák

A cozy caretaker game for Linux and Android. You look after Bubák, a cheeky lilac-grey bunny
with one perky ear and one floppy ear, who lives in your apartment. (`bubak_photos/` holds photos
of the real Bubák; a `.gdignore` keeps them out of the build.)

## How to play

- **Bowls, hay rack, litter box:** tap them to refill or clean them.
- **Pet Bubák:** hold your finger on him. Poking him quickly scares him. He's shy at first.
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
  wardrobe, and they go straight on. Every accessory adds photo likes and show style.
- **Work** is ready when the laptop jiggles.
- **Goals** (Journal) give coin rewards. Once Bubák has 25 followers, a **sponsor** pays every
  day, with a bonus for consecutive days.
- **Shop:** food, leafy branches he eats, toys (ball, box, tunnel) and home items (bed, rug, plant,
  lamp, cable cover).
- **Move:** drag furniture around.
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
     when he gets distracted. Each try uses focus, which comes back over time. Tricks earn up
     to 3 stars. The clicker, treat pouch and hoop are on the shop's Club tab.
  2. **Grooming**, after his first trick star. Swipe the loose fur off his coat before his
     patience runs out, and trim his nails (needs trust). Every couple of weeks he molts for a
     few days: his coat dulls faster and he leaves tufts of fur around the flat.
  3. **Shows**, after 3 trick stars and a first grooming. The categories are Best in Show
     (coat, nails, outfit, calmness), Tricks (a live routine) and Photogenic (your best photo).
     Bubák competes against rival bunnies. There are Neighbourhood, Regional and National
     shows; two wins open the next level. Ribbons and the championship cup go on a shelf on
     the wall.
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
- **Walks:** once Bubák is Bonded and has 6 trick stars, the Shop's Club tab sells a harness and
  leash. Then the Walk button takes him out once a day: the park first, then the meadow (after 2
  walks), the beach (4), the city (7) and the cinema (10). Each walk is a half-minute cutscene (no
  buttons) with a string of little adventures: a butterfly on his nose in the park, binkies,
  zoomies and a dandelion in the meadow, a wave, a crab, a seagull and a sunset at the beach, a
  pigeon, a café carrot and a crowd of fans in town, and popcorn, a scary bit and a nap in the
  cinema; it brings trust past the daily limit and lots of
  fun, and the city brings new followers. Goals: a first walk, and all 5 places.
- **A friend for Bubák:** late in the game (Best buds and Cozy level 5) the bunny rescue opens.
  Pick a rabbit from the hutch and take it home. The newcomer has their own needs, trust and
  card. Happy rabbits slowly bond, and close friends snuggle together.
- **Settings:** language, sound effects and music on/off, whether time passes while the game is closed, **game pace** (Normal,
  or Fast: the original quick game where Bubák bonds within a session or two), **named saves** (save, load, delete, start a new game) and
  **Test play**, a sandbox with everything unlocked and 10000 coins that leaves your real game
  alone. "Back to my game" returns to it.

Trust is the main progression (Shy → Curious → Friendly → Trusting → Cuddly → Bonded → Best
buds; the hearts next to his name show it, one per level), and it takes many days: the balcony opens at Trusting, selfies at Cuddly, and the friend
only after a long game. Each level is slower to fill than the last, and the more he has warmed up
to you today, the less each extra bit counts, so a little every day beats one long session. Each
treat he already had today counts less too. Each level unlocks new behaviours: chinning, begging
and bowl flipping; binkies and zoomies; flops and nose bonks; tooth purring. The pace is set in
`scripts/catalog.gd` (`TRUST_LEVELS`, `TRUST_PACE`, `TRUST_DAILY`, `TREAT_REPEAT`); Settings > Game
pace > Fast uses the `FAST_*` values instead. If he's bored he chews the laptop cable. Time of day follows your
clock: he's most active at dawn and dusk, and naps for a few minutes when his energy (the moon bar) runs low, mostly around midday and at night. Life goes on (gently) while the game is closed, unless Settings is switched to "Time stops".

## Languages

English and Czech, switched with the gear button (Settings). On first launch the game follows
the phone or OS language. Texts in the code are English and go through `tr()` / `tr_n()`. The
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
