-- FlingService.luau
-- The launch pad: timing meter -> distance -> zone and luck -> dig spot.
--
-- The client shows the meter and tells us where the player tapped. The server
-- also tracks the time since the meter started, works out where the needle
-- should be, and ignores the client's value if it's too far off (anti-cheat).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Meter = require(ReplicatedStorage.Shared.Meter)
local Passes = require(ReplicatedStorage.Shared.Config.Passes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Events = require(script.Parent.Parent.Events)
local Notify = require(script.Parent.Parent.Notify)

local FlingService = {}

local DataService, MapService, MonetizationService, CarryService, BoostService, NestService

local sessions: { [Player]: number } = {} -- player -> os.clock() when the meter started
local lastFling: { [Player]: number } = {}
local perfectStreak: { [Player]: number } = {}
local rng = Random.new()

local function nearPad(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local offset = root.Position - MapService.PadPosition
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= Balance.FlingRange + 2
end

local function canFling(player: Player): boolean
	if not DataService.IsLoaded(player) or CarryService.IsCarrying(player) then
		return false
	end
	if lastFling[player] and os.clock() - lastFling[player] < Balance.FlingCooldown then
		return false
	end
	return nearPad(player)
end

-- Pure maths, handy to tweak: how far a fling goes.
function FlingService.Distance(strength: number, shovelPower: number, timingMultiplier: number): number
	local raw = (Balance.BaseDistance + Balance.StrengthScale * math.sqrt(math.max(strength, 0)))
		* shovelPower
		* timingMultiplier
	return math.clamp(raw, 8, Zones.MaxDistance - 6)
end

-- Auto Fling's dino drone: digs the egg and flies it straight into a free
-- incubator. Returns false (so a normal dig spot is made) if the nest is full.
local function droneDelivery(player: Player, luck: number, zoneId: string): boolean
	local data = DataService.Get(player)
	if not data or #data.Incubating >= Balance.IncubatorSlots then
		return false
	end
	local egg = CarryService.RollEgg(player, luck, zoneId)
	if not NestService.TryAddEgg(player, egg) then
		return false
	end
	data.Stats.EggsDug += 1
	Events.Fire("Dig", player, egg)
	Events.Fire("Deliver", player, egg)
	Notify.Player(player, "Your dino drone brought home a " .. string.upper(egg.Rarity) .. " egg!", "good")
	return true
end

local function resolve(player: Player, meterValue: number, auto: boolean?)
	local data = DataService.Get(player)
	if not data then
		return
	end
	lastFling[player] = os.clock()

	local shovel = Shop.Shovels[data.ShovelTier] or Shop.Shovels[1]
	local timing, grade = Meter.TimingMultiplier(meterValue)
	local perfect = grade == "Perfect"
	-- Perfects in a row stack a bonus; anything else resets the streak.
	local streak = if perfect then (perfectStreak[player] or 0) + 1 else 0
	perfectStreak[player] = streak
	if perfect then
		timing *= 1 + math.min(streak - 1, Balance.PerfectStreakMax) * Balance.PerfectStreakBonus
	end
	local distance = FlingService.Distance(data.Strength, shovel.Power, timing)
	local zone = Zones.ForDistance(distance)

	local luck = zone.Luck * shovel.Luck
	if MonetizationService.Has(player, "LuckyShovel") then
		luck *= Passes.Effects.LuckMultiplier
	end
	luck *= BoostService.Multiplier(player, "Luck")

	-- First time reaching a zone gets a NEW ZONE banner (the first zone doesn't count).
	local newZone = zone.StartDistance > 0 and not data.ZonesReached[zone.Id]
	data.ZonesReached[zone.Id] = true

	local halfWidth = MapService.CanyonWidth / 2 - 12
	local origin = MapService.LaunchOrigin
	local landing = Vector3.new(origin.X + rng:NextNumber(-halfWidth, halfWidth), 0, origin.Z + distance)
	local from = MapService.PadPosition + Vector3.new(0, 4, 0)

	data.Stats.Flings += 1
	if distance > data.Stats.BestDistance then
		data.Stats.BestDistance = math.floor(distance)
	end

	-- Everyone sees the shovel fly; the flinger's camera follows it.
	Remotes.Get("FlingResult"):FireAllClients({
		UserId = player.UserId,
		From = from,
		To = landing,
		Duration = Balance.FlightSeconds,
		Distance = math.floor(distance),
		ZoneName = zone.Name,
		Luck = luck,
		Perfect = perfect,
		Grade = grade,
		Streak = streak,
		ShovelTier = data.ShovelTier,
		NewZone = newZone,
		ZoneLuck = zone.Luck,
	})
	Events.Fire("Fling", player, distance, zone.Id, grade)

	local zoneId = zone.Id
	task.delay(Balance.FlightSeconds, function()
		if player.Parent ~= Players then
			return
		end
		if auto and MonetizationService.Has(player, "AutoFling") and droneDelivery(player, luck, zoneId) then
			return
		end
		if not CarryService.IsCarrying(player) then
			CarryService.CreateDigSpot(player, landing, zoneId, luck)
		end
	end)
end

function FlingService.Init(Services)
	DataService = Services.DataService
	MapService = Services.MapService
	MonetizationService = Services.MonetizationService
	CarryService = Services.CarryService
	BoostService = Services.BoostService
	NestService = Services.NestService
end

function FlingService.Start()
	Remotes.Get("StartFling").OnServerEvent:Connect(function(player, options)
		if not canFling(player) then
			return
		end
		if type(options) == "table" and options.auto == true then
			if MonetizationService.Has(player, "AutoFling") then
				sessions[player] = nil
				resolve(player, Balance.AutoFlingTiming, true)
			end
			return
		end
		sessions[player] = os.clock()
	end)

	Remotes.Get("StopFling").OnServerEvent:Connect(function(player, clientValue)
		local started = sessions[player]
		sessions[player] = nil
		if not started or not canFling(player) then
			return
		end
		local elapsed = os.clock() - started
		if elapsed > 15 then
			return
		end
		local serverValue = Meter.ValueAt(elapsed)
		local value = serverValue
		if type(clientValue) == "number" and clientValue == clientValue then
			clientValue = math.clamp(clientValue, 0, 1)
			if math.abs(clientValue - serverValue) <= Balance.MeterTolerance then
				value = clientValue
			end
		end
		resolve(player, value)
	end)

	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
		lastFling[player] = nil
		perfectStreak[player] = nil
	end)
end

return FlingService
