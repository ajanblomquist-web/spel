-- Dinos.luau
-- Which dinosaurs hatch from each rarity, and their base coins per second.
-- Dinos with a Zone only hatch from eggs dug in that zone (a reason to reach it).
-- To use a real model instead of the greybox block, put a Model named after
-- the dino Id (e.g. "Velociraptor") in ReplicatedStorage > DinoModels.
-- Models made with tools/blender/dino_maker.py are coloured from Color, plus the
-- optional Belly, Accent (spikes/plates) and Pattern (stripes/spots) colours, and scaled to Height studs
-- (default 6). Gold, Rainbow and Baby versions come from the same model.

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
	{
		Id = "TRex",
		Name = "T. rex",
		Rarity = "Legendary",
		Income = 90,
		Color = Color3.fromRGB(95, 170, 80),
		Belly = Color3.fromRGB(240, 230, 170),
		Accent = Color3.fromRGB(240, 150, 60),
		Pattern = Color3.fromRGB(65, 130, 60),
		Height = 7,
	},
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
