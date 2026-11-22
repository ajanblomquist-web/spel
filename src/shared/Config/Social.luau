-- Social.luau
-- The game's Roblox group and the pass hints.
--
-- Group: create a group on Roblox, then paste its ID into GroupId. Joining
-- gives a one-time reward (a Luck boost and coins); a "Join our group" row
-- shows at the top of the Passes menu until claimed, and one hint suggests it
-- after the tutorial. With GroupId = 0 all group features are hidden.
--
-- Hints: short tips that point at a pass right when it would help. They never
-- show during the tutorial, at most one every HintGapSeconds, each one at most
-- once per session, and never for a pass you already own.

local Social = {}

Social.GroupId = 0
-- One-time reward for joining: a 2x Luck boost and coins (at least MinCoins,
-- or this many seconds of your income, whichever is more).
Social.GroupReward = { BoostSeconds = 900, MinCoins = 5000, IncomeSeconds = 600 }

Social.HintGapSeconds = 300 -- at least 5 minutes between hints
Social.HintShowSeconds = 9 -- a hint card closes by itself after this long

-- Text for each hint. Pass = the pass it opens (or "Group" for the group).
Social.Hints = {
	PedestalsFull = { Pass = "ExtraPedestals", Text = "Pedestals full! Extra Pedestals gives you 6 more." },
	IncubatorsFull = {
		Pass = "FastIncubator",
		Text = "Waiting on eggs? Fast Incubator hatches them 2x faster.",
	},
	NestRobbed = { Pass = "FortressGate", Text = "Robbed! Fortress Gate locks your nest for 3 minutes." },
	CarryRobbed = { Pass = "SpeedyBoots", Text = "Too slow! Speedy Boots makes you 25% faster." },
	LotsOfTraining = { Pass = "AutoTrain", Text = "Auto Train trains at full speed from anywhere." },
	LotsOfFlings = { Pass = "AutoFling", Text = "Auto Fling flings for you and a drone brings eggs home." },
	ManyCommons = { Pass = "LuckyShovel", Text = "Want rarer eggs? Lucky Shovel gives +50% luck." },
	Group = { Pass = "Group", Text = "Join our group for a free 15 min 2x Luck + coins!" },
}

-- How many of something before a hint shows.
Social.TrainingRepsForHint = 150
Social.FlingsForHint = 15
Social.CommonsForHint = 8
Social.GroupHintDelay = 90 -- seconds after the tutorial

return Social
