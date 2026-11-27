-- Dinos.luau
-- Which dinosaurs hatch from each rarity, and their base coins per second.
-- Dinos with a Zone only hatch from eggs dug in that zone (a reason to reach it).
-- Shape picks the body plan in DinoArt (Accent colours the belly/plates/frill).
-- To use a real model instead of the code-built one, put a Model named after
-- the dino Id (e.g. "Velociraptor") in ReplicatedStorage > DinoModels.

local Dinos = {}

Dinos.List = {
	-- Common
	{
		Id = "Compsognathus",
		Shape = "Raptor",
		Accent = Color3.fromRGB(235, 225, 160),
		Name = "Compy",
		Rarity = "Common",
		Income = 1,
		Color = Color3.fromRGB(140, 170, 90),
	},
	{
		Id = "Protoceratops",
		Shape = "Horned",
		Accent = Color3.fromRGB(225, 200, 150),
		Name = "Protoceratops",
		Rarity = "Common",
		Income = 1.2,
		Color = Color3.fromRGB(190, 150, 110),
	},
	-- Uncommon
	{
		Id = "Velociraptor",
		Shape = "Raptor",
		Accent = Color3.fromRGB(235, 200, 150),
		Name = "Velociraptor",
		Rarity = "Uncommon",
		Income = 3,
		Color = Color3.fromRGB(170, 110, 70),
	},
	{
		Id = "Stegosaurus",
		Shape = "Plated",
		Accent = Color3.fromRGB(235, 150, 90),
		Name = "Stegosaurus",
		Rarity = "Uncommon",
		Income = 3.5,
		Color = Color3.fromRGB(110, 150, 110),
	},
	-- Rare
	{
		Id = "Triceratops",
		Shape = "Horned",
		Accent = Color3.fromRGB(230, 130, 140),
		Name = "Triceratops",
		Rarity = "Rare",
		Income = 8,
		Color = Color3.fromRGB(120, 130, 170),
	},
	{
		Id = "Ankylosaurus",
		Shape = "Armored",
		Accent = Color3.fromRGB(200, 170, 130),
		Name = "Ankylosaurus",
		Rarity = "Rare",
		Income = 9,
		Color = Color3.fromRGB(150, 120, 90),
	},
	-- Epic
	{
		Id = "Parasaurolophus",
		Shape = "Crested",
		Accent = Color3.fromRGB(240, 205, 90),
		Name = "Parasaurolophus",
		Rarity = "Epic",
		Income = 25,
		Color = Color3.fromRGB(80, 160, 170),
	},
	{
		Id = "Pteranodon",
		Shape = "Flyer",
		Accent = Color3.fromRGB(250, 215, 160),
		Name = "Pteranodon",
		Rarity = "Epic",
		Income = 28,
		Color = Color3.fromRGB(200, 120, 90),
	},
	-- Legendary
	{
		Id = "TRex",
		Shape = "Rex",
		Accent = Color3.fromRGB(205, 185, 145),
		Name = "T. rex",
		Rarity = "Legendary",
		Income = 90,
		Color = Color3.fromRGB(110, 90, 70),
	},
	{
		Id = "Spinosaurus",
		Shape = "Sail",
		Accent = Color3.fromRGB(240, 150, 90),
		Name = "Spinosaurus",
		Rarity = "Legendary",
		Income = 100,
		Color = Color3.fromRGB(60, 110, 140),
	},
	-- Mythic
	{
		Id = "Brachiosaurus",
		Shape = "LongNeck",
		Accent = Color3.fromRGB(210, 215, 170),
		Name = "Brachiosaurus",
		Rarity = "Mythic",
		Income = 360,
		Color = Color3.fromRGB(150, 160, 120),
	},
	-- Secret
	{
		Id = "MeteorRex",
		Shape = "Rex",
		Name = "Meteor Rex",
		Rarity = "Secret",
		Income = 1500,
		Color = Color3.fromRGB(255, 60, 30),
	},
	-- Amber Cliffs exclusives
	{
		Id = "Dimetrodon",
		Shape = "Sail",
		Accent = Color3.fromRGB(240, 180, 100),
		Name = "Dimetrodon",
		Rarity = "Uncommon",
		Income = 4.5,
		Zone = "AmberCliffs",
		Color = Color3.fromRGB(200, 110, 60),
	},
	{
		Id = "AmberRaptor",
		Shape = "Raptor",
		Name = "Amber Raptor",
		Rarity = "Rare",
		Income = 13,
		Zone = "AmberCliffs",
		Color = Color3.fromRGB(240, 170, 60),
	},
	{
		Id = "Therizinosaurus",
		Shape = "Claw",
		Accent = Color3.fromRGB(210, 180, 140),
		Name = "Therizinosaurus",
		Rarity = "Epic",
		Income = 40,
		Zone = "AmberCliffs",
		Color = Color3.fromRGB(150, 120, 80),
	},
	{
		Id = "AmberRex",
		Shape = "Rex",
		Name = "Amber Rex",
		Rarity = "Legendary",
		Income = 140,
		Zone = "AmberCliffs",
		Color = Color3.fromRGB(255, 150, 30),
	},
	-- Frozen Tundra exclusives
	{
		Id = "SnowCompy",
		Shape = "Raptor",
		Name = "Snow Compy",
		Rarity = "Uncommon",
		Income = 6,
		Zone = "FrozenTundra",
		Color = Color3.fromRGB(235, 245, 255),
	},
	{
		Id = "FrostRaptor",
		Shape = "Raptor",
		Name = "Frost Raptor",
		Rarity = "Rare",
		Income = 18,
		Zone = "FrozenTundra",
		Color = Color3.fromRGB(150, 210, 255),
	},
	{
		Id = "GlacierAnkylo",
		Shape = "Armored",
		Name = "Glacier Ankylo",
		Rarity = "Epic",
		Income = 55,
		Zone = "FrozenTundra",
		Color = Color3.fromRGB(120, 180, 230),
	},
	{
		Id = "BlizzardSpino",
		Shape = "Sail",
		Name = "Blizzard Spino",
		Rarity = "Legendary",
		Income = 190,
		Zone = "FrozenTundra",
		Color = Color3.fromRGB(200, 230, 255),
	},
	-- Volcano Rim exclusives
	{
		Id = "EmberRaptor",
		Shape = "Raptor",
		Name = "Ember Raptor",
		Rarity = "Rare",
		Income = 24,
		Zone = "VolcanoRim",
		Color = Color3.fromRGB(255, 110, 40),
	},
	{
		Id = "MagmaStego",
		Shape = "Plated",
		Name = "Magma Stego",
		Rarity = "Epic",
		Income = 75,
		Zone = "VolcanoRim",
		Color = Color3.fromRGB(200, 60, 30),
	},
	{
		Id = "InfernoSpino",
		Shape = "Sail",
		Name = "Inferno Spino",
		Rarity = "Legendary",
		Income = 260,
		Zone = "VolcanoRim",
		Color = Color3.fromRGB(255, 80, 20),
	},
	{
		Id = "VolcanoTitan",
		Shape = "LongNeck",
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
