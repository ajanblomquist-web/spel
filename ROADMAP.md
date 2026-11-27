# Roadmap to launch

Where Fling for Fossils stands against the design doc, and what's left to finish it. Milestones 1 to 3 (core loop, first 30 minutes, first-week collection) are built; see README.md.

## M4: The rest of the world (content)
- Done: all 9 zones from the design doc: Frozen Tundra, Volcano Rim, Crystal Caves, Meteor Crater and the secret **Sky Island** (name hidden on signs), each with 4 zone-only dinos and its own world dressing.
- Optional, a design call: **Speed training** (treadmill tiers) as a free counter to stealing. Field speed already keeps carrying quick.

## M5: Shop and social (monetization finish)
- Done: **coin packs** (5 / 10 / 24 hours of income), **Rare Egg**, **Codes** box.
- Done: boost potions, **Server Luck**, **Instant Hatch** (3 sizes), PolicyService check for the Rare Egg.
- Done: **friend boost** (+10% coins per Roblox friend in the server, up to 4).
- Optional: **gift a pass** to another player. Roblox can't gift game passes, so it needs a second developer product per pass (16 more to set up in Creator Hub); left out for now.
- The Rare Egg is the only paid random item (odds shown, hidden where restricted). Keep every other product fixed.

## M6: Safe saving (done)
- DataService uses **ProfileStore** (s## M7: Art and feel (done, needs a Studio look)
- Code-built dinos in 10 body shapes (`Shared/DinoArt`), egg shapes and sparkles per rarity, 3D dino on the hatch screen, idle bob on pedestals.
- World (`WorldDecor`): themed props per zone, zone gates, a camp-style hub, canyon cliffs, mountains, a volcano, lakes and a river out to the horizon, clouds and pterosaurs.
- Lighting (`AtmosphereService`), fling trail, landing dust, dig burst, Perfect-fling shake.
- UI theme pass: one palette, button press feedback, panel title bars, emoji HUD, phone fit.
- Not done: sound effects and music. Roblox only plays audio you own or that is public in the Creator Store, so pick sounds there and add their IDs.
- Real models still drop in through `ReplicatedStorage.DinoModels` and override the code-built ones.

## M8: Launch checklist (needs the owner's Roblox account)
1. In Studio, set **Lighting > Technology** to Future (scripts can't set it), and turn on **Game Settings > Security > Enable Studio Access to API Services** so saving works in tests.
2. Play-test (2 players, see README "How to play-test"), checking especially:
   - Dinos: shapes look right (Triceratops frill and horns, Parasaurolophus crest, Therizinosaurus claws, Pteranodon wings), they fit the pedestals, Gold/Rainbow/Baby look right, the bob doesn't jitter.
   - Hatch screen: the spinning dino shows; the dark backdrop covers the whole screen on a phone-size window.
   - World: no floating edges, props don't block landing spots, zone gate boards don't clip the flying shovel, palm/fern/tent angles look right; dirt bursts when digging.
   - UI: buttons press and spring back, Shop/Passes/Index open with shadows, everything fits at 812x375 (Studio's device emulator).
   - Saving: leave and rejoin keeps progress; buying Starter Pack / potions / Instant Hatch / Server Luck with "Test buy" works.
   - Frame rate on a phone (Studio emulator first, then a real phone via a private server). If it's low, remove some clouds or mountains in `WorldDecor`.
3. Publish, create the passes and developer products in Creator Hub (README lists them all with prices), paste the IDs into `Config/Passes.luau` and `Config/Products.luau`.
4. Set `Social.GroupId` if you make a Roblox group.
5. Fill out the Experience Questionnaire. Make the icon and thumbnails (a screenshot of the hub with a big dino works well).

bnails.
- Play-test pass in Studio with 2 players (see README "How to play-test").

## Next games
Built one at a time after this one ships, each in its own repo and reusing this game's structure:
1. **Aliens game**: same genre, its own loop and theme.
2. **Influencer game**: original parody streamer / YouTuber characters, never real people's names, faces or trademarks.
