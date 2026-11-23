-- ProductService.luau
-- Developer products sold in the Shop's Robux sections (see Config/Products):
-- the Rare Egg and the coin packs. The Starter Pack has its own service.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FormatNumber = require(ReplicatedStorage.Shared.Util.FormatNumber)
local Products = require(ReplicatedStorage.Shared.Config.Products)
local Notify = require(script.Parent.Parent.Notify)

local ProductService = {}

function ProductService.Init(Services)
	local DataService = Services.DataService
	local MonetizationService = Services.MonetizationService
	local NestService = Services.NestService
	local IncomeService = Services.IncomeService

	MonetizationService.OnProduct("RareEgg", function(player)
		local egg = { Id = DataService.NewId(), Rarity = "Rare", Size = "Normal", Mutation = "None" }
		NestService.GiveEgg(player, egg)
		Notify.Player(player, "Rare Egg bought! Enjoy your new dino!", "epic")
	end)

	for _, product in Products.List do
		if product.Hours then
			MonetizationService.OnProduct(product.Key, function(player)
				local coins = Products.CoinPackAmount(product, IncomeService.Total(player))
				DataService.AddCoins(player, coins)
				Notify.Player(player, "+" .. FormatNumber(coins) .. " coins! Thanks!", "epic")
			end)
		end
	end
end

return ProductService
