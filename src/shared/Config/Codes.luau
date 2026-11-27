-- Codes.luau
-- Redeemable codes for the Codes box at the top of the Shop. Share them on
-- YouTube, Discord or the group wall. Each code works once per player.
--
-- Code: what players type (not case sensitive, spaces ignored).
-- Reward: same format as playtime gifts (see Config/Gifts):
--   { Boost = "Luck" | "Coins" | "Strength", Seconds = 900 }
--   { MinCoins = 1000, IncomeSeconds = 600 }  coins = 10 min of income, at least 1,000
--   { Egg = "Rare" }
-- Expires: optional unix time (https://www.unixtimestamp.com) after which it stops working.
--
-- To add a code: add a line, publish. Never reuse an old code's name.

return {
	{ Code = "FOSSIL", Reward = { Boost = "Luck", Seconds = 900 } },
	{ Code = "RELEASE", Reward = { MinCoins = 1000, IncomeSeconds = 600 } },
	{ Code = "DINOPOWER", Reward = { Boost = "Strength", Seconds = 900 } },
}
