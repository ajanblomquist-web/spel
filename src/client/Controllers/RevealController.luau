-- RevealController.luau
-- The big feel-good moments:
--   * full-screen hatch reveal (egg shakes, flash, light rays, dino card)
--   * BREAKTHROUGH celebration (~30 min, the Gold Rock)
--   * banners: QUEST COMPLETE, NEW ZONE, GIFT, TUTORIAL DONE
--   * the one-time Starter Pack offer after the first hatch
--
-- Full-screen moments queue up so they never overlap; banners queue separately.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local DinoArt = require(ReplicatedStorage.Shared.DinoArt)
local Dinos = require(ReplicatedStorage.Shared.Config.Dinos)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local FormatNumber = require(ReplicatedStorage.Shared.Util.FormatNumber)
local Index = require(ReplicatedStorage.Shared.Config.Index)
local Products = require(ReplicatedStorage.Shared.Config.Products)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local RevealController = {}

local UI
local fullscreenQueue: { () -> () } = {}
local bannerQueue: { { Title: string, Subtitle: string, Color: Color3 } } = {}
local fullscreenRunning = false
local bannerRunning = false

local function tween(instance: Instance, seconds: number, props, style: Enum.EasingStyle?)
	local t = TweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad), props)
	t:Play()
	return t
end

-- Queues -------------------------------------------------------------------------

local function runFullscreen()
	if fullscreenRunning then
		return
	end
	fullscreenRunning = true
	task.spawn(function()
		while #fullscreenQueue > 0 do
			local show = table.remove(fullscreenQueue, 1)
			local ok, err = pcall(show)
			if not ok then
				warn("[RevealController] " .. tostring(err))
			end
		end
		fullscreenRunning = false
	end)
end

local function queueFullscreen(show: () -> ())
	table.insert(fullscreenQueue, show)
	runFullscreen()
end

local function showBanner(title: string, subtitle: string, color: Color3)
	local gui = UI.Gui()
	local frame = UI.Make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 150),
		Size = UDim2.fromOffset(480, 90),
		BackgroundColor3 = color,
		ZIndex = 40,
		Parent = gui,
	}, { UI.Corner(18), UI.Stroke(4) })
	local scale = UI.Make("UIScale", { Scale = 0.2, Parent = frame })
	UI.Label({
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 46),
		Text = title,
		ZIndex = 41,
		Parent = frame,
	})
	UI.Label({
		Position = UDim2.fromOffset(12, 54),
		Size = UDim2.new(1, -24, 0, 28),
		Text = subtitle,
		ZIndex = 41,
		Parent = frame,
	})
	tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	task.wait(2.6)
	tween(scale, 0.25, { Scale = 0 })
	task.wait(0.25)
	frame:Destroy()
end

function RevealController.Banner(title: string, subtitle: string, color: Color3?)
	table.insert(bannerQueue, { Title = title, Subtitle = subtitle, Color = color or UI.Colors.Purple })
	if bannerRunning then
		return
	end
	bannerRunning = true
	task.spawn(function()
		while #bannerQueue > 0 do
			local b = table.remove(bannerQueue, 1)
			showBanner(b.Title, b.Subtitle, b.Color)
		end
		bannerRunning = false
	end)
end

-- Building blocks for full-screen moments ---------------------------------------

-- A dark overlay that the player taps to close. Returns the overlay, a
-- function that waits until it's closed (or autoClose seconds pass), and a
-- function that closes it from code.
local function overlay(autoClose: number?): (TextButton, () -> (), () -> ())
	local button = UI.Make("TextButton", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 50,
		Parent = UI.Gui(),
	})
	tween(button, 0.25, { BackgroundTransparency = 0.35 })
	local closed = false
	local canClose = false
	button.Activated:Connect(function()
		if canClose then
			closed = true
		end
	end)
	local function waitClosed()
		canClose = true
		local started = os.clock()
		while not closed and (not autoClose or os.clock() - started < autoClose) do
			task.wait(0.05)
		end
		tween(button, 0.2, { BackgroundTransparency = 1 })
		for _, d in button:GetDescendants() do
			if d:IsA("GuiObject") then
				d.Visible = false
			end
		end
		task.wait(0.2)
		button:Destroy()
	end
	local function close()
		closed = true
	end
	return button, waitClosed, close
end

local function flash(parent: Instance)
	local white = UI.Make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		ZIndex = 70,
		Parent = parent,
	})
	tween(white, 0.6, { BackgroundTransparency = 1 })
	task.delay(0.6, function()
		white:Destroy()
	end)
end

-- Spinning light rays behind a reveal. Returns a stop function.
local function rays(parent: Instance, color: Color3, count: number): () -> ()
	local holder = UI.Make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(10, 10),
		BackgroundTransparency = 1,
		ZIndex = 51,
		Parent = parent,
	})
	for i = 1, count do
		UI.Make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(46, 900),
			Rotation = (i - 1) * (180 / count),
			BackgroundColor3 = color,
			BackgroundTransparency = 0.7,
			BorderSizePixel = 0,
			ZIndex = 51,
			Parent = holder,
		})
	end
	local connection = RunService.RenderStepped:Connect(function(dt)
		holder.Rotation += dt * 25
	end)
	return function()
		connection:Disconnect()
		holder:Destroy()
	end
end

-- Hatch reveal ---------------------------------------------------------------------

-- A slowly spinning copy of the hatched dino, with mutation colours and baby look.
-- Returns the ViewportFrame; the spin stops when it is destroyed.
local function dinoViewport(parent: Instance, record): ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "DinoView"
	viewport.BackgroundTransparency = 1
	viewport.ZIndex = 61
	viewport.Parent = parent

	local model = DinoArt.Get(record.DinoId)
	DinoArt.ApplyMutation(model, record.Mutation)
	if record.Baby then
		DinoArt.ApplyBaby(model)
	end
	model.Parent = viewport

	-- Centre the dino on the origin and frame its bounding sphere.
	local boxCFrame, boxSize = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() - boxCFrame.Position)
	local basePivot = model:GetPivot()
	local radius = boxSize.Magnitude / 2
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	local distance = radius / math.sin(math.rad(camera.FieldOfView / 2)) * 1.05
	camera.CFrame = CFrame.lookAt(Vector3.new(0, radius * 0.35, distance), Vector3.zero)
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local angle = math.rad(200)
	local connection = RunService.RenderStepped:Connect(function(dt)
		angle += dt * 0.9
		model:PivotTo(CFrame.Angles(0, angle, 0) * basePivot)
	end)
	viewport.Destroying:Connect(function()
		connection:Disconnect()
	end)
	return viewport
end

local function showHatch(record, income: number, isFirst: boolean)
	local rarity = Eggs.RarityById[record.Rarity]
	local dino = Dinos.ById[record.DinoId]
	local root, waitClosed = overlay(10)

	-- 1. The egg shakes harder and harder (longer for rarer eggs).
	local egg = UI.Make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(130, 165),
		BackgroundColor3 = rarity.Color,
		ZIndex = 55,
		Parent = root,
	}, { UI.Make("UICorner", { CornerRadius = UDim.new(0.5, 0) }), UI.Stroke(5) })
	local shakeTime = 1.1 + rarity.Order * 0.25
	local started = os.clock()
	while os.clock() - started < shakeTime do
		local t = (os.clock() - started) / shakeTime
		local amount = 4 + t * 22
		egg.Rotation = math.sin(os.clock() * 40) * amount
		egg.Position = UDim2.new(0.5, math.random(-1, 1) * t * 6, 0.5, 0)
		RunService.RenderStepped:Wait()
	end
	egg:Destroy()

	-- 2. Flash, rays, and the dino card. Babies get a pink double flash and extra rays.
	local baby = record.Baby == true
	local glowColor = if baby then Index.BabyColor else rarity.Color
	flash(root)
	if baby then
		task.wait(0.15)
		flash(root)
	end
	local stopRays = rays(root, glowColor, if baby then 16 elseif rarity.Order >= 3 then 10 else 6)

	local card = UI.Make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(600, 250),
		BackgroundColor3 = UI.Colors.Panel,
		ZIndex = 60,
		Parent = root,
	}, { UI.Corner(22), UI.Stroke(5, glowColor) })
	local view = dinoViewport(card, record)
	view.Position = UDim2.fromOffset(12, 20)
	view.Size = UDim2.fromOffset(210, 210)
	local scale = UI.Make("UIScale", { Scale = 0.1, Parent = card })
	tween(scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)

	local extras = {}
	if record.Size ~= "Normal" then
		table.insert(extras, record.Size)
	end
	if record.Mutation ~= "None" then
		table.insert(extras, record.Mutation)
	end
	if baby then
		table.insert(extras, Index.BabyIncomeMultiplier .. "x coins")
	end

	local name = dino and dino.Name or record.DinoId
	local lines = {
		{
			Text = if baby then "IT'S A BABY!" elseif isFirst then "YOUR FIRST DINO!" else "YOU HATCHED",
			Size = 30,
			Color = if baby then Index.BabyColor else Color3.new(1, 1, 1),
		},
		{ Text = if baby then "Baby " .. name else name, Size = 52, Color = Color3.new(1, 1, 1) },
		{
			Text = if baby then "BABY " .. string.upper(record.Rarity) else string.upper(record.Rarity),
			Size = 36,
			Color = glowColor,
		},
		{
			Text = if #extras > 0 then table.concat(extras, " + ") .. "!" else "",
			Size = 26,
			Color = Color3.fromRGB(255, 200, 90),
		},
		{ Text = "+" .. FormatNumber(income) .. " coins every second", Size = 28, Color = UI.Colors.Coins },
		{ Text = "Tap to continue", Size = 20, Color = Color3.fromRGB(200, 200, 210) },
	}
	local y = 10
	for _, line in lines do
		UI.Label({
			Position = UDim2.fromOffset(230, y),
			Size = UDim2.new(1, -240, 0, line.Size),
			Text = line.Text,
			TextColor3 = line.Color,
			ZIndex = 61,
			Parent = card,
		})
		y += line.Size + 4
	end

	waitClosed()
	stopRays()
end

-- Breakthrough ---------------------------------------------------------------------

local function showBreakthrough(data)
	local root, waitClosed = overlay(9)
	flash(root)
	local stopRays = rays(root, Color3.fromRGB(255, 200, 60), 12)
	local title = UI.Label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromOffset(600, 90),
		Text = "BREAKTHROUGH!",
		TextColor3 = Color3.fromRGB(255, 215, 70),
		ZIndex = 60,
		Parent = root,
	})
	local scale = UI.Make("UIScale", { Scale = 0.1, Parent = title })
	tween(scale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	UI.Label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(560, 44),
		Text = data.Name .. " Rock: " .. data.Multiplier .. "x Strength every rep!",
		ZIndex = 60,
		Parent = root,
	})
	UI.Label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.66),
		Size = UDim2.fromOffset(560, 34),
		Text = "Train a little, then fling all the way to Amber Cliffs!",
		TextColor3 = Color3.fromRGB(255, 200, 120),
		ZIndex = 60,
		Parent = root,
	})
	waitClosed()
	stopRays()
end

-- Rebirth ----------------------------------------------------------------------------

local function showRebirth(data)
	local color = Color3.fromRGB(255, 120, 220)
	local root, waitClosed = overlay(9)
	flash(root)
	local stopRays = rays(root, color, 14)
	local title = UI.Label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromOffset(600, 90),
		Text = "REBIRTH " .. data.Count .. "!",
		TextColor3 = color,
		ZIndex = 60,
		Parent = root,
	})
	local scale = UI.Make("UIScale", { Scale = 0.1, Parent = title })
	tween(scale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	UI.Label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.54),
		Size = UDim2.fromOffset(560, 40),
		Text = string.format(
			"Forever: x%.2f Strength, x%.2f Coins, x%.2f Luck",
			data.Strength,
			data.Coins,
			data.Luck
		),
		ZIndex = 60,
		Parent = root,
	})
	UI.Label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.65),
		Size = UDim2.fromOffset(560, 34),
		Text = "Your dinos and Index stay. Climb back up faster than ever!",
		TextColor3 = Color3.fromRGB(255, 200, 230),
		ZIndex = 60,
		Parent = root,
	})
	waitClosed()
	stopRays()
end

-- Starter Pack offer -------------------------------------------------------------------

local function showStarterOffer()
	local product = Products.StarterPack
	local root, waitClosed, close = overlay(nil)
	local card = UI.Make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(440, 270),
		BackgroundColor3 = UI.Colors.Panel,
		ZIndex = 60,
		Active = true,
		Parent = root,
	}, { UI.Corner(22), UI.Stroke(5, Color3.fromRGB(255, 200, 60)) })
	UI.Label({
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -32, 0, 48),
		Text = product.Name,
		TextColor3 = Color3.fromRGB(255, 215, 70),
		ZIndex = 61,
		Parent = card,
	})
	UI.Label({
		Position = UDim2.fromOffset(16, 66),
		Size = UDim2.new(1, -32, 0, 90),
		Text = "2x Coins for 30 minutes\nA Rare egg\n1,000 coins",
		ZIndex = 61,
		Parent = card,
	})
	local buy = UI.Button({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(240, 70),
		Text = if product.ProductId ~= 0 then "Get it  R$ " .. product.Price else "Get it (test)",
		BackgroundColor3 = UI.Colors.Green,
		ZIndex = 62,
		Parent = card,
	})
	local later = UI.Button({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(150, 70),
		Text = "Maybe later",
		BackgroundColor3 = UI.Colors.Grey,
		ZIndex = 62,
		Parent = card,
	})
	buy.Activated:Connect(function()
		UI.PromptProduct("StarterPack")
		close()
	end)
	later.Activated:Connect(close)
	waitClosed()
end

-- Start ----------------------------------------------------------------------------

function RevealController.Start(Controllers)
	UI = Controllers.UIController

	Remotes.Get("Hatched").OnClientEvent:Connect(function(record, income, isFirst)
		queueFullscreen(function()
			showHatch(record, income, isFirst)
		end)
	end)

	Remotes.Get("Celebrate").OnClientEvent:Connect(function(kind, data)
		if kind == "Quest" then
			RevealController.Banner("QUEST COMPLETE!", data.Reward, UI.Colors.Green)
			if data.TutorialDone then
				RevealController.Banner(
					"TUTORIAL DONE!",
					"Follow the quests to grow your dino collection",
					UI.Colors.Purple
				)
			end
		elseif kind == "Gift" then
			RevealController.Banner("GIFT!", data.Text, Color3.fromRGB(200, 140, 30))
		elseif kind == "Breakthrough" then
			queueFullscreen(function()
				showBreakthrough(data)
			end)
		elseif kind == "IndexPage" then
			RevealController.Banner(
				string.upper(data.Rarity) .. " PAGE COMPLETE!",
				"+"
					.. FormatNumber(data.Coins)
					.. " coins, Baby odds now x"
					.. string.format("%.1f", data.BabyLuck),
				Color3.fromRGB(255, 140, 200)
			)
		elseif kind == "Event" then
			RevealController.Banner(data.Name .. "!", data.Text, Color3.fromRGB(255, 150, 40))
		elseif kind == "Daily" then
			RevealController.Banner(
				"DAY " .. data.Streak .. " STREAK!",
				data.Text,
				Color3.fromRGB(60, 150, 255)
			)
		elseif kind == "Rebirth" then
			queueFullscreen(function()
				showRebirth(data)
			end)
		elseif kind == "StarterOffer" then
			queueFullscreen(showStarterOffer)
		end
	end)
end

return RevealController
