-- UIController.luau
-- All on-screen UI, built in code. Designed for phones first:
--   * one big context button at the bottom centre (TRAIN / FLING / STOP!),
--     clear of the thumbstick (bottom-left) and jump button (bottom-right)
--   * big square menu buttons on the right edge
--   * a UIScale so everything is the same physical size on any screen
--
-- Other controllers talk to the UI through the functions on UIController.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local FormatNumber = require(ReplicatedStorage.Shared.Util.FormatNumber)
local Passes = require(ReplicatedStorage.Shared.Config.Passes)
local Products = require(ReplicatedStorage.Shared.Config.Products)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)

local player = Players.LocalPlayer

local UIController = {}
UIController.AutoState = { AutoTrain = false, AutoFling = false }

local FONT = Enum.Font.FredokaOne
local COLORS = {
	Panel = Color3.fromRGB(35, 30, 45),
	PanelLight = Color3.fromRGB(60, 52, 75),
	Text = Color3.new(1, 1, 1),
	Coins = Color3.fromRGB(255, 215, 70),
	Strength = Color3.fromRGB(255, 130, 90),
	Green = Color3.fromRGB(70, 200, 90),
	Orange = Color3.fromRGB(255, 150, 40),
	Blue = Color3.fromRGB(60, 150, 255),
	Purple = Color3.fromRGB(160, 90, 255),
	Grey = Color3.fromRGB(110, 110, 120),
	Red = Color3.fromRGB(235, 70, 70),
}
local TOAST_COLORS = {
	info = COLORS.PanelLight,
	good = Color3.fromRGB(40, 150, 70),
	bad = Color3.fromRGB(180, 50, 50),
	epic = Color3.fromRGB(150, 70, 230),
}

-- Small helpers ----------------------------------------------------------------

local function make(className: string, props: { [string]: any }, children: { Instance }?): any
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	if props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

local function corner(radius: number?): UICorner
	return make("UICorner", { CornerRadius = UDim.new(0, radius or 14) })
end

local function stroke(thickness: number?, color: Color3?): UIStroke
	return make("UIStroke", {
		Thickness = thickness or 3,
		Color = color or Color3.new(0, 0, 0),
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function textStroke(): UIStroke
	return make("UIStroke", { Thickness = 2, Color = Color3.new(0, 0, 0) })
end

local function label(props): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = FONT,
		TextColor3 = COLORS.Text,
		TextScaled = true,
	}
	for k, v in props do
		defaults[k] = v
	end
	return make("TextLabel", defaults, { textStroke() })
end

local function bigButton(props): TextButton
	local defaults = {
		AutoButtonColor = true,
		Font = FONT,
		TextColor3 = COLORS.Text,
		TextScaled = true,
		BackgroundColor3 = COLORS.Orange,
	}
	for k, v in props do
		defaults[k] = v
	end
	local button = make("TextButton", defaults, {
		corner(16),
		stroke(3),
		make("UIPadding", {
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
		make("UITextSizeConstraint", { MaxTextSize = 40 }),
	})
	-- Text stroke via a child UIStroke would outline the border, so use TextStroke.
	button.TextStrokeTransparency = 0.4
	button.Activated:Connect(function()
		local scale = button:FindFirstChildOfClass("UIScale") or make("UIScale", { Parent = button })
		scale.Scale = 0.92
		TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end)
	return button
end

-- Root GUI ---------------------------------------------------------------------

local gui: ScreenGui
local uiScale: UIScale
local coinsLabel, incomeLabel, strengthLabel, statusLabel
local toastList: Frame
local actionButton: TextButton
local meterFrame: Frame
local meterNeedle: Frame
local shopPanel: Frame
local passesPanel: Frame
local shopButton: TextButton
local shopBadge: TextLabel
local shopAttention = false
local autoButtons = {}

local actionProviders: { { Priority: number, Fn: () -> any } } = {}
local currentAction: any = nil

local function updateScale()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	-- Designed at 420px tall (a phone in landscape). Bigger screens scale up a bit.
	uiScale.Scale = math.clamp(math.min(viewport.X / 760, viewport.Y / 420), 0.7, 1.6)
end

local function buildTopBar()
	local bar = make("Frame", {
		Name = "TopBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(390, 54),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local coinsPill = make("Frame", {
		Name = "Coins",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(230, 54),
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 0.15,
		Parent = bar,
	}, { corner(27), stroke(3) })
	coinsLabel = label({
		Size = UDim2.new(1, -16, 0.66, 0),
		Position = UDim2.fromOffset(8, 2),
		TextColor3 = COLORS.Coins,
		Text = "Coins 0",
		Parent = coinsPill,
	})
	incomeLabel = label({
		Size = UDim2.new(1, -16, 0.34, -2),
		Position = UDim2.new(0, 8, 0.66, 0),
		Text = "+0/s",
		Parent = coinsPill,
	})

	local strengthPill = make("Frame", {
		Name = "Strength",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(150, 54),
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 0.15,
		Parent = bar,
	}, { corner(27), stroke(3) })
	strengthLabel = label({
		Size = UDim2.new(1, -16, 1, -12),
		Position = UDim2.fromOffset(8, 6),
		TextColor3 = COLORS.Strength,
		Text = "Str 0",
		Parent = strengthPill,
	})

	statusLabel = label({
		Name = "Status",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -186),
		Size = UDim2.fromOffset(460, 34),
		Text = "",
		Visible = false,
		Parent = gui,
	})
end

local function refreshStats()
	coinsLabel.Text = "Coins " .. FormatNumber(math.floor(player:GetAttribute("Coins") or 0))
	incomeLabel.Text = "+" .. FormatNumber(player:GetAttribute("IncomePerSec") or 0) .. "/s"
	strengthLabel.Text = "Str " .. FormatNumber(player:GetAttribute("Strength") or 0)
end

local function buildToasts()
	toastList = make("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 68),
		Size = UDim2.fromOffset(400, 220),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		make("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

local toastCount = 0
function UIController.Toast(text: string, kind: string?)
	toastCount += 1
	local frame = make("Frame", {
		LayoutOrder = toastCount,
		Size = UDim2.fromOffset(390, 44),
		BackgroundColor3 = TOAST_COLORS[kind or "info"] or TOAST_COLORS.info,
		Parent = toastList,
	}, { corner(12), stroke(2) })
	local textLabel = label({
		Size = UDim2.new(1, -20, 1, -10),
		Position = UDim2.fromOffset(10, 5),
		Text = text,
		Parent = frame,
	})
	-- Keep at most 4 on screen.
	local toasts = {}
	for _, child in toastList:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	table.sort(toasts, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 1, #toasts - 4 do
		toasts[i]:Destroy()
	end

	local life = if kind == "epic" then 5 else 3
	task.delay(life, function()
		if frame.Parent then
			local info = TweenInfo.new(0.4)
			TweenService:Create(frame, info, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(textLabel, info, { TextTransparency = 1 }):Play()
			task.wait(0.4)
			frame:Destroy()
		end
	end)
end

function UIController.SetStatus(text: string?)
	statusLabel.Visible = text ~= nil and text ~= ""
	statusLabel.Text = text or ""
end

-- Floating "+3" text that rises from the action button.
function UIController.Floater(text: string, color: Color3?)
	local floater = label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, math.random(-60, 60), 1, -130),
		Size = UDim2.fromOffset(160, 40),
		Text = text,
		TextColor3 = color or COLORS.Strength,
		Parent = gui,
	})
	local info = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(floater, info, {
		Position = floater.Position - UDim2.fromOffset(0, 70),
		TextTransparency = 1,
	}):Play()
	task.delay(0.8, function()
		floater:Destroy()
	end)
end

-- Context action button ----------------------------------------------------------

-- fn returns nil (nothing to do) or { Text = "...", Color = Color3?, Callback = function? }.
-- The highest-priority provider that returns something wins.
function UIController.RegisterAction(priority: number, fn: () -> any)
	table.insert(actionProviders, { Priority = priority, Fn = fn })
	table.sort(actionProviders, function(a, b)
		return a.Priority > b.Priority
	end)
end

local function buildActionButton()
	actionButton = bigButton({
		Name = "Action",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -22),
		Size = UDim2.fromOffset(230, 96),
		Text = "",
		Visible = false,
		Parent = gui,
	})
	actionButton.Activated:Connect(function()
		if currentAction and currentAction.Callback then
			currentAction.Callback()
		end
	end)
end

local function refreshAction()
	local chosen = nil
	for _, provider in actionProviders do
		local ok, result = pcall(provider.Fn)
		if ok and result then
			chosen = result
			break
		end
	end
	currentAction = chosen
	actionButton.Visible = chosen ~= nil
	if chosen then
		actionButton.Text = chosen.Text
		actionButton.BackgroundColor3 = chosen.Color or COLORS.Orange
		actionButton.AutoButtonColor = chosen.Callback ~= nil
	end
end

-- Fling meter --------------------------------------------------------------------

local function buildMeter()
	meterFrame = make("Frame", {
		Name = "Meter",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -132),
		Size = UDim2.fromOffset(380, 48),
		BackgroundColor3 = Color3.fromRGB(200, 60, 60),
		Visible = false,
		Parent = gui,
	}, { corner(12), stroke(3) })

	make("Frame", {
		Name = "Great",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(Balance.GreatWindow * 2, 1),
		BackgroundColor3 = Color3.fromRGB(250, 210, 60),
		BorderSizePixel = 0,
		Parent = meterFrame,
	})
	make("Frame", {
		Name = "Perfect",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(Balance.PerfectWindow * 2, 1),
		BackgroundColor3 = COLORS.Green,
		BorderSizePixel = 0,
		Parent = meterFrame,
	})
	label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -4),
		Size = UDim2.fromOffset(300, 30),
		Text = "Hit the thin green line!",
		Parent = meterFrame,
	})
	meterNeedle = make("Frame", {
		Name = "Needle",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(0, 8, 1, 16),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
		Parent = meterFrame,
	}, { corner(4), stroke(2) })
end

function UIController.SetMeterVisible(visible: boolean)
	meterFrame.Visible = visible
end

function UIController.SetMeterValue(value: number)
	meterNeedle.Position = UDim2.fromScale(value, 0.5)
end

-- Passes -----------------------------------------------------------------------

function UIController.OwnsPass(key: string): boolean
	return player:GetAttribute(Passes.AttributeName(key)) == true
end

function UIController.PromptPass(key: string)
	local pass = Passes.ByKey[key]
	if not pass then
		return
	end
	if pass.GamePassId ~= 0 then
		MarketplaceService:PromptGamePassPurchase(player, pass.GamePassId)
	elseif RunService:IsStudio() then
		Remotes.Get("StudioSetPass"):FireServer(key, not UIController.OwnsPass(key))
	else
		UIController.Toast(pass.Name .. " is coming soon!", "info")
	end
end

-- Panels -------------------------------------------------------------------------

local function closeAllPanels()
	shopPanel.Visible = false
	passesPanel.Visible = false
end

local function buildPanel(name: string, title: string): (Frame, ScrollingFrame)
	local panel = make("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(560, 340),
		BackgroundColor3 = COLORS.Panel,
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	}, { corner(20), stroke(4) })

	label({
		Position = UDim2.fromOffset(20, 10),
		Size = UDim2.new(1, -100, 0, 42),
		Text = title,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 11,
		Parent = panel,
	})
	local close = bigButton({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(56, 56),
		Text = "X",
		BackgroundColor3 = COLORS.Red,
		ZIndex = 11,
		Parent = panel,
	})
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	local list = make("ScrollingFrame", {
		Position = UDim2.fromOffset(14, 72),
		Size = UDim2.new(1, -28, 1, -86),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 10,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 11,
		Parent = panel,
	}, {
		make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	return panel, list
end

local function row(parent: Instance, order: number, title: string, subtitle: string): (Frame, TextButton)
	local frame = make("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -12, 0, 74),
		BackgroundColor3 = COLORS.PanelLight,
		ZIndex = 12,
		Parent = parent,
	}, { corner(14) })
	label({
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.new(1, -190, 0, 34),
		Text = title,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 13,
		Parent = frame,
	})
	label({
		Position = UDim2.fromOffset(14, 42),
		Size = UDim2.new(1, -190, 0, 24),
		Text = subtitle,
		TextColor3 = Color3.fromRGB(210, 210, 220),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 13,
		Parent = frame,
	})
	local button = bigButton({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(160, 58),
		Text = "",
		ZIndex = 13,
		Parent = frame,
	})
	return frame, button
end

local shopRows = {} -- { { Category, Tier, Button } }

local function refreshShop()
	local coins = player:GetAttribute("Coins") or 0
	for _, entry in shopRows do
		local current = player:GetAttribute(if entry.Category == "Rocks" then "RockTier" else "ShovelTier")
			or 1
		local item = entry.Item
		if entry.Tier <= current then
			entry.Button.Text = "Owned"
			entry.Button.BackgroundColor3 = COLORS.Grey
		elseif entry.Tier == current + 1 then
			entry.Button.Text = FormatNumber(item.Price)
			entry.Button.BackgroundColor3 = if coins >= item.Price then COLORS.Green else COLORS.Orange
		else
			entry.Button.Text = "Locked"
			entry.Button.BackgroundColor3 = COLORS.Grey
		end
	end
end

local function buildShop()
	local list
	shopPanel, list = buildPanel("ShopPanel", "Shop")
	local order = 0
	local function add(category: string, items, describe)
		for tier, item in items do
			if tier > 1 then
				order += 1
				local frame, button = row(list, order, item.Name, describe(item))
				if item.Breakthrough then
					frame.BackgroundColor3 = Color3.fromRGB(150, 110, 20)
				end
				button.Activated:Connect(function()
					Remotes.Get("BuyUpgrade"):FireServer(category, tier)
				end)
				table.insert(shopRows, { Category = category, Tier = tier, Item = item, Button = button })
			end
		end
	end
	add("Rocks", Shop.Rocks, function(item)
		local text = "Training rock: +" .. FormatNumber(item.StrengthPerRep) .. " Strength per rep"
		if item.Breakthrough then
			text = "BIG UPGRADE! " .. text
		end
		return text
	end)
	add("Shovels", Shop.Shovels, function(item)
		return "Shovel: x" .. item.Power .. " distance, x" .. item.Luck .. " luck"
	end)
	refreshShop()
end

local passRows = {}
local starterRow: Frame
local starterButton: TextButton

function UIController.PromptProduct(key: string)
	local product = Products[key]
	if not product then
		return
	end
	if product.ProductId ~= 0 then
		MarketplaceService:PromptProductPurchase(player, product.ProductId)
	elseif RunService:IsStudio() then
		Remotes.Get("StudioBuyProduct"):FireServer(key)
	else
		UIController.Toast(product.Name .. " is coming soon!", "info")
	end
end

local function refreshPasses()
	for key, button in passRows do
		local pass = Passes.ByKey[key]
		if UIController.OwnsPass(key) then
			button.Text = if RunService:IsStudio() and pass.GamePassId == 0 then "Owned (test)" else "Owned"
			button.BackgroundColor3 = COLORS.Grey
		elseif pass.GamePassId == 0 then
			button.Text = if RunService:IsStudio() then "Test it" else "Soon"
			button.BackgroundColor3 = COLORS.Purple
		else
			button.Text = "R$ " .. pass.Price
			button.BackgroundColor3 = COLORS.Green
		end
	end
	if starterRow then
		starterRow.Visible = player:GetAttribute("StarterPackBought") ~= true
		local product = Products.StarterPack
		starterButton.Text = if product.ProductId ~= 0
			then "R$ " .. product.Price
			elseif RunService:IsStudio() then "Test buy"
			else "Soon"
	end
	for key, button in autoButtons do
		local owned = UIController.OwnsPass(key)
		local on = owned and UIController.AutoState[key]
		button.BackgroundColor3 = if on then COLORS.Green elseif owned then COLORS.Grey else COLORS.Purple
		local short = if key == "AutoTrain" then "Train" else "Fling"
		button.Text = "Auto\n" .. short .. "\n" .. (if on then "ON" elseif owned then "OFF" else "R$")
	end
end

local function buildPasses()
	local list
	passesPanel, list = buildPanel("PassesPanel", "Game Passes")
	starterRow, starterButton = row(list, 0, Products.StarterPack.Name, Products.StarterPack.Description)
	starterRow.BackgroundColor3 = Color3.fromRGB(150, 110, 20)
	starterButton.BackgroundColor3 = COLORS.Green
	starterButton.Activated:Connect(function()
		UIController.PromptProduct("StarterPack")
	end)
	for i, pass in Passes.Sorted() do
		local _, button = row(list, i, pass.Name, pass.Description)
		button.Activated:Connect(function()
			-- In Studio, unconfigured passes toggle on and off for testing.
			local studioToggle = RunService:IsStudio() and pass.GamePassId == 0
			if studioToggle or not UIController.OwnsPass(pass.Key) then
				UIController.PromptPass(pass.Key)
			end
		end)
		passRows[pass.Key] = button
	end
	refreshPasses()
end

-- The next upgrade you can afford (or a quest pointing at the Shop) makes the
-- Shop button bounce with a "!" badge, so there's always something to aim for.
local function nextAffordable(): boolean
	local coins = player:GetAttribute("Coins") or 0
	local rock = Shop.Rocks[(player:GetAttribute("RockTier") or 1) + 1]
	local shovel = Shop.Shovels[(player:GetAttribute("ShovelTier") or 1) + 1]
	return (rock ~= nil and coins >= rock.Price) or (shovel ~= nil and coins >= shovel.Price)
end

local function refreshShopAttention()
	-- During the tutorial only the quest decides, so the Shop doesn't compete with the guide line.
	local guided = player:GetAttribute("QuestGuide") == "Shop"
	local want = guided or (not player:GetAttribute("QuestTutorial") and nextAffordable())
	if want == shopAttention then
		return
	end
	shopAttention = want
	shopBadge.Visible = want
	if want then
		task.spawn(function()
			local scale = shopButton:FindFirstChild("Pulse") :: UIScale
			while shopAttention do
				TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Sine), { Scale = 1.12 })
					:Play()
				task.wait(0.35)
				TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Sine), { Scale = 1 }):Play()
				task.wait(0.55)
			end
		end)
	end
end

local function buildSideButtons()
	local column = make("Frame", {
		Name = "SideButtons",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.45, 0),
		Size = UDim2.fromOffset(86, 4 * 86 + 3 * 8),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	shopButton = bigButton({
		LayoutOrder = 1,
		Size = UDim2.fromOffset(86, 86),
		Text = "Shop",
		BackgroundColor3 = COLORS.Blue,
		Parent = column,
	})
	make("UIScale", { Name = "Pulse", Parent = shopButton })
	shopBadge = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 6, 0, 6),
		Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = COLORS.Red,
		Font = FONT,
		Text = "!",
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Visible = false,
		ZIndex = 5,
		Parent = shopButton,
	}, { corner(16), stroke(2) })
	shopButton.Activated:Connect(function()
		local open = not shopPanel.Visible
		closeAllPanels()
		shopPanel.Visible = open
		refreshShop()
	end)

	local passButton = bigButton({
		LayoutOrder = 2,
		Size = UDim2.fromOffset(86, 86),
		Text = "Passes",
		BackgroundColor3 = COLORS.Purple,
		Parent = column,
	})
	passButton.Activated:Connect(function()
		local open = not passesPanel.Visible
		closeAllPanels()
		passesPanel.Visible = open
		refreshPasses()
	end)

	for i, key in { "AutoTrain", "AutoFling" } do
		local button = bigButton({
			LayoutOrder = 2 + i,
			Size = UDim2.fromOffset(86, 86),
			Text = "",
			Parent = column,
		})
		button.Activated:Connect(function()
			if UIController.OwnsPass(key) then
				UIController.AutoState[key] = not UIController.AutoState[key]
				refreshPasses()
			else
				UIController.PromptPass(key)
			end
		end)
		autoButtons[key] = button
	end
end

-- Welcome-back popup ---------------------------------------------------------------

local function formatDuration(seconds: number): string
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	if hours > 0 then
		return hours .. "h " .. minutes .. "m"
	end
	return math.max(minutes, 1) .. "m"
end

function UIController.ShowOfflinePopup(coins: number, seconds: number)
	local popup = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(440, 240),
		BackgroundColor3 = COLORS.Panel,
		ZIndex = 20,
		Parent = gui,
	}, { corner(20), stroke(4) })
	label({
		Position = UDim2.fromOffset(20, 14),
		Size = UDim2.new(1, -40, 0, 46),
		Text = "Welcome back!",
		ZIndex = 21,
		Parent = popup,
	})
	label({
		Position = UDim2.fromOffset(20, 66),
		Size = UDim2.new(1, -40, 0, 70),
		Text = "Your dinos earned "
			.. FormatNumber(coins)
			.. " coins\nwhile you were away ("
			.. formatDuration(seconds)
			.. ")",
		TextColor3 = COLORS.Coins,
		ZIndex = 21,
		Parent = popup,
	})
	local collect = bigButton({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(220, 70),
		Text = "Collect!",
		BackgroundColor3 = COLORS.Green,
		ZIndex = 21,
		Parent = popup,
	})
	collect.Activated:Connect(function()
		popup:Destroy()
	end)
end

-- Shared building blocks for the other controllers ----------------------------------

UIController.Make = make
UIController.Label = label
UIController.Button = bigButton
UIController.Corner = corner
UIController.Stroke = stroke
UIController.Colors = COLORS
UIController.Font = FONT

function UIController.Gui(): ScreenGui
	return gui
end

-- Start --------------------------------------------------------------------------

function UIController.Start()
	local playerGui = player:WaitForChild("PlayerGui")
	gui = make("ScreenGui", {
		Name = "HUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	uiScale = make("UIScale", { Parent = gui })
	updateScale()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end

	buildTopBar()
	buildToasts()
	buildActionButton()
	buildMeter()
	buildShop()
	buildPasses()
	buildSideButtons()

	refreshStats()
	refreshPasses()
	for _, attribute in { "Coins", "IncomePerSec", "Strength" } do
		player:GetAttributeChangedSignal(attribute):Connect(refreshStats)
	end
	for _, attribute in { "Coins", "RockTier", "ShovelTier" } do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			if shopPanel.Visible then
				refreshShop()
			end
		end)
	end
	player.AttributeChanged:Connect(function(name)
		if string.sub(name, 1, 5) == "Pass_" or name == "StarterPackBought" then
			refreshPasses()
		end
	end)

	Remotes.Get("Notify").OnClientEvent:Connect(UIController.Toast)
	Remotes.Get("OfflineEarned").OnClientEvent:Connect(UIController.ShowOfflinePopup)

	task.spawn(function()
		while true do
			refreshAction()
			refreshShopAttention()
			task.wait(0.1)
		end
	end)
end

return UIController
