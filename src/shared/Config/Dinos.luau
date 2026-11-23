-- Dinos.luau
-- Which dinosaurs hatch from each rarity, and their base coins per second.
-- Dinos with a Zone only hatch from eggs dug in that zone (a reason to reach it).
-- To use a real model instead of the greybox block, put a Model named after
-- the dino Id (e.g. "Velociraptor") in ReplicatedStorage > DinoModels.

local Dinos = {}

Dinos.List = {
	-- Common
	{
		Id = "Compsognathus",
		Name = "Compy",
		Rarity = "Common",
		Income = 1,
		Color = Color3.fromRGB(140, 170, 90),
	},
	{
		Id = "Protoceratops",
		Name = "Protoceratops",
		Rarity = "Common",
		Income = 1.2,
		Color = Color3.fromRGB(190, 150, 110),
	},
	-- Uncommon
	{
		Id = "Velociraptor",
		Name = "Velociraptor",
		Rarity = "Uncommon",
		Income = 3,
		Color = Color3.fromRGB(170, 110, 70),
	},
	{
		Id = "Stegosaurus",
		Name = "Stegosaurus",
		Rarity = "Uncommon",
		Income = 3.5,
		Color = Color3.fromRGB(110, 150, 110),
	},
	-- Rare
	{
		Id = "Triceratops",
		Name = "Triceratops",
		Rarity = "Rare",
		Income = 8,
		Color = Color3.fromRGB(120, 130, 170),
	},
	{
		Id = "Ankylosaurus",
		Name = "Ankylosaurus",
		Rarity = "Rare",
		Income = 9,
		Color = Color3.fromRGB(150, 120, 90),
	},
	-- Epic
	{
		Id = "Parasaurolophus",
		Name = "Parasaurolophus",
		Rarity = "Epic",
		Income = 25,
		Color = Color3.fromRGB(80, 160, 170),
	},
	{
		Id = "Pteranodon",
		Name = "Pteranodon",
		Rarity = "Epic",
		Income = 28,
		Color = Color3.fromRGB(200, 120, 90),
	},
	-- Legendary
	{ Id = "TRex", Name = "T. rex", Rarity = "Legendary", Income = 90, Color = Color3.fromRGB(110, 90, 70) },
	{
		Id = "Spinosaurus",
		Name = "Spinosaurus",
		Rarity = "Legendary",
		Income = 100,
		Color = Color3.fromRGB(60, 110, 140),
	},
	-- Mythic
	{
		Id = "Brachiosaurus",
		Name = "Brachiosaurus",
		Rarity = "Mythic",
		Income = 360,
		Color = Color3.fromRGB(150, 160, 120),
	},
	-- Secret
	{
		Id = "MeteorRex",
		Name = "Meteor Rex",
		Rarity = "Secret",
		Income = 1500,
		Color = Color3.fromRGB(255, 60, 30),
	},
	-- Amber Cliffs exclusives
	{
		Id = "Dimetrodon",
		Name = "Dimetrodon",
		Rarity = "Uncommon",
		Income = 4.5,
		Zone = "AmberCliffs",
		Color = Color3.fromRGB(200, 110, 60),
	},
	{
		Id = "AmberRaptor",
		Name = "Amber Raptor",
		Rarity = "Rare",
		Income = 13,
		Zone = "AmberCliffs",
		Color = Color3.fromRGB(240, 170, 60),
	},
	{
		Id = "Therizinosaurus",
		Name = "Therizinosaurus",
		Rarity = "Epic",
		Income = 40,
		Zone = "AmberCliffs",
		Color = Color3.fromRGB(150, 120, 80),
	},
	{
		Id = "AmberRex",
		Name = "Amber Rex",
		Rarity = "Legendary",
		Income = 140,
		Zone = "AmberCliffs",
		Color = Color3.fromRGB(255, 150, 30),
	},
	-- Frozen Tundra exclusives
	{
		Id = "SnowCompy",
		Name = "Snow Compy",
		Rarity = "Uncommon",
		Income = 6,
		Zone = "FrozenTundra",
		Color = Color3.fromRGB(235, 245, 255),
	},
	{
		Id = "FrostRaptor",
		Name = "Frost Raptor",
		Rarity = "Rare",
		Income = 18,
		Zone = "FrozenTundra",
		Color = Color3.fromRGB(150, 210, 255),
	},
	{
		Id = "GlacierAnkylo",
		Name = "Glacier Ankylo",
		Rarity = "Epic",
		Income = 55,
		Zone = "FrozenTundra",
		Color = Color3.fromRGB(120, 180, 230),
	},
	{
		Id = "BlizzardSpino",
		Name = "Blizzard Spino",
		Rarity = "Legendary",
		Income = 190,
		Zone = "FrozenTundra",
		Color = Color3.fromRGB(200, 230, 255),
	},
	-- Volcano Rim exclusives
	{
		Id = "EmberRaptor",
		Name = "Ember Raptor",
		Rarity = "Rare",
		Income = 24,
		Zone = "VolcanoRim",
		Color = Color3.fromRGB(255, 110, 40),
	},
	{
		Id = "MagmaStego",
		Name = "Magma Stego",
		Rarity = "Epic",
		Income = 75,
		Zone = "VolcanoRim",
		Color = Color3.fromRGB(200, 60, 30),
	},
	{
		Id = "InfernoSpino",
		Name = "Inferno Spino",
		Rarity = "Legendary",
		Income = 260,
		Zone = "VolcanoRim",
		Color = Color3.fromRGB(255, 80, 20),
	},
	{
		Id = "VolcanoTitan",
		Name = "Volcano Titan",
		Rarity = "Mythic",
		Income = 500,
		Zone = "VolcanoRim",
		Color = Color3.fromRGB(110, 40, 30),
	},
}

Dinos.ById = {}
Dinos.ByRarity = {} -- dinos that hatch anywhere
for _, dino in Dinos.List do
	Dinos.ById[dino.Id] = dino
	if not dino.Zone then
		Dinos.ByRarity[dino.Rarity] = Dinos.ByRarity[dino.Rarity] or {}
		table.insert(Dinos.ByRarity[dino.Rarity], dino)
	end
end

-- The dinos an egg of this rarity from this zone can hatch into.
function Dinos.Pool(rarityId: string, zoneId: string?): { any }
	local pool = table.clone(Dinos.ByRarity[rarityId] or Dinos.ByRarity.Common)
	for _, dino in Dinos.List do
		if dino.Zone and dino.Zone == zoneId and dino.Rarity == rarityId then
			table.insert(pool, dino)
		end
	end
	return pool
end

return Dinos
