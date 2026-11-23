-- Eggs.luau
-- Rarity, size and mutation tables for fossil eggs. All rolls happen on the
-- server (see EggService). Eggs are never sold for Robux, so no odds
-- disclosure is needed, but the odds are still easy to show in an Index later.

local Eggs = {}

-- LuckPower: how strongly luck boosts this rarity. Weight used for the roll is
-- Weight * luck ^ LuckPower, so luck 1 gives exactly these weights.
Eggs.Rarities = {
	{
		Id = "Common",
		Weight = 60,
		LuckPower = 0,
		IncubateSeconds = 30,
		Color = Color3.fromRGB(200, 200, 200),
	},
	{
		Id = "Uncommon",
		Weight = 25,
		LuckPower = 0.5,
		IncubateSeconds = 60,
		Color = Color3.fromRGB(95, 200, 95),
	},
	{ Id = "Rare", Weight = 10, LuckPower = 1, IncubateSeconds = 120, Color = Color3.fromRGB(70, 140, 255) },
	{
		Id = "Epic",
		Weight = 4,
		LuckPower = 1.25,
		IncubateSeconds = 300,
		Color = Color3.fromRGB(170, 85, 255),
	},
	{
		Id = "Legendary",
		Weight = 0.9,
		LuckPower = 1.5,
		IncubateSeconds = 600,
		Color = Color3.fromRGB(255, 190, 40),
	},
	{
		Id = "Mythic",
		Weight = 0.09,
		LuckPower = 1.75,
		IncubateSeconds = 1200,
		Color = Color3.fromRGB(255, 70, 110),
	},
	{
		Id = "Secret",
		Weight = 0.01,
		LuckPower = 2,
		IncubateSeconds = 1800,
		Color = Color3.fromRGB(20, 20, 20),
	},
}

-- Size changes both the dino's scale and its income.
Eggs.Sizes = {
	{ Id = "Small", Weight = 20, Multiplier = 0.8, Scale = 0.7 },
	{ Id = "Normal", Weight = 60, Multiplier = 1, Scale = 1 },
	{ Id = "Big", Weight = 15, Multiplier = 1.5, Scale = 1.3 },
	{ Id = "Huge", Weight = 4.5, Multiplier = 2.5, Scale = 1.7 },
	{ Id = "Colossal", Weight = 0.5, Multiplier = 5, Scale = 2.3 },
}

-- Mutations multiply income and change the look. Kept to a short ladder
-- (normal, Gold, Rainbow) so the Dino Index stays easy to read.
Eggs.Mutations = {
	{ Id = "None", Weight = 92.5, Multiplier = 1 },
	{
		Id = "Gold",
		Weight = 7,
		Multiplier = 2,
		Color = Color3.fromRGB(255, 200, 50),
		Material = Enum.Material.Foil,
	},
	{
		Id = "Rainbow",
		Weight = 0.5,
		Multiplier = 10,
		Color = Color3.fromRGB(255, 120, 220),
		Material = Enum.Material.ForceField,
	},
}

-- Mutations that were removed, and what old saves turn them into.
Eggs.RetiredMutations = { Lava = "Gold", Frozen = "Gold", Crystal = "Gold" }

local function index(list)
	local byId = {}
	for order, entry in list do
		entry.Order = order
		byId[entry.Id] = entry
	end
	return byId
end

Eggs.RarityById = index(Eggs.Rarities)
Eggs.SizeById = index(Eggs.Sizes)
Eggs.MutationById = index(Eggs.Mutations)

return Eggs
