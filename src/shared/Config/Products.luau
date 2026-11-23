-- Products.luau
-- Developer products (can be bought more than once, or once if OneTime).
-- Create them in Creator Hub (your experience > Monetization > Developer
-- Products) and paste each ID into ProductId. ID 0 = not set up yet; in Studio
-- the "Test buy" button grants it without Robux.
--
-- Nothing here is a hidden roll: every product says exactly what it gives. The
-- Rare Egg lists the dinos it can hatch and their odds.
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

Products.List = {
	{
		Key = "StarterPack",
		Name = "Starter Pack",
		Description = "2x Coins for 30 min, a Rare egg and 1,000 coins.",
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

return Products
