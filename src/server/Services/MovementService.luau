-- MovementService.luau
-- Sets each player's walk speed from: base speed, Speedy Boots pass, whether
-- they're carrying an egg, and how far out into the fling field they are.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Passes = require(ReplicatedStorage.Shared.Config.Passes)

local MovementService = {}

local MonetizationService, MapService

local REFRESH_INTERVAL = 0.2

-- 1 in the hub, ramping up to Balance.FieldSpeedMax far out in the field.
local function fieldMultiplier(character: Model): number
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return 1
	end
	local out = root.Position.Z - MapService.LaunchOrigin.Z - Balance.FieldSpeedStart
	local span = Balance.FieldSpeedFullAt - Balance.FieldSpeedStart
	local t = math.clamp(out / span, 0, 1)
	return 1 + t * (Balance.FieldSpeedMax - 1)
end

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
	local field = fieldMultiplier(character)
	speed *= field
	-- Rounded so small position changes don't spam replication.
	speed = math.floor(speed + 0.5)
	if humanoid.WalkSpeed ~= speed then
		humanoid.WalkSpeed = speed
	end
	player:SetAttribute("FieldSpeed", math.floor(field * 10 + 0.5) / 10)
end

function MovementService.Init(Services)
	MonetizationService = Services.MonetizationService
	MapService = Services.MapService
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
	-- Field speed depends on where you are, so keep it updated as players move.
	task.spawn(function()
		while true do
			task.wait(REFRESH_INTERVAL)
			for _, player in Players:GetPlayers() do
				MovementService.Refresh(player)
			end
		end
	end)
end

return MovementService
