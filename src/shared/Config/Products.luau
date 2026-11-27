-- Products.luau
-- Developer products (can be bought more than once, or once if OneTime).
-- Create them in Creator Hub (your experience > Monetization > Developer
-- Products) and paste each ID into ProductId. ID 0 = not set up yet; in Studio
-- the "Test buy" button grants it without Robux.
--
-- Nothing here is a hidden roll: every product says exactly what it gives. The
-- Rare Egg is the only paid random item: it lists the dinos it can hatch and
-- their odds, and it is hidden for players where PolicyService restricts paid
-- random items. The Starter Pack's egg is always the same dino.
--
-- Boost potions add 15 minutes to your own 2x boost. Server Luck gives 2x luck
-- to everyone in the server (on top of their own boosts). Instant Hatch comes in
-- three sizes: the Shop offers the smallest one that covers your longest egg;
-- each one takes up to MaxSeconds off every egg in your incubators.
--
-- Coin packs give a number of hours of your current income (what your dinos
-- earn per second right now), with a minimum so new players still get a lot.

local Dinos = require(script.Parent.Dinos)

local Products = {}

Products.CoinPackMinimumPerHour = 2500

-- Coins a coin pack gives at this income per second.
function Products.CoinPackAmount(product, incomePerSecond: number): number
	local perHour = math.max(incomePerSecond * 3600, Products.CoinPackMinimumPerHour)
	return math.floor(perHour * product.Hours)
end

-- "Triceratops or Ankylosaurus, 50% each" for the Rare Egg row.
local function rareEggText(): string
	local names = {}
	for _, dino in Dinos.Pool("Rare", nil) do
		table.insert(names, dino.Name)
	end
	local odds = math.floor(100 / math.max(#names, 1))
	local list = if #names <= 1
		then table.concat(names)
		else table.concat(names, ", ", 1, #names - 1) .. " or " .. names[#names]
	return list .. ", " .. odds .. "% each"
end

-- The dino in the Starter Pack's egg (always the same one, so it isn't a roll).
Products.StarterPackDinoId = Dinos.Pool("Rare", nil)[1].Id
local starterDinoName = Dinos.Pool("Rare", nil)[1].Name

Products.List = {
	{
		Key = "StarterPack",
		Name = "Starter Pack",
		Description = "2x Coins for 30 min, a Rare " .. starterDinoName .. " egg and 1,000 coins.",
		ProductId = 0,
		Price = 99,
		OneTime = true,
	},
	{
		Key = "RareEgg",
		Name = "Rare Egg",
		Description = rareEggText(),
		ProductId = 0,
		Price = 49,
	},
	{
		Key = "LuckPotion",
		Name = "2x Luck potion",
		Description = "2x luck on every dig for 15 min. Adds to time you already have.",
		Boost = "Luck",
		Seconds = 15 * 60,
		ProductId = 0,
		Price = 79,
	},
	{
		Key = "CoinsPotion",
		Name = "2x Coins potion",
		Description = "2x dino income for 15 min. Adds to time you already have.",
		Boost = "Coins",
		Seconds = 15 * 60,
		ProductId = 0,
		Price = 79,
	},
	{
		Key = "StrengthPotion",
		Name = "2x Strength potion",
		Description = "2x Strength per rep for 15 min. Adds to time you already have.",
		Boost = "Strength",
		Seconds = 15 * 60,
		ProductId = 0,
		Price = 49,
	},
	{
		Key = "ServerLuck",
		Name = "Server Luck",
		Description = "2x luck for EVERYONE in this server for 10 min. Everyone sees who bought it!",
		ServerBoost = "Luck",
		Seconds = 10 * 60,
		ProductId = 0,
		Price = 199,
	},
	{
		Key = "InstantHatch5",
		Name = "Instant Hatch",
		MaxSeconds = 5 * 60,
		ProductId = 0,
		Price = 19,
	},
	{
		Key = "InstantHatch30",
		Name = "Instant Hatch",
		MaxSeconds = 30 * 60,
		ProductId = 0,
		Price = 49,
	},
	{
		Key = "InstantHatchAll",
		Name = "Instant Hatch",
		MaxSeconds = math.huge,
		ProductId = 0,
		Price = 99,
	},
	{
		Key = "Coins5h",
		Name = "5 hours of coins",
		Hours = 5,
		ProductId = 0,
		Price = 99,
	},
	{
		Key = "Coins10h",
		Name = "10 hours of coins",
		Hours = 10,
		ProductId = 0,
		Price = 179,
	},
	{
		Key = "Coins24h",
		Name = "24 hours of coins",
		Hours = 24,
		ProductId = 0,
		Price = 349,
	},
}

for _, product in Products.List do
	Products[product.Key] = product
end

-- The smallest Instant Hatch that finishes an egg with this many seconds left.
function Products.InstantHatchFor(secondsLeft: number)
	for _, key in { "InstantHatch5", "InstantHatch30", "InstantHatchAll" } do
		if secondsLeft <= Products[key].MaxSeconds then
			return Products[key]
		end
	end
	return Products.InstantHatchAll
end

return Products
