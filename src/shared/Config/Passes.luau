-- Passes.luau
-- Game passes. Create each pass in Creator Hub (your experience > Monetization >
-- Passes), then paste its ID into GamePassId below. A pass with ID 0 shows as
-- "Coming soon" in the shop. In Studio you can switch passes on and off from the
-- Passes menu to test them without buying.
--
-- All passes speed up the loop. None sells a random roll.

export type Pass = {
	Key: string,
	Name: string,
	Description: string,
	GamePassId: number,
	Price: number, -- display only; the real price is set in Creator Hub
	Order: number,
	Shop: string?, -- "Weapon" or "Skin": shown in the Shop's weapon section, not the Passes menu
}

local Passes: { [string]: Pass } = {
	DoubleCoins = {
		Key = "DoubleCoins",
		Name = "2x Coins",
		Description = "Doubles all dino income.",
		GamePassId = 0,
		Price = 399,
		Order = 1,
	},
	DoubleStrength = {
		Key = "DoubleStrength",
		Name = "2x Strength",
		Description = "Doubles Strength from every rep.",
		GamePassId = 0,
		Price = 199,
		Order = 2,
	},
	AutoTrain = {
		Key = "AutoTrain",
		Name = "Auto Train",
		Description = "Trains by itself while you stand at the rock.",
		GamePassId = 0,
		Price = 249,
		Order = 3,
	},
	AutoFling = {
		Key = "AutoFling",
		Name = "Auto Fling",
		Description = "Stand at the pad: it flings for you and a dino drone flies every egg straight to your nest.",
		GamePassId = 0,
		Price = 349,
		Order = 4,
	},
	LuckyShovel = {
		Key = "LuckyShovel",
		Name = "Lucky Shovel",
		Description = "+50% luck on every dig.",
		GamePassId = 0,
		Price = 299,
		Order = 5,
	},
	FastIncubator = {
		Key = "FastIncubator",
		Name = "Fast Incubator",
		Description = "Eggs hatch 2x faster.",
		GamePassId = 0,
		Price = 249,
		Order = 6,
	},
	ExtraPedestals = {
		Key = "ExtraPedestals",
		Name = "Extra Pedestals",
		Description = "+6 pedestals for more dinos.",
		GamePassId = 0,
		Price = 199,
		Order = 7,
	},
	SpeedyBoots = {
		Key = "SpeedyBoots",
		Name = "Speedy Boots",
		Description = "+25% walk speed, also while carrying.",
		GamePassId = 0,
		Price = 149,
		Order = 8,
	},
	FortressGate = {
		Key = "FortressGate",
		Name = "Fortress Gate",
		Description = "Your nest lock lasts 3 minutes instead of 1.",
		GamePassId = 0,
		Price = 149,
		Order = 9,
	},
	VIP = {
		Key = "VIP",
		Name = "VIP",
		Description = "+10% coins and a VIP tag.",
		GamePassId = 0,
		Price = 449,
		Order = 10,
	},

	-- Weapons and skins (see Config/Weapons). Shown in the Shop, not the Passes menu.
	AmberHammer = {
		Key = "AmberHammer",
		Name = "Amber Hammer",
		Description = "Bonk weapon: as strong as the Raptor Claw, no grinding needed.",
		GamePassId = 0,
		Price = 149,
		Order = 101,
		Shop = "Weapon",
	},
	MeteorBat = {
		Key = "MeteorBat",
		Name = "Meteor Bat",
		Description = "Bonk weapon: as strong as the Raptor Claw, glows purple.",
		GamePassId = 0,
		Price = 249,
		Order = 102,
		Shop = "Weapon",
	},
	SkinGolden = {
		Key = "SkinGolden",
		Name = "Golden skin",
		Description = "Makes any weapon gold. Looks only.",
		GamePassId = 0,
		Price = 99,
		Order = 111,
		Shop = "Skin",
	},
	SkinLava = {
		Key = "SkinLava",
		Name = "Lava skin",
		Description = "Makes any weapon glow like lava. Looks only.",
		GamePassId = 0,
		Price = 99,
		Order = 112,
		Shop = "Skin",
	},
	SkinCrystal = {
		Key = "SkinCrystal",
		Name = "Crystal skin",
		Description = "Makes any weapon crystal. Looks only.",
		GamePassId = 0,
		Price = 99,
		Order = 113,
		Shop = "Skin",
	},
	SkinRainbow = {
		Key = "SkinRainbow",
		Name = "Rainbow skin",
		Description = "Makes any weapon shimmer. Looks only.",
		GamePassId = 0,
		Price = 149,
		Order = 114,
		Shop = "Skin",
	},
}

-- Effects, read by the services. Keep numbers here so they're easy to tune.
local Effects = {
	CoinMultiplier = 2, -- DoubleCoins
	StrengthMultiplier = 2, -- DoubleStrength
	LuckMultiplier = 1.5, -- LuckyShovel
	IncubationSpeed = 2, -- FastIncubator
	ExtraPedestals = 6, -- ExtraPedestals
	SpeedMultiplier = 1.25, -- SpeedyBoots
	VIPCoinMultiplier = 1.1, -- VIP
	FortressLockSeconds = 180, -- FortressGate
}

local Module = {}
Module.ByKey = Passes
Module.Effects = Effects

-- Passes for the Passes menu (weapons and skins are listed in the Shop instead).
function Module.Sorted(): { Pass }
	local list = {}
	for _, pass in Passes do
		if not pass.Shop then
			table.insert(list, pass)
		end
	end
	table.sort(list, function(a, b)
		return a.Order < b.Order
	end)
	return list
end

function Module.AttributeName(key: string): string
	return "Pass_" .. key
end

return Module
