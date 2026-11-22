-- TrainingService.luau
-- Each rep at the training rock adds Strength. More Strength = longer flings.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Passes = require(ReplicatedStorage.Shared.Config.Passes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Events = require(script.Parent.Parent.Events)

local TrainingService = {}

local DataService, MapService, MonetizationService, BoostService
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
end

function TrainingService.Start()
	Remotes.Get("Train").OnServerEvent:Connect(function(player)
		local data = DataService.Get(player)
		if not data then
			return
		end
		local now = os.clock()
		-- 0.85 allows for network jitter between taps.
		if lastRep[player] and now - lastRep[player] < Balance.TrainCooldown * 0.85 then
			return
		end
		if not isNearRock(player) then
			return
		end
		lastRep[player] = now

		local rock = Shop.Rocks[data.RockTier] or Shop.Rocks[1]
		local gain = rock.StrengthPerRep
		if MonetizationService.Has(player, "DoubleStrength") then
			gain *= Passes.Effects.StrengthMultiplier
		end
		gain *= BoostService.Multiplier(player, "Strength")
		DataService.Increment(player, "Strength", gain)
		Events.Fire("TrainRep", player, gain)
	end)

	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastRep[player] = nil
	end)
end

return TrainingService
