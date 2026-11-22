-- TrainingService.luau
-- Each rep at the training rock adds Strength. More Strength = longer flings.
--
-- Free AFK: standing at the rock trains you by itself at half speed (every
-- Balance.FreeAutoTrainSeconds). Tapping TRAIN is full speed. The Auto Train
-- pass trains at full speed from anywhere.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Passes = require(ReplicatedStorage.Shared.Config.Passes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Events = require(script.Parent.Parent.Events)

local TrainingService = {}

local DataService, MapService, MonetizationService, BoostService, RebirthService, EventService
local lastRep: { [Player]: number } = {}

local function isNearRock(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	-- +4 for the rock's radius, +2 slack for lag.
	return (root.Position - MapService.TrainingRockPosition).Magnitude <= Balance.TrainRange + 6
end

function TrainingService.Init(Services)
	DataService = Services.DataService
	MapService = Services.MapService
	MonetizationService = Services.MonetizationService
	BoostService = Services.BoostService
	RebirthService = Services.RebirthService
	EventService = Services.EventService
end

local function doRep(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	lastRep[player] = os.clock()
	local rock = Shop.Rocks[data.RockTier] or Shop.Rocks[1]
	local gain = rock.StrengthPerRep
	if MonetizationService.Has(player, "DoubleStrength") then
		gain *= Passes.Effects.StrengthMultiplier
	end
	gain *= BoostService.Multiplier(player, "Strength")
	gain *= RebirthService.Multiplier(player, "Strength")
	gain *= EventService.Multiplier("Strength")
	DataService.Increment(player, "Strength", gain)
	Events.Fire("TrainRep", player, gain)
end

function TrainingService.Start()
	Remotes.Get("Train").OnServerEvent:Connect(function(player, options)
		local now = os.clock()
		-- 0.85 allows for network jitter between taps.
		if lastRep[player] and now - lastRep[player] < Balance.TrainCooldown * 0.85 then
			return
		end
		local auto = type(options) == "table" and options.auto == true
		local allowed = isNearRock(player) or (auto and MonetizationService.Has(player, "AutoTrain"))
		if allowed then
			doRep(player)
		end
	end)

	-- Free AFK training at the rock.
	task.spawn(function()
		while true do
			task.wait(0.1)
			local now = os.clock()
			for _, player in DataService.LoadedPlayers() do
				local last = lastRep[player] or 0
				if now - last >= Balance.FreeAutoTrainSeconds and isNearRock(player) then
					doRep(player)
				end
			end
		end
	end)

	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastRep[player] = nil
	end)
end

return TrainingService
