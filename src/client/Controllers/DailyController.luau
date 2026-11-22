-- DailyController.luau
-- The daily streak popup: a row of 7 day cards with today's highlighted and a
-- Claim button. Opens by itself on join when today's reward is ready (after
-- the tutorial). There's no button for it, to keep the screen clean: the
-- popup only needs one tap.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Daily = require(ReplicatedStorage.Shared.Config.Daily)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local DailyController = {}

local UI
local popup: Frame? = nil
local shownThisSession = false

local function closePopup()
	if popup then
		popup:Destroy()
		popup = nil
	end
end

local function openPopup()
	closePopup()
	local ready = player:GetAttribute("DailyReady") == true
	local index = player:GetAttribute("DailyIndex") or 1
	local streak = player:GetAttribute("DailyStreak") or 1

	local frame = UI.Make("Frame", {
		Name = "Daily",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(620, 260),
		BackgroundColor3 = UI.Colors.Panel,
		ZIndex = 20,
		Parent = UI.Gui(),
	}, { UI.Corner(20), UI.Stroke(4, UI.Colors.Blue) })
	popup = frame
	local scale = UI.Make("UIScale", { Scale = 0.3, Parent = frame })
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()

	UI.Label({
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -90, 0, 40),
		Text = if ready then "Daily reward! Day " .. streak .. " streak" else "Come back tomorrow!",
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 21,
		Parent = frame,
	})
	local x = UI.Button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(48, 48),
		Text = "X",
		BackgroundColor3 = UI.Colors.Red,
		ZIndex = 21,
		Parent = frame,
	})
	x.Activated:Connect(closePopup)

	local row = UI.Make("Frame", {
		Position = UDim2.fromOffset(12, 62),
		Size = UDim2.new(1, -24, 0, 100),
		BackgroundTransparency = 1,
		ZIndex = 21,
		Parent = frame,
	}, {
		UI.Make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for day, entry in Daily do
		local claimedAlready = day < index or (day == index and not ready)
		local isToday = day == index and ready
		local card = UI.Make("Frame", {
			LayoutOrder = day,
			Size = UDim2.new(1 / #Daily, -6, 1, 0),
			BackgroundColor3 = if isToday
				then UI.Colors.Green
				elseif claimedAlready then UI.Colors.Grey
				else UI.Colors.PanelLight,
			ZIndex = 22,
			Parent = row,
		}, { UI.Corner(12), if isToday then UI.Stroke(3, Color3.new(1, 1, 1)) else nil })
		UI.Label({
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.new(1, -8, 0, 26),
			Text = "Day " .. day,
			ZIndex = 23,
			Parent = card,
		})
		UI.Label({
			Position = UDim2.fromOffset(4, 34),
			Size = UDim2.new(1, -8, 1, -40),
			Text = if claimedAlready then "Done" else entry.Text,
			TextWrapped = true,
			ZIndex = 23,
			Parent = card,
		})
	end

	local claim = UI.Button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(240, 66),
		Text = if ready then "Claim!" else "OK",
		BackgroundColor3 = if ready then UI.Colors.Green else UI.Colors.Grey,
		ZIndex = 21,
		Parent = frame,
	})
	claim.Activated:Connect(function()
		if ready then
			Remotes.Get("ClaimDaily"):FireServer()
		end
		closePopup()
	end)
end

-- Opens by itself once per session when today's reward is ready, after the tutorial.
local function check()
	local ready = player:GetAttribute("DailyReady") == true
	if ready and not shownThisSession and player:GetAttribute("QuestTutorial") == false then
		shownThisSession = true
		task.delay(3, openPopup)
	end
end

function DailyController.Start(Controllers)
	UI = Controllers.UIController
	for _, attribute in { "DailyReady", "QuestTutorial" } do
		player:GetAttributeChangedSignal(attribute):Connect(check)
	end
	check()
end

return DailyController
