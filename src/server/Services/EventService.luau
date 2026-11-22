-- EventService.luau
-- Server-wide events (see Config/WorldEvents): one automatic event at the
-- start of every hour, the same on every server, plus owner chat commands
-- (/event <Id>, /event stop) that start an event on every server.
--
-- Other services ask EventService.Multiplier("Luck" | "Coins" | "Strength" |
-- "Mutation" | "Baby"). Clients read the EventId / EventEndsAt attributes on
-- Workspace for the timer pill.

local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local WorldEvents = require(ReplicatedStorage.Shared.Config.WorldEvents)
local Notify = require(script.Parent.Parent.Notify)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local EventService = {}

local TOPIC = "WorldEvent"

local manual: { Id: string?, EndsAt: number }? = nil -- set by /event, unix time
local activeKey: string? = nil

-- The event running right now and its end (unix time), or nil.
local function current(): (any, number?)
	local now = os.time()
	if manual and now < manual.EndsAt then
		if manual.Id == nil then
			return nil, nil -- "/event stop" pauses the automatic ones too
		end
		return WorldEvents.ById[manual.Id], manual.EndsAt
	end
	local slot = math.floor(now / WorldEvents.EverySeconds)
	local into = now % WorldEvents.EverySeconds
	if into < WorldEvents.DurationSeconds then
		local event = WorldEvents.List[(slot % #WorldEvents.List) + 1]
		return event, slot * WorldEvents.EverySeconds + WorldEvents.DurationSeconds
	end
	return nil, nil
end

function EventService.Active(): any
	local event = current()
	return event
end

function EventService.Multiplier(effect: string): number
	local event = current()
	if event and event.Effect == effect then
		return event.Multiplier
	end
	return 1
end

local function apply(id: string?, seconds: number)
	manual = { Id = id, EndsAt = os.time() + seconds }
end

local function isOwner(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if game.CreatorType == Enum.CreatorType.Group then
		local ok, rank = pcall(function()
			return player:GetRankInGroup(game.CreatorId)
		end)
		return ok and rank == 255
	end
	return player.UserId == game.CreatorId
end

local function onChat(player: Player, message: string)
	local command, arg = string.match(message, "^/event%s+(%S+)%s*(%S*)")
	if not command or not isOwner(player) then
		return
	end
	local id: string? = nil
	local seconds = WorldEvents.DurationSeconds
	if string.lower(command) == "stop" then
		seconds = 60 -- pause events for a minute
	else
		for _, event in WorldEvents.List do
			if string.lower(event.Id) == string.lower(command) then
				id = event.Id
			end
		end
		if not id then
			Notify.Player(
				player,
				"Unknown event. Try: DoubleLuck, DoubleCoins, GoldenHour, BabyBoom, StrengthSurge",
				"bad"
			)
			return
		end
		local minutes = tonumber(arg)
		if minutes then
			seconds = math.clamp(minutes, 1, 120) * 60
		end
	end
	apply(id, seconds)
	-- Tell every other server too.
	pcall(function()
		MessagingService:PublishAsync(TOPIC, { Id = id or "", Seconds = seconds })
	end)
end

function EventService.Init() end

function EventService.Start()
	pcall(function()
		MessagingService:SubscribeAsync(TOPIC, function(message)
			local data = message.Data
			if type(data) == "table" and type(data.Seconds) == "number" then
				apply(if data.Id == "" then nil else data.Id, data.Seconds)
			end
		end)
	end)

	local function onPlayer(player: Player)
		player.Chatted:Connect(function(message)
			onChat(player, message)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	while true do
		local event, endsAt = current()
		local key = if event then event.Id .. ":" .. tostring(endsAt) else nil
		if key ~= activeKey then
			activeKey = key
			if event and endsAt then
				Workspace:SetAttribute("EventId", event.Id)
				Workspace:SetAttribute("EventEndsAt", Workspace:GetServerTimeNow() + (endsAt - os.time()))
				Remotes.Get("Celebrate"):FireAllClients("Event", {
					Name = event.Name,
					Text = WorldEvents.Describe(event),
				})
			else
				Workspace:SetAttribute("EventId", nil)
				Workspace:SetAttribute("EventEndsAt", nil)
			end
		end
		task.wait(1)
	end
end

return EventService
