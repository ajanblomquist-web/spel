-- WorldController.luau
-- Things in the 3D world for the local player:
--   * hides prompts that aren't for you (your own "Steal egg", other people's
--     Dig and Sell prompts)
--   * counts down incubator timers
--   * draws a guide line to your dig spot, or home while carrying an egg
--   * the status line and the LOCK NEST button when you're at home

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local WorldController = {}

local UIController

local function shouldHide(prompt: ProximityPrompt): boolean
	local ownerOnly = prompt:GetAttribute("OwnerOnly")
	if ownerOnly and ownerOnly ~= player.UserId then
		return true
	end
	local notFor = prompt:GetAttribute("NotForUserId")
	return notFor ~= nil and notFor == player.UserId
end

local function filterPrompt(prompt: ProximityPrompt)
	if not shouldHide(prompt) then
		return
	end
	prompt.Enabled = false
	-- The server may switch it back on (e.g. after a nest lock); hide it again.
	prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
		if prompt.Enabled then
			prompt.Enabled = false
		end
	end)
end

-- Timers ---------------------------------------------------------------------------

local timerLabels: { [BillboardGui]: true } = {}

local function trackTimer(instance: Instance)
	if instance:IsA("BillboardGui") and instance:GetAttribute("ReadyAtServer") then
		timerLabels[instance] = true
		instance.AncestryChanged:Connect(function()
			if not instance:IsDescendantOf(game) then
				timerLabels[instance] = nil
			end
		end)
	end
end

local function formatTime(seconds: number): string
	seconds = math.ceil(seconds)
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function updateTimers()
	local now = Workspace:GetServerTimeNow()
	for gui in timerLabels do
		local line = gui:FindFirstChild("Line2") :: TextLabel?
		if line then
			local left = gui:GetAttribute("ReadyAtServer") - now
			line.Text = if left > 0 then formatTime(left) else "Hatching..."
		end
	end
end

-- Home / guide line ----------------------------------------------------------------

local function myPlotFloor(): BasePart?
	local index = player:GetAttribute("PlotIndex")
	local plots = Workspace:FindFirstChild("Plots")
	local plot = index and plots and plots:FindFirstChild("Plot" .. index)
	return plot and plot:FindFirstChild("Floor") :: BasePart?
end

local function myRoot(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function WorldController.IsHome(): boolean
	local floor, root = myPlotFloor(), myRoot()
	if not floor or not root then
		return false
	end
	local offset = root.Position - floor.Position
	local limit = floor.Size.X / 2 + 2
	return math.abs(offset.X) <= limit and math.abs(offset.Z) <= limit
end

function WorldController.MyDigSpot(): BasePart?
	local folder = Workspace:FindFirstChild("DigSpots")
	if not folder then
		return nil
	end
	for _, spot in folder:GetChildren() do
		if spot:GetAttribute("OwnerUserId") == player.UserId then
			return spot :: BasePart
		end
	end
	return nil
end

local beam: Beam
local fromAttachment: Attachment
local toAttachment: Attachment

local function setupBeam()
	toAttachment = Instance.new("Attachment")
	toAttachment.Name = "GuideTarget"
	toAttachment.Parent = Workspace.Terrain

	beam = Instance.new("Beam")
	beam.Name = "GuideBeam"
	beam.Width0 = 1
	beam.Width1 = 1
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Transparency = NumberSequence.new(0.25)
	beam.Attachment1 = toAttachment
	beam.Enabled = false
	beam.Parent = Workspace.Terrain
end

local function updateGuide()
	local root = myRoot()
	if root and (not fromAttachment or fromAttachment.Parent ~= root) then
		fromAttachment = Instance.new("Attachment")
		fromAttachment.Name = "GuideFrom"
		fromAttachment.Parent = root
		beam.Attachment0 = fromAttachment
	end

	local carrying = player:GetAttribute("Carrying") == true
	local now = Workspace:GetServerTimeNow()
	local lockedUntil = player:GetAttribute("NestLockedUntil") or 0
	local target: Vector3? = nil
	local status: string? = nil

	if carrying then
		local floor = myPlotFloor()
		target = floor and floor.Position
		beam.Color = ColorSequence.new(Color3.fromRGB(90, 255, 120))
		status = "Carrying a " .. string.upper(player:GetAttribute("CarryRarity") or "") .. " egg! Run home!"
	else
		local spot = WorldController.MyDigSpot()
		if spot then
			target = spot.Position
			beam.Color = ColorSequence.new(Color3.fromRGB(255, 220, 80))
			status = "Follow the line to your dig spot!"
		elseif player:GetAttribute("PedestalsFull") then
			status = "Pedestals full! Sell a dino to hatch more."
		end
	end
	if lockedUntil > now then
		local lockText = "Nest locked " .. formatTime(lockedUntil - now)
		status = if status then status .. "   |   " .. lockText else lockText
	end

	beam.Enabled = target ~= nil and root ~= nil
	if target then
		toAttachment.WorldPosition = target + Vector3.new(0, 2, 0)
	end
	UIController.SetStatus(status)
end

function WorldController.Start(Controllers)
	UIController = Controllers.UIController

	for _, d in Workspace:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			filterPrompt(d)
		end
		trackTimer(d)
	end
	Workspace.DescendantAdded:Connect(function(d)
		if d:IsA("ProximityPrompt") then
			filterPrompt(d)
		end
		trackTimer(d)
	end)

	setupBeam()

	-- LOCK NEST shows when you're home and the lock is ready.
	UIController.RegisterAction(30, function()
		if player:GetAttribute("Carrying") or not WorldController.IsHome() then
			return nil
		end
		local now = Workspace:GetServerTimeNow()
		if (player:GetAttribute("NestLockedUntil") or 0) > now then
			return nil
		end
		local readyAt = player:GetAttribute("NestLockReadyAt") or 0
		if readyAt > now then
			return {
				Text = "Lock ready in " .. formatTime(readyAt - now),
				Color = Color3.fromRGB(110, 110, 120),
			}
		end
		return {
			Text = "LOCK NEST",
			Color = Color3.fromRGB(60, 150, 255),
			Callback = function()
				Remotes.Get("LockNest"):FireServer()
			end,
		}
	end)

	task.spawn(function()
		while true do
			updateTimers()
			updateGuide()
			task.wait(0.2)
		end
	end)
end

return WorldController
