-- MovementService.luau
-- Sets each player's walk speed from: base speed, Speedy Boots pass, and
-- whether they're carrying an egg.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Passes = require(ReplicatedStorage.Shared.Config.Passes)

local MovementService = {}

local MonetizationService

function MovementService.Refresh(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local speed = Balance.WalkSpeed
	if MonetizationService.Has(player, "SpeedyBoots") then
		speed *= Passes.Effects.SpeedMultiplier
	end
	if player:GetAttribute("Carrying") then
		speed *= Balance.CarrySpeedMultiplier
	end
	humanoid.WalkSpeed = speed
end

function MovementService.Init(Services)
	MonetizationService = Services.MonetizationService
	MonetizationService.OnPassChanged(function(player, key)
		if key == "SpeedyBoots" then
			MovementService.Refresh(player)
		end
	end)
	Services.DataService.OnLoaded(function(player)
		MovementService.Refresh(player)
	end)
end

function MovementService.Start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 5)
			MovementService.Refresh(player)
		end)
		player:GetAttributeChangedSignal("Carrying"):Connect(function()
			MovementService.Refresh(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return MovementService
