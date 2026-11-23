-- Daily.luau
-- Daily login streak: claim once per day (UTC). Come back the next day to
-- move along the track; miss a day and it starts over at day 1. After day 7
-- it loops back to day 1 but the streak count keeps growing.
-- Rewards use the same format as playtime gifts (see Config/Gifts).

return {
	{ Text = "Coins", Reward = { MinCoins = 500, IncomeSeconds = 120 } },
	{ Text = "2x Luck 10 min", Reward = { Boost = "Luck", Seconds = 600 } },
	{ Text = "Big coins", Reward = { MinCoins = 2000, IncomeSeconds = 300 } },
	{ Text = "2x Strength 15 min", Reward = { Boost = "Strength", Seconds = 900 } },
	{ Text = "Rare egg", Reward = { Egg = "Rare" } },
	{ Text = "2x Coins 20 min", Reward = { Boost = "Coins", Seconds = 1200 } },
	{ Text = "EPIC egg", Reward = { Egg = "Epic" } },
}
