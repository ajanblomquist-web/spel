-- DailyService.luau
-- Daily login streak (see Config/Daily). Days are UTC days. On join the client
-- gets the streak state and shows the claim popup if today's reward is ready.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Daily = require(ReplicatedStorage.Shared.Config.Daily)
local Notify = require(script.Parent.Parent.Notify)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local DailyService = {}

local DataService, GiftService

local function today(): number
	return math.floor(os.time() / 86400)
end

-- The streak you'd have after claiming today, and the reward index (1-7).
local function nextClaim(data): (number, number)
	local streak = if data.Daily.LastDay == today() - 1 then data.Daily.Streak + 1 else 1
	return streak, ((streak - 1) % #Daily) + 1
end

local function publish(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local ready = data.Daily.LastDay ~= today()
	local streak, index = nextClaim(data)
	if not ready then
		streak = data.Daily.Streak
		index = ((streak - 1) % #Daily) + 1
	end
	player:SetAttribute("DailyReady", ready)
	player:SetAttribute("DailyStreak", streak)
	player:SetAttribute("DailyIndex", index)
end

local function claim(player: Player)
	local data = DataService.Get(player)
	if not data or data.Daily.LastDay == today() then
		return
	end
	local streak, index = nextClaim(data)
	data.Daily.Streak = streak
	data.Daily.LastDay = today()
	local text = GiftService.Grant(player, Daily[index].Reward)
	DataService.SaveNow(player)
	publish(player)
	Remotes.Get("Celebrate"):FireClient(player, "Daily", { Day = index, Streak = streak, Text = text })
	Notify.Player(player, "Day " .. streak .. " streak! You got " .. text, "good")
end

function DailyService.Init(Services)
	DataService = Services.DataService
	GiftService = Services.GiftService
	DataService.OnLoaded(function(player)
		publish(player)
	end)
end

function DailyService.Start()
	Remotes.Get("ClaimDaily").OnServerEvent:Connect(claim)
	-- Catch the day rolling over for players who stay online past midnight UTC.
	while true do
		task.wait(60)
		for _, player in DataService.LoadedPlayers() do
			publish(player)
		end
	end
end

return DailyService
