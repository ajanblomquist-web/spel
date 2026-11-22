-- QuestController.luau
-- Left side of the screen: the current quest card (with progress bar and
-- reward), the playtime gift button, and timers for active 2x boosts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local FormatNumber = require(ReplicatedStorage.Shared.Util.FormatNumber)
local Gifts = require(ReplicatedStorage.Shared.Config.Gifts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local QuestController = {}

local UI
local card: Frame
local titleLabel: TextLabel
local textLabel: TextLabel
local barFill: Frame
local barLabel: TextLabel
local rewardLabel: TextLabel
local giftButton: TextButton
local boostList: Frame
local boostLabels: { [string]: TextLabel } = {}

local BOOST_COLORS = {
	Luck = Color3.fromRGB(90, 200, 110),
	Coins = Color3.fromRGB(230, 180, 40),
	Strength = Color3.fromRGB(240, 110, 80),
}

local function formatTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function build()
	local gui = UI.Gui()
	card = UI.Make("Frame", {
		Name = "Quest",
		Position = UDim2.fromOffset(10, 60),
		Size = UDim2.fromOffset(250, 104),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.1,
		Parent = gui,
	}, { UI.Corner(16), UI.Stroke(3) })
	titleLabel = UI.Label({
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 20),
		Text = "QUEST",
		TextColor3 = Color3.fromRGB(120, 220, 255),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})
	textLabel = UI.Label({
		Position = UDim2.fromOffset(12, 28),
		Size = UDim2.new(1, -24, 0, 26),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})
	local bar = UI.Make("Frame", {
		Position = UDim2.fromOffset(12, 58),
		Size = UDim2.new(1, -24, 0, 18),
		BackgroundColor3 = Color3.fromRGB(20, 18, 28),
		Parent = card,
	}, { UI.Corner(9) })
	barFill = UI.Make("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = UI.Colors.Green,
		Parent = bar,
	}, { UI.Corner(9) })
	barLabel = UI.Label({
		Size = UDim2.fromScale(1, 1),
		Text = "",
		ZIndex = 2,
		Parent = bar,
	})
	rewardLabel = UI.Label({
		Position = UDim2.fromOffset(12, 80),
		Size = UDim2.new(1, -24, 0, 18),
		Text = "",
		TextColor3 = UI.Colors.Coins,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})

	giftButton = UI.Button({
		Name = "Gift",
		Position = UDim2.fromOffset(10, 172),
		Size = UDim2.fromOffset(86, 86),
		Text = "Gift",
		BackgroundColor3 = UI.Colors.Grey,
		Parent = gui,
	})
	giftButton.Activated:Connect(function()
		Remotes.Get("ClaimGift"):FireServer()
	end)

	boostList = UI.Make("Frame", {
		Position = UDim2.fromOffset(104, 172),
		Size = UDim2.fromOffset(170, 110),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { UI.Make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
	for i, name in { "Luck", "Coins", "Strength" } do
		local pill = UI.Make("Frame", {
			LayoutOrder = i,
			Size = UDim2.fromOffset(170, 32),
			BackgroundColor3 = BOOST_COLORS[name],
			Visible = false,
			Parent = boostList,
		}, { UI.Corner(16), UI.Stroke(2) })
		boostLabels[name] = UI.Label({
			Position = UDim2.fromOffset(8, 3),
			Size = UDim2.new(1, -16, 1, -6),
			Text = "",
			Parent = pill,
		})
	end
end

local lastIndex = nil

local function refreshQuest()
	local index = player:GetAttribute("QuestIndex")
	local text = player:GetAttribute("QuestText")
	card.Visible = text ~= nil
	if not text then
		return
	end
	local progress = player:GetAttribute("QuestProgress") or 0
	local target = math.max(player:GetAttribute("QuestTarget") or 1, 1)
	local unit = player:GetAttribute("QuestUnit") or ""
	titleLabel.Text = if player:GetAttribute("QuestTutorial") then "TUTORIAL" else "QUEST"
	textLabel.Text = text
	barLabel.Text = FormatNumber(progress) .. unit .. " / " .. FormatNumber(target) .. unit
	TweenService
		:Create(
			barFill,
			TweenInfo.new(0.25),
			{ Size = UDim2.fromScale(math.clamp(progress / target, 0, 1), 1) }
		)
		:Play()
	local reward = player:GetAttribute("QuestReward")
	rewardLabel.Text = if reward then "Reward: " .. reward else ""

	if index ~= lastIndex then
		-- New quest: pop the card.
		lastIndex = index
		local scale = card:FindFirstChildOfClass("UIScale") or UI.Make("UIScale", { Parent = card })
		scale.Scale = 1.15
		TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
end

local function refreshTimers()
	local now = Workspace:GetServerTimeNow()

	-- Gift button
	local nextIndex = player:GetAttribute("NextGift")
	local gift = nextIndex and Gifts[nextIndex]
	local startedAt = player:GetAttribute("SessionStartServer")
	-- Hidden during the tutorial so new players see one thing at a time.
	if not gift or not startedAt or player:GetAttribute("QuestTutorial") then
		giftButton.Visible = false
	else
		giftButton.Visible = true
		local scale = player:GetAttribute("GiftTimeScale") or 1
		local left = startedAt + gift.Minutes * 60 * scale - now
		if left <= 0 then
			giftButton.Text = "Gift\nOPEN!"
			giftButton.BackgroundColor3 = UI.Colors.Green
			giftButton.Rotation = math.sin(os.clock() * 8) * 6
		else
			giftButton.Text = "Gift\n" .. formatTime(left)
			giftButton.BackgroundColor3 = UI.Colors.Grey
			giftButton.Rotation = 0
		end
	end

	-- Boost timers
	for name, label in boostLabels do
		local endsAt = player:GetAttribute("Boost_" .. name)
		local pill = label.Parent :: Frame
		if endsAt and endsAt > now then
			pill.Visible = true
			label.Text = "2x " .. name .. "  " .. formatTime(endsAt - now)
		else
			pill.Visible = false
		end
	end
end

function QuestController.Start(Controllers)
	UI = Controllers.UIController
	build()
	refreshQuest()
	player.AttributeChanged:Connect(function(name)
		if string.sub(name, 1, 5) == "Quest" then
			refreshQuest()
		end
	end)
	task.spawn(function()
		while true do
			refreshTimers()
			task.wait(0.1)
		end
	end)
end

return QuestController
