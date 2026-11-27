-- EffectsController.luau
-- Small client-only world effects:
--   * a burst of dirt where an egg is dug up (the server fires DigBurst),
--   * the clouds built by WorldDecor drifting slowly across the sky,
--   * a few pterosaurs circling far away.
-- All of it is cheap on purpose (a handful of parts, one emitter per dig).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local EffectsController = {}

local CLOUD_SPEED = 4 -- studs per second
local CLOUD_WRAP = 3200

local function digBurst(position: Vector3, color: Color3)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position + Vector3.new(0, 1, 0)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.Rate = 0
	emitter.Color = ColorSequence.new(color)
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Speed = NumberRange.new(12, 22)
	emitter.SpreadAngle = Vector2.new(35, 35)
	emitter.Acceleration = Vector3.new(0, -45, 0)
	emitter.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0.4) })
	emitter.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	emitter.Parent = anchor
	anchor.Parent = Workspace
	emitter:Emit(24)
	task.delay(1.5, function()
		anchor:Destroy()
	end)
end

local function watchDigSpots()
	Remotes.Get("DigBurst").OnClientEvent:Connect(function(position: Vector3, color: Color3)
		digBurst(position, color:Lerp(Color3.new(1, 1, 1), 0.2))
	end)
end

local function driftClouds()
	local map = Workspace:WaitForChild("Map")
	local dressing = map:WaitForChild("Dressing")
	local landscape = dressing:WaitForChild("Landscape")
	local folder = landscape:WaitForChild("Clouds")
	local clouds = {}
	for _, cloud in folder:GetChildren() do
		if cloud:IsA("Model") then
			table.insert(clouds, { Model = cloud, Origin = cloud:GetPivot() })
		end
	end
	local elapsed = 0
	local accumulated = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulated += dt
		if accumulated < 0.1 then
			return
		end
		elapsed += accumulated
		accumulated = 0
		for _, cloud in clouds do
			local origin: CFrame = cloud.Origin
			local x = (origin.X + elapsed * CLOUD_SPEED + CLOUD_WRAP / 2) % CLOUD_WRAP - CLOUD_WRAP / 2
			cloud.Model:PivotTo(origin - Vector3.new(origin.X - x, 0, 0))
		end
	end)
end

local function circleBirds()
	local folder = Instance.new("Folder")
	folder.Name = "Pterosaurs"
	folder.Parent = Workspace
	local color = Color3.fromRGB(96, 78, 84)
	local birds = {}
	for i = 1, 6 do
		local function part(size: Vector3): Part
			local p = Instance.new("Part")
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Color = color
			p.Material = Enum.Material.SmoothPlastic
			p.Size = size
			p.Parent = folder
			return p
		end
		table.insert(birds, {
			Body = part(Vector3.new(1.6, 1.2, 7)),
			Left = part(Vector3.new(9, 0.2, 3)),
			Right = part(Vector3.new(9, 0.2, 3)),
			Center = Vector3.new(((i % 3) - 1) * 380, 170 + (i % 2) * 70, 120 + i * 190),
			Radius = 140 + i * 25,
			Speed = (if i % 2 == 0 then 1 else -1) * (0.08 + 0.01 * i),
			Phase = i * 1.3,
		})
	end
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		for _, bird in birds do
			local angle = bird.Phase + elapsed * bird.Speed
			local position = bird.Center
				+ Vector3.new(
					math.cos(angle) * bird.Radius,
					math.sin(elapsed * 0.4 + bird.Phase) * 8,
					math.sin(angle) * bird.Radius
				)
			-- face along the circle (the direction of travel)
			local direction = Vector3.new(-math.sin(angle), 0, math.cos(angle)) * math.sign(bird.Speed)
			local base = CFrame.lookAt(position, position + direction)
				* CFrame.Angles(0, 0, math.sin(angle * 4) * 0.12)
			local flap = math.sin(elapsed * 3 + bird.Phase) * 0.45
			bird.Body.CFrame = base
			bird.Left.CFrame = base * CFrame.new(-4.5, 0, 0) * CFrame.Angles(0, 0, -flap)
			bird.Right.CFrame = base * CFrame.new(4.5, 0, 0) * CFrame.Angles(0, 0, flap)
		end
	end)
end

function EffectsController.Start(_Controllers)
	task.spawn(watchDigSpots)
	task.spawn(driftClouds)
	circleBirds()
end

return EffectsController
