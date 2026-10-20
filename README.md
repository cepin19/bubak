# Bubák

A cozy caretaker game for Linux and Android. You look after Bubák, a cheeky lilac-grey bunny
with one perky ear and one floppy ear, who lives in your apartment.

## How to play

- **Bowls, hay rack, litter box:** tap them to refill or clean them.
- **Pet Bubák:** hold your finger on him. Poking him quickly scares him. He's shy at first.
- **Treats:** pick one, then tap the floor. He comes over and eats from your hand. Too much
  apple (his favourite) gives him a tummy ache.
- **Pick him up:** drag him upwards (or tap Selfie in Photo mode) to cuddle him and snap a selfie
  together. This only works once he trusts you (Bonded). Try earlier and he bolts, and trust drops.
- **Photo:** catch him doing cute things. Rare moments sparkle and pay the most coins.
  New behaviours pay double; repeating the same shot pays less.
- **Desk / laptop:** remote work. Shifts earn coins and career XP, and promotions (Intern →
  Director of Carrots) raise pay, pay a bonus and unlock new jobs: Inbox zero, Bug hunt, Pair
  programming (memory), Video call and Crate stacking. Streaks raise a points multiplier (up to x4),
  the last 5 seconds count double, and each shift is rated 1–3 stars (more stars, more pay; best
  scores are kept). One job a day is the boss's pick, with double XP. There's a coffee break between shifts.
- **Upgrades:** each care item has 3 tiers (bigger bowl, fountain, hay house, luxury litter box), and
  desk gear makes work pay better.
- **Coziness:** furniture, toys and upgrades raise the Cozy level (shown under the trust bar). It
  makes Bubák happier, brings more followers and unlocks fancier items.
- **Style:** accessories Bubák wears (bow, glasses, flower crown, top hat). Photos get more likes.
- **Goals** (Journal) give coin rewards. Once Bubák has 25 followers, a **sponsor** pays every
  day, with a bonus for consecutive days.
- **Shop:** food, leafy branches he eats, toys (ball, box, tunnel) and home items (bed, rug, plant,
  lamp, cable cover).
- **Move:** drag furniture around.
- **Balcony:** the door on the left is locked at first. Once Bubák trusts you (Bonded) and he has
  300 followers, buy Balcony netting in the shop to open it. He then goes out on his own to
  sunbathe, watch birds and raid the herb planter, and comes back in for food, water and the
  litter box. Tap the door to follow him. The milestone is set in `scripts/catalog.gd`.
- **Journal:** the behaviours you've discovered, your photo album, and stats.
- **Show club** (Club button). It opens in stages, so new players aren't swamped:
  1. **Training**, once Bubák is Curious and the flat reaches Cozy level 2. Pick a trick
     (Come, Stand up, Spin, Hoop jump), then tap Reward the moment he does it. Don't reward him
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
- **A friend for Bubák:** late in the game (Bonded and Cozy level 4) the bunny rescue opens.
  Pick a rabbit from the hutch and take it home. The newcomer has their own needs, trust and
  card. Happy rabbits slowly bond, and close friends snuggle together.
- **Settings:** language, whether time passes while the game is closed, **named saves** (save, load, delete, start a new game) and
  **Test play**, a sandbox with everything unlocked and 10000 coins that leaves your real game
  alone. "Back to my game" returns to it.

Trust is the main progression (Shy → Curious → Friendly → Bonded → Best buds). Each level
unlocks new behaviours: chinning, begging and bowl flipping; binkies and zoomies; flops and
nose bonks; tooth purring. If he's bored he chews the laptop cable. Time of day follows your
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
adb install -r build/android/bubak.apk            # phone with USB debugging on
```

The Android build is signed with `~/.android/debug.keystore`. Publishing to a store needs a
release keystore set in the Android export preset.

Saves are kept in `~/.local/share/godot/app_userdata/Bubák/` (and in the app's private storage on
Android).

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
tools/gen_art.py        generates all placeholder art in assets/art/ (SVG)
tools/autotest.gd       scripted playtest
```

All art is generated by `tools/gen_art.py` (outlined shapes get soft shading automatically). It is
imported at 2x (backgrounds 1.5x) with mipmaps and shown at design size, so it stays sharp on big
screens. Bubák's perky ear and nose are separate sprites so they can twitch. To use hand-drawn art, replace any SVG/PNG in
`assets/art/`, keeping the same size and with the feet or base at the bottom centre.
Font: Fredoka (SIL Open Font License, `assets/fonts/OFL.txt`).
