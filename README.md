# Fling for Fossils

A Roblox game: train your Strength, fling your shovel across a giant dig site, dig up a fossil egg where it lands, carry it home before someone steals it, and hatch a dinosaur that earns coins (even while you're offline).

This repo is **milestone 1: the greybox core loop**. Everything is plain blocks so we can test the fun before buying art. The whole world is built by code, so you don't need a place file.

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
6. **Turn on saving in Studio:** *Home > Game Settings > Security > Enable Studio Access to API Services*. (You must publish the place first: *File > Publish to Roblox*.) Without it the game still runs, it just won't save, and shows a red message saying so.
7. **Set Max Players to 8** in *Game Settings > Places* (there are 8 base plots).
8. **Save the place** (`.rbxl`) anywhere outside this folder. Next time, just open it, run `rojo serve` and press Connect.

Now press **Play**.

> Always edit the `.luau` files in VS Code, not in Studio. Rojo overwrites Studio's copy with the files from this folder.

---

## How to play-test

| Step | What to do |
|---|---|
| Train | Walk to the grey **TRAIN** rock and tap the big **TRAIN** button. Each tap adds Strength. |
| Fling | Stand on the orange **FLING** pad, tap **FLING**, then tap **STOP!** when the white needle is in the green. |
| Dig | Follow the yellow line to your dig spot and hold **Dig** (E on PC). |
| Carry | Your egg sits on your head. You're slower now. Follow the green line home. |
| Hatch | Walk into your plot: the egg drops into an incubator and counts down. |
| Earn | The dino stands on a pedestal and earns coins every second. Hold **Sell** on it to sell it. |
| Upgrade | **Shop** (right side) sells better training rocks and shovels. |

**Testing with two players:** *Test tab > Clients and Servers > 2 Players > Start*. One player carries an egg, the other walks up and holds **Steal egg**. You can also hold **Steal egg** on an egg in someone else's incubator. Defend with **LOCK NEST** (shows when you stand in your plot).

**Testing game passes in Studio:** open **Passes** and press **Test it** on any pass to switch it on or off. This only works in Studio.

**Faster testing:** in `src/shared/Config/Balance.luau`, the `Balance.Studio` section makes eggs hatch 10x faster in Studio and can give you starting coins.

---

## What's in milestone 1

- Strength training (6 rock tiers in the shop)
- Fling with timing meter, Perfect hits, 3 zones (Sandy Pit, Fern Valley, Tar Pits); farther zones have more luck
- Egg rolls on the server: 7 rarities, 5 sizes, 6 mutations; luck pushes toward rarer eggs
- Carry eggs home, slower while carrying
- **PvP stealing**
  - Steal an egg from a player who's carrying one (they get it back by stealing it back; a fresh steal is protected for 5 s)
  - Steal eggs out of other players' incubators (the owner gets a warning while it's happening)
  - Free **nest lock** for 60 s, then a 60 s cooldown (Fortress Gate pass makes it 3 min)
  - **Steals** column on the leaderboard, next to Coins and Strength
  - Hatched dinos can never be stolen, only eggs
- 3 incubators, 4 pedestals (+6 with a pass), selling dinos
- Coins per second, offline income (50%, up to 8 hours) with a welcome-back popup
- Server-wide shout when someone hatches a Legendary or better
- All 10 game passes wired up (see below)
- Saving with DataStores (autosave every 60 s and on leave)
- Mobile-first UI: one big context button (TRAIN / FLING / STOP! / LOCK NEST), large side buttons, scales to any screen

## Game passes

All passes speed up the loop; none sell random rolls (so no odds-disclosure rules apply). To make them real:

1. Publish the game, then in **Creator Hub > your experience > Monetization > Passes** create each pass and set its price.
2. Copy each pass ID into `GamePassId` in `src/shared/Config/Passes.luau`.

| Pass | Effect | Suggested R$ |
|---|---|---|
| 2x Coins | Doubles dino income | 399 |
| 2x Strength | Doubles Strength per rep | 199 |
| Auto Train | Trains by itself at the rock | 249 |
| Auto Fling | Flings by itself with a good hit at the pad | 349 |
| Lucky Shovel | +50% luck | 299 |
| Fast Incubator | Eggs hatch 2x faster | 249 |
| Extra Pedestals | +6 pedestals | 199 |
| Speedy Boots | +25% walk speed | 149 |
| Fortress Gate | Nest lock lasts 3 min | 149 |
| VIP | +10% coins | 449 |

Boost potions, Server Luck and Instant Hatch (developer products) come in milestone 3.

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
    Util/                 WeightedRandom, FormatNumber
    Meter.luau            the timing meter maths (same on client and server)
    Remotes.luau          list of every RemoteEvent
  server/                 ServerScriptService.Server
    init.server.luau      starts the services in order
    Services/
      DataService         load / save / leaderboard
      MonetizationService game pass ownership
      MapService          builds the greybox world and the 8 plots
      MovementService     walk speed (carrying, Speedy Boots)
      NestService         incubators, hatching, pedestals, selling, nest stealing, nest lock
      IncomeService       coins per second and offline income
      TrainingService     Strength reps
      CarryService        dig spots, carrying eggs, stealing from carriers, delivery
      FlingService        meter check, distance, zone, luck
      ShopService         buying upgrades
    EggRoll.luau          the egg and dino rolls
    Visuals.luau          greybox eggs, dinos and labels
  client/                 StarterPlayerScripts.Client
    Controllers/
      UIController        all screen UI
      WorldController     guide line, timers, prompt filtering, LOCK NEST
      TrainingController  TRAIN button, Auto Train
      FlingController     FLING button, meter, flying shovel, Auto Fling
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
