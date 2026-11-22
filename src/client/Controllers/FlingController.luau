-- FlingController.luau
-- FLING button at the launch pad, the timing meter, and the flying shovel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Meter = require(ReplicatedStorage.Shared.Meter)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)

local player = Players.LocalPlayer

local FlingController = {}

local UIController, WorldController, RevealController
local meterStart: number? = nil
local lastFling = 0

local function nearPad(): boolean
	local map = Workspace:FindFirstChild("Map")
	local pad = map and map:FindFirstChild("LaunchPad") :: BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not pad or not root then
		return false
	end
	local offset = root.Position - pad.Position
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= Balance.FlingRange
end

local function stopMeter()
	local started = meterStart
	if not started then
		return
	end
	meterStart = nil
	UIController.SetMeterVisible(false)
	Remotes.Get("StopFling"):FireServer(Meter.ValueAt(os.clock() - started))
	lastFling = os.clock()
end

local function startMeter()
	if meterStart or os.clock() - lastFling < Balance.FlingCooldown then
		return
	end
	meterStart = os.clock()
	Remotes.Get("StartFling"):FireServer()
	UIController.SetMeterVisible(true)
end

-- The shovel flying through the air (everyone sees everyone's).
local function makeShovel(tier: number): Model
	local shovel = Shop.Shovels[tier] or Shop.Shovels[1]
	local model = Instance.new("Model")
	model.Name = "FlyingShovel"
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.5, 5, 0.5)
	handle.Color = Color3.fromRGB(120, 80, 45)
	handle.Parent = model
	local blade = Instance.new("Part")
	blade.Name = "Blade"
	blade.Size = Vector3.new(2, 2.2, 0.3)
	blade.Color = shovel.Color
	blade.Material = Enum.Material.Metal
	blade.CFrame = handle.CFrame * CFrame.new(0, -3.4, 0)
	blade.Parent = model
	for _, part in { handle, blade } do
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
	end
	model.PrimaryPart = handle
	model.Parent = Workspace
	return model
end

local function dustPuff(position: Vector3)
	local puff = Instance.new("Part")
	puff.Shape = Enum.PartType.Ball
	puff.Anchored = true
	puff.CanCollide = false
	puff.CanQuery = false
	puff.Size = Vector3.new(2, 2, 2)
	puff.Color = Color3.fromRGB(210, 190, 150)
	puff.Transparency = 0.2
	puff.Position = position
	puff.Parent = Workspace
	TweenService:Create(puff, TweenInfo.new(0.6), { Size = Vector3.new(14, 14, 14), Transparency = 1 }):Play()
	task.delay(0.7, function()
		puff:Destroy()
	end)
end

-- Big distance number that counts up while your shovel flies.
local function distanceCounter(result)
	local label = UIController.Label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.32),
		Size = UDim2.fromOffset(320, 80),
		Text = "0m",
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 30,
		Parent = UIController.Gui(),
	})
	local scale = UIController.Make("UIScale", { Parent = label })
	local started = os.clock()
	while true do
		local t = math.min((os.clock() - started) / result.Duration, 1)
		-- Ease out so the number races, then slows near the end (more suspense).
		local shown = math.floor(result.Distance * (1 - (1 - t) ^ 2))
		label.Text = shown .. "m"
		if t >= 1 then
			break
		end
		RunService.RenderStepped:Wait()
	end
	label.TextColor3 = if result.Perfect
		then Color3.fromRGB(120, 255, 140)
		elseif result.Grade == "Miss" then Color3.fromRGB(255, 120, 120)
		else Color3.fromRGB(255, 230, 90)
	scale.Scale = 1.5
	TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.wait(1.4)
	TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
	task.wait(0.4)
	label:Destroy()
end

local function perfectFlash()
	local white = UIController.Make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(200, 255, 210),
		BackgroundTransparency = 0.4,
		ZIndex = 29,
		Parent = UIController.Gui(),
	})
	TweenService:Create(white, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	task.delay(0.5, function()
		white:Destroy()
	end)
end

local function onFlingResult(result)
	local isMine = result.UserId == player.UserId
	local model = makeShovel(result.ShovelTier)
	local from: Vector3, to: Vector3 = result.From, result.To
	local height = math.max(25, (to - from).Magnitude * 0.35)
	local duration = result.Duration

	local camera = Workspace.CurrentCamera
	if isMine and camera then
		camera.CameraSubject = model.PrimaryPart
	end

	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.min((os.clock() - started) / duration, 1)
		local position = from:Lerp(to, t) + Vector3.new(0, height * 4 * t * (1 - t), 0)
		local spin = CFrame.Angles(t * math.pi * 6, 0, 0)
		model:PivotTo(CFrame.new(position) * spin)
		if t >= 1 then
			connection:Disconnect()
			model:PivotTo(CFrame.new(to + Vector3.new(0, 2.5, 0)) * CFrame.Angles(math.rad(20), 0, 0))
			dustPuff(to)
			task.delay(1.2, function()
				if isMine and camera then
					local character = player.Character
					local humanoid = character and character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						camera.CameraSubject = humanoid
					end
				end
			end)
			task.delay(3, function()
				model:Destroy()
			end)
		end
	end)

	if isMine then
		task.spawn(distanceCounter, result)
		if result.Perfect then
			perfectFlash()
		end
		if result.NewZone then
			task.delay(duration, function()
				RevealController.Banner(
					"NEW ZONE: " .. string.upper(result.ZoneName) .. "!",
					"x" .. result.ZoneLuck .. " luck for eggs dug here",
					Color3.fromRGB(230, 140, 40)
				)
			end)
		end
		local prefix = ""
		if result.Perfect then
			prefix = if result.Streak > 1 then "PERFECT x" .. result.Streak .. "! " else "PERFECT! "
		elseif result.Grade == "Great" then
			prefix = "Great! "
		else
			prefix = "Missed... "
		end
		UIController.Toast(
			prefix
				.. result.Distance
				.. "m into "
				.. result.ZoneName
				.. string.format(" (x%.1f luck)", result.Luck),
			if result.Perfect then "epic" elseif result.Grade == "Great" then "good" else "bad"
		)
	end
end

function FlingController.Start(Controllers)
	UIController = Controllers.UIController
	WorldController = Controllers.WorldController
	RevealController = Controllers.RevealController

	-- STOP! while the meter runs (top priority), FLING at the pad otherwise.
	UIController.RegisterAction(100, function()
		if meterStart then
			return { Text = "STOP!", Color = Color3.fromRGB(70, 200, 90), Callback = stopMeter }
		end
		return nil
	end)
	UIController.RegisterAction(50, function()
		if not nearPad() then
			return nil
		end
		if player:GetAttribute("Carrying") then
			return { Text = "Take your egg home!", Color = Color3.fromRGB(110, 110, 120) }
		end
		return { Text = "FLING", Color = Color3.fromRGB(255, 150, 40), Callback = startMeter }
	end)

	RunService.RenderStepped:Connect(function()
		if meterStart then
			local elapsed = os.clock() - meterStart
			UIController.SetMeterValue(Meter.ValueAt(elapsed))
			if elapsed > 10 or not nearPad() then
				meterStart = nil
				UIController.SetMeterVisible(false)
			end
		end
	end)

	Remotes.Get("FlingResult").OnClientEvent:Connect(onFlingResult)

	-- Auto Fling: flings for you when you're at the pad with nothing to dig.
	task.spawn(function()
		while true do
			task.wait(0.5)
			if
				UIController.AutoState.AutoFling
				and UIController.OwnsPass("AutoFling")
				and nearPad()
				and not meterStart
				and not player:GetAttribute("Carrying")
				and not WorldController.MyDigSpot()
				and os.clock() - lastFling > Balance.FlingCooldown + 0.5
			then
				lastFling = os.clock()
				Remotes.Get("StartFling"):FireServer({ auto = true })
			end
		end
	end)
end

return FlingController
