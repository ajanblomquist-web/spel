# Roadmap to launch

Where Fling for Fossils stands against the design doc, and what's left to finish it. Milestones 1 to 3 (core loop, first 30 minutes, first-week collection) are built; see README.md.

## M4: The rest of the world (content)
- Done: **Frozen Tundra** and **Volcano Rim** with 8 zone-only dinos; Volcano Rim is the end of the map for now.
- Optional, a design call: Crystal Caves, Meteor Crater and the secret Sky Island from the design doc, and **Speed training** (treadmill tiers) as a free counter to stealing. Field speed already keeps carrying quick.

## M5: Shop and social (monetization finish)
- Done: **coin packs** (5 / 10 / 24 hours of income), **Rare Egg**, **Codes** box.
- To do: boost potions (2x Luck / Coins / Strength, 15 min), **Server Luck** (2x luck for everyone for 10 min, announced with the buyer's name), **Instant Hatch** (price scales with time left).
- To do: **gift a pass** to another player in the server, and a **friend boost** (+10% coins per friend in the server, capped).
- Nothing random is ever sold for Robux, so no odds disclosure or PolicyService gating is needed. Keep it that way.

## M6: Safe saving
- Switch DataService to **ProfileStore** (session locking against item duplication). Keep DataService's public functions the same so no other service changes.

## M7: Art and feel
- Dinos, eggs and the world built in code from parts, so it looks finished without uploaded assets: a shaped model per dino species, mutation materials and glow, egg shapes per rarity.
- Each zone dressed with its own terrain colours, rocks, plants, props and lighting / atmosphere / sky.
- Effects: fling trail, landing burst, dig particles, hatch effects, Perfect hit, mutation sparkles.
- UI pass: one consistent theme (colours, corner radius, strokes, fonts), icons, button feedback, readable at phone size.
- Sound slots in Config (empty IDs by default; drop in sound IDs from the Creator Store).
- Real models still drop in through `ReplicatedStorage.DinoModels` and override the code-built ones.

## M8: Launch checklist (needs the owner's Roblox account)
- Publish, create passes and products in Creator Hub, paste the IDs into `Config/Passes.luau` and `Config/Products.luau`.
- Fill out the Experience Questionnaire. Make the icon and thumbnails.
- Play-test pass in Studio with 2 players (see README "How to play-test").

## Next games
Built one at a time after this one ships, each in its own repo and reusing this game's structure:
1. **Aliens game**: same genre, its own loop and theme.
2. **Influencer game**: original parody streamer / YouTuber characters, never real people's names, faces or trademarks.
