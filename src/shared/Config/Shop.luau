-- Shop.luau
-- Upgrades bought with coins. Tier 1 of each is what every player starts with.

local Shop = {}

Shop.Rocks = {
	{ Name = "Pebble", Price = 0, StrengthPerRep = 1, Color = Color3.fromRGB(160, 160, 160) },
	{ Name = "Stone", Price = 250, StrengthPerRep = 3, Color = Color3.fromRGB(120, 115, 110) },
	{ Name = "Iron", Price = 2500, StrengthPerRep = 10, Color = Color3.fromRGB(90, 95, 105) },
	{ Name = "Gold", Price = 25000, StrengthPerRep = 35, Color = Color3.fromRGB(240, 190, 50) },
	{ Name = "Diamond", Price = 250000, StrengthPerRep = 120, Color = Color3.fromRGB(120, 220, 255) },
	{ Name = "Meteorite", Price = 2500000, StrengthPerRep = 400, Color = Color3.fromRGB(150, 50, 40) },
}

Shop.Shovels = {
	{ Name = "Wooden Shovel", Price = 0, Power = 1, Luck = 1, Color = Color3.fromRGB(150, 105, 60) },
	{ Name = "Stone Shovel", Price = 500, Power = 1.2, Luck = 1.1, Color = Color3.fromRGB(130, 130, 130) },
	{ Name = "Iron Shovel", Price = 5000, Power = 1.45, Luck = 1.25, Color = Color3.fromRGB(95, 100, 110) },
	{ Name = "Gold Shovel", Price = 50000, Power = 1.75, Luck = 1.5, Color = Color3.fromRGB(240, 190, 50) },
	{ Name = "Diamond Shovel", Price = 500000, Power = 2.1, Luck = 2, Color = Color3.fromRGB(120, 220, 255) },
	{ Name = "Fossil Pick", Price = 5000000, Power = 2.6, Luck = 3, Color = Color3.fromRGB(230, 220, 200) },
}

return Shop
