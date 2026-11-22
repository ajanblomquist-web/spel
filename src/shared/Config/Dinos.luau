-- Dinos.luau
-- Which dinosaurs hatch from each rarity, and their base coins per second.
-- To use a real model instead of the greybox block, put a Model named after
-- the dino Id (e.g. "Velociraptor") in ReplicatedStorage > DinoModels.

local Dinos = {}

Dinos.List = {
	-- Common
	{
		Id = "Compsognathus",
		Name = "Compy",
		Rarity = "Common",
		Income = 2,
		Color = Color3.fromRGB(140, 170, 90),
	},
	{
		Id = "Protoceratops",
		Name = "Protoceratops",
		Rarity = "Common",
		Income = 2.5,
		Color = Color3.fromRGB(190, 150, 110),
	},
	-- Uncommon
	{
		Id = "Velociraptor",
		Name = "Velociraptor",
		Rarity = "Uncommon",
		Income = 6,
		Color = Color3.fromRGB(170, 110, 70),
	},
	{
		Id = "Stegosaurus",
		Name = "Stegosaurus",
		Rarity = "Uncommon",
		Income = 7,
		Color = Color3.fromRGB(110, 150, 110),
	},
	-- Rare
	{
		Id = "Triceratops",
		Name = "Triceratops",
		Rarity = "Rare",
		Income = 20,
		Color = Color3.fromRGB(120, 130, 170),
	},
	{
		Id = "Ankylosaurus",
		Name = "Ankylosaurus",
		Rarity = "Rare",
		Income = 22,
		Color = Color3.fromRGB(150, 120, 90),
	},
	-- Epic
	{
		Id = "Parasaurolophus",
		Name = "Parasaurolophus",
		Rarity = "Epic",
		Income = 70,
		Color = Color3.fromRGB(80, 160, 170),
	},
	{
		Id = "Pteranodon",
		Name = "Pteranodon",
		Rarity = "Epic",
		Income = 75,
		Color = Color3.fromRGB(200, 120, 90),
	},
	-- Legendary
	{ Id = "TRex", Name = "T. rex", Rarity = "Legendary", Income = 250, Color = Color3.fromRGB(110, 90, 70) },
	{
		Id = "Spinosaurus",
		Name = "Spinosaurus",
		Rarity = "Legendary",
		Income = 270,
		Color = Color3.fromRGB(60, 110, 140),
	},
	-- Mythic
	{
		Id = "Brachiosaurus",
		Name = "Brachiosaurus",
		Rarity = "Mythic",
		Income = 1000,
		Color = Color3.fromRGB(150, 160, 120),
	},
	-- Secret
	{
		Id = "MeteorRex",
		Name = "Meteor Rex",
		Rarity = "Secret",
		Income = 5000,
		Color = Color3.fromRGB(255, 60, 30),
	},
}

Dinos.ById = {}
Dinos.ByRarity = {}
for _, dino in Dinos.List do
	Dinos.ById[dino.Id] = dino
	Dinos.ByRarity[dino.Rarity] = Dinos.ByRarity[dino.Rarity] or {}
	table.insert(Dinos.ByRarity[dino.Rarity], dino)
end

return Dinos
