-- WorldEvents.luau
-- Server-wide events. One runs automatically for DurationSeconds at the start
-- of every hour (UTC), the same event on every server, picked in order from
-- this list. The game owner can also start one with a chat command:
--   /event DoubleLuck      (or any Id below)
--   /event stop
--
-- Effects multiply: Luck (egg rarity), Coins (dino income), Strength (per rep),
-- Mutation (chance of Gold/Lava/... eggs), Baby (Baby dino odds).

local WorldEvents = {}

WorldEvents.DurationSeconds = 600 -- 10 minutes
WorldEvents.EverySeconds = 3600 -- one automatic event per hour

WorldEvents.List = {
	{
		Id = "DoubleLuck",
		Name = "DOUBLE LUCK",
		Effect = "Luck",
		Multiplier = 2,
		Color = Color3.fromRGB(70, 200, 90),
	},
	{
		Id = "DoubleCoins",
		Name = "DOUBLE COINS",
		Effect = "Coins",
		Multiplier = 2,
		Color = Color3.fromRGB(255, 200, 50),
	},
	{
		Id = "GoldenHour",
		Name = "GOLDEN HOUR",
		Effect = "Mutation",
		Multiplier = 3,
		Color = Color3.fromRGB(255, 170, 30),
	},
	{
		Id = "BabyBoom",
		Name = "BABY BOOM",
		Effect = "Baby",
		Multiplier = 5,
		Color = Color3.fromRGB(255, 140, 200),
	},
	{
		Id = "StrengthSurge",
		Name = "STRENGTH SURGE",
		Effect = "Strength",
		Multiplier = 2,
		Color = Color3.fromRGB(255, 120, 80),
	},
}

WorldEvents.ById = {}
for _, event in WorldEvents.List do
	WorldEvents.ById[event.Id] = event
end

-- Short description for banners.
function WorldEvents.Describe(event): string
	if event.Effect == "Mutation" then
		return event.Multiplier .. "x mutation chance!"
	elseif event.Effect == "Baby" then
		return event.Multiplier .. "x Baby dino odds!"
	end
	return event.Multiplier .. "x " .. event.Effect .. " for everyone!"
end

return WorldEvents
