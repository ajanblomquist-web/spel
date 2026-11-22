-- TrainingController.luau
-- TRAIN button near the rock, plus Auto Train for pass owners.
-- Standing at the rock also trains you for free at half speed (the server does
-- it); this shows a floater for those reps too.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local FormatNumber = require(ReplicatedStorage.Shared.Util.FormatNumber)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

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

local function rep(auto: boolean?)
	local now = os.clock()
	if now - lastRep < Balance.TrainCooldown then
		return
	end
	lastRep = now
	Remotes.Get("Train"):FireServer(if auto then { auto = true } else nil)
end

function TrainingController.Start(Controllers)
	UIController = Controllers.UIController

	UIController.RegisterAction(40, function()
		if not nearRock() then
			return nil
		end
		local idle = os.clock() - lastRep > 1
		return {
			Text = if idle then "AUTO TRAINING\nTap for 2x!" else "TRAIN",
			Color = Color3.fromRGB(255, 120, 80),
			Callback = function()
				rep(false)
			end,
		}
	end)

	-- Auto Train pass: full speed, anywhere.
	task.spawn(function()
		while true do
			task.wait(Balance.TrainCooldown + 0.02)
			if UIController.AutoState.AutoTrain and UIController.OwnsPass("AutoTrain") then
				rep(true)
			end
		end
	end)

	-- A "+Str" floater for every rep (tapped, auto or free AFK).
	local lastStrength = player:GetAttribute("Strength") or 0
	player:GetAttributeChangedSignal("Strength"):Connect(function()
		local strength = player:GetAttribute("Strength") or 0
		local gain = strength - lastStrength
		lastStrength = strength
		if gain > 0 then
			UIController.Floater("+" .. FormatNumber(gain) .. " Str")
		end
	end)
end

return TrainingController
