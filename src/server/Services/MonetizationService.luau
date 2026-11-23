-- MonetizationService.luau
-- Tracks which game passes each player owns and tells other services when that
-- changes (e.g. right after a purchase, so the effect applies instantly).
--
-- Ownership is mirrored to the player as attributes ("Pass_DoubleCoins" = true)
-- so the client UI can show "Owned" and enable the auto toggles.
--
-- Developer products (Config/Products) go through ProcessReceipt. Each purchase
-- ID is remembered in the player's data so a product is never granted twice.
-- Nothing here sells a random roll.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Passes = require(ReplicatedStorage.Shared.Config.Passes)
local Products = require(ReplicatedStorage.Shared.Config.Products)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Notify = require(script.Parent.Parent.Notify)

local MonetizationService = {}

local owned: { [Player]: { [string]: boolean } } = {}
local changedCallbacks = {}
local productHandlers: { [string]: (Player, any) -> () } = {}
local DataService

local function setOwned(player: Player, key: string, value: boolean)
	owned[player] = owned[player] or {}
	if owned[player][key] == value then
		return
	end
	owned[player][key] = value
	player:SetAttribute(Passes.AttributeName(key), value)
	for _, callback in changedCallbacks do
		task.spawn(callback, player, key, value)
	end
end

local function passKeyForId(passId: number): string?
	for key, pass in Passes.ByKey do
		if pass.GamePassId == passId and passId ~= 0 then
			return key
		end
	end
	return nil
end

function MonetizationService.Has(player: Player, key: string): boolean
	local list = owned[player]
	return list ~= nil and list[key] == true
end

-- callback(player, passKey, ownsIt) after a pass is bought (or toggled in Studio).
function MonetizationService.OnPassChanged(callback: (Player, string, boolean) -> ())
	table.insert(changedCallbacks, callback)
end

-- handler(player, data) gives the player what they bought.
function MonetizationService.OnProduct(key: string, handler: (Player, any) -> ())
	productHandlers[key] = handler
end

local function productKeyForId(productId: number): string?
	for _, product in Products.List do
		if product.ProductId == productId and productId ~= 0 then
			return product.Key
		end
	end
	return nil
end

-- Returns true once the product has been given (or was given before).
local function grantProduct(player: Player, key: string, purchaseId: string?): boolean
	local data = DataService.Get(player)
	local handler = productHandlers[key]
	if not data or not handler then
		return false
	end
	if purchaseId and data.Purchases[purchaseId] then
		return true
	end
	local ok, err = pcall(handler, player, data)
	if not ok then
		warn("[MonetizationService] Product " .. key .. " failed: " .. tostring(err))
		return false
	end
	if purchaseId then
		data.Purchases[purchaseId] = true
	end
	DataService.SaveNow(player)
	return true
end

function MonetizationService.Init(Services)
	DataService = Services.DataService
	-- Check passes before the other services set up the player, so things like
	-- extra pedestals and offline income already know what the player owns.
	Services.DataService.OnLoaded(function(player)
		owned[player] = {}
		for key, pass in Passes.ByKey do
			local has = false
			if pass.GamePassId ~= 0 then
				local ok, result = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.GamePassId)
				end)
				has = ok and result == true
			end
			owned[player][key] = has
			player:SetAttribute(Passes.AttributeName(key), has)
		end
	end)
end

function MonetizationService.Start()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local key = passKeyForId(passId)
		if key then
			setOwned(player, key, true)
			Notify.Player(player, "Thanks! " .. Passes.ByKey[key].Name .. " is now active.", "epic")
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
	end)

	MarketplaceService.ProcessReceipt = function(info)
		local player = Players:GetPlayerByUserId(info.PlayerId)
		local key = productKeyForId(info.ProductId)
		if not player or not key then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if grantProduct(player, key, info.PurchaseId) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Studio-only: test a developer product without Robux.
	Remotes.Get("StudioBuyProduct").OnServerEvent:Connect(function(player, key)
		if RunService:IsStudio() and type(key) == "string" and productHandlers[key] then
			grantProduct(player, key, nil)
		end
	end)

	-- Studio-only test switch so you can try every pass without buying it.
	Remotes.Get("StudioSetPass").OnServerEvent:Connect(function(player, key, value)
		if not RunService:IsStudio() then
			return
		end
		if type(key) ~= "string" or not Passes.ByKey[key] or type(value) ~= "boolean" then
			return
		end
		setOwned(player, key, value)
		Notify.Player(
			player,
			"[Studio] " .. Passes.ByKey[key].Name .. (if value then " ON" else " OFF"),
			"info"
		)
	end)
end

return MonetizationService
