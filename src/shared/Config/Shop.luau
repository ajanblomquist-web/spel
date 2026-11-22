-- Shop.luau
-- Upgrades bought with coins. Tier 1 of each is what every player starts with.

local Shop = {}

-- Progression shape (checked with a simulation, see README "Tuning the curve"):
--   minutes 0-5   fast burst: Stone Rock and Stone Shovel come quickly
--   minutes 5-30  slow climb: Iron tiers, Tar Pits is hard-earned
--   ~minute 30    BREAKTHROUGH: the Gold Rock is a 6x jump and sends you to Amber Cliffs
-- Breakthrough = true makes the shop highlight it and plays the big celebration.

Shop.Rocks = {
	{ Name = "Pebble", Price = 0, StrengthPerRep = 2, Color = Color3.fromRGB(160, 160, 160) },
	{ Name = "Stone", Price = 150, StrengthPerRep = 5, Color = Color3.fromRGB(120, 115, 110) },
	{ Name = "Iron", Price = 1500, StrengthPerRep = 10, Color = Color3.fromRGB(90, 95, 105) },
	{
		Name = "Gold",
		Price = 55000,
		StrengthPerRep = 60,
		Color = Color3.fromRGB(240, 190, 50),
		Breakthrough = true,
	},
	{ Name = "Diamond", Price = 400000, StrengthPerRep = 180, Color = Color3.fromRGB(120, 220, 255) },
	{ Name = "Meteorite", Price = 4000000, StrengthPerRep = 600, Color = Color3.fromRGB(150, 50, 40) },
}

Shop.Shovels = {
	{ Name = "Wooden Shovel", Price = 0, Power = 1, Luck = 1, Color = Color3.fromRGB(150, 105, 60) },
	{ Name = "Stone Shovel", Price = 300, Power = 1.15, Luck = 1.1, Color = Color3.fromRGB(130, 130, 130) },
	{ Name = "Iron Shovel", Price = 6000, Power = 1.3, Luck = 1.25, Color = Color3.fromRGB(95, 100, 110) },
	{ Name = "Gold Shovel", Price = 120000, Power = 1.8, Luck = 1.6, Color = Color3.fromRGB(240, 190, 50) },
	{
		Name = "Diamond Shovel",
		Price = 600000,
		Power = 2.2,
		Luck = 2.2,
		Color = Color3.fromRGB(120, 220, 255),
	},
	{ Name = "Fossil Pick", Price = 6000000, Power = 2.7, Luck = 3, Color = Color3.fromRGB(230, 220, 200) },
}

return Shop
