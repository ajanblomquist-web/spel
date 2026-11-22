-- Quests.luau
-- The quest chain. One quest is always on screen with a progress bar.
-- The first 5 are the guided tutorial (Tutorial = true): a glowing line
-- points at the place to go (Guide).
--
-- Type        Target means
--   Reps        training reps
--   Fling       flings
--   Perfect     Perfect flings
--   Distance    fling at least this far (studs, shown as m)
--   Dig         eggs dug
--   Deliver     eggs carried home
--   Hatch       dinos hatched
--   HatchRarity hatch one of at least this rarity (Target = rarity Id)
--   HatchZone   hatch a dino from an egg dug in this zone (Target = zone Id)
--   RockTier    own at least this rock tier
--   ShovelTier  own at least this shovel tier
--   Steal       eggs stolen (the practice thief counts)
--   LockNest    times you locked your nest
--   IndexCount  boxes ticked in the Dino Index (total, so old ones count)
--   IndexPage   complete this page of the Dino Index (Target = rarity Id)
--
-- Reward: { Coins = n } or { Boost = "Luck" | "Coins" | "Strength", Seconds = n }
-- Guide: "Rock" | "Pad" | "DigSpot" | "Home" | "Shop" | "Thief"

export type Quest = {
	Text: string,
	Type: string,
	Target: any,
	Guide: string?,
	Tutorial: boolean?,
	Reward: { Coins: number?, Boost: string?, Seconds: number? },
}

local Quests: { Quest } = {
	-- Tutorial: the first loop, about 3 minutes
	{
		Text = "Train at the rock",
		Type = "Reps",
		Target = 15,
		Guide = "Rock",
		Tutorial = true,
		Reward = { Coins = 25 },
	},
	{
		Text = "Fling your shovel",
		Type = "Fling",
		Target = 1,
		Guide = "Pad",
		Tutorial = true,
		Reward = { Coins = 25 },
	},
	{
		Text = "Dig up your egg",
		Type = "Dig",
		Target = 1,
		Guide = "DigSpot",
		Tutorial = true,
		Reward = { Coins = 25 },
	},
	{
		Text = "Carry it home",
		Type = "Deliver",
		Target = 1,
		Guide = "Home",
		Tutorial = true,
		Reward = { Coins = 25 },
	},
	{
		Text = "Hatch your egg",
		Type = "Hatch",
		Target = 1,
		Guide = "Home",
		Tutorial = true,
		Reward = { Coins = 75 },
	},

	-- Burst: minutes 3 to 8
	{ Text = "Buy the Stone Rock", Type = "RockTier", Target = 2, Guide = "Shop", Reward = { Coins = 100 } },
	{
		Text = "Train to make your flings longer",
		Type = "Reps",
		Target = 60,
		Guide = "Rock",
		Reward = { Boost = "Strength", Seconds = 120 },
	},
	{
		Text = "Fling 120m into Fern Valley",
		Type = "Distance",
		Target = 120,
		Guide = "Pad",
		Reward = { Boost = "Luck", Seconds = 180 },
	},
	{
		Text = "Buy the Stone Shovel",
		Type = "ShovelTier",
		Target = 2,
		Guide = "Shop",
		Reward = { Coins = 150 },
	},
	{ Text = "Land 2 Perfect flings", Type = "Perfect", Target = 2, Guide = "Pad", Reward = { Coins = 250 } },

	-- Slow climb: minutes 8 to 30
	{
		Text = "Steal an egg (try the thief in the hub!)",
		Type = "Steal",
		Target = 1,
		Guide = "Thief",
		Reward = { Coins = 300 },
	},
	{
		Text = "Hatch 3 more dinos",
		Type = "Hatch",
		Target = 3,
		Guide = "Pad",
		Reward = { Boost = "Coins", Seconds = 300 },
	},
	{ Text = "Lock your nest", Type = "LockNest", Target = 1, Guide = "Home", Reward = { Coins = 400 } },
	{ Text = "Buy the Iron Rock", Type = "RockTier", Target = 3, Guide = "Shop", Reward = { Coins = 600 } },
	{
		Text = "Fling 300m into the Tar Pits",
		Type = "Distance",
		Target = 300,
		Guide = "Pad",
		Reward = { Boost = "Luck", Seconds = 300 },
	},
	{
		Text = "Fill 6 boxes in your Dino Index",
		Type = "IndexCount",
		Target = 6,
		Guide = "Pad",
		Reward = { Coins = 1500 },
	},
	{
		Text = "Buy the Iron Shovel",
		Type = "ShovelTier",
		Target = 3,
		Guide = "Shop",
		Reward = { Coins = 2500 },
	},
	{
		Text = "Hatch an Epic dino",
		Type = "HatchRarity",
		Target = "Epic",
		Guide = "Pad",
		Reward = { Coins = 5000 },
	},

	-- Breakthrough: around minute 30
	{
		Text = "BREAKTHROUGH: buy the Gold Rock",
		Type = "RockTier",
		Target = 4,
		Guide = "Shop",
		Reward = { Boost = "Strength", Seconds = 300 },
	},
	{
		Text = "Fling 550m into Amber Cliffs",
		Type = "Distance",
		Target = 550,
		Guide = "Pad",
		Reward = { Coins = 15000 },
	},
	{
		Text = "Hatch an Amber Cliffs dino",
		Type = "HatchZone",
		Target = "AmberCliffs",
		Guide = "Pad",
		Reward = { Boost = "Coins", Seconds = 600 },
	},
	{
		Text = "Buy the Gold Shovel",
		Type = "ShovelTier",
		Target = 4,
		Guide = "Shop",
		Reward = { Coins = 40000 },
	},
	{
		Text = "Complete the Uncommon page of your Index",
		Type = "IndexPage",
		Target = "Uncommon",
		Guide = "Pad",
		Reward = { Coins = 20000 },
	},
	{
		Text = "Fill 25 boxes in your Dino Index",
		Type = "IndexCount",
		Target = 25,
		Guide = "Pad",
		Reward = { Boost = "Luck", Seconds = 600 },
	},
}

return Quests
