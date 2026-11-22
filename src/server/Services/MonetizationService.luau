-- MonetizationService.luau
-- Tracks which game passes each player owns and tells other services when that
-- changes (e.g. right after a purchase, so the effect applies instantly).
--
-- Ownership is mirrored to the player as attributes ("Pass_DoubleCoins" = true)
-- so the client UI can show "Owned" and enable the auto toggles.
--
-- Developer products (boost potions, Instant Hatch) come in milestone 3 with a
-- ProcessReceipt handler. Nothing here sells a random roll.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Passes = require(ReplicatedStorage.Shared.Config.Passes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Notify = require(script.Parent.Parent.Notify)

local MonetizationService = {}

local owned: { [Player]: { [string]: boolean } } = {}
local changedCallbacks = {}

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

function MonetizationService.Init(Services)
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
