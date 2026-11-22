-- TrainingController.luau
-- TRAIN button near the rock, plus Auto Train for pass owners.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local FormatNumber = require(ReplicatedStorage.Shared.Util.FormatNumber)
local Passes = require(ReplicatedStorage.Shared.Config.Passes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)

local player = Players.LocalPlayer

local TrainingController = {}

local UIController
local lastRep = 0

local function nearRock(): boolean
	local map = Workspace:FindFirstChild("Map")
	local rock = map and map:FindFirstChild("TrainingRock") :: BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return rock ~= nil and root ~= nil and (root.Position - rock.Position).Magnitude <= Balance.TrainRange + 4
end

local function rep()
	local now = os.clock()
	if now - lastRep < Balance.TrainCooldown then
		return
	end
	lastRep = now
	Remotes.Get("Train"):FireServer()

	local rock = Shop.Rocks[player:GetAttribute("RockTier") or 1] or Shop.Rocks[1]
	local gain = rock.StrengthPerRep
	if UIController.OwnsPass("DoubleStrength") then
		gain *= Passes.Effects.StrengthMultiplier
	end
	UIController.Floater("+" .. FormatNumber(gain) .. " Str")
end

function TrainingController.Start(Controllers)
	UIController = Controllers.UIController

	UIController.RegisterAction(40, function()
		if not nearRock() then
			return nil
		end
		return { Text = "TRAIN", Color = Color3.fromRGB(255, 120, 80), Callback = rep }
	end)

	task.spawn(function()
		while true do
			task.wait(Balance.TrainCooldown + 0.02)
			if UIController.AutoState.AutoTrain and UIController.OwnsPass("AutoTrain") and nearRock() then
				rep()
			end
		end
	end)
end

return TrainingController
