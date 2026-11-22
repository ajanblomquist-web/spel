-- ShopService.luau
-- Buy the next tier of training rock or shovel with coins.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FormatNumber = require(ReplicatedStorage.Shared.Util.FormatNumber)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Notify = require(script.Parent.Parent.Notify)

local ShopService = {}

local DataService

local CATEGORIES = {
	Rocks = { List = Shop.Rocks, Field = "RockTier" },
	Shovels = { List = Shop.Shovels, Field = "ShovelTier" },
}

function ShopService.Init(Services)
	DataService = Services.DataService
end

function ShopService.Start()
	Remotes.Get("BuyUpgrade").OnServerEvent:Connect(function(player, categoryName, tier)
		local category = CATEGORIES[categoryName]
		local data = DataService.Get(player)
		if not category or not data or type(tier) ~= "number" then
			return
		end
		local current = data[category.Field]
		if tier ~= current + 1 then
			return -- buy tiers in order
		end
		local item = category.List[tier]
		if not item then
			return
		end
		if not DataService.SpendCoins(player, item.Price) then
			Notify.Player(
				player,
				"You need " .. FormatNumber(item.Price - data.Coins) .. " more coins.",
				"bad"
			)
			return
		end
		DataService.Set(player, category.Field, tier)
		Notify.Player(player, "Unlocked " .. item.Name .. "!", "good")
	end)
end

return ShopService
