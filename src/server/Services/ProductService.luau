-- ProductService.luau
-- Developer products sold in the Shop's Robux sections (see Config/Products):
-- the Rare Egg, boost potions, Server Luck, Instant Hatch and the coin packs.
-- The Starter Pack has its own service.

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
	local BoostService = Services.BoostService

	MonetizationService.OnProduct("RareEgg", function(player)
		local egg = { Id = DataService.NewId(), Rarity = "Rare", Size = "Normal", Mutation = "None" }
		NestService.GiveEgg(player, egg)
		Notify.Player(player, "Rare Egg bought! Enjoy your new dino!", "epic")
	end)

	for _, product in Products.List do
		if product.Boost then
			MonetizationService.OnProduct(product.Key, function(player)
				BoostService.Add(player, product.Boost, product.Seconds)
				Notify.Player(
					player,
					BoostService.Describe(product.Boost, product.Seconds) .. "! Thanks!",
					"epic"
				)
			end)
		elseif product.ServerBoost then
			MonetizationService.OnProduct(product.Key, function(player)
				BoostService.AddServer(product.ServerBoost, product.Seconds)
				Notify.All(
					player.DisplayName .. " bought SERVER LUCK! 2x luck for everyone for 10 min!",
					"epic"
				)
			end)
		elseif product.MaxSeconds then
			MonetizationService.OnProduct(product.Key, function(player)
				local count = NestService.SkipTime(player, product.MaxSeconds)
				if count == 0 then
					-- Bought with nothing incubating (the Shop hides the row then):
					-- don't waste it.
					local coins = Products.CoinPackAmount(Products.Coins5h, IncomeService.Total(player))
					DataService.AddCoins(player, coins)
					Notify.Player(
						player,
						"No eggs were incubating, so here's +" .. FormatNumber(coins) .. " coins!",
						"good"
					)
				else
					Notify.Player(player, "Instant Hatch! Your eggs are hatching!", "epic")
				end
			end)
		elseif product.Hours then
			MonetizationService.OnProduct(product.Key, function(player)
				local coins = Products.CoinPackAmount(product, IncomeService.Total(player))
				DataService.AddCoins(player, coins)
				Notify.Player(player, "+" .. FormatNumber(coins) .. " coins! Thanks!", "epic")
			end)
		end
	end
end

return ProductService
