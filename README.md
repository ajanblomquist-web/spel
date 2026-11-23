# Fling for Fossils

A Roblox game: train your Strength, fling your shovel across a giant dig site, dig up a fossil egg where it lands, carry it home before someone steals it, and hatch a dinosaur that earns coins (even while you're offline).

This repo has **milestone 1 (the greybox core loop)** and **milestone 2 (the first 5 and 30 minutes: tutorial, quests, celebrations and the progression curve)**. Everything is plain blocks so we can test the fun before buying art. The whole world is built by code, so you don't need a place file.

Design doc: https://claude.ai/artifact/YDRaLZfJ13HRfQKPsLRWJC

---

## Setup (one time, about 10 minutes)

You need: **Roblox Studio**, **VS Code**, and **Rojo** (it copies the code from this folder into Studio while you work).

1. **Get the code.** Clone this repo, or on GitHub press *Code > Download ZIP* and unzip it.
2. **Install Rojo.** Pick one way:

   **Easiest: the VS Code extension (no terminal needed).** In VS Code, open the Extensions tab, install **Rojo** (by evaera), open this folder with *File > Open Folder*, then press `Cmd+Shift+P` (Mac) or `Ctrl+Shift+P` (Windows), type `Rojo: Open menu` and pick **Start server**. It installs Rojo by itself, and its menu can install the Studio plugin too. Then skip to step 4.

   **Or with the terminal (Rokit).** On a Mac, open Terminal and paste:
   ```
   curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
   ```
   **Then quit Terminal completely (Cmd+Q) and open it again.** Rokit adds itself to your PATH, but only new Terminal windows see it. That's the usual cause of `command not found`. Check it worked with `rokit --version`. Now go to this folder and install the tools listed in `rokit.toml`:
   ```
   cd path/to/spel
   rokit install
   ```
   Answer **yes** if it asks whether to trust the tools. Check with `rojo --version` (it should say 7.4.4). On Windows, download the installer from https://github.com/rojo-rbx/rokit/releases instead, and restart the terminal after it finishes.

   `rojo` only works inside this folder (where `rokit.toml` is). If you see `command not found: rojo`, run `pwd` to check you're in the spel folder.
3. **Install the Rojo plugin in Studio.** Run `rojo plugin install` in the terminal, or get "Rojo" from the Creator Store plugins. Restart Studio.
4. **Make a place.** In Studio: *New > Baseplate*. Delete the `Baseplate` part and the default `SpawnLocation` from Workspace (the game builds its own).
5. **Start syncing.** With the VS Code extension, *Start server* already did this. With the terminal, run this in the spel folder:
   ```
   rojo serve
   ```
   In Studio open the **Rojo** plugin (Plugins tab) and press **Connect**. The scripts appear under ServerScriptService > Server, StarterPlayerScripts > Client and ReplicatedStorage > Shared.
6. **Turn on saving in Studio:** *File > Game Settings* (older Studio: *Home > Game Settings*) *> Security > Enable Studio Access to API Services*. (You must publish the place first: *File > Publish to Roblox*.) Without it the game still runs, it just won't save, and shows a red message saying so.
7. **Set Max Players to 8** in Creator Hub (your experience > Places > the place > Configure > Server Size) (there are 8 base plots).
8. **Save the place** (`.rbxl`) anywhere outside this folder. Next time, just open it, run `rojo serve` and press Connect.

Now press **Play**.

> Always edit the `.luau` files in VS Code, not in Studio. Rojo overwrites Studio's copy with the files from this folder.

---

## How to play-test

| Step | What to do |
|---|---|
| Train | Walk to the grey **TRAIN** rock and tap the big **TRAIN** button. Each tap adds Strength. |
| Fling | Stand on the orange **FLING** pad, tap **FLING**, then tap **STOP!** when the white needle is on the thin green line (Perfect, and Perfects in a row stack a bonus). Yellow is Great, red is a weak throw. |
| Dig | Follow the yellow line to your dig spot and hold **Dig** (E on PC). |
| Carry | Your egg sits on your head. You're slower now. Follow the green line home. |
| Hatch | Walk into your plot: the egg drops into an incubator and counts down. |
| Earn | The dino stands on a pedestal and earns coins every second. Hold **Sell** on it to sell it. |
| Upgrade | **Shop** (right side) sells better training rocks and shovels. |

**Testing with two players:** *Test tab > Clients and Servers > 2 Players > Start*. One player carries an egg, the other walks up and holds **Steal egg**. You can also hold **Steal egg** on an egg in someone else's incubator. Defend with **LOCK NEST** (shows when you stand in your plot).

**Testing game passes in Studio:** open **Passes** and press **Test it** on any pass to switch it on or off. This only works in Studio.

**Faster testing:** in `src/shared/Config/Balance.luau`, the `Balance.Studio` section can make eggs hatch faster (`IncubationScale`) and playtime gifts unlock sooner (`GiftTimeScale`) in Studio (both use real timing by default), and can give you starting coins.

**Testing the new-player experience:** a fresh account plays the tutorial. Your own save has already played, so to see it again either test with a second account, or change `Balance.DataStoreName` (for example to `PlayerData_test1`) to start from an empty save. Change it back afterwards.

**Testing the Starter Pack:** it pops up once after your first hatch. In Studio its button says "Get it (test)" and grants it without Robux. Later it's in the **Shop** under ROBUX DEALS.

---

## What's in milestone 1

- Strength training (6 rock tiers in the shop)
- Fling with timing meter: thin Perfect zone with a Perfect-streak bonus, Great zone, harsh misses; 3 zones (Sandy Pit, Fern Valley, Tar Pits); farther zones have more luck
- Egg rolls on the server: 7 rarities, 5 sizes, 6 mutations; luck pushes toward rarer eggs
- Carry eggs home, slower while carrying
- **PvP stealing**
  - Steal an egg from a player who's carrying one (they get it back by stealing it back; a fresh steal is protected for 5 s)
  - Steal eggs out of other players' incubators (the owner gets a warning while it's happening)
  - Free **nest lock** for 60 s, then a 60 s cooldown (Fortress Gate pass makes it 3 min)
  - **Steals** column on the leaderboard, next to Coins and Strength
  - Hatched dinos can never be stolen, only eggs
- 3 incubators, 6 pedestals (+6 with a pass), selling dinos
- Coins per second, offline income (50%, up to 8 hours) with a welcome-back popup
- Server-wide shout when someone hatches a Legendary or better
- All 10 game passes wired up (see below)
- Saving with DataStores (autosave every 60 s and on leave)
- Mobile-first UI: one big context button (TRAIN / FLING / STOP! / LOCK NEST), large side buttons, scales to any screen

## What's in milestone 2 (first 5 and 30 minutes)

**First 5 minutes: understand the game, feel something big**
- Guided tutorial as the first 5 quests (Train, Fling, Dig, Carry home, Hatch), with a glowing blue line showing where to go
- Your **first egg is always a Rare**, can't be stolen on the way home, and hatches in 8 seconds
- **Full-screen hatch reveal** for every egg: the egg shakes (longer for rarer eggs), then a flash, spinning light rays and a dino card with rarity, size, mutation and coins/s
- Fling feel: a distance counter that races up while the shovel flies, a green flash on Perfect, and a **NEW ZONE** banner the first time you reach a zone
- **Starter Pack** offer shown once, right after the first hatch (a developer product: 2x Coins for 30 min, a Rare egg, 1,000 coins; nothing random)

**First 30 minutes: burst, slow climb, breakthrough**
- **Quest chain** of 24 quests, always one on screen with a progress bar and its reward (coins or a timed 2x boost)
- **Egg Thief** NPC walking around the hub with an egg anyone can steal: teaches stealing and works in solo servers (counts for quests, not the Steals leaderboard)
- **Field speed**: you walk faster the further out into the fling field you are (up to 2.25x at 600 studs), so fetching far eggs stays quick
- **Playtime gifts** at 3, 8, 15, 25, 40 and 60 minutes (coins, 2x boosts, a Rare and an Epic egg)
- The **Shop button bounces with a "!"** when you can afford your next upgrade
- **Timed boosts** (2x Luck, Coins, Strength) with timers on the left
- **Progression curve** retuned (checked with `tools/curve_sim.py`): Fern Valley ~3 min, Tar Pits ~10-15 min, then a slower climb to the **Gold Rock breakthrough** around minute 25-30 (6x Strength per rep, full-screen BREAKTHROUGH celebration) that sends you to the new zone:
- **Amber Cliffs** (zone 4, 550-850m, x4 luck) with 4 dinos you can only get there

## What's in milestone 3 so far (first 7 days: collection)

- **Dino Index** (left button, after the tutorial): a tab per rarity (opens on the first page you haven't finished); each page lists dinos found everywhere, then one section per zone with its own dinos. One row per dino, 4 boxes per row: Dino, Gold, Rainbow and Baby. 27 dinos x 4 = 108 boxes. The Secret page stays hidden until you hatch a Secret dino. Mutations are just Gold (2x) and Rainbow (10x, rare); size changes income but has no box. Old saves: Lava/Ice/Crystal dinos became Gold. One hatch can tick several boxes. New boxes get a toast and a "NEW" badge on the button.
- **Page rewards**: finding every dino of a rarity pays one-time coins (500 for Common up to 20M for Secret) and gives +10% Baby odds for good.
- **Baby dinos**: every hatch has a 1 in 500 chance to be a Baby: 3x income, small body with a big head and a pink outline, its own reveal ("IT'S A BABY!") and a server-wide shout. Never sold for Robux.
- **Index quests**: fill 6 boxes, complete the Uncommon page, fill 25 boxes.
- Dinos you already own are added to your Index when you join. The "Tiny" size is now called "Small" (old saves are converted).
- To test Babies in Studio, set `Balance.Studio.BabyChance` to e.g. 0.25.
- **Bonk weapons**: your weapon is a tool in the Roblox hotbar (press 1 or tap it). While you hold it and an egg carrier is in reach, a red **BONK!** button shows (clicking/tapping with the tool works too). A bonk knocks them over and they drop the egg; anyone can grab it (counts as a steal). Fresh steals and your first egg are protected, and you're safe at home. If nobody grabs a dropped egg in 25 s it goes back to its carrier.
- **Weapon shop** (bottom of the Shop): Stick (free), Bone Club (5K), Tail Mace (60K), Raptor Claw (600K) for coins; Amber Hammer and Meteor Bat for Robux (only as strong as the Raptor Claw); skins for Robux that work on every weapon and change only the look. Better weapons reach further and bonk more often.
- **Free AFK training**: standing at the training rock without tapping trains you by itself with half-strength reps (1 Strength per tick on the Pebble rock; "AUTO TRAINING, tap for 2x!"). Auto Train makes it full speed from anywhere.
- **Auto Fling drone**: with Auto Fling, a dino drone flies each egg straight into a free incubator, so you can AFK at the pad.
- **Pass hints**: a small card (bottom right) suggests a pass right when it would help: pedestals full, incubators busy, just got robbed, lots of training or flinging, many Common eggs. Never during the tutorial, at most one every 5 minutes, each once per session, never for passes you own. Texts and limits are in `Config/Social.luau`.
- **Group reward**: create a Roblox group and put its ID in `Social.GroupId`. Players who join get a one-time 15 min 2x Strength boost; a "Join our group" row sits at the top of the Passes menu until claimed, and one hint suggests it after the tutorial. With `GroupId = 0` this is all hidden.
- **6 pedestals** for everyone (12 with Extra Pedestals).
- **Rebirth** (top row of the Shop, after reaching Amber Cliffs): pay coins (1M, then 3x more each time) to reset coins, Strength, rock and shovel. You keep dinos, Index, eggs, passes and weapons, and get +50% Strength, +25% coins and +10% luck forever per rebirth, a "Rebirth N" tag above your head and a Rebirths column on the player list. Numbers in `Config/Rebirth.luau`.
- **Daily streak**: a 7-day reward track (coins, boosts, Rare egg, Epic egg on day 7) that pops up once a day after the tutorial. Missing a day starts it over. Rewards in `Config/Daily.luau`.
- **Server events**: a 10-minute event at the start of every hour, the same on every server: Double Luck, Double Coins, Golden Hour (3x mutations), Baby Boom (5x Baby odds), Strength Surge. A banner announces it and a timer pill shows under the top bar. As the game owner (or anyone in Studio) type `/event DoubleLuck` (optionally `/event BabyBoom 30` for 30 minutes) or `/event stop` in chat; it reaches every server. Events in `Config/WorldEvents.luau`.
- **Amber Cliffs is tough**: zones have a Toughness (Amber Cliffs 6.5), so each stud there takes 6.5x the fling power. Reaching it still takes ~25 min, but its far edge takes ~80 min, about as long as a first rebirth. Luck also rises the deeper you land in a zone (Amber Cliffs x4 at the start up to x6 at the edge), so longer flings always pay. Tuned in `Config/Zones.luau`.
- **Two new zones past Amber Cliffs**, each with 4 dinos you can only get there:
  - **Frozen Tundra** (850-1150m, x6 luck, Toughness 10): Snow Compy, Frost Raptor, Glacier Ankylo, Blizzard Spino. Reached around the first rebirth (~80 min in the simulator).
  - **Volcano Rim** (1150-1450m, x9 luck, Toughness 40): Ember Raptor, Magma Stego, Inferno Spino, Volcano Titan (Mythic). Reached after about 2 rebirths (~4 h); its far edge takes ~9 h.
  - Field speed: you run 3.5x speed from 150m out, so fetching eggs is quick and the hub (where thieves and bonkers wait) is the slow, risky part.
- **Shop sections**: Codes, Rebirth, Training Rocks, Shovels, Weapons, Weapon Skins, Robux Deals (Starter Pack, Rare Egg) and Coin Packs.
- **Codes**: type a code in the box at the top of the Shop. Each works once per player. Starting codes: `FOSSIL` (2x Luck 15 min), `RELEASE` (10 min of income, at least 1,000 coins), `DINOPOWER` (2x Strength 15 min). Add codes in `Config/Codes.luau` (rewards use the gift format; optional expiry date).
- **Global leaderboards**: four boards next to the launch pad, shared by all servers: Top Thieves and Top Diggers (this week, reset Monday 00:00 UTC), Top Collectors (Index boxes) and Richest Nests (coins per second). In Studio without API access they show the players in your server.

## Game passes

All passes speed up the loop; none sell random rolls (so no odds-disclosure rules apply). To make them real:

1. Publish the game, then in **Creator Hub > your experience > Monetization > Passes** create each pass and set its price.
2. Copy each pass ID into `GamePassId` in `src/shared/Config/Passes.luau`.

| Pass | Effect | Suggested R$ |
|---|---|---|
| 2x Coins | Doubles dino income | 399 |
| 2x Strength | Doubles Strength per rep | 199 |
| Auto Train | Trains at full speed by itself, anywhere (the rock alone trains free at half speed) | 249 |
| Auto Fling | Flings for you at the pad and a dino drone brings each egg straight to your nest (while an incubator is free) | 349 |
| Lucky Shovel | +50% luck | 299 |
| Fast Incubator | Eggs hatch 2x faster | 249 |
| Extra Pedestals | +6 pedestals | 199 |
| Speedy Boots | +25% walk speed | 149 |
| Fortress Gate | Nest lock lasts 3 min | 149 |
| VIP | +10% coins | 449 |
| Amber Hammer (Shop) | Bonk weapon, same as the Raptor Claw | 149 |
| Meteor Bat (Shop) | Bonk weapon, same as the Raptor Claw | 249 |
| Golden / Lava / Crystal skin (Shop) | Weapon look only | 99 |
| Rainbow skin (Shop) | Weapon look only | 149 |

## Developer products

Create these in **Creator Hub > Monetization > Developer Products** and paste the IDs into `src/shared/Config/Products.luau`. Purchases are handled in `MonetizationService` (ProcessReceipt), and each purchase ID is saved so it's never granted twice.

| Product | What you get | Suggested R$ |
|---|---|---|
| Starter Pack (one time) | 2x Coins for 30 min, a Rare egg, 1,000 coins | 99 |
| Rare Egg (Shop) | One Rare egg (dinos and odds shown on the row). Waits for a free incubator if yours are full | 49 |
| 5 / 10 / 24 hours of coins (Shop) | That many hours of your current income (at least 2,500 per hour) | 99 / 179 / 349 |


---

## Where things are

```
src/
  shared/                 ReplicatedStorage.Shared (both sides can read)
    Config/
      Balance.luau        every tuning number (speeds, timers, distances, offline income)
      Zones.luau          dig zones, distances and luck (the map is built from this)
      Eggs.luau           rarity / size / mutation odds and incubation times
      Dinos.luau          which dinos hatch from each rarity and their coins/s
      Shop.luau           rocks and shovels
      Passes.luau         game pass IDs, prices and effects
      Products.luau       developer products (Starter Pack, Rare Egg, coin packs)
      Codes.luau          redeemable codes (add new ones here)
      Quests.luau         the quest chain (the first 5 are the tutorial)
      Gifts.luau          playtime gift times and rewards
      Index.luau          Dino Index variants, page rewards, Baby odds
      Weapons.luau        bonk weapons and skins
      Social.luau         group ID and reward, pass hint texts
      Rebirth.luau        rebirth price and bonuses
      Daily.luau          daily streak rewards
      WorldEvents.luau    server events
    Util/                 WeightedRandom, FormatNumber
    Meter.luau            the timing meter maths (same on client and server)
    Remotes.luau          list of every RemoteEvent
  server/                 ServerScriptService.Server
    init.server.luau      starts the services in order
    Services/
      DataService         load / save / leaderboard
      MonetizationService game pass ownership
      MapService          builds the greybox world and the 8 plots
      MovementService     walk speed (carrying, Speedy Boots, field speed)
      NestService         incubators, hatching, pedestals, selling, nest stealing, nest lock
      IncomeService       coins per second and offline income
      TrainingService     Strength reps
      CarryService        dig spots, carrying eggs, stealing from carriers, delivery
      FlingService        meter check, distance, zone, luck
      ShopService         buying upgrades, breakthrough celebration
      QuestService        tutorial and quest chain
      IndexService        Dino Index, page rewards, Baby roll
      LeaderboardService  global and weekly leaderboard boards
      WeaponService       bonk weapons, skins, buying, the bonk
      HintService         pass hints and the group reward
      RebirthService      rebirth, permanent bonuses, rebirth tag
      DailyService        daily login streak
      EventService        hourly server events and /event commands
      BoostService        timed 2x Luck / Coins / Strength
      GiftService         playtime gifts
      StarterPackService  Starter Pack offer and reward
      ProductService      Rare Egg and coin packs
      CodeService         redeemable codes
      NpcService          the Egg Thief
    Events.luau           tiny event bus (Fling, Dig, Hatch...) that quests listen to
    EggRoll.luau          the egg and dino rolls
    Visuals.luau          greybox eggs, dinos and labels
  client/                 StarterPlayerScripts.Client
    Controllers/
      UIController        all screen UI
      WorldController     guide line, timers, prompt filtering, LOCK NEST
      TrainingController  TRAIN button, Auto Train
      FlingController     FLING button, meter, flying shovel, distance counter, Auto Fling
      RevealController    hatch reveal, BREAKTHROUGH, banners, Starter Pack offer
      QuestController     quest card, gift button, boost timers
      IndexController     Dino Index button and panel
      WeaponController    BONK! button, hit effects, weapon rows in the Shop
      HintController      hint card, "Join our group" row
      RebirthController   Rebirth row in the Shop
      DailyController     daily streak popup
      EventController     event timer pill
      ProductController   Codes box, Robux deals and coin packs in the Shop
tools/
  curve_sim.py            rough progression simulator (python3 tools/curve_sim.py)
```

**Cheating:** every roll, reward and purchase happens on the server. The client only says "I tapped the meter at X", and the server checks that against its own clock.

## Swapping in real art

- **Dinos:** put a Model named after the dino's Id (for example `TRex`, `Velociraptor`, see `Dinos.luau`) with a PrimaryPart in **ReplicatedStorage > DinoModels**. It's used instead of the block dino automatically.
- **Eggs:** put a part named `EggModel` in ReplicatedStorage.
- **World:** the map is built in `MapService.luau`. Keep the `TrainingRock` and `LaunchPad` parts (the code looks for them) and decorate around them.

## Before a public launch

- Swap DataService's saving for **ProfileStore** (adds session locking so items can't be duplicated by fast server hopping).
- Fill out the **Experience Questionnaire** in Creator Hub.
- Nothing to switch off for testing: the `Balance.Studio` values only apply in Studio.

## Tools

- `stylua src` formats the code (config in `stylua.toml`).
- `selene src` lints it (run `selene generate-roblox-std` once first).
- `python3 tools/curve_sim.py` prints when a typical player reaches each upgrade and zone. Change prices in `Config/Shop.luau`, mirror them at the top of the script, and re-run to see how the curve moves.
