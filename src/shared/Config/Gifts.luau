-- Gifts.luau
-- Playtime gifts: claimable after this many minutes played in one session.
-- Coins rewards scale with your income so they stay worth having.
--   Coins: at least MinCoins, or IncomeSeconds worth of your coins per second
--   Boost: a timed 2x boost
--   Egg:   a free egg of this rarity, straight into an incubator

return {
	{ Minutes = 3, Reward = { MinCoins = 100, IncomeSeconds = 60 } },
	{ Minutes = 8, Reward = { Boost = "Luck", Seconds = 300 } },
	{ Minutes = 15, Reward = { MinCoins = 1000, IncomeSeconds = 180 } },
	{ Minutes = 25, Reward = { Egg = "Rare" } },
	{ Minutes = 40, Reward = { Boost = "Coins", Seconds = 600 } },
	{ Minutes = 60, Reward = { Egg = "Epic" } },
}
