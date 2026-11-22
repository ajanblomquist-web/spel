-- BoostService.luau
-- Timed 2x boosts ("Luck", "Coins", "Strength") from quests, playtime gifts
-- and the Starter Pack. End times are real clock times, so they also run
-- out while you're offline. The client shows them from Boost_<name> attributes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Notify = require(script.Parent.Parent.Notify)

local BoostService = {}

local DataService

local NAMES = { "Luck", "Coins", "Strength" }

local function publish(player: Player, name: string)
	local data = DataService.Get(player)
	local endsAt = data and data.Boosts[name]
	if endsAt and endsAt > os.time() then
		player:SetAttribute("Boost_" .. name, Workspace:GetServerTimeNow() + (endsAt - os.time()))
	else
		player:SetAttribute("Boost_" .. name, nil)
	end
end

function BoostService.IsActive(player: Player, name: string): boolean
	local data = DataService.Get(player)
	local endsAt = data and data.Boosts[name]
	return endsAt ~= nil and endsAt > os.time()
end

-- 2 while the boost runs, otherwise 1.
function BoostService.Multiplier(player: Player, name: string): number
	return if BoostService.IsActive(player, name) then Balance.BoostMultiplier else 1
end

-- Adds time to a boost (stacks on top of time already left).
function BoostService.Add(player: Player, name: string, seconds: number)
	local data = DataService.Get(player)
	if not data or not table.find(NAMES, name) then
		return
	end
	local now = os.time()
	data.Boosts[name] = math.max(data.Boosts[name] or 0, now) + seconds
	publish(player, name)
end

function BoostService.Describe(name: string, seconds: number): string
	local minutes = math.floor(seconds / 60)
	return "2x " .. name .. " for " .. (if minutes >= 1 then minutes .. " min" else seconds .. " s")
end

function BoostService.Init(Services)
	DataService = Services.DataService
	DataService.OnLoaded(function(player)
		for _, name in NAMES do
			publish(player, name)
		end
	end)
end

function BoostService.Start()
	-- Clear finished boosts so the UI timer disappears.
	while true do
		task.wait(1)
		for _, player in DataService.LoadedPlayers() do
			for _, name in NAMES do
				if player:GetAttribute("Boost_" .. name) and not BoostService.IsActive(player, name) then
					player:SetAttribute("Boost_" .. name, nil)
					Notify.Player(player, "Your 2x " .. name .. " boost ended.", "info")
				end
			end
		end
	end
end

return BoostService
